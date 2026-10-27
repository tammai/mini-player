import AppKit
import Combine
import MiniPlayerCore
import os

private let log = Logger(subsystem: "dev.mini-player", category: "config")

/// Loads, saves and watches `config.json`.
///
/// - The file is the source of truth and is meant to be edited by hand. It is polled once a
///   second, so editors that rewrite in place and editors that replace the file both work.
/// - Settings changes are saved a moment after the last change, in a stable pretty-printed form.
/// - An unreadable file at launch means defaults, with the original kept as `config.json.bak`.
///   An unreadable file while running (an editor mid-save, say) keeps the current look.
@MainActor
final class ConfigStore: ObservableObject {
    @Published var config: Config {
        didSet {
            guard !applyingFromDisk, config != oldValue else { return }
            scheduleSave()
        }
    }
    /// Set when the file could not be read, so the menu can say so.
    @Published private(set) var problem: String?

    /// Asks the card to turn wherever it is now into a custom position, without moving it. The card
    /// window answers; the store only knows settings, not where a window is.
    let customPositionRequests = PassthroughSubject<Void, Never>()

    let fileURL: URL
    private let backupURL: URL
    /// The file contents we last read or wrote, so we can tell a real edit from our own save.
    private var lastDiskData: Data?
    private var lastStamp: (Date, Int)?
    private var applyingFromDisk = false
    private var saveTimer: Timer?
    private var pollTimer: Timer?

    /// Where the config file and the adapter's PID file live. `MINIPLAYER_CONFIG_DIR` overrides it,
    /// which is how tests run without touching the real files.
    nonisolated static var supportDirectory: URL {
        if let env = ProcessInfo.processInfo.environment["MINIPLAYER_CONFIG_DIR"] {
            return URL(fileURLWithPath: env, isDirectory: true)
        }
        return FileManager.default.urls(for: .applicationSupportDirectory, in: .userDomainMask)[0]
            .appendingPathComponent("mini-player", isDirectory: true)
    }

    init() {
        let directory = Self.supportDirectory
        try? FileManager.default.createDirectory(at: directory, withIntermediateDirectories: true)
        fileURL = directory.appendingPathComponent("config.json")
        backupURL = directory.appendingPathComponent("config.json.bak")
        config = Config()

        if FileManager.default.fileExists(atPath: fileURL.path) {
            reload(atLaunch: true)
        } else {
            save()  // first run: write the defaults so there is a file to edit
        }
        startPolling()
    }

    var directory: URL { fileURL.deletingLastPathComponent() }

    func resetAppearance() { config = config.resettingAppearance() }

    func makePositionCustom() { customPositionRequests.send() }

    // MARK: Reading

    private func startPolling() {
        let timer = Timer(timeInterval: 1, repeats: true) { [weak self] _ in
            MainActor.assumeIsolated { self?.pollForEdits() }
        }
        RunLoop.main.add(timer, forMode: .common)  // keeps running while a menu is open
        pollTimer = timer
    }

    private func pollForEdits() {
        guard let attrs = try? FileManager.default.attributesOfItem(atPath: fileURL.path) else { return }
        let stamp = ((attrs[.modificationDate] as? Date) ?? .distantPast, (attrs[.size] as? Int) ?? -1)
        if let lastStamp, lastStamp == stamp { return }
        lastStamp = stamp
        reload(atLaunch: false)
    }

    private func reload(atLaunch: Bool) {
        guard let data = try? Data(contentsOf: fileURL) else { return }
        guard data != lastDiskData else { return }
        lastDiskData = data
        lastStamp = stamp()
        do {
            let loaded = try Config.decode(from: data)
            problem = nil
            apply(loaded)
            log.info("config loaded")
        } catch {
            problem = "Config file is not valid JSON"
            log.error("config unreadable: \(error.localizedDescription)")
            keepBackup(of: data)
            // At launch there is nothing better than defaults. While running, keep the current look.
            if atLaunch { apply(Config()) }
        }
    }

    private func apply(_ new: Config) {
        applyingFromDisk = true
        config = new
        applyingFromDisk = false
    }

    private func keepBackup(of data: Data) {
        guard (try? Data(contentsOf: backupURL)) != data else { return }
        try? data.write(to: backupURL, options: .atomic)
    }

    // MARK: Writing

    private func scheduleSave() {
        saveTimer?.invalidate()
        saveTimer = Timer.scheduledTimer(withTimeInterval: 0.3, repeats: false) { [weak self] _ in
            MainActor.assumeIsolated { self?.save() }
        }
    }

    private func save() {
        saveTimer?.invalidate()
        guard let data = try? config.encoded(), data != lastDiskData else { return }
        do {
            try data.write(to: fileURL, options: .atomic)
            lastDiskData = data
            lastStamp = stamp()
            problem = nil
        } catch {
            log.error("could not save config: \(error.localizedDescription)")
        }
    }

    private func stamp() -> (Date, Int)? {
        guard let attrs = try? FileManager.default.attributesOfItem(atPath: fileURL.path) else { return nil }
        return ((attrs[.modificationDate] as? Date) ?? .distantPast, (attrs[.size] as? Int) ?? -1)
    }

    func revealInFinder() {
        NSWorkspace.shared.activateFileViewerSelecting([fileURL])
    }
}
