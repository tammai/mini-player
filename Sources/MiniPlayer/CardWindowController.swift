import AppKit
import Combine
import SwiftUI

/// Owns the borderless glass window that sits on the desktop, between the wallpaper and the icons.
@MainActor
final class CardWindowController {
    private let model: AppModel
    private let window: NSWindow
    private var cancellables: Set<AnyCancellable> = []
    private var wasEditing = false

    /// One above the wallpaper, below the desktop icons. Finder keeps a full-screen window at the
    /// icon level, so at this level the card can never receive a click: it is click-through by
    /// construction.
    private static let restingLevel = NSWindow.Level(rawValue: Int(CGWindowLevelForKey(.desktopWindow)) + 1)

    /// In Edit mode the card has to be reachable, so it floats above every window.
    private static let editingLevel = NSWindow.Level.floating

    private static let originKey = "windowOrigin"
    private static let size = NSSize(width: 540, height: 164)

    init(model: AppModel) {
        self.model = model

        window = NSWindow(contentRect: NSRect(origin: Self.initialOrigin(), size: Self.size),
                          styleMask: [.borderless], backing: .buffered, defer: false)
        window.isOpaque = false
        window.backgroundColor = .clear
        window.hasShadow = false
        window.level = Self.restingLevel
        window.collectionBehavior = [.canJoinAllSpaces, .stationary, .ignoresCycle, .fullScreenAuxiliary]
        window.ignoresMouseEvents = true
        window.alphaValue = 0
        window.isReleasedWhenClosed = false

        let glass = NSGlassEffectView(frame: NSRect(origin: .zero, size: Self.size))
        glass.cornerRadius = 28
        glass.contentView = NSHostingView(rootView: CardView(model: model))
        window.contentView = glass

        // objectWillChange fires before the value changes, so hop to the next
        // run loop turn and read the settled state.
        model.objectWillChange
            .receive(on: DispatchQueue.main)
            .sink { [weak self] in self?.sync() }
            .store(in: &cancellables)
        sync()
    }

    /// Fades the card in or out and toggles Edit mode behavior (draggable, takes clicks).
    private func sync() {
        let editing = model.editMode
        if editing != wasEditing {
            window.level = editing ? Self.editingLevel : Self.restingLevel
            window.ignoresMouseEvents = !editing
            window.isMovableByWindowBackground = editing
            if !editing { saveOrigin() }
            wasEditing = editing
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

    private func saveOrigin() {
        UserDefaults.standard.set(NSStringFromPoint(window.frame.origin), forKey: Self.originKey)
    }

    private static func initialOrigin() -> NSPoint {
        if let saved = UserDefaults.standard.string(forKey: originKey) {
            return NSPointFromString(saved)
        }
        let area = NSScreen.main?.visibleFrame ?? .zero
        return NSPoint(x: area.minX + 60, y: area.minY + 60)
    }
}
