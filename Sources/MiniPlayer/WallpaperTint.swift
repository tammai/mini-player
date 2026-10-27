import AppKit
import MiniPlayerCore
import ScreenCaptureKit

/// Works out a tint from the wallpaper behind a window: the clock's color, or the card's accent.
///
/// It captures just macOS's own wallpaper window (the Dock owns one per display), cropped to where the clock
/// is, and averages it. That is the real picture on screen: whichever Space is showing, whatever dynamic or
/// cached image macOS draws. Reading the wallpaper *file* does not work: on current macOS the settings can
/// name a file that is gone while a cached copy is still drawn, and the API for it returned a stale path.
///
/// The capture sees the wallpaper window only, so it never includes the clock or any other window. It does
/// need the Screen Recording permission.
@MainActor
final class WallpaperTint: ObservableObject {
    enum State: Equatable {
        case idle
        case tinted(RGB)
        case needsPermission
        case failed(String)
    }

    @Published private(set) var state = State.idle

    var color: RGB? {
        if case .tinted(let color) = state { return color }
        return nil
    }

    private struct Request {
        /// The clock's frame in global screen coordinates with the origin at the top left.
        let rect: CGRect
        let opacity: Double
    }

    private var latest: Request?
    private var debounce: Timer?
    private var running = false
    private var runAgain = false
    /// Shared by every tint in the app, so the permission is asked for once, not once per use.
    private static var askedForPermission = false

    /// Asks for a fresh tint for the window at `frame` (Cocoa coordinates). Moves arrive in a stream while the
    /// card is dragged, so the work waits until they stop.
    func request(frame: NSRect, opacity: Double) {
        guard let main = NSScreen.screens.first else { return }
        latest = Request(rect: CGRect(x: frame.minX, y: main.frame.height - frame.maxY,
                                      width: frame.width, height: frame.height),
                         opacity: opacity)
        debounce?.invalidate()
        debounce = Timer.scheduledTimer(withTimeInterval: 0.5, repeats: false) { [weak self] _ in
            MainActor.assumeIsolated { self?.start() }
        }
    }

    /// Samples again where the clock last was, to pick up a changed wallpaper.
    func refresh() { start() }

    private func start() {
        guard let request = latest else { return }
        guard !running else { runAgain = true; return }
        guard CGPreflightScreenCaptureAccess() else {
            // Ask once, and only when this tint is actually wanted. After the user allows it, macOS needs the
            // app restarted before the permission applies.
            if !Self.askedForPermission {
                Self.askedForPermission = true
                CGRequestScreenCaptureAccess()
            }
            if state != .needsPermission { state = .needsPermission }
            return
        }
        running = true
        Task { [weak self] in
            let outcome = await Self.sample(request)
            guard let self else { return }
            running = false
            switch outcome {
            case .success(let tint): if state != .tinted(tint) { state = .tinted(tint) }
            case .failure(let error): state = .failed(error.message)
            }
            if runAgain { runAgain = false; start() }
        }
    }

    func openPrivacySettings() {
        if let url = URL(string: "x-apple.systempreferences:com.apple.preference.security?Privacy_ScreenCapture") {
            NSWorkspace.shared.open(url)
        }
    }

    // MARK: Capture

    struct SampleError: Error { let message: String }

    nonisolated private static func sample(_ request: Request) async -> Result<RGB, SampleError> {
        do {
            let content = try await SCShareableContent.excludingDesktopWindows(false, onScreenWindowsOnly: true)
            // The Dock draws the wallpaper, in a window at the desktop level, one per display.
            let wallpapers = content.windows.filter {
                $0.owningApplication?.bundleIdentifier == "com.apple.dock"
                    && ($0.title ?? "").hasPrefix("Wallpaper") && $0.windowLayer < -2_000_000_000
            }
            let center = CGPoint(x: request.rect.midX, y: request.rect.midY)
            guard let wall = wallpapers.first(where: { $0.frame.contains(center) }) ?? wallpapers.first else {
                return .failure(SampleError(message: "macOS did not offer its wallpaper window"))
            }
            // Relative to that window, clipped to it.
            let local = request.rect.offsetBy(dx: -wall.frame.minX, dy: -wall.frame.minY)
                .intersection(CGRect(origin: .zero, size: wall.frame.size))
            guard !local.isNull, local.width >= 1, local.height >= 1 else {
                return .failure(SampleError(message: "the clock is off the screen"))
            }

            let configuration = SCStreamConfiguration()
            configuration.sourceRect = local
            configuration.width = max(16, min(200, Int(local.width)))     // a small picture is plenty for an average
            configuration.height = max(16, min(200, Int(local.height)))
            configuration.showsCursor = false
            let image = try await SCScreenshotManager.captureImage(
                contentFilter: SCContentFilter(desktopIndependentWindow: wall), configuration: configuration)

            guard let pixels = PixelSampler.pixels(of: image, width: 24, height: 14), !pixels.isEmpty else {
                return .failure(SampleError(message: "the captured picture was empty"))
            }
            return .success(ContrastTint.pick(from: pixels, opacity: request.opacity))
        } catch {
            return .failure(SampleError(message: error.localizedDescription))
        }
    }
}
