import AppKit
import SwiftUI

/// The settings window. The card sits at the desktop level, so the window is parked at the
/// top right of the screen, away from where the card normally lives.
///
/// Its size comes from the SwiftUI content (the tab bar's natural width), so it is placed again
/// whenever it resizes, until the user moves it themselves.
@MainActor
final class SettingsWindowController: NSObject, NSWindowDelegate {
    private var window: NSWindow?
    private let store: ConfigStore
    private let login: LoginItemController
    private let clockTint: WallpaperTint
    private let accentTint: WallpaperTint
    private var placing = false
    private var movedByUser = false

    /// Called when the window closes.
    var onClose: (() -> Void)?

    init(store: ConfigStore, login: LoginItemController, clockTint: WallpaperTint, accentTint: WallpaperTint) {
        self.store = store
        self.login = login
        self.clockTint = clockTint
        self.accentTint = accentTint
    }

    var isOpen: Bool { window?.isVisible ?? false }

    func show() {
        if window == nil {
            let window = NSWindow(contentViewController: NSHostingController(rootView: SettingsView(store: store, login: login, clockTint: clockTint, accentTint: accentTint)))
            window.title = "mini-player Settings"
            window.styleMask = [.titled, .closable, .miniaturizable]
            window.isReleasedWhenClosed = false
            window.delegate = self
            self.window = window
            place()
        }
        NSApp.activate()
        window?.makeKeyAndOrderFront(nil)
    }

    /// Top right of the main screen, 24 pt in from the edge.
    private func place() {
        guard let window, let area = NSScreen.main?.visibleFrame else { return }
        placing = true
        window.setFrameTopLeftPoint(NSPoint(x: area.maxX - window.frame.width - 24, y: area.maxY - 24))
        placing = false
    }

    func windowDidResize(_ notification: Notification) {
        if !movedByUser { place() }  // keep the right edge where it was while the width settles
    }

    func windowDidMove(_ notification: Notification) {
        if !placing { movedByUser = true }
    }

    func windowWillClose(_ notification: Notification) {
        onClose?()
    }
}
