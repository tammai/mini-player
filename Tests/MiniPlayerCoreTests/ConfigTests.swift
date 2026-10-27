import CoreGraphics
import Foundation
import Testing
@testable import MiniPlayerCore

@Suite struct ConfigTests {
    func decode(_ json: String) throws -> Config { try Config.decode(from: Data(json.utf8)) }

    @Test func emptyObjectGivesDefaults() throws {
        #expect(try decode("{}") == Config())
    }

    @Test func missingKeysTakeDefaults() throws {
        let c = try decode(#"{"card":{"scale":1.5},"waves":{"count":24}}"#)
        #expect(c.card.scale == 1.5)
        #expect(c.card.cornerRadius == 28, "other card keys keep their defaults")
        #expect(c.waves.count == 24)
        #expect(c.waves.thickness == 5)
        #expect(c.general == GeneralSettings())
    }

    @Test func unknownKeysAreIgnored() throws {
        let c = try decode(#"{"future":{"x":1},"card":{"scale":1.2,"sparkle":true}}"#)
        #expect(c.card.scale == 1.2)
    }

    @Test func aWrongTypeFallsBackForThatFieldOnly() throws {
        let c = try decode(#"{"card":{"scale":"huge","cornerRadius":10},"waves":"nope"}"#)
        #expect(c.card.scale == 1, "mistyped value takes the default")
        #expect(c.card.cornerRadius == 10, "its neighbours are unaffected")
        #expect(c.waves == WaveSettings(), "a mistyped group takes its defaults")
    }

    @Test func anUnknownChoiceFallsBackToTheDefault() throws {
        let c = try decode(#"{"waves":{"shape":"hexagons","anchor":"topRight"}}"#)
        #expect(c.waves.shape == .bars)
        #expect(c.waves.anchor == .topRight)
    }

    @Test func numbersAreClamped() throws {
        let c = try decode(#"{"card":{"scale":99,"artworkSize":1},"waves":{"count":1000,"roundness":-3},"general":{"pauseTimeout":0}}"#)
        #expect(c.card.scale == 2.5)
        #expect(c.card.artworkSize == 60)
        #expect(c.waves.count == 48)
        #expect(c.waves.roundness == 0)
        #expect(c.general.pauseTimeout == 5)
    }

    @Test func badColorsAreDropped() throws {
        let c = try decode(##"{"accent":{"hex":"blue"},"background":{"tintHex":"#12"}}"##)
        #expect(c.accent.hex == "#0A84FF")
        #expect(c.background.tintHex == nil)
    }

    @Test func notJSONThrows() {
        #expect(throws: (any Error).self) { try decode("not json") }
        #expect(throws: (any Error).self) { try decode("") }
        #expect(throws: (any Error).self) { try decode("[1,2]") }
    }

    @Test func roundTrips() throws {
        var c = Config()
        c.card.scale = 1.4
        c.text.fontName = "Avenir Next"
        c.background.tintHex = "#FF8800"
        c.waves.shape = .dots
        c.position = PositionSettings(display: "ABC", anchor: nil, relX: 0.25, relY: 0.75, snap: false, margin: 10)
        #expect(try Config.decode(from: c.encoded()) == c)
    }

    @Test func optionalKeysAreWrittenSoTheyCanBeFoundInTheFile() throws {
        let text = String(decoding: try Config().encoded(), as: UTF8.self)
        #expect(text.contains(#""fontName" : null"#))
        #expect(text.contains(#""tintHex" : null"#))
    }

    @Test func aFreePositionSurvivesTheRoundTrip() throws {
        var c = Config()
        c.position.anchor = nil
        c.position.relX = 0.4
        let back = try Config.decode(from: c.encoded())
        #expect(back.position.anchor == nil, "null anchor means custom, not 'use the default place'")
        #expect(back.position.relX == 0.4)
    }

    @Test func aMissingAnchorKeyMeansTheDefaultPlace() throws {
        #expect(try decode(#"{"position":{"margin":10}}"#).position.anchor == .bottomRight)
    }

    @Test func resettingKeepsPositionAndGeneral() {
        var c = Config()
        c.card.scale = 2
        c.position.anchor = .topRight
        c.general.launchAtLogin = false
        let r = c.resettingAppearance()
        #expect(r.card.scale == 1)
        #expect(r.position.anchor == .topRight)
        #expect(r.general.launchAtLogin == false)
    }
}

@Suite struct RGBTests {
    @Test func hexRoundTrip() throws {
        #expect(RGB(hex: "#FF8000")?.hex == "#FF8000")
        #expect(RGB(hex: "0A84FF")?.hex == "#0A84FF")
        #expect(RGB(hex: "nope") == nil)
        #expect(RGB(hex: "#FFF") == nil)
    }

    @Test func hsbRoundTrip() {
        for hex in ["#FF0000", "#00FF00", "#0000FF", "#3A7BD5", "#808080"] {
            let c = RGB(hex: hex)!
            let (h, s, b) = c.hsb
            let back = RGB(h: h, s: s, b: b)
            #expect(abs(back.r - c.r) < 0.01 && abs(back.g - c.g) < 0.01 && abs(back.b - c.b) < 0.01)
        }
    }
}

@Suite struct AccentColorTests {
    func pixels(_ hex: String, _ n: Int) -> [RGB] { Array(repeating: RGB(hex: hex)!, count: n) }

    @Test func picksTheDominantHue() throws {
        // Mostly green with a little orange and a lot of off-white, like the "japanese green tea" art.
        let art = pixels("#7FBF3F", 60) + pixels("#F2A33C", 8) + pixels("#F8F5D0", 100)
        let accent = try #require(AccentColor.pick(from: art))
        let hue = accent.hsb.h * 360
        #expect(hue > 80 && hue < 130, "expected green, got hue \(hue)")
    }

    @Test func grayscaleArtHasNoAccent() {
        #expect(AccentColor.pick(from: pixels("#808080", 50) + pixels("#101010", 50) + pixels("#FFFFFF", 50)) == nil)
    }

    @Test func emptyInputHasNoAccent() {
        #expect(AccentColor.pick(from: []) == nil)
    }

    @Test func brightnessIsKeptInAReadableRange() throws {
        // Dark but still red (near-black pixels are ignored on purpose, they carry no hue).
        let dark = try #require(AccentColor.pick(from: pixels("#661111", 30) + pixels("#551010", 30)))
        #expect(dark.hsb.b >= 0.6)
        let pale = try #require(AccentColor.pick(from: pixels("#FFFF99", 40)))
        #expect(pale.hsb.b <= 0.9)
        #expect(pale.hsb.s >= 0.45)
    }
}

@Suite struct ScreenAnchorTests {
    // A screen's visible frame under a 25 pt menu bar, the 540x164 card, and a 192x154 clock to its left.
    let screen = CGRect(x: 0, y: 25, width: 1536, height: 900)
    let card = CGSize(width: 540, height: 164)
    let clock = CGSize(width: 192, height: 154)

    func group(withClock: Bool) -> CGRect {
        ClockLayout.groupBounds(card: card, clock: withClock ? clock : nil, anchor: .leftCenter, gap: 24)
    }

    func origin(_ a: ScreenAnchor, clock withClock: Bool = false, margin: Double = 32) -> CGPoint {
        PositionResolver.origin(for: PositionSettings(anchor: a, margin: margin), cardSize: card,
                                group: group(withClock: withClock), in: screen)
    }

    /// Where the center of the card and clock together ends up.
    func groupCenter(_ a: ScreenAnchor, clock withClock: Bool) -> CGPoint {
        let o = origin(a, clock: withClock), g = group(withClock: withClock)
        return CGPoint(x: o.x + g.midX, y: o.y + g.midY)
    }

    @Test func thereAreNinePointsOnA3x3Grid() {
        #expect(ScreenAnchor.allCases.count == 9)
        #expect(Set(ScreenAnchor.allCases.map { "\($0.row),\($0.column)" }).count == 9)
        #expect(ScreenAnchor(row: 1, column: 1) == .center)
        #expect(ScreenAnchor(row: 0, column: 2) == .topRight)
    }

    @Test func thePointsAreOnTheRuleOfThirdsGrid() {
        let third: Double = 1.0 / 3, half: Double = 0.5, twoThirds: Double = 2.0 / 3
        let xs = Set(ScreenAnchor.allCases.map { $0.fraction.x })
        let ys = Set(ScreenAnchor.allCases.map { $0.fraction.y })
        let expected: Set<Double> = [third, half, twoThirds]
        #expect(xs == expected)
        #expect(ys == expected)
        let center = ScreenAnchor.center.fraction
        #expect(center.x == half)
        #expect(center.y == half)
        // Top row is high on the screen (Cocoa's y grows upward).
        #expect(ScreenAnchor.topLeft.fraction.y > ScreenAnchor.bottomLeft.fraction.y)
        #expect(ScreenAnchor.topLeft.fraction.x < ScreenAnchor.topRight.fraction.x)
    }

    @Test func theCardAloneIsCenteredOnThePoint() {
        let c = groupCenter(.topLeft, clock: false)
        let expectedX: Double = 1536.0 / 3
        let expectedY: Double = 25.0 + 600.0  // two thirds of the 900 pt visible height, above the 25 pt base
        #expect(abs(c.x - expectedX) < 0.001)
        #expect(abs(c.y - expectedY) < 0.001)
        let mid = groupCenter(.center, clock: false)
        #expect(abs(mid.x - 768) < 0.001)
        #expect(abs(mid.y - 475) < 0.001)
    }

    @Test func theCardAndClockTogetherAreCenteredOnThePoint() {
        for a in ScreenAnchor.allCases {
            let c = groupCenter(a, clock: true)
            let f = a.fraction
            let expectedX: Double = 1536.0 * f.x
            let expectedY: Double = 25.0 + 900.0 * f.y
            #expect(abs(c.x - expectedX) < 0.001, "\(a) x")
            #expect(abs(c.y - expectedY) < 0.001, "\(a) y")
        }
    }

    @Test func withAClockOnTheLeftTheCardSitsToTheRightOfThePoint() {
        // The group is wider than the card and extends left of it, so the card's center is right of the point.
        let withClock = origin(.center, clock: true), without = origin(.center, clock: false)
        #expect(withClock.x > without.x)
        #expect(abs(withClock.y - without.y) < 6, "a clock that is not taller than the card barely moves it vertically")
    }

    @Test func theGroupBoundsCoverBothAndTouchTheCardOrigin() {
        let g = group(withClock: true)
        #expect(abs(g.minX - (-216)) < 0.001)   // clock width 192 + gap 24, to the left of the card
        #expect(abs(g.maxX - 540) < 0.001)
        #expect(abs(g.height - 164) < 0.001)     // the 154 pt clock is centered beside the 164 pt card
        let cardOnly = group(withClock: false)
        #expect(cardOnly.minX == 0 && cardOnly.minY == 0)
        #expect(abs(cardOnly.width - 540) < 0.001 && abs(cardOnly.height - 164) < 0.001)
    }

    @Test func theMarginKeepsTheGroupOffTheScreenEdge() {
        // 340 pt is a margin the 756 pt-wide group can honor on this screen, and it is bigger than the point
        // would give, so the group gets pushed in from the upper left.
        let p = PositionSettings(anchor: .topLeft, margin: 340)
        let g = group(withClock: true)
        let o = PositionResolver.origin(for: p, cardSize: card, group: g, in: screen)
        #expect(o.x + g.minX >= 340 - 0.001)
        #expect(o.y + g.maxY <= 925 - 340 + 0.001)
    }

    @Test func aMarginTooBigToHonorFallsBackToCenteringTheGroup() {
        // 400 pt of margin on both sides leaves no room for the group: it is centered instead of overflowing.
        let p = PositionSettings(anchor: .topLeft, margin: 400)
        let g = group(withClock: true)
        let o = PositionResolver.origin(for: p, cardSize: card, group: g, in: screen)
        let groupCenterX = o.x + g.midX
        #expect(abs(groupCenterX - 768) < 0.001)
        #expect(screen.contains(CGRect(origin: o, size: card)))
    }

    @Test func everyPointKeepsTheCardOnScreen() {
        for a in ScreenAnchor.allCases {
            let o = origin(a, clock: true, margin: 500)
            #expect(screen.contains(CGRect(origin: o, size: card)), "\(a)")
        }
    }

    @Test func rowsRunTopToBottomAndColumnsLeftToRight() {
        #expect(origin(.top).y > origin(.center).y)
        #expect(origin(.center).y > origin(.bottom).y)
        #expect(origin(.left).x < origin(.center).x)
        #expect(origin(.center).x < origin(.right).x)
    }

    @Test func droppingTheGroupNearAPointSnapsToIt() {
        let base = PositionSettings(snap: true)
        let g = group(withClock: true)
        let o = origin(.topRight, clock: true)
        let nudged = CGPoint(x: o.x + 20, y: o.y - 20)
        let p = PositionResolver.position(forDropAt: nudged, cardSize: card, group: g, in: screen, keeping: base)
        #expect(p.anchor == .topRight)
    }

    @Test func snappingGoesToTheNearestPointNotJustAnyPoint() {
        let base = PositionSettings(snap: true)
        let g = group(withClock: false)
        // Dropped exactly on the center point's spot: that point wins even if others are within range.
        let p = PositionResolver.position(forDropAt: origin(.center), cardSize: card, group: g, in: screen, keeping: base,
                                          snapDistance: 10_000)
        #expect(p.anchor == .center)
    }

    @Test func droppingAwayFromEveryPointStoresACustomPosition() {
        let base = PositionSettings(snap: true)
        let g = group(withClock: false)
        let farFromAll = CGPoint(x: 5, y: 30)
        let p = PositionResolver.position(forDropAt: farFromAll, cardSize: card, group: g, in: screen, keeping: base)
        #expect(p.anchor == nil)
        #expect(p.relX >= 0 && p.relX <= 1 && p.relY >= 0 && p.relY <= 1)
    }

    @Test func snapOffNeverSnaps() {
        var base = PositionSettings(snap: false)
        base.anchor = nil
        let p = PositionResolver.position(forDropAt: origin(.center), cardSize: card, group: group(withClock: false),
                                          in: screen, keeping: base)
        #expect(p.anchor == nil)
    }

    @Test func aCustomPositionSurvivesAResolutionChange() {
        let base = PositionSettings(snap: false)
        let stored = PositionResolver.position(forDropAt: CGPoint(x: 498, y: 393), cardSize: card, in: screen, keeping: base)
        let bigger = CGRect(x: 0, y: 25, width: 2560, height: 1400)
        let o = PositionResolver.origin(for: stored, cardSize: card, in: bigger)
        #expect(abs(o.x - (2560 - 540) / 2) < 0.5, "still horizontally centred on the larger display")
    }

    @Test func aSavedCustomPositionNeverLeavesTheScreen() {
        let off = PositionSettings(anchor: nil, relX: 5, relY: -5)
        let o = PositionResolver.origin(for: off, cardSize: card, in: screen)
        #expect(screen.contains(CGRect(origin: o, size: card)))
    }

    @Test func filesWrittenWithTheOldCornerKeyStillLoad() throws {
        let c = try Config.decode(from: Data(#"{"position":{"corner":"topLeft","margin":20}}"#.utf8))
        #expect(c.position.anchor == .topLeft)
        let free = try Config.decode(from: Data(#"{"position":{"corner":null,"relX":0.3}}"#.utf8))
        #expect(free.position.anchor == nil)
        #expect(free.position.relX == 0.3)
        let both = try Config.decode(from: Data(#"{"position":{"anchor":"center","corner":"topLeft"}}"#.utf8))
        #expect(both.position.anchor == .center, "the new key wins")
    }

    @Test func thePointsRoundTrip() throws {
        for a in ScreenAnchor.allCases {
            var c = Config()
            c.position.anchor = a
            #expect(try Config.decode(from: c.encoded()).position.anchor == a)
        }
    }
}
