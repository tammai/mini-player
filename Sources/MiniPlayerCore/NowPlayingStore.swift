import Foundation

/// Accumulates the adapter's JSON-lines stream into one now-playing state.
///
/// Observed stream shape (macOS 26.6.2):
///  - The first event can be an empty payload, which means no media.
///  - A full snapshot has `diff:false` and replaces everything.
///  - Later events have `diff:true` and carry only the keys that changed.
public struct NowPlayingStore {
    private var payload: [String: Any] = [:]
    public private(set) var info: NowPlayingInfo?

    public init() {}

    /// Applies one line of adapter output. Returns false for lines that are not data events.
    @discardableResult
    public mutating func apply(line: String) -> Bool {
        guard let event = Self.parse(line: line) else { return false }
        apply(diff: event.diff, payload: event.payload)
        return true
    }

    public mutating func apply(diff: Bool, payload new: [String: Any]) {
        if diff {
            for (key, value) in new {
                if value is NSNull {
                    payload.removeValue(forKey: key)
                } else {
                    payload[key] = value
                }
            }
        } else {
            payload = new.filter { !($0.value is NSNull) }
        }
        info = Self.makeInfo(from: payload)
    }

    static func parse(line: String) -> (diff: Bool, payload: [String: Any])? {
        guard let data = line.data(using: .utf8),
              let object = try? JSONSerialization.jsonObject(with: data) as? [String: Any],
              (object["type"] as? String) == "data",
              let payload = object["payload"] as? [String: Any]
        else { return nil }
        return (object["diff"] as? Bool ?? false, payload)
    }

    static func makeInfo(from payload: [String: Any]) -> NowPlayingInfo? {
        // Media without a title is ignored, as the adapter does by default.
        guard let title = payload["title"] as? String, !title.isEmpty else { return nil }
        return NowPlayingInfo(
            title: title,
            artist: (payload["artist"] as? String).flatMap { $0.isEmpty ? nil : $0 },
            album: (payload["album"] as? String).flatMap { $0.isEmpty ? nil : $0 },
            duration: (payload["duration"] as? NSNumber)?.doubleValue,
            elapsedTime: (payload["elapsedTime"] as? NSNumber)?.doubleValue,
            timestamp: (payload["timestamp"] as? String).flatMap(parseDate),
            playbackRate: (payload["playbackRate"] as? NSNumber)?.doubleValue ?? 1,
            playing: (payload["playing"] as? NSNumber)?.boolValue ?? false,
            bundleIdentifier: payload["bundleIdentifier"] as? String,
            artworkData: (payload["artworkData"] as? String).flatMap { Data(base64Encoded: $0) }
        )
    }

    private static func parseDate(_ string: String) -> Date? {
        let plain = ISO8601DateFormatter()
        if let date = plain.date(from: string) { return date }
        let fractional = ISO8601DateFormatter()
        fractional.formatOptions = [.withInternetDateTime, .withFractionalSeconds]
        return fractional.date(from: string)
    }
}
