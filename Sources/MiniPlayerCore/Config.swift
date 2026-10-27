import Foundation

// MARK: Choices

public enum ArtworkSide: String, Codable, Sendable, CaseIterable { case left, right }
public enum ArtworkFit: String, Codable, Sendable, CaseIterable {
    /// A square slot: the image fills it and the edges are cropped.
    case fill
    /// The slot follows the image's shape, so the whole image shows (16:9 thumbnails stay wide).
    case fit
}
public enum GlassStyle: String, Codable, Sendable, CaseIterable { case regular, clear }

/// What sits behind the card's content.
public enum BackgroundKind: String, Codable, Sendable, CaseIterable {
    /// Liquid Glass.
    case glass
    /// A frosted blur of whatever is behind the card.
    case frosted
    /// Nothing: the content floats directly on the wallpaper.
    case none
}

/// The blur materials macOS offers. They differ in how strongly they blur and tint.
public enum FrostMaterial: String, Codable, Sendable, CaseIterable {
    case underWindow, sidebar, menu, popover, header, hud
}
public enum AccentMode: String, Codable, Sendable, CaseIterable {
    /// Taken from the artwork.
    case auto
    /// The color in `accent.hex`.
    case manual
    /// The system label color: plain black or white, whichever reads on the glass.
    case system
}
public enum WaveShape: String, Codable, Sendable, CaseIterable {
    case bars
    /// Left and right halves mirror each other.
    case mirrored
    /// Round dots that bounce instead of bars that grow.
    case dots
}
public enum WaveBaseline: String, Codable, Sendable, CaseIterable { case center, bottom }
public enum WaveAnchor: String, Codable, Sendable, CaseIterable {
    /// In the text column, where the transport buttons would be.
    case row
    case topRight, bottomRight
}
public enum WaveColor: String, Codable, Sendable, CaseIterable { case accent, primary }

/// Twelve places around the card: three on each side. The clock sits just outside the card.
/// Reads as "side, then alignment along that side": `leftCenter` is left of the card, vertically centered.
public enum ClockAnchor: String, Codable, Sendable, CaseIterable {
    case topLeft, topCenter, topRight
    case bottomLeft, bottomCenter, bottomRight
    case leftTop, leftCenter, leftBottom
    case rightTop, rightCenter, rightBottom
}
public enum ClockDatePlacement: String, Codable, Sendable, CaseIterable { case above, below }
public enum ClockDateAlignment: String, Codable, Sendable, CaseIterable { case left, center, right }
public enum ClockFormat: String, Codable, Sendable, CaseIterable {
    /// Follows the system's 12 or 24 hour setting.
    case system, h12, h24
}

// MARK: Settings

public struct CardSettings: Equatable, Codable, Sendable {
    public var scale = 1.0
    public var cornerRadius = 28.0
    public var artworkSide = ArtworkSide.left
    public var artworkFit = ArtworkFit.fit
    /// Height of the artwork slot in points.
    public var artworkSize = 120.0

    public init() {}
    enum CodingKeys: String, CodingKey { case scale, cornerRadius, artworkSide, artworkFit, artworkSize }
    public init(from decoder: Decoder) throws {
        let c = try decoder.container(keyedBy: CodingKeys.self)
        scale = c.value(.scale, scale)
        cornerRadius = c.value(.cornerRadius, cornerRadius)
        artworkSide = c.value(.artworkSide, artworkSide)
        artworkFit = c.value(.artworkFit, artworkFit)
        artworkSize = c.value(.artworkSize, artworkSize)
    }
}

public struct BackgroundSettings: Equatable, Codable, Sendable {
    public var kind = BackgroundKind.glass
    /// How opaque the background is. The content on top is not affected.
    public var opacity = 1.0
    /// Liquid Glass only.
    public var style = GlassStyle.regular
    /// Frosted only.
    public var frost = FrostMaterial.popover
    /// `#RRGGBB`, or nil for no tint. Applies to glass and frosted.
    public var tintHex: String?
    public var tintOpacity = 0.3

    public init() {}
    enum CodingKeys: String, CodingKey { case kind, opacity, style, frost, tintHex, tintOpacity }
    public init(from decoder: Decoder) throws {
        let c = try decoder.container(keyedBy: CodingKeys.self)
        kind = c.value(.kind, kind)
        opacity = c.value(.opacity, opacity)
        style = c.value(.style, style)
        frost = c.value(.frost, frost)
        tintHex = c.optionalValue(.tintHex)
        tintOpacity = c.value(.tintOpacity, tintOpacity)
    }
    public func encode(to encoder: Encoder) throws {
        var c = encoder.container(keyedBy: CodingKeys.self)
        try c.encode(kind, forKey: .kind)
        try c.encode(opacity, forKey: .opacity)
        try c.encode(style, forKey: .style)
        try c.encode(frost, forKey: .frost)
        try c.encode(tintHex, forKey: .tintHex)  // written as null so the key is discoverable in the file
        try c.encode(tintOpacity, forKey: .tintOpacity)
    }
}

