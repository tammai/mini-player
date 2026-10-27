import CoreGraphics
import Foundation
import Testing
@testable import MiniPlayerCore

@Suite struct ClockLayoutTests {
    // A card at (400, 300), 540x164, and a 200x120 clock.
    let card = CGRect(x: 400, y: 300, width: 540, height: 164)
    let clock = CGSize(width: 200, height: 120)

    func origin(_ a: ClockAnchor, gap: Double = 20) -> CGPoint {
        ClockLayout.origin(anchor: a, card: card, clock: clock, gap: gap)
    }

    @Test func topAnchorsSitAboveTheCard() {
        #expect(origin(.topLeft) == CGPoint(x: 400, y: 484))      // maxY 464 + gap
        #expect(origin(.topCenter) == CGPoint(x: 400 + (540 - 200) / 2, y: 484))
        #expect(origin(.topRight) == CGPoint(x: 940 - 200, y: 484))
    }

    @Test func bottomAnchorsSitBelowTheCard() {
        #expect(origin(.bottomLeft) == CGPoint(x: 400, y: 300 - 20 - 120))
        #expect(origin(.bottomCenter) == CGPoint(x: 570, y: 160))
        #expect(origin(.bottomRight) == CGPoint(x: 740, y: 160))
    }

    @Test func leftAnchorsSitLeftOfTheCard() {
        #expect(origin(.leftTop) == CGPoint(x: 400 - 20 - 200, y: 464 - 120))     // top edges meet
        #expect(origin(.leftCenter) == CGPoint(x: 180, y: 300 + (164 - 120) / 2)) // centered
        #expect(origin(.leftBottom) == CGPoint(x: 180, y: 300))                   // bottom edges meet
    }

    @Test func rightAnchorsSitRightOfTheCard() {
        #expect(origin(.rightTop) == CGPoint(x: 960, y: 344))
        #expect(origin(.rightCenter) == CGPoint(x: 960, y: 322))
        #expect(origin(.rightBottom) == CGPoint(x: 960, y: 300))
    }

    @Test func thereAreTwelveAnchorsAndTheyAllDiffer() {
        #expect(ClockAnchor.allCases.count == 12)
        let origins = ClockAnchor.allCases.map { origin($0) }
        #expect(Set(origins.map { "\($0.x),\($0.y)" }).count == 12)
    }

    @Test func gapPushesTheClockAway() {
        #expect(origin(.leftCenter, gap: 60).x == origin(.leftCenter, gap: 20).x - 40)
        #expect(origin(.topCenter, gap: 60).y == origin(.topCenter, gap: 20).y + 40)
    }

    @Test func offsetsMoveRightAndDown() {
        let base = origin(.leftCenter)
        let moved = ClockLayout.origin(anchor: .leftCenter, card: card, clock: clock, gap: 20, offsetX: 10, offsetY: 15)
        #expect(moved.x == base.x + 10)
        #expect(moved.y == base.y - 15, "down on screen is toward smaller y in Cocoa coordinates")
    }

    @Test func theClockIsKeptOnScreen() {
        let area = CGRect(x: 0, y: 25, width: 1536, height: 900)
        // The card hugs the left edge, so a clock on its left has no room: it is pulled back on screen.
        let nearEdge = CGRect(x: 32, y: 57, width: 540, height: 164)
        let o = ClockLayout.origin(anchor: .leftCenter, card: nearEdge, clock: clock, gap: 24, in: area)
        #expect(o.x == 0)
        #expect(area.contains(CGRect(origin: o, size: clock)))
    }
}

@Suite struct ClockFormatterTests {
    // 2026-10-27 10:15:00 and 15:05:00 UTC.
    let morning = Date(timeIntervalSince1970: 1_793_096_100)
    let afternoon = Date(timeIntervalSince1970: 1_793_113_500)
    let utc = TimeZone(identifier: "UTC")!

    @Test func dateReadsLikeTheLockScreen() {
        #expect(ClockFormatter.day(morning, locale: Locale(identifier: "en_GB"), timeZone: utc) == "Tue 27 Oct")
    }

    @Test func dateOrderFollowsTheLocale() {
        #expect(ClockFormatter.day(morning, locale: Locale(identifier: "en_US"), timeZone: utc) == "Tue, Oct 27")
    }

    @Test func twentyFourHourPadsTheHour() {
        let nine = Date(timeIntervalSince1970: 1_793_096_100 - 3600 - 15 * 60 + 41 * 60)  // 09:41
        #expect(ClockFormatter.time(nine, format: .h24, timeZone: utc) == "09:41")
        #expect(ClockFormatter.time(afternoon, format: .h24, timeZone: utc) == "15:05")
    }

