import Foundation
import Testing
@testable import MiniPlayerCore

/// Events captured from `mediaremote-adapter stream` on macOS 26.6.2 (Chrome, YouTube mix).
enum Fixture {
    static let empty = #"{"type":"data","diff":false,"payload":{}}"#
    static let snapshot = #"{"type":"data","diff":false,"payload":{"artist":"healing studio","playbackRate":1,"contentItemIdentifier":"B29B86E8-A982-435B-9C3E-3ABF277818BC","title":"Japanese Green Tea.","elapsedTime":2228.1173330000001,"duration":14217.101000000001,"playing":true,"bundleIdentifier":"com.google.Chrome","album":"","processIdentifier":3866,"timestamp":"2026-10-27T02:43:55Z"}}"#
    static let pausedFlag = #"{"type":"data","diff":true,"payload":{"playing":false}}"#
    static let pausedRate = #"{"type":"data","diff":true,"payload":{"playbackRate":0,"contentItemIdentifier":"E07AAED1-38C0-4E34-893C-EE8B3220AB25","elapsedTime":2275.5087880000001,"timestamp":"2026-10-27T02:44:42Z"}}"#
    static let resumedFlag = #"{"type":"data","diff":true,"payload":{"playing":true}}"#
    static let resumedRate = #"{"type":"data","diff":true,"payload":{"playbackRate":1,"contentItemIdentifier":"51640BF6-92E7-4F19-BDEA-20CF636AE95C","elapsedTime":2275.5626670000001,"timestamp":"2026-10-27T02:44:45Z"}}"#
}

func date(_ iso: String) -> Date { ISO8601DateFormatter().date(from: iso)! }

@Suite struct NowPlayingStoreTests {
    @Test func emptyPayloadMeansNoMedia() {
        var store = NowPlayingStore()
        store.apply(line: Fixture.empty)
        #expect(store.info == nil)
    }

    @Test func snapshotIsParsed() throws {
        var store = NowPlayingStore()
        store.apply(line: Fixture.snapshot)
        let info = try #require(store.info)
        #expect(info.title == "Japanese Green Tea.")
        #expect(info.artist == "healing studio")
        #expect(info.album == nil, "empty album strings are treated as absent")
        #expect(info.duration == 14217.101000000001)
        #expect(info.playing)
        #expect(info.bundleIdentifier == "com.google.Chrome")
        #expect(info.timestamp == date("2026-10-27T02:43:55Z"))
    }

    @Test func diffsMergeIntoHeldState() throws {
        var store = NowPlayingStore()
        store.apply(line: Fixture.snapshot)
        store.apply(line: Fixture.pausedFlag)
        let info = try #require(store.info)
        #expect(!info.playing)
        #expect(info.title == "Japanese Green Tea.", "keys absent from a diff are unchanged")
        #expect(info.elapsedTime == 2228.1173330000001)
    }

    @Test func pauseAndResumeKeepTheSameTrackKey() throws {
        var store = NowPlayingStore()
        store.apply(line: Fixture.snapshot)
        let before = try #require(store.info).trackKey
        for line in [Fixture.pausedFlag, Fixture.pausedRate, Fixture.resumedFlag, Fixture.resumedRate] {
            store.apply(line: line)
        }
        #expect(try #require(store.info).trackKey == before)
    }

    @Test func nullInADiffRemovesTheKey() throws {
        var store = NowPlayingStore()
        store.apply(line: Fixture.snapshot)
        store.apply(line: #"{"type":"data","diff":true,"payload":{"artist":null}}"#)
        #expect(try #require(store.info).artist == nil)
    }

    @Test func aFullSnapshotReplacesEverything() throws {
        var store = NowPlayingStore()
        store.apply(line: Fixture.snapshot)
        store.apply(line: #"{"type":"data","diff":false,"payload":{"title":"Other","playing":true}}"#)
        let info = try #require(store.info)
        #expect(info.title == "Other")
        #expect(info.artist == nil)
    }

    @Test func closingTheSourceReturnsToNoMedia() {
        var store = NowPlayingStore()
        store.apply(line: Fixture.snapshot)
        store.apply(line: Fixture.empty)
        #expect(store.info == nil)
    }

    @Test func nonDataLinesAreIgnored() {
        var store = NowPlayingStore()
        let garbage = store.apply(line: "not json")
        let error = store.apply(line: #"{"type":"error","message":"x"}"#)
        #expect(!garbage)
        #expect(!error)
        #expect(store.info == nil)
    }
}

@Suite struct ElapsedExtrapolationTests {
    @Test func matchesObservedPlayback() throws {
        // Real data: snapshot at 02:43:55Z had elapsed 2228.117s. 47s of wall time
        // later the paused position was 2275.509s, so extrapolation must land within 1s.
        var store = NowPlayingStore()
        store.apply(line: Fixture.snapshot)
        let info = try #require(store.info)
        let position = try #require(info.elapsed(at: date("2026-10-27T02:44:42Z")))
        #expect(abs(position - 2275.5087880000001) < 1)
    }

    @Test func isFrozenWhilePaused() throws {
        var store = NowPlayingStore()
        for line in [Fixture.snapshot, Fixture.pausedFlag, Fixture.pausedRate] { store.apply(line: line) }
        let info = try #require(store.info)
        let a = try #require(info.elapsed(at: date("2026-10-27T02:44:43Z")))
        let b = try #require(info.elapsed(at: date("2026-10-27T02:44:58Z")))
        #expect(a == b)
    }

    @Test func doesNotCreepBetweenThePauseFlagAndTheRateEvent() throws {
        var store = NowPlayingStore()
        for line in [Fixture.snapshot, Fixture.pausedFlag] { store.apply(line: line) }
        let info = try #require(store.info)
        #expect(info.playbackRate == 1)
        #expect(info.elapsed(at: date("2026-10-27T02:44:30Z")) == 2228.1173330000001)
    }

    @Test func isClampedToTheDuration() {
        let info = NowPlayingInfo(title: "t", duration: 100, elapsedTime: 90, timestamp: date("2026-10-27T02:00:00Z"))
        #expect(info.elapsed(at: date("2026-10-27T03:00:00Z")) == 100)
    }
}
