import AppKit
import MiniPlayerCore

@MainActor
final class AppDelegate: NSObject, NSApplicationDelegate, NSMenuDelegate {
    private let model = AppModel()
    private var statusItem: NSStatusItem!
    private var cardWindow: CardWindowController!
    private var adapter: AdapterProcess?

    private let statusMessageItem = NSMenuItem()
    private let visibilityItem = NSMenuItem()
    private let editItem = NSMenuItem()

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
        cardWindow = CardWindowController(model: model)
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
        editItem.title = "Edit Mode"
        editItem.action = #selector(toggleEditMode)
        editItem.target = self
        menu.addItem(statusMessageItem)
        menu.addItem(visibilityItem)
        menu.addItem(editItem)
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
        visibilityItem.title = model.hidden ? "Show Widget" : "Hide Widget"
        editItem.state = model.editMode ? .on : .off
    }

    @objc private func toggleVisibility() { model.setHidden(!model.hidden) }
    @objc private func toggleEditMode() { model.setEditMode(!model.editMode) }

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