public struct AccentSettings: Equatable, Codable, Sendable {
    public var mode = AccentMode.auto
    public var hex = "#0A84FF"

    public init() {}
    enum CodingKeys: String, CodingKey { case mode, hex }
    public init(from decoder: Decoder) throws {
        let c = try decoder.container(keyedBy: CodingKeys.self)
        mode = c.value(.mode, mode)
        hex = c.value(.hex, hex)
    }
}

public struct TextSettings: Equatable, Codable, Sendable {
    /// A font family name, or nil for the system font.
    public var fontName: String?
    public var titleSize = 19.0
    public var artistSize = 14.0

    public init() {}
    enum CodingKeys: String, CodingKey { case fontName, titleSize, artistSize }
    public init(from decoder: Decoder) throws {
        let c = try decoder.container(keyedBy: CodingKeys.self)
        fontName = c.optionalValue(.fontName)
        titleSize = c.value(.titleSize, titleSize)
        artistSize = c.value(.artistSize, artistSize)
    }
    public func encode(to encoder: Encoder) throws {
        var c = encoder.container(keyedBy: CodingKeys.self)
        try c.encode(fontName, forKey: .fontName)
        try c.encode(titleSize, forKey: .titleSize)
        try c.encode(artistSize, forKey: .artistSize)
    }
}

public struct ElementSettings: Equatable, Codable, Sendable {
    public var artwork = true
    public var artist = true
    public var progress = true
    public var times = true
    public var waves = true

    public init() {}
    enum CodingKeys: String, CodingKey { case artwork, artist, progress, times, waves }
    public init(from decoder: Decoder) throws {
        let c = try decoder.container(keyedBy: CodingKeys.self)
        artwork = c.value(.artwork, artwork)
        artist = c.value(.artist, artist)
        progress = c.value(.progress, progress)
        times = c.value(.times, times)
        waves = c.value(.waves, waves)
    }
}

public struct WaveSettings: Equatable, Hashable, Codable, Sendable {
    public var count = 16
    public var thickness = 5.0
    public var gap = 4.0
    public var maxHeight = 22.0
    /// 0 is square ends, 1 is fully round.
    public var roundness = 1.0
    public var shape = WaveShape.bars
    public var baseline = WaveBaseline.center
    public var anchor = WaveAnchor.row
    public var offsetX = 0.0
    public var offsetY = 0.0
    public var color = WaveColor.accent

    public init() {}
    enum CodingKeys: String, CodingKey {
        case count, thickness, gap, maxHeight, roundness, shape, baseline, anchor, offsetX, offsetY, color
    }
    public init(from decoder: Decoder) throws {
        let c = try decoder.container(keyedBy: CodingKeys.self)
        count = c.value(.count, count)
        thickness = c.value(.thickness, thickness)
        gap = c.value(.gap, gap)
        maxHeight = c.value(.maxHeight, maxHeight)
        roundness = c.value(.roundness, roundness)
        shape = c.value(.shape, shape)
        baseline = c.value(.baseline, baseline)
        anchor = c.value(.anchor, anchor)
        offsetX = c.value(.offsetX, offsetX)
        offsetY = c.value(.offsetY, offsetY)
        color = c.value(.color, color)
    }
}

extension PositionSettings: Codable {
    /// `corner` is the key files used before the card could sit at all nine places. It is still read.
    enum CodingKeys: String, CodingKey { case display, anchor, corner, relX, relY, snap, margin }
    public init(from decoder: Decoder) throws {
        let c = try decoder.container(keyedBy: CodingKeys.self)
        let d = PositionSettings()
        // A custom position stores `anchor: null`, so a missing key means the default place, not custom.
        let anchor: ScreenAnchor?
        if c.contains(.anchor) { anchor = c.optionalValue(.anchor) }
        else if c.contains(.corner) { anchor = c.optionalValue(.corner) }
        else { anchor = d.anchor }
        self.init(display: c.optionalValue(.display), anchor: anchor,
                  relX: c.value(.relX, d.relX), relY: c.value(.relY, d.relY),
                  snap: c.value(.snap, d.snap), margin: c.value(.margin, d.margin))
    }
    public func encode(to encoder: Encoder) throws {
        var c = encoder.container(keyedBy: CodingKeys.self)
        try c.encode(display, forKey: .display)
        try c.encode(anchor, forKey: .anchor)
        try c.encode(relX, forKey: .relX)
        try c.encode(relY, forKey: .relY)
        try c.encode(snap, forKey: .snap)
        try c.encode(margin, forKey: .margin)
    }
}

