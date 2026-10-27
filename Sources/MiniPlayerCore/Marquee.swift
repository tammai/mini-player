import Foundation

/// Scroll position for a title that is wider than its slot.
///
/// The text rests at the start, scrolls left one full copy plus a gap, then the second copy
/// sits where the first began, so the loop is seamless.
public enum Marquee {
    /// Horizontal offset (zero or negative) `elapsed` seconds after the marquee (re)started.
    public static func offset(
        elapsed: TimeInterval,
        textWidth: Double,
        containerWidth: Double,
        gap: Double = 48,
        speed: Double = 36,
        pause: Double = 2.5
    ) -> Double {
        guard textWidth > containerWidth, speed > 0 else { return 0 }
        let travel = textWidth + gap
        let cycle = pause + travel / speed
        let t = max(0, elapsed).truncatingRemainder(dividingBy: cycle)
        if t < pause { return 0 }
        return -(t - pause) * speed
    }
}
