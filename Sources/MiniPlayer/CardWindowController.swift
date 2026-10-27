import AppKit
import Combine
import MiniPlayerCore
import SwiftUI

extension NSScreen {
    /// A stable id for the display, so a saved position finds its screen again after a restart.
    var displayUUID: String? {
        guard let number = deviceDescription[NSDeviceDescriptionKey("NSScreenNumber")] as? NSNumber,
              let uuid = CGDisplayCreateUUIDFromDisplayID(number.uint32Value)?.takeRetainedValue()
        else { return nil }
        return CFUUIDCreateString(nil, uuid) as String?
    }
}

/// Owns the borderless glass window that sits on the desktop, between the wallpaper and the icons.
@MainActor
final class CardWindowController {
    let window: NSWindow

    private let model: AppModel
    private let store: ConfigStore
    private let accentTint: WallpaperTint
    private let background = CardBackgroundView()
    private var config: Config
    private var cancellables: Set<AnyCancellable> = []
    private var observers: [NSObjectProtocol] = []
    private var wasEditing = false
    private var contentSize = CGSize(width: CardView.baseWidth, height: 164)
    private var movingProgrammatically = false
    private var dropTimer: Timer?

    /// One above the wallpaper, below the desktop icons. Finder keeps a full-screen window at the
    /// icon level, so at this level the card can never receive a click: it is click-through by
    /// construction.
    static let restingLevel = NSWindow.Level(rawValue: Int(CGWindowLevelForKey(.desktopWindow)) + 1)

    /// In Edit mode the card has to be reachable, so it floats above every window.
    static let editingLevel = NSWindow.Level.floating

    let geometry = CardGeometry()

    init(model: AppModel, store: ConfigStore, accentTint: WallpaperTint) {
        self.model = model
        self.store = store
        self.accentTint = accentTint
        config = store.config

        window = NSWindow(contentRect: NSRect(origin: .zero, size: contentSize),
                          styleMask: [.borderless], backing: .buffered, defer: false)
        window.isOpaque = false
        window.backgroundColor = .clear
        window.hasShadow = false
        window.level = Self.restingLevel
        window.collectionBehavior = [.canJoinAllSpaces, .stationary, .ignoresCycle, .fullScreenAuxiliary]
        window.ignoresMouseEvents = true
        window.alphaValue = 0
        window.isReleasedWhenClosed = false

        let hosting = NSHostingView(rootView: CardView(
            model: model, store: store, accentTint: accentTint,
            onContentSize: { [weak self] size in self?.contentSizeChanged(size) }))
        // The window controller owns the window's size. By default the hosting view clamps the window
        // to SwiftUI's current min/max size, which lags a settings change by one edit.
        hosting.sizingOptions = []
        // The background and the content are siblings in a plain container, so the background follows
        // every window resize and its opacity can change without fading the text.
        let container = CardContainerView(frame: NSRect(origin: .zero, size: contentSize))
        container.autoresizesSubviews = false  // CardContainerView sets the frames itself
        for view in [background, hosting] { container.addSubview(view) }
        window.contentView = container
        applyBackground()
        applySize()
        reposition()

        // `$config` and `objectWillChange` fire before the value changes. The first hands us the new
        // value; the second is hopped to the next run loop turn so the settled state can be read.
        store.$config.removeDuplicates()
            .sink { [weak self] new in self?.configChanged(new) }
            .store(in: &cancellables)
        model.objectWillChange
            .receive(on: DispatchQueue.main)
            .sink { [weak self] in self?.sync() }
            .store(in: &cancellables)
        store.customPositionRequests
            .sink { [weak self] in self?.adoptCurrentSpotAsCustom() }
            .store(in: &cancellables)
        // The clock changing size (or appearing) moves the pair's center, so the card follows. Deferred so the
        // new value is in place, and so it never runs inside the clock's own update.
        geometry.$clockSize.removeDuplicates()
            .sink { [weak self] _ in
                DispatchQueue.main.async { MainActor.assumeIsolated { self?.updateFrame() } }
            }
            .store(in: &cancellables)

        let center = NotificationCenter.default
        observers.append(center.addObserver(forName: NSWindow.didMoveNotification, object: window, queue: .main) { [weak self] _ in
            MainActor.assumeIsolated { self?.windowMoved() }
        })
        observers.append(center.addObserver(forName: NSApplication.didChangeScreenParametersNotification, object: nil, queue: .main) { [weak self] _ in
            MainActor.assumeIsolated { self?.reposition() }
        })
        // Another Space can have another wallpaper behind the card, and nothing announces a changed wallpaper,
        // so look again on a Space change, and now and then ask, which only reads when the wallpaper setting changed.
        observers.append(NSWorkspace.shared.notificationCenter.addObserver(
            forName: NSWorkspace.activeSpaceDidChangeNotification, object: nil, queue: .main) { [weak self] _ in
            MainActor.assumeIsolated { self?.requestAccentTint(force: true) }
        })
        let refresher = Timer(timeInterval: 30, repeats: true) { [weak self] _ in
            MainActor.assumeIsolated { self?.requestAccentTint() }
        }
        RunLoop.main.add(refresher, forMode: .common)
        sync()
        requestAccentTint()
    }

