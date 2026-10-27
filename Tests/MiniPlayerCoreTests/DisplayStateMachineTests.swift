import Foundation
import Testing
@testable import MiniPlayerCore

@Suite struct DisplayStateMachineTests {
    let t0 = Date(timeIntervalSince1970: 1_000_000)
    func playing() -> NowPlayingInfo { NowPlayingInfo(title: "t", playing: true) }
    func paused() -> NowPlayingInfo { NowPlayingInfo(title: "t", playing: false) }

    @Test func startsIdle() {
        let machine = DisplayStateMachine()
        #expect(machine.state(at: t0) == .idle)
    }

    @Test func playingShowsTheCard() {
        var machine = DisplayStateMachine()
        machine.apply(info: playing(), now: t0)
        #expect(machine.state(at: t0) == .playing)
    }

    @Test func pausedFor29SecondsIsStillVisible() {
        var machine = DisplayStateMachine()
        machine.apply(info: playing(), now: t0)
        machine.apply(info: paused(), now: t0)
        #expect(machine.state(at: t0.addingTimeInterval(29)) == .paused)
    }

    @Test func pausedFor31SecondsIsIdle() {
        var machine = DisplayStateMachine()
        machine.apply(info: playing(), now: t0)
        machine.apply(info: paused(), now: t0)
        #expect(machine.state(at: t0.addingTimeInterval(31)) == .idle)
    }

    @Test func resumingCancelsTheTimer() {
        var machine = DisplayStateMachine()
        machine.apply(info: playing(), now: t0)
        machine.apply(info: paused(), now: t0)
        machine.apply(info: playing(), now: t0.addingTimeInterval(20))
        #expect(machine.state(at: t0.addingTimeInterval(60)) == .playing)
        #expect(machine.nextTransition(after: t0.addingTimeInterval(60)) == nil)
    }

    @Test func repeatedPausedUpdatesDoNotRestartTheTimer() {
        // The pause arrives as two events (playing:false, then playbackRate:0).
        var machine = DisplayStateMachine()
        machine.apply(info: playing(), now: t0)
        machine.apply(info: paused(), now: t0)
        machine.apply(info: paused(), now: t0.addingTimeInterval(20))
        #expect(machine.state(at: t0.addingTimeInterval(31)) == .idle)
    }

    @Test func firstSeenAlreadyPausedStartsTheTimerThen() {
        var machine = DisplayStateMachine()
        machine.apply(info: paused(), now: t0)
        #expect(machine.state(at: t0.addingTimeInterval(29)) == .paused)
        #expect(machine.state(at: t0.addingTimeInterval(31)) == .idle)
    }

    @Test func closingTheSourceHidesTheCardImmediately() {
        var machine = DisplayStateMachine()
        machine.apply(info: playing(), now: t0)
        machine.apply(info: nil, now: t0.addingTimeInterval(1))
        #expect(machine.state(at: t0.addingTimeInterval(1)) == .idle)
    }

    @Test func editModeAlwaysShowsTheCard() {
        var machine = DisplayStateMachine()
        machine.editMode = true
        #expect(machine.state(at: t0) == .edit)
        machine.editMode = false
        #expect(machine.state(at: t0) == .idle)
    }

    @Test func nextTransitionPointsAtTheTimeout() {
        var machine = DisplayStateMachine()
        machine.apply(info: playing(), now: t0)
        machine.apply(info: paused(), now: t0)
        #expect(machine.nextTransition(after: t0.addingTimeInterval(5)) == t0.addingTimeInterval(30))
        #expect(machine.nextTransition(after: t0.addingTimeInterval(31)) == nil)
    }
}
