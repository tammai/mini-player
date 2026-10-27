import Foundation
import os

private let log = Logger(subsystem: "dev.mini-player", category: "adapter")

/// Where the mediaremote-adapter pieces live.
///
/// The framework is passed to the script as a path and is never linked.
struct AdapterPaths {
    let script: URL
    let framework: URL
    let testClient: URL?

    /// Looks in the app bundle first, then in `MINIPLAYER_ADAPTER_*` environment variables
    /// (used when running with `swift run`, where there is no bundle).
    static func locate() -> AdapterPaths? {
        let fm = FileManager.default
        if let resources = Bundle.main.resourceURL, let frameworks = Bundle.main.privateFrameworksURL {
            let script = resources.appendingPathComponent("mediaremote-adapter.pl")
            let framework = frameworks.appendingPathComponent("MediaRemoteAdapter.framework")
            let client = resources.appendingPathComponent("MediaRemoteAdapterTestClient")
            if fm.fileExists(atPath: script.path), fm.fileExists(atPath: framework.path) {
                return AdapterPaths(script: script, framework: framework,
                                    testClient: fm.fileExists(atPath: client.path) ? client : nil)
            }
        }
        let env = ProcessInfo.processInfo.environment
        if let script = env["MINIPLAYER_ADAPTER_SCRIPT"], let framework = env["MINIPLAYER_ADAPTER_FRAMEWORK"] {
            return AdapterPaths(script: URL(fileURLWithPath: script),
                                framework: URL(fileURLWithPath: framework),
                                testClient: env["MINIPLAYER_ADAPTER_TESTCLIENT"].map { URL(fileURLWithPath: $0) })
        }
        return nil
    }
}

/// Runs `perl mediaremote-adapter.pl <framework> stream` and delivers its JSON lines.
///
/// `/usr/bin/perl` is the entitled binary that is still allowed to read MediaRemote on
/// macOS 15.4 and later. The subprocess is restarted with backoff if it dies and is
/// terminated on `stop()`.
final class AdapterProcess {
    private let paths: AdapterPaths
    private let onLine: @MainActor (String) -> Void
    private var process: Process?
    private var buffer = Data()
    private var stopped = false
    private var restartDelay: TimeInterval = 1

    init(paths: AdapterPaths, onLine: @escaping @MainActor (String) -> Void) {
        self.paths = paths
        self.onLine = onLine
    }

    /// Runs the adapter's own `test` command. Exit code 0 means it is safe to use.
    static func selfTest(_ paths: AdapterPaths) async -> Bool {
        guard let client = paths.testClient else { return true }
        return await withCheckedContinuation { continuation in
            let process = Process()
            process.executableURL = URL(fileURLWithPath: "/usr/bin/perl")
            process.arguments = [paths.script.path, paths.framework.path, client.path, "test"]
            process.standardOutput = FileHandle.nullDevice
            process.standardError = FileHandle.nullDevice
            process.terminationHandler = { continuation.resume(returning: $0.terminationStatus == 0) }
            do { try process.run() } catch {
                log.error("self-test failed to launch: \(error.localizedDescription)")
                continuation.resume(returning: false)
            }
        }
    }

    @MainActor func start() {
        stopped = false
        reapStaleProcess()
        launch()
    }

    func stop() {
        stopped = true
        process?.terminationHandler = nil
        process?.terminate()
        process = nil
        try? FileManager.default.removeItem(at: Self.pidFile)
    }

    // MARK: Orphan protection
    //
    // The adapter only writes when media changes, so it would not notice a dead parent for a
    // long time. A graceful quit (including SIGTERM/SIGINT) stops it in `stop()`. For a crash
    // or `kill -9`, the PID is recorded and a leftover process is reaped at the next launch.

    private static var pidFile: URL {
        FileManager.default.urls(for: .applicationSupportDirectory, in: .userDomainMask)[0]
            .appendingPathComponent("mini-player/adapter.pid")
    }

    private func recordPID(_ pid: Int32) {
        let file = Self.pidFile
        try? FileManager.default.createDirectory(at: file.deletingLastPathComponent(), withIntermediateDirectories: true)
        try? String(pid).write(to: file, atomically: true, encoding: .utf8)
    }

    private func reapStaleProcess() {
        guard let text = try? String(contentsOf: Self.pidFile, encoding: .utf8),
              let pid = Int32(text.trimmingCharacters(in: .whitespacesAndNewlines)) else { return }
        defer { try? FileManager.default.removeItem(at: Self.pidFile) }
        // Only signal the PID if it is still our adapter, since PIDs get reused.
        let ps = Process()
        ps.executableURL = URL(fileURLWithPath: "/bin/ps")
        ps.arguments = ["-p", String(pid), "-o", "command="]
        let out = Pipe()
        ps.standardOutput = out
        ps.standardError = FileHandle.nullDevice
        guard (try? ps.run()) != nil else { return }
        let data = out.fileHandleForReading.readDataToEndOfFile()
        ps.waitUntilExit()
        let command = String(data: data, encoding: .utf8) ?? ""
        if command.contains(paths.script.path) {
            log.info("reaping stale adapter process \(pid)")
            kill(pid, SIGTERM)
        }
    }

    @MainActor private func launch() {
        let process = Process()
        process.executableURL = URL(fileURLWithPath: "/usr/bin/perl")
        process.arguments = [paths.script.path, paths.framework.path, "stream"]
        let pipe = Pipe()
        process.standardOutput = pipe
        process.standardError = FileHandle.nullDevice
        buffer.removeAll()

        pipe.fileHandleForReading.readabilityHandler = { [weak self] handle in
            let data = handle.availableData
            guard !data.isEmpty else { return }
            DispatchQueue.main.async { self?.consume(data) }
        }
        process.terminationHandler = { [weak self] finished in
            pipe.fileHandleForReading.readabilityHandler = nil
            DispatchQueue.main.async { self?.didExit(status: finished.terminationStatus) }
        }
        do {
            try process.run()
            self.process = process
            recordPID(process.processIdentifier)
        } catch {
            log.error("could not launch adapter: \(error.localizedDescription)")
            scheduleRestart()
        }
    }

    @MainActor private func consume(_ data: Data) {
        restartDelay = 1
        buffer.append(data)
        while let newline = buffer.firstIndex(of: 0x0A) {
            let lineData = buffer[buffer.startIndex..<newline]
            buffer.removeSubrange(buffer.startIndex...newline)
            if let line = String(data: lineData, encoding: .utf8), !line.isEmpty { onLine(line) }
        }
    }

    @MainActor private func didExit(status: Int32) {
        guard !stopped else { return }
        log.error("adapter exited with status \(status), restarting")
        scheduleRestart()
    }

    @MainActor private func scheduleRestart() {
        let delay = restartDelay
        restartDelay = min(restartDelay * 2, 30)
        DispatchQueue.main.asyncAfter(deadline: .now() + delay) { [weak self] in
            guard let self, !self.stopped else { return }
            self.launch()
        }
    }
}