    /// Samples the wallpaper behind the card, but only when the accent is tinted from it, so the Screen
    /// Recording permission is never requested for nothing.
    private func requestAccentTint(frame: NSRect? = nil, force: Bool = false) {
        guard config.accent.mode == .wallpaper else { return }
        accentTint.request(frame: frame ?? window.frame, opacity: 0.9, force: force)
    }

    // MARK: Config

    private func configChanged(_ new: Config) {
        let old = config
        config = new
        if new.card.scale != old.card.scale { applySize() }
        if new.card != old.card || new.background != old.background { applyBackground() }
        if new.accent != old.accent { requestAccentTint() }
        // Where the clock sits around the card changes the pair's bounds, and so where the card goes.
        if new.clock != old.clock && new.position == old.position { updateFrame() }
        // A new place glides there; a scale change just resizes.
        if new.position != old.position { reposition(animated: true) }
        else if new.card.scale != old.card.scale { reposition() }
    }

    private func applyBackground() {
        background.apply(config.background, cornerRadius: config.card.cornerRadius * config.card.scale)
    }

    /// SwiftUI reports the content's size from inside its own layout pass. Resizing the window right
    /// there is re-entrant: after a shrink the window drew its old contents offset and clipped. So
    /// the size is recorded now and the window follows on the next run loop turn.
    private func contentSizeChanged(_ size: CGSize) {
        contentSize = size
        DispatchQueue.main.async { [weak self] in
            MainActor.assumeIsolated { self?.updateFrame() }
        }
    }

    private func applySize() { updateFrame() }

    // MARK: Visibility and Edit mode

    /// Fades the card in or out and toggles Edit mode behavior (draggable, takes clicks).
    private func sync() {
        let editing = model.editMode
        if editing != wasEditing {
            if !editing { commitDrop() }  // a drag still waiting for its settle timer is saved now
            wasEditing = editing
            window.level = editing ? Self.editingLevel : Self.restingLevel
            window.ignoresMouseEvents = !editing
            window.isMovableByWindowBackground = editing
        }
        setVisible(model.cardVisible)
    }

    private func setVisible(_ visible: Bool) {
        let target: CGFloat = visible ? 1 : 0
        guard window.alphaValue != target || (visible && !window.isVisible) else { return }
        if visible { window.orderFrontRegardless() }
        NSAnimationContext.runAnimationGroup { context in
            context.duration = 0.3
            window.animator().alphaValue = target
        } completionHandler: { [weak self] in
            // AppKit calls this on the main thread.
            MainActor.assumeIsolated {
                guard let self, !self.model.cardVisible else { return }
                self.window.orderOut(nil)
            }
        }
    }

    // MARK: Position

    private func screen(for position: PositionSettings) -> NSScreen {
        NSScreen.screens.first { $0.displayUUID != nil && $0.displayUUID == position.display }
            ?? NSScreen.main ?? NSScreen.screens[0]
    }