    @Test func twelveHourHasNoAmPmAndNoPadding() {
        #expect(ClockFormatter.time(afternoon, format: .h12, timeZone: utc) == "3:05")
        #expect(ClockFormatter.time(morning, format: .h12, timeZone: utc) == "10:15")
    }

    @Test func systemFollowsTheLocalesHourCycle() {
        #expect(ClockFormatter.time(afternoon, format: .system, locale: Locale(identifier: "en_US"), timeZone: utc) == "3:05")
        #expect(ClockFormatter.time(afternoon, format: .system, locale: Locale(identifier: "en_GB"), timeZone: utc) == "15:05")
    }
}

@Suite struct ClockSettingsTests {
    @Test func theClockIsOnByDefaultAtTheLeftOfTheCard() {
        let c = Config()
        #expect(c.clock.enabled)
        #expect(c.clock.anchor == .leftCenter)
        #expect(c.clock.showDate)
    }

    @Test func clockSettingsAreClampedAndTolerant() throws {
        let c = try Config.decode(from: Data(#"{"clock":{"size":9999,"opacity":0,"anchor":"middle","colorHex":"red"}}"#.utf8))
        #expect(c.clock.size == 300)
        #expect(c.clock.opacity == 0.1)
        #expect(c.clock.anchor == .leftCenter, "an unknown anchor falls back to the default")
        #expect(c.clock.colorHex == "#FFFFFF")
    }

    @Test func clockSettingsRoundTrip() throws {
        var c = Config()
        c.clock.anchor = .topRight
        c.clock.size = 140
        c.clock.fontName = "Avenir Next Condensed"
        #expect(try Config.decode(from: c.encoded()) == c)
    }
}

@Suite struct ClockFitTests {
    let card = CGSize(width: 540, height: 164)

    @Test func aClockThatFitsIsLeftAlone() {
        #expect(ClockLayout.fitScale(content: CGSize(width: 300, height: 120), limit: card) == 1)
    }

    @Test func aTooTallClockShrinksToTheCardsHeight() {
        let s = ClockLayout.fitScale(content: CGSize(width: 300, height: 328), limit: card)
        #expect(abs(s - 0.5) < 0.0001)
    }

    @Test func aTooWideClockShrinksToTheCardsWidth() {
        let s = ClockLayout.fitScale(content: CGSize(width: 1080, height: 100), limit: card)
        #expect(abs(s - 0.5) < 0.0001)
    }

    @Test func theTighterLimitWins() {
        let s = ClockLayout.fitScale(content: CGSize(width: 1080, height: 656), limit: card)  // 0.5 by width, 0.25 by height
        #expect(abs(s - 0.25) < 0.0001)
    }

    @Test func neverEnlarges() {
        #expect(ClockLayout.fitScale(content: CGSize(width: 10, height: 10), limit: card) == 1)
    }

    @Test func degenerateSizesAreIgnored() {
        #expect(ClockLayout.fitScale(content: .zero, limit: card) == 1)
        #expect(ClockLayout.fitScale(content: CGSize(width: 100, height: 100), limit: .zero) == 1)
    }
}

@Suite struct ClockDateSettingsTests {
    @Test func theDateDefaultsToAboveAndCentered() {
        let c = ClockSettings()
        #expect(c.datePlacement == .above)
        #expect(c.dateAlignment == .center)
        #expect(c.dateGap == 0)
    }

    @Test func dateSettingsRoundTripAndTolerateBadValues() throws {
        var c = Config()
        c.clock.datePlacement = .below
        c.clock.dateAlignment = .right
        c.clock.dateGap = -12
        c.clock.dateOffsetX = 30
        #expect(try Config.decode(from: c.encoded()) == c)
        let bad = try Config.decode(from: Data(#"{"clock":{"dateAlignment":"middle","dateGap":9999}}"#.utf8))
        #expect(bad.clock.dateAlignment == .center)
        #expect(bad.clock.dateGap == 100)
    }

    @Test func backgroundSettingsDefaultsAndLimits() throws {
        let b = BackgroundSettings()
        #expect(b.kind == .glass)
        #expect(b.opacity == 1)
        let c = try Config.decode(from: Data(#"{"background":{"kind":"frosted","opacity":5,"frost":"hud"}}"#.utf8))
        #expect(c.background.kind == .frosted)
        #expect(c.background.opacity == 1)
        #expect(c.background.frost == .hud)
        let bad = try Config.decode(from: Data(#"{"background":{"kind":"neon"}}"#.utf8))
        #expect(bad.background.kind == .glass, "an unknown kind falls back to glass")
    }
}
