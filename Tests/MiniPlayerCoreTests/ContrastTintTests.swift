import Foundation
import Testing
@testable import MiniPlayerCore

@Suite struct ContrastTintTests {
    func solid(_ hex: String, _ n: Int = 20) -> [RGB] { Array(repeating: RGB(hex: hex)!, count: n) }

    @Test func aLightWallpaperGetsADarkerTint() throws {
        let backdrop = RGB(hex: "#CFE3E3")!
        let tint = ContrastTint.pick(from: solid("#CFE3E3"), opacity: 1)
        #expect(tint.relativeLuminance < backdrop.relativeLuminance)
        #expect(RGB.contrast(tint, backdrop) >= 4.5, "a solid tint is readable against it")
    }

    @Test func aDarkWallpaperGetsALighterTint() {
        let backdrop = RGB(hex: "#12303A")!
        let tint = ContrastTint.pick(from: solid("#12303A"), opacity: 1)
        #expect(tint.relativeLuminance > backdrop.relativeLuminance)
        #expect(RGB.contrast(tint, backdrop) >= 4.5)
    }

    @Test func theTintBorrowsTheWallpapersHue() {
        let teal = RGB(hex: "#9CC8C8")!.hsb.h
        let tint = ContrastTint.pick(from: solid("#9CC8C8"), opacity: 1)
        let diff = abs(tint.hsb.h - teal)
        #expect(min(diff, 1 - diff) < 0.04, "within about 15 degrees of the wallpaper's hue")
        #expect(tint.hsb.s > 0.3, "it is a color, not gray")
    }

    @Test func aGrayWallpaperGetsAGrayTint() {
        let tint = ContrastTint.pick(from: solid("#B0B0B0"), opacity: 1)
        #expect(tint.hsb.s < 0.01)
    }

    @Test func theTintStaysAColorAndNeverPureBlackOrWhite() {
        let onWhite = ContrastTint.pick(from: solid("#FFFFFF"), opacity: 0.7)
        #expect(onWhite.hsb.b >= 0.22 - 0.001, "the dark limit keeps some brightness")
        let onBlack = ContrastTint.pick(from: solid("#000000"), opacity: 0.7)
        #expect(onBlack.hsb.b <= 1.0)
    }

    @Test func lessOpacityPushesTheTintFurther() {
        let pale = solid("#CFE3E3")
        let faint = ContrastTint.pick(from: pale, opacity: 0.5)
        let strong = ContrastTint.pick(from: pale, opacity: 1)
        #expect(faint.relativeLuminance <= strong.relativeLuminance, "a fainter clock needs a darker tint")
    }

    @Test func aMixedBackdropIsAveraged() {
        // Half pale, half dark: the average is mid, and the tint is still readable against that average.
        let mixed = solid("#E0EEEE", 10) + solid("#103030", 10)
        let tint = ContrastTint.pick(from: mixed, opacity: 1)
        let avg = RGB(r: (0xE0 + 0x10) / 2.0 / 255, g: (0xEE + 0x30) / 2.0 / 255, b: (0xEE + 0x30) / 2.0 / 255)
        #expect(RGB.contrast(tint, avg) >= 3.5)
    }

    @Test func noPixelsMeansTheFallback() {
        let fallback = RGB(hex: "#FF8800")!
        #expect(ContrastTint.pick(from: [], fallback: fallback) == fallback)
    }

    @Test func contrastMatchesTheWCAGExtremes() {
        let ratio = RGB.contrast(RGB(r: 0, g: 0, b: 0), RGB(r: 1, g: 1, b: 1))
        #expect(abs(ratio - 21) < 0.01)
        #expect(abs(RGB.contrast(RGB(r: 0.5, g: 0.5, b: 0.5), RGB(r: 0.5, g: 0.5, b: 0.5)) - 1) < 0.0001)
    }
}

@Suite struct ClockColorModeTests {
    @Test func theClockIsTintedFromTheWallpaperByDefault() {
        #expect(ClockSettings().colorMode == .wallpaper)
    }

    @Test func aConfigWithoutTheKeyGetsTheDefault() throws {
        // Files written before this option existed.
        let c = try Config.decode(from: Data(##"{"clock":{"colorHex":"#112233"}}"##.utf8))
        #expect(c.clock.colorMode == .wallpaper)
        #expect(c.clock.colorHex == "#112233")
    }

    @Test func anUnknownModeFallsBackAndTheModeRoundTrips() throws {
        let bad = try Config.decode(from: Data(#"{"clock":{"colorMode":"rainbow"}}"#.utf8))
        #expect(bad.clock.colorMode == .wallpaper)
        var c = Config()
        c.clock.colorMode = .custom
        #expect(try Config.decode(from: c.encoded()).clock.colorMode == .custom)
    }
}

@Suite struct AccentModeTests {
    @Test func theAccentDefaultsToTheArtwork() {
        #expect(AccentSettings().mode == .auto)
    }

    @Test func theWallpaperModeRoundTripsAndKeepsTheFallbackColor() throws {
        var c = Config()
        c.accent.mode = .wallpaper
        c.accent.hex = "#336699"
        let back = try Config.decode(from: c.encoded())
        #expect(back.accent.mode == .wallpaper)
        #expect(back.accent.hex == "#336699")
    }

    @Test func anUnknownAccentModeFallsBackToTheDefault() throws {
        let c = try Config.decode(from: Data(#"{"accent":{"mode":"neon"}}"#.utf8))
        #expect(c.accent.mode == .auto)
    }

    @Test func everyAccentModeIsListed() {
        #expect(Set(AccentMode.allCases.map(\.rawValue)) == ["auto", "wallpaper", "manual", "system"])
    }
}
