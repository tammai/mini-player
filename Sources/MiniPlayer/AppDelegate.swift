import AppKit
import Combine
import MiniPlayerCore

@MainActor
final class AppDelegate: NSObject, NSApplicationDelegate, NSMenuDelegate {
    private let model = AppModel()
    private let store = ConfigStore()
    private let loginItem = LoginItemController()
    /// One tint for the clock and one for the card's accent: each looks at its own patch of wallpaper.
    private let clockTint = WallpaperTint()
    private let accentTint = WallpaperTint()
    private var statusItem: NSStatusItem!
    private var cardWindow: CardWindowController!
    private var clockWindow: ClockWindowController!
    private var settings: SettingsWindowController!
    private var editModeBeforeSettings = false
    private var cancellables: Set<AnyCancellable> = []
    private var adapter: AdapterProcess?

    private let statusMessageItem = NSMenuItem()
    private let visibilityItem = NSMenuItem()
    private let positionItem = NSMenuItem(title: "Change Position", action: nil, keyEquivalent: "")
    private let customItem = NSMenuItem()
    private var anchorItems: [ScreenAnchor: NSMenuItem] = [:]
    private let configProblemItem = NSMenuItem()

    private var signalSources: [DispatchSourceSignal] = []

    func applicationDidFinishLaunching(_ notification: Notification) {
        // Quit through the normal path on SIGTERM/SIGINT so the adapter child is stopped too.
        for sig in [SIGTERM, SIGINT] {
            signal(sig, SIG_IGN)
            let source = DispatchSource.makeSignalSource(signal: sig, queue: .main)
            source.setEventHandler { NSApp.terminate(nil) }
            source.resume()
            signalSources.append(source)
        }
        cardWindow = CardWindowController(model: model, store: store, accentTint: accentTint)
        clockWindow = ClockWindowController(model: model, store: store, cardWindow: cardWindow.window, geometry: cardWindow.geometry,
                                           tint: clockTint)
        settings = SettingsWindowController(store: store, login: loginItem, clockTint: clockTint, accentTint: accentTint)
        settings.onClose = { [weak self] in
            guard let self else { return }
            model.setEditMode(editModeBeforeSettings)  // leave Edit mode if opening Settings was what entered it
        }

        // Settings that act on the app rather than on how it looks.
        store.$config.map(\.general.pauseTimeout).removeDuplicates()
            .sink { [model] in model.setPauseTimeout($0) }
            .store(in: &cancellables)
        store.$config.map(\.general.launchAtLogin).removeDuplicates()
            .sink { [loginItem] in loginItem.apply(enabled: $0) }
            .store(in: &cancellables)

        buildStatusItem()
        startAdapter()
    }

    func applicationWillTerminate(_ notification: Notification) {
        adapter?.stop()
    }

    // MARK: Menu bar

    private func buildStatusItem() {
        statusItem = NSStatusBar.system.statusItem(withLength: NSStatusItem.squareLength)
        statusItem.button?.image = NSImage(systemSymbolName: "waveform", accessibilityDescription: "mini-player")

        let menu = NSMenu()
        menu.delegate = self
        statusMessageItem.isEnabled = false
        visibilityItem.action = #selector(toggleVisibility)
        visibilityItem.target = self
        positionItem.submenu = buildPositionMenu()
        configProblemItem.isEnabled = false
        menu.addItem(statusMessageItem)
        menu.addItem(configProblemItem)
        menu.addItem(visibilityItem)
        menu.addItem(positionItem)
        let settingsItem = NSMenuItem(title: "Settings…", action: #selector(openSettings), keyEquivalent: ",")
        settingsItem.target = self
        menu.addItem(settingsItem)
        let folderItem = NSMenuItem(title: "Show Config in Finder", action: #selector(showConfig), keyEquivalent: "")
        folderItem.target = self
        menu.addItem(folderItem)
        menu.addItem(.separator())
        menu.addItem(NSMenuItem(title: "Quit mini-player", action: #selector(NSApplication.terminate(_:)), keyEquivalent: "q"))
        statusItem.menu = menu
    }

    func menuWillOpen(_ menu: NSMenu) {
        switch model.adapterStatus {
        case .starting: statusMessageItem.isHidden = true
        case .ready: statusMessageItem.isHidden = true
        case .unavailable(let reason):
            statusMessageItem.title = reason
            statusMessageItem.isHidden = false
        }
        configProblemItem.title = "Config file is not valid JSON, using defaults"
        configProblemItem.isHidden = store.problem == nil
        visibilityItem.title = model.hidden ? "Show Widget" : "Hide Widget"
        let current = store.config.position.anchor
        customItem.state = current == nil ? .on : .off
        customItem.title = model.editMode ? "Custom - Finish Dragging" : "Custom"
        for (anchor, item) in anchorItems { item.state = anchor == current ? .on : .off }
    }

    @objc private func toggleVisibility() { model.setHidden(!model.hidden) }

    // MARK: Change Position

    private func buildPositionMenu() -> NSMenu {
        let menu = NSMenu(title: "Change Position")
        customItem.title = "Custom"
        customItem.action = #selector(chooseCustomPosition)
        customItem.target = self
        menu.addItem(customItem)
        for anchor in ScreenAnchor.menuOrder {
            let item = NSMenuItem(title: anchor.menuTitle, action: #selector(chooseAnchor(_:)), keyEquivalent: "")
            item.target = self
            item.representedObject = anchor.rawValue
            anchorItems[anchor] = item
            menu.addItem(item)
        }
        return menu
    }

    /// Custom keeps the card where it is and lets you drag it: it turns the current spot into a custom
    /// position and enters Edit mode. Choosing it again, while dragging, finishes.
    @objc private func chooseCustomPosition() {
        if store.config.position.anchor != nil {
            store.makePositionCustom()
            model.setEditMode(true)
        } else {
            model.setEditMode(!model.editMode)
        }
    }

    @objc private func chooseAnchor(_ item: NSMenuItem) {
        guard let raw = item.representedObject as? String, let anchor = ScreenAnchor(rawValue: raw) else { return }
        store.config.position.anchor = anchor
    }
    @objc private func showConfig() { store.revealInFinder() }

    /// Opening Settings turns Edit mode on, so the card floats above the settings window with demo
    /// content: you see every change live, even when nothing is playing.
    @objc private func openSettings() {
        if !settings.isOpen {
            editModeBeforeSettings = model.editMode
            model.setEditMode(true)
        }
        settings.show()
    }

    // MARK: Adapter

    private func startAdapter() {
        guard let paths = AdapterPaths.locate() else {
            model.setAdapterStatus(.unavailable("Adapter not found (see README)"))
            return
        }
        Task { @MainActor in
            guard await AdapterProcess.selfTest(paths) else {
                model.setAdapterStatus(.unavailable("Now playing unavailable on this macOS version"))
                return
            }
            model.setAdapterStatus(.ready)
            let adapter = AdapterProcess(paths: paths) { [model] line in model.handle(line: line) }
            self.adapter = adapter
            adapter.start()
        }
    }
}
