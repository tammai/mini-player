import Foundation

public enum DisplayState: Equatable, Sendable {
    /// Track playing: card visible, waves animate, progress ticks.
    case playing
    /// Track paused: card visible and dimmed, until the idle timeout.
    case paused
    /// Nothing playing: card hidden.
    case idle
    /// Edit mode: card always visible with demo content.
    case edit
}

/// Decides what the card should show. Time is passed in so the logic is testable.
public struct DisplayStateMachine {
    /// How long a pause keeps the card visible before it fades out.
    public var pauseTimeout: TimeInterval
    public var editMode = false

    private var info: NowPlayingInfo?
    private var pausedSince: Date?

    public init(pauseTimeout: TimeInterval = 30) {
        self.pauseTimeout = pauseTimeout
    }

    /// Feeds the latest now-playing info. Call whenever the store changes.
    public mutating func apply(info new: NowPlayingInfo?, now: Date) {
        if let new, !new.playing {
            // The pause timer starts at the playing -> paused edge, and only there.
            if info == nil || info?.playing == true || pausedSince == nil {
                pausedSince = now
            }
        } else {
            pausedSince = nil
        }
        info = new
    }

    public func state(at now: Date) -> DisplayState {
        if editMode { return .edit }
        guard let info else { return .idle }
        if info.playing { return .playing }
        if let pausedSince, now.timeIntervalSince(pausedSince) >= pauseTimeout { return .idle }
        return .paused
    }

    /// When the state will next change on its own, so the caller can schedule a wake-up.
    public func nextTransition(after now: Date) -> Date? {
        guard !editMode, let info, !info.playing, let pausedSince else { return nil }
        let deadline = pausedSince.addingTimeInterval(pauseTimeout)
        return deadline > now ? deadline : nil
    }
}
