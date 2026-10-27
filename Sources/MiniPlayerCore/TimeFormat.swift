import Foundation

/// Formats times the way Control Center's Now Playing card does:
/// `11:29` under an hour, `03:45:28` from one hour, remaining time prefixed with `-`.
public enum TimeFormat {
    public static func clock(_ seconds: TimeInterval) -> String {
        let total = max(0, Int(seconds.rounded(.down)))
        let h = total / 3600, m = (total % 3600) / 60, s = total % 60
        if h > 0 { return String(format: "%02d:%02d:%02d", h, m, s) }
        return String(format: "%d:%02d", m, s)
    }

    public static func remaining(duration: TimeInterval, elapsed: TimeInterval) -> String {
        "-" + clock(max(0, duration - elapsed))
    }
}
