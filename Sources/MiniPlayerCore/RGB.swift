import Foundation

/// A color in sRGB, components 0...1. Kept free of AppKit so the logic stays testable.
public struct RGB: Equatable, Sendable {
    public var r: Double, g: Double, b: Double

    public init(r: Double, g: Double, b: Double) {
        self.r = r; self.g = g; self.b = b
    }

    /// Parses `#RRGGBB` or `RRGGBB`.
    public init?(hex: String) {
        var s = hex.trimmingCharacters(in: .whitespaces)
        if s.hasPrefix("#") { s.removeFirst() }
        guard s.count == 6, let value = UInt32(s, radix: 16) else { return nil }
        self.init(r: Double((value >> 16) & 0xFF) / 255,
                  g: Double((value >> 8) & 0xFF) / 255,
                  b: Double(value & 0xFF) / 255)
    }

    public var hex: String {
        func byte(_ x: Double) -> Int { Int((min(1, max(0, x)) * 255).rounded()) }
        return String(format: "#%02X%02X%02X", byte(r), byte(g), byte(b))
    }

    /// WCAG relative luminance, 0 (black) to 1 (white).
    public var relativeLuminance: Double {
        func linear(_ c: Double) -> Double { c <= 0.03928 ? c / 12.92 : pow((c + 0.055) / 1.055, 2.4) }
        return 0.2126 * linear(r) + 0.7152 * linear(g) + 0.0722 * linear(b)
    }

    /// WCAG contrast ratio between two colors, 1 (identical) to 21 (black on white).
    public static func contrast(_ a: RGB, _ b: RGB) -> Double {
        let (la, lb) = (a.relativeLuminance, b.relativeLuminance)
        return (max(la, lb) + 0.05) / (min(la, lb) + 0.05)
    }

    /// This color drawn at `opacity` over `backdrop`.
    public func blended(over backdrop: RGB, opacity: Double) -> RGB {
        let o = min(1, max(0, opacity))
        return RGB(r: r * o + backdrop.r * (1 - o), g: g * o + backdrop.g * (1 - o), b: b * o + backdrop.b * (1 - o))
    }

    public var hsb: (h: Double, s: Double, b: Double) {
        let maxV = max(r, g, b), minV = min(r, g, b), d = maxV - minV
        var h = 0.0
        if d > 0 {
            if maxV == r { h = ((g - b) / d).truncatingRemainder(dividingBy: 6) }
            else if maxV == g { h = (b - r) / d + 2 }
            else { h = (r - g) / d + 4 }
            h /= 6
            if h < 0 { h += 1 }
        }
        return (h, maxV == 0 ? 0 : d / maxV, maxV)
    }

    public init(h: Double, s: Double, b: Double) {
        let h6 = (h - floor(h)) * 6
        let c = b * s, x = c * (1 - abs(h6.truncatingRemainder(dividingBy: 2) - 1)), m = b - c
        let (r, g, bl): (Double, Double, Double)
        switch Int(h6) {
        case 0: (r, g, bl) = (c, x, 0)
        case 1: (r, g, bl) = (x, c, 0)
        case 2: (r, g, bl) = (0, c, x)
        case 3: (r, g, bl) = (0, x, c)
        case 4: (r, g, bl) = (x, 0, c)
        default: (r, g, bl) = (c, 0, x)
        }
        self.init(r: r + m, g: g + m, b: bl + m)
    }
}

/// Picks one accent color for a piece of artwork.
public enum AccentColor {
    /// The most prominent colorful hue among `pixels`, nudged into a mid brightness range so it
    /// stays visible on both light and dark glass. Returns nil for grayscale or near-black/white art.
    public static func pick(from pixels: [RGB]) -> RGB? {
        let bins = 12
        var weight = Array(repeating: 0.0, count: bins)
        var sums = Array(repeating: (r: 0.0, g: 0.0, b: 0.0, n: 0.0), count: bins)

        for pixel in pixels {
            let (h, s, v) = pixel.hsb
            // Skip grays, near-black and near-white: they carry no hue.
            guard s > 0.18, v > 0.2, !(v > 0.95 && s < 0.3) else { continue }
            let bin = min(bins - 1, Int(h * Double(bins)))
            let w = s * v  // prefer vivid, bright pixels
            weight[bin] += w
            sums[bin].r += pixel.r * w; sums[bin].g += pixel.g * w; sums[bin].b += pixel.b * w; sums[bin].n += w
        }
        guard let best = weight.indices.max(by: { weight[$0] < weight[$1] }), weight[best] > 0 else { return nil }
        let n = sums[best].n
        let average = RGB(r: sums[best].r / n, g: sums[best].g / n, b: sums[best].b / n)
        let (h, s, v) = average.hsb
        return RGB(h: h, s: max(s, 0.45), b: min(max(v, 0.6), 0.9))
    }
}
