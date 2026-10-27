import Foundation

/// Picks a tint from the wallpaper behind something (the clock, or the card's accent), the way the lock screen
/// tints its clock.
public enum ContrastTint {
    /// A tint with the hue of the backdrop and a lightness that stands out from it: lighter on a dark
    /// wallpaper, darker on a light one. `backdrop` is a sample of the pixels behind the clock.
    ///
    /// The clock is drawn at `opacity`, which weakens contrast, so lightness is pushed until the blended
    /// color reaches `minimumContrast` (or the limit, which keeps the tint a color and never pure black or
    /// pure white).
    public static func pick(
        from backdrop: [RGB], opacity: Double = 0.7, minimumContrast: Double = 4.5,
        fallback: RGB = RGB(r: 1, g: 1, b: 1)
    ) -> RGB {
        guard !backdrop.isEmpty else { return fallback }
        let n = Double(backdrop.count)
        let average = RGB(r: backdrop.map(\.r).reduce(0, +) / n,
                          g: backdrop.map(\.g).reduce(0, +) / n,
                          b: backdrop.map(\.b).reduce(0, +) / n)
        let (hue, saturation, _) = average.hsb
        let neutral = saturation < 0.06  // a gray backdrop has no hue to borrow

        // Go in whichever direction has more room: darker where black would stand out more than white.
        let darker = RGB.contrast(RGB(r: 0, g: 0, b: 0), average) >= RGB.contrast(RGB(r: 1, g: 1, b: 1), average)

        var best = fallback
        if darker {
            let tintSaturation = neutral ? 0 : min(0.85, max(0.35, saturation * 1.8))
            var brightness = 0.50
            while brightness >= 0.22 - 1e-9 {
                best = RGB(h: hue, s: tintSaturation, b: brightness)
                if RGB.contrast(best.blended(over: average, opacity: opacity), average) >= minimumContrast { return best }
                brightness -= 0.02
            }
        } else {
            let tintSaturation = neutral ? 0 : min(0.45, saturation * 0.9)
            var brightness = 0.88
            while brightness <= 1.0 + 1e-9 {
                best = RGB(h: hue, s: tintSaturation, b: brightness)
                if RGB.contrast(best.blended(over: average, opacity: opacity), average) >= minimumContrast { return best }
                brightness += 0.01
            }
        }
        return best
    }
}
