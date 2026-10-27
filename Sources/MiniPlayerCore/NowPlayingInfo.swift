import Foundation

/// A snapshot of what the system reports as now playing.
public struct NowPlayingInfo: Equatable, Sendable {
    public var title: String
    public var artist: String?
    public var album: String?
    public var duration: TimeInterval?
    /// Elapsed time at `timestamp`, not at the present moment.
    public var elapsedTime: TimeInterval?
    public var timestamp: Date?
    public var playbackRate: Double
    public var playing: Bool
    public var bundleIdentifier: String?
    public var artworkData: Data?

    public init(
        title: String,
        artist: String? = nil,
        album: String? = nil,
        duration: TimeInterval? = nil,
        elapsedTime: TimeInterval? = nil,
        timestamp: Date? = nil,
        playbackRate: Double = 1,
        playing: Bool = true,
        bundleIdentifier: String? = nil,
        artworkData: Data? = nil
    ) {
        self.title = title
        self.artist = artist
        self.album = album
        self.duration = duration
        self.elapsedTime = elapsedTime
        self.timestamp = timestamp
        self.playbackRate = playbackRate
        self.playing = playing
        self.bundleIdentifier = bundleIdentifier
        self.artworkData = artworkData
    }

    /// Elapsed playback position at `now`, extrapolated from the last snapshot.
    ///
    /// The stream sends no per-second events, so the UI ticks this itself.
    /// `playing` wins over `playbackRate`: a pause arrives as `playing:false`
    /// slightly before `playbackRate:0`, and progress must not creep in between.
    public func elapsed(at now: Date) -> TimeInterval? {
        guard let elapsedTime else { return nil }
        guard let timestamp else { return elapsedTime }
        let rate = playing ? playbackRate : 0
        let position = elapsedTime + now.timeIntervalSince(timestamp) * rate
        let clamped = max(0, position)
        if let duration { return min(clamped, duration) }
        return clamped
    }

    /// Identity of the track, ignoring pause and resume.
    ///
    /// `contentItemIdentifier` is not used: it changes on every pause and resume.
    public var trackKey: String {
        "\(title)\u{1F}\(artist ?? "")\u{1F}\(duration.map { String($0) } ?? "")"
    }
}
