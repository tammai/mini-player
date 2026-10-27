import CoreGraphics
import Foundation

/// Where the clock window goes, given where the card is. Coordinates are Cocoa's (origin bottom-left).
public enum ClockLayout {
    /// The clock's origin for `anchor`, `gap` points outside `card`, then nudged by the offsets
    /// (positive moves right and down) and kept inside `area` when one is given.
    public static func origin(
        anchor: ClockAnchor, card: CGRect, clock: CGSize,
        gap: Double, offsetX: Double = 0, offsetY: Double = 0, in area: CGRect? = nil
    ) -> CGPoint {
        var x: Double, y: Double
        switch anchor {
        case .topLeft, .topCenter, .topRight:
            y = card.maxY + gap
            x = alongX(anchor == .topLeft ? 0 : anchor == .topCenter ? 0.5 : 1, card: card, clock: clock)
        case .bottomLeft, .bottomCenter, .bottomRight:
            y = card.minY - gap - clock.height
            x = alongX(anchor == .bottomLeft ? 0 : anchor == .bottomCenter ? 0.5 : 1, card: card, clock: clock)
        case .leftTop, .leftCenter, .leftBottom:
            x = card.minX - gap - clock.width
            y = alongY(anchor == .leftBottom ? 0 : anchor == .leftCenter ? 0.5 : 1, card: card, clock: clock)
        case .rightTop, .rightCenter, .rightBottom:
            x = card.maxX + gap
            y = alongY(anchor == .rightBottom ? 0 : anchor == .rightCenter ? 0.5 : 1, card: card, clock: clock)
        }
        x += offsetX
        y -= offsetY
        if let area {
            x = min(max(x, area.minX), max(area.minX, area.maxX - clock.width))
            y = min(max(y, area.minY), max(area.minY, area.maxY - clock.height))
        }
        return CGPoint(x: x, y: y)
    }

    /// The bounding box of the card and the clock together, relative to the card's origin (the card is at 0,0).
    /// With no clock (hidden or switched off) it is just the card.
    public static func groupBounds(
        card: CGSize, clock: CGSize?, anchor: ClockAnchor, gap: Double, offsetX: Double = 0, offsetY: Double = 0
    ) -> CGRect {
        let cardRect = CGRect(origin: .zero, size: card)
        guard let clock else { return cardRect }
        let origin = Self.origin(anchor: anchor, card: cardRect, clock: clock, gap: gap, offsetX: offsetX, offsetY: offsetY)
        return cardRect.union(CGRect(origin: origin, size: clock))
    }

    /// How much to shrink the clock so it fits inside `limit` (the card's size). 1 means it already fits.
    /// The clock is never enlarged, and it never grows past the card's width or height.
    public static func fitScale(content: CGSize, limit: CGSize) -> Double {
        guard content.width > 0, content.height > 0, limit.width > 0, limit.height > 0 else { return 1 }
        return min(1, limit.width / content.width, limit.height / content.height)
    }

    /// Aligns the clock along the card's width: 0 = left edges meet, 0.5 = centered, 1 = right edges meet.
    private static func alongX(_ t: Double, card: CGRect, clock: CGSize) -> Double {
        card.minX + t * (card.width - clock.width)
    }

    /// Aligns the clock along the card's height: 0 = bottom edges meet, 0.5 = centered, 1 = top edges meet.
    private static func alongY(_ t: Double, card: CGRect, clock: CGSize) -> Double {
        card.minY + t * (card.height - clock.height)
    }
}

/// Date and time text for the clock. Locale and time zone are parameters so this is testable.
public enum ClockFormatter {
    /// `10:15`. Without AM/PM, like the lock screen. Hours are padded only in 24 hour mode.
    public static func time(_ date: Date, format: ClockFormat, locale: Locale = .current, timeZone: TimeZone = .current) -> String {
        let use24 = format == .h24 || (format == .system && uses24Hour(locale: locale))
        let formatter = DateFormatter()
        formatter.locale = locale
        formatter.timeZone = timeZone
        formatter.dateFormat = use24 ? "HH:mm" : "h:mm"
        return formatter.string(from: date)
    }

    /// `Tue 27 Oct`, in the order the locale uses.
    public static func day(_ date: Date, locale: Locale = .current, timeZone: TimeZone = .current) -> String {
        let formatter = DateFormatter()
        formatter.locale = locale
        formatter.timeZone = timeZone
        formatter.setLocalizedDateFormatFromTemplate("EEEdMMM")
        return formatter.string(from: date)
    }

    static func uses24Hour(locale: Locale) -> Bool {
        // The "j" template resolves to the locale's preferred hour cycle; "a" appears only in 12 hour ones.
        let pattern = DateFormatter.dateFormat(fromTemplate: "j", options: 0, locale: locale) ?? ""
        return !pattern.contains("a")
    }
}