public struct ClockSettings: Equatable, Codable, Sendable {
    public var enabled = true
    public var anchor = ClockAnchor.leftCenter
    /// Space between the card and the clock, in points.
    public var gap = 24.0
    /// Fine adjustment after anchoring. Positive moves right and down, like screen coordinates.
    public var offsetX = 0.0
    public var offsetY = 0.0
    /// Font size of the time in points. The date is sized from it. The clock is scaled down
    /// when this would make it larger than the card.
    public var size = 96.0
    public var showDate = true
    public var datePlacement = ClockDatePlacement.above
    /// Which edge of the time the date lines up with.
    public var dateAlignment = ClockDateAlignment.center
    /// Extra distance between date and time. Negative pulls them closer. The default look is tight already.
    public var dateGap = 0.0
    /// Shifts the date sideways from where its alignment puts it. Positive moves right.
    public var dateOffsetX = 0.0
    public var format = ClockFormat.system
    public var colorHex = "#FFFFFF"
    public var opacity = 0.7
    /// A font family name, or nil for the system compressed font.
    public var fontName: String?

    public init() {}
    enum CodingKeys: String, CodingKey {
        case enabled, anchor, gap, offsetX, offsetY, size, showDate, datePlacement, dateAlignment, dateGap, dateOffsetX
        case format, colorHex, opacity, fontName
    }
    public init(from decoder: Decoder) throws {
        let c = try decoder.container(keyedBy: CodingKeys.self)
        enabled = c.value(.enabled, enabled)
        anchor = c.value(.anchor, anchor)
        gap = c.value(.gap, gap)
        offsetX = c.value(.offsetX, offsetX)
        offsetY = c.value(.offsetY, offsetY)
        size = c.value(.size, size)
        showDate = c.value(.showDate, showDate)
        datePlacement = c.value(.datePlacement, datePlacement)
        dateAlignment = c.value(.dateAlignment, dateAlignment)
        dateGap = c.value(.dateGap, dateGap)
        dateOffsetX = c.value(.dateOffsetX, dateOffsetX)
        format = c.value(.format, format)
        colorHex = c.value(.colorHex, colorHex)
        opacity = c.value(.opacity, opacity)
        fontName = c.optionalValue(.fontName)
    }
    public func encode(to encoder: Encoder) throws {
        var c = encoder.container(keyedBy: CodingKeys.self)
        try c.encode(enabled, forKey: .enabled)
        try c.encode(anchor, forKey: .anchor)
        try c.encode(gap, forKey: .gap)
        try c.encode(offsetX, forKey: .offsetX)
        try c.encode(offsetY, forKey: .offsetY)
        try c.encode(size, forKey: .size)
        try c.encode(showDate, forKey: .showDate)
        try c.encode(datePlacement, forKey: .datePlacement)
        try c.encode(dateAlignment, forKey: .dateAlignment)
        try c.encode(dateGap, forKey: .dateGap)
        try c.encode(dateOffsetX, forKey: .dateOffsetX)
        try c.encode(format, forKey: .format)
        try c.encode(colorHex, forKey: .colorHex)
        try c.encode(opacity, forKey: .opacity)
        try c.encode(fontName, forKey: .fontName)
    }
}

public struct GeneralSettings: Equatable, Codable, Sendable {
    public var launchAtLogin = true
    /// Seconds a paused track keeps the card visible before it fades out.
    public var pauseTimeout = 30.0

    public init() {}
    enum CodingKeys: String, CodingKey { case launchAtLogin, pauseTimeout }
    public init(from decoder: Decoder) throws {
        let c = try decoder.container(keyedBy: CodingKeys.self)
        launchAtLogin = c.value(.launchAtLogin, launchAtLogin)
        pauseTimeout = c.value(.pauseTimeout, pauseTimeout)
    }
}

// MARK: Config

/// Everything the user can change, stored as one hand-editable JSON file.
///
/// Decoding is forgiving: unknown keys are ignored, a missing key takes its default, and a value
/// of the wrong type or an unknown choice falls back to the default for that one field.
public struct Config: Equatable, Codable, Sendable {
    public var card = CardSettings()
    public var background = BackgroundSettings()
    public var accent = AccentSettings()
    public var text = TextSettings()
    public var elements = ElementSettings()
    public var waves = WaveSettings()
    public var clock = ClockSettings()
    public var position = PositionSettings()
    public var general = GeneralSettings()

