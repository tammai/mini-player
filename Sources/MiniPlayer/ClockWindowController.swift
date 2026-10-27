import AppKit
import Combine
import MiniPlayerCore
import SwiftUI

/// A second desktop window for the clock. It sits just outside the card at one of twelve anchors
/// and follows the card when it moves. It stays visible when nothing is playing, since it is a clock.
@MainActor
final class ClockWindowController {
    private let model: AppModel
    private let store: ConfigStore
    private let cardWindow: NSWindow
    private let window: NSWindow
    private let geometry: CardGeometry
    private var config: ClockSettings
    private var size = CGSize(width: 260, height: 160)
    private var editing = false
    private var cancellables: Set<AnyCancellable> = []
    private var observers: [NSObjectProtocol] = []

    init(model: AppModel, store: ConfigStore, cardWindow: NSWindow, geometry: CardGeometry) {
        self.model = model
        self.store = store
        self.cardWindow = cardWindow
        self.geometry = geometry
        config = store.config.clock

        window = NSWindow(contentRect: NSRect(origin: .zero, size: size),
                          styleMask: [.borderless], backing: .buffered, defer: false)
        window.isOpaque = false
        window.backgroundColor = .clear
        window.hasShadow = false
        window.level = CardWindowController.restingLevel
        window.collectionBehavior = [.canJoinAllSpaces, .stationary, .ignoresCycle, .fullScreenAuxiliary]
        window.ignoresMouseEvents = true  // the clock is placed by anchor, never dragged
        window.alphaValue = 0
        window.isReleasedWhenClosed = false
        let hosting = NSHostingView(rootView: ClockView(store: store, geometry: geometry, onSize: { [weak self] size in
            self?.sizeChanged(size)
        }))
        hosting.sizingOptions = []  // the window follows the size we measure, not the other way round
        window.contentView = hosting

        store.$config.map(\.clock).removeDuplicates()
            .sink { [weak self] new in
                self?.config = new
                self?.reposition()
                self?.sync()
            }
            .store(in: &cancellables)
        model.objectWillChange
            .receive(on: DispatchQueue.main)
            .sink { [weak self] in self?.sync() }
            .store(in: &cancellables)

        // Follow the card wherever it goes.
        let center = NotificationCenter.default
        for name in [NSWindow.didMoveNotification, NSWindow.didResizeNotification] {
            observers.append(center.addObserver(forName: name, object: cardWindow, queue: .main) { [weak self] _ in
                MainActor.assumeIsolated { self?.reposition() }
            })
        }
        observers.append(center.addObserver(forName: NSApplication.didChangeScreenParametersNotification, object: nil, queue: .main) { [weak self] _ in
            MainActor.assumeIsolated { self?.reposition() }
        })
        reposition()
        sync()
    }

    /// The clock reports its size from inside its own SwiftUI update. Resizing the window right there
    /// forces a layout, which updates the view, which reports again: a feedback loop that pinned the
    /// main thread at 90% CPU and starved every other window. So unchanged sizes are ignored and the
    /// window follows on the next run loop turn, outside the update.
    private func sizeChanged(_ new: CGSize) {
        guard new.width > 0, new.height > 0 else { return }
        guard abs(new.width - size.width) > 0.5 || abs(new.height - size.height) > 0.5 else { return }
        size = new
        DispatchQueue.main.async { [weak self] in
            MainActor.assumeIsolated {
                self?.reposition()
                self?.publishSize()
            }
        }
    }

    /// Tells the card how big the clock is, or that there is none, so the pair can be centered on a point.
    private func publishSize() {
        let value: CGSize? = (config.enabled && !model.hidden) ? size : nil
        if geometry.clockSize != value { geometry.clockSize = value }  // @Published fires even for equal values
    }

    /// Places the clock relative to the card's frame, which persists even while the card is hidden,
    /// so the clock does not jump when the card fades out.
    private func reposition() {
        let card = cardWindow.frame
        let center = CGPoint(x: card.midX, y: card.midY)
        let area = (NSScreen.screens.first { $0.frame.contains(center) } ?? NSScreen.main)?.visibleFrame
        let origin = ClockLayout.origin(anchor: config.anchor, card: card, clock: size, gap: config.gap,
                                        offsetX: config.offsetX, offsetY: config.offsetY, in: area)
        let frame = NSRect(origin: origin, size: size)
        if frame != window.frame { window.setFrame(frame, display: true) }
    }

    private func sync() {
        publishSize()
        let nowEditing = model.editMode
        if nowEditing != editing {
            editing = nowEditing
            // In Edit mode the card floats above windows, so the clock does too, to be seen with it.
            window.level = nowEditing ? CardWindowController.editingLevel : CardWindowController.restingLevel
        }
        let visible = config.enabled && !model.hidden
        let target: CGFloat = visible ? 1 : 0
        guard window.alphaValue != target || (visible && !window.isVisible) else { return }
        if visible { window.orderFrontRegardless() }
        NSAnimationContext.runAnimationGroup { context in
            context.duration = 0.3
            window.animator().alphaValue = target
        } completionHandler: { [weak self] in
            MainActor.assumeIsolated {
                guard let self, !(self.config.enabled && !self.model.hidden) else { return }
                self.window.orderOut(nil)
            }
        }
    }
}