    /// Sets the window's size and position in one step.
    ///
    /// The size is the measured content size times the scale. The position comes from the saved
    /// settings; if the saved display is not connected, the main display is used with the same
    /// relative position, and the saved display is kept so the card returns when that display does.
    ///
    /// Size and position change together in a single `setFrame`. Resizing and then moving as two
    /// steps left the window with stale contents after a shrink: the card drew offset and clipped.
    private func updateFrame(animated: Bool = false) {
        let scale = config.card.scale
        let size = CGSize(width: contentSize.width * scale, height: contentSize.height * scale)
        let area = screen(for: config.position).visibleFrame
        let origin = PositionResolver.origin(for: config.position, cardSize: size, group: groupBounds(cardSize: size), in: area)
        let frame = NSRect(origin: origin, size: size)
        let current = window.frame
        let unchanged = abs(frame.minX - current.minX) < 0.5 && abs(frame.minY - current.minY) < 0.5
            && abs(frame.width - current.width) < 0.5 && abs(frame.height - current.height) < 0.5
        guard !unchanged else { return }

        movingProgrammatically = true
        if animated && window.isVisible {
            NSAnimationContext.runAnimationGroup { context in
                context.duration = 0.2
                // Only setFrame animates through the window's animator; setFrameOrigin silently does not.
                window.animator().setFrame(frame, display: true)
            } completionHandler: { [weak self] in
                MainActor.assumeIsolated { self?.movingProgrammatically = false }
            }
        } else {
            window.setFrame(frame, display: true)
            movingProgrammatically = false
        }
        applyBackground()
        requestAccentTint(frame: frame)  // it is over a different part of the wallpaper now
        if geometry.size != size { geometry.size = size }  // @Published fires even for equal values
    }

    private func reposition(animated: Bool = false) { updateFrame(animated: animated) }

    /// The card and the clock together, relative to the card's origin. This is what gets centered on a point.
    private func groupBounds(cardSize: CGSize) -> CGRect {
        let c = config.clock
        return ClockLayout.groupBounds(card: cardSize, clock: geometry.clockSize, anchor: c.anchor,
                                       gap: c.gap, offsetX: c.offsetX, offsetY: c.offsetY)
    }

    /// Dragging fires a stream of move events; once they stop for a moment the drop is committed.
    private func windowMoved() {
        guard wasEditing, !movingProgrammatically else { return }
        dropTimer?.invalidate()
        dropTimer = Timer.scheduledTimer(withTimeInterval: 0.25, repeats: false) { [weak self] _ in
            MainActor.assumeIsolated { self?.commitDrop() }
        }
    }

    /// "Custom" from the menu or the grid: keep the card exactly where it is and store that spot as a
    /// custom position, so it no longer jumps back to a named place.
    private func adoptCurrentSpotAsCustom() {
        let frame = window.frame
        let center = CGPoint(x: frame.midX, y: frame.midY)
        let screen = NSScreen.screens.first { $0.frame.contains(center) } ?? NSScreen.main ?? NSScreen.screens[0]
        var base = store.config.position
        base.display = screen.displayUUID
        let keepSnap = base.snap
        base.snap = false  // do not let it snap into a corner: the point is to stay put
        var position = PositionResolver.position(forDropAt: frame.origin, cardSize: frame.size,
                                                 group: groupBounds(cardSize: frame.size),
                                                 in: screen.visibleFrame, keeping: base)
        position.snap = keepSnap
        store.config.position = position
    }

    /// Stores where the card was dropped, snapping to a grid point when the card and clock are centered near one.
    private func commitDrop() {
        guard dropTimer != nil else { return }
        dropTimer?.invalidate()
        dropTimer = nil
        let frame = window.frame
        let center = CGPoint(x: frame.midX, y: frame.midY)
        let screen = NSScreen.screens.first { $0.frame.contains(center) } ?? NSScreen.main ?? NSScreen.screens[0]
        var base = store.config.position
        base.display = screen.displayUUID
        let position = PositionResolver.position(forDropAt: frame.origin, cardSize: frame.size,
                                                 group: groupBounds(cardSize: frame.size),
                                                 in: screen.visibleFrame, keeping: base)
        store.config.position = position
        reposition(animated: true)  // settles into the corner even when the stored position did not change
    }
}