    public init() {}

    enum CodingKeys: String, CodingKey { case card, background, accent, text, elements, waves, clock, position, general }
    public init(from decoder: Decoder) throws {
        let c = try decoder.container(keyedBy: CodingKeys.self)
        card = c.value(.card, card)
        background = c.value(.background, background)
        accent = c.value(.accent, accent)
        text = c.value(.text, text)
        elements = c.value(.elements, elements)
        waves = c.value(.waves, waves)
        clock = c.value(.clock, clock)
        position = c.value(.position, position)
        general = c.value(.general, general)
    }

    // MARK: File format

    /// Throws if `data` is not a JSON object.
    public static func decode(from data: Data) throws -> Config {
        try JSONDecoder().decode(Config.self, from: data).normalized()
    }

    /// Pretty-printed with sorted keys, so the file is pleasant to edit and diffs stay small.
    public func encoded() throws -> Data {
        let encoder = JSONEncoder()
        encoder.outputFormatting = [.prettyPrinted, .sortedKeys, .withoutEscapingSlashes]
        return try encoder.encode(self)
    }

    // MARK: Limits

    /// Clamps every number into a range the card can render sensibly.
    public func normalized() -> Config {
        var c = self
        func clamp(_ v: Double, _ lo: Double, _ hi: Double) -> Double { v.isFinite ? min(hi, max(lo, v)) : lo }
        c.card.scale = clamp(c.card.scale, 0.5, 2.5)
        c.card.cornerRadius = clamp(c.card.cornerRadius, 0, 60)
        c.card.artworkSize = clamp(c.card.artworkSize, 60, 200)
        c.background.opacity = clamp(c.background.opacity, 0, 1)
        c.background.tintOpacity = clamp(c.background.tintOpacity, 0, 1)
        if let hex = c.background.tintHex, RGB(hex: hex) == nil { c.background.tintHex = nil }
        if RGB(hex: c.accent.hex) == nil { c.accent.hex = AccentSettings().hex }
        c.text.titleSize = clamp(c.text.titleSize, 10, 40)
        c.text.artistSize = clamp(c.text.artistSize, 8, 30)
        c.waves.count = min(48, max(4, c.waves.count))
        c.waves.thickness = clamp(c.waves.thickness, 2, 14)
        c.waves.gap = clamp(c.waves.gap, 0, 14)
        c.waves.maxHeight = clamp(c.waves.maxHeight, 8, 48)
        c.waves.roundness = clamp(c.waves.roundness, 0, 1)
        c.waves.offsetX = clamp(c.waves.offsetX, -200, 200)
        c.waves.offsetY = clamp(c.waves.offsetY, -200, 200)
        c.clock.size = clamp(c.clock.size, 24, 300)
        c.clock.gap = clamp(c.clock.gap, 0, 200)
        c.clock.offsetX = clamp(c.clock.offsetX, -400, 400)
        c.clock.offsetY = clamp(c.clock.offsetY, -400, 400)
        c.clock.opacity = clamp(c.clock.opacity, 0.1, 1)
        c.clock.dateGap = clamp(c.clock.dateGap, -100, 100)
        c.clock.dateOffsetX = clamp(c.clock.dateOffsetX, -200, 200)
        if RGB(hex: c.clock.colorHex) == nil { c.clock.colorHex = ClockSettings().colorHex }
        c.position.relX = clamp(c.position.relX, 0, 1)
        c.position.relY = clamp(c.position.relY, 0, 1)
        c.position.margin = clamp(c.position.margin, 0, 200)
        c.general.pauseTimeout = clamp(c.general.pauseTimeout, 5, 600)
        return c
    }

    /// Appearance settings back to factory values. Position and general settings are kept.
    public func resettingAppearance() -> Config {
        var c = Config()
        c.position = position
        c.general = general
        return c
    }
}

extension KeyedDecodingContainer {
    /// Decodes a value, or `fallback` when the key is missing, null, mistyped or an unknown choice.
    func value<T: Decodable>(_ key: Key, _ fallback: T) -> T {
        ((try? decodeIfPresent(T.self, forKey: key)) ?? nil) ?? fallback
    }

    /// Decodes an optional value, or nil when the key is missing, null or mistyped.
    func optionalValue<T: Decodable>(_ key: Key) -> T? {
        (try? decodeIfPresent(T.self, forKey: key)) ?? nil
    }
}
