import CoreGraphics
import Foundation

/// The nine points where the card can be put: the points on the rule-of-thirds grid, a 3×3 set with x and y
/// each at one third, one half and two thirds of the screen. The point being placed is the center of the
/// card and the clock together, so the pair moves as one.
///
/// "Top - Left" is the point where the upper vertical third line and the left horizontal third line cross.
public enum ScreenAnchor: String, Codable, Sendable, CaseIterable {
    case topLeft, top, topRight
    case left, center, right
    case bottomLeft, bottom, bottomRight

    /// Row (0 = top) and column (0 = left) in the 3×3 grid.
    public var row: Int {
        switch self {
        case .topLeft, .top, .topRight: 0
        case .left, .center, .right: 1
        case .bottomLeft, .bottom, .bottomRight: 2
        }
    }

    public var column: Int {
        switch self {
        case .topLeft, .left, .bottomLeft: 0
        case .top, .center, .bottom: 1
        case .topRight, .right, .bottomRight: 2
        }
    }

    public init(row: Int, column: Int) {
        self = Self.allCases.first { $0.row == row && $0.column == column } ?? .center
    }

    /// Where the point sits on a screen, as fractions of its visible area: `x` from the left and `y` from the
    /// bottom (Cocoa's direction, so the top row has the largest `y`).
    public var fraction: (x: Double, y: Double) {
        let x = [1.0 / 3, 1.0 / 2, 2.0 / 3][column]
        let y = [2.0 / 3, 1.0 / 2, 1.0 / 3][row]
        return (x, y)
    }
}

/// Where the card sits, stored relative to a display so it survives resolution and display changes.
public struct PositionSettings: Equatable, Sendable {
    /// Display UUID. nil means the main display.
    public var display: String?
    /// When set, the center of the card and clock together sits on this rule-of-thirds point. `relX` and `relY`
    /// are then ignored. nil means a custom position: wherever it was dropped.
    public var anchor: ScreenAnchor?
    /// Custom position of the card as a fraction (0...1) of the room it has to move in. y = 0 is the bottom.
    public var relX: Double
    public var relY: Double
    /// Snap to the nearest of the nine points when dropped close to one.
    public var snap: Bool
    /// The least distance, in points, between the card and clock and any screen edge. It only matters when a
    /// point would otherwise push them closer to an edge than this.
    public var margin: Double

    public init(display: String? = nil, anchor: ScreenAnchor? = .bottomRight, relX: Double = 0, relY: Double = 0,
                snap: Bool = true, margin: Double = 32) {
        self.display = display; self.anchor = anchor; self.relX = relX; self.relY = relY
        self.snap = snap; self.margin = margin
    }
}

/// Converts between stored positions and window origins. Coordinates are Cocoa's:
/// origin at the bottom-left, and `area` is a screen's visible frame (menu bar and Dock excluded).
///
/// `group` is the bounding box of the card and the clock together, relative to the card's origin (the card
/// itself is at 0,0). Without it, the group is just the card.
public enum PositionResolver {
    public static func origin(for position: PositionSettings, cardSize: CGSize, group: CGRect? = nil, in area: CGRect) -> CGPoint {
        let card = CGRect(origin: .zero, size: cardSize)
        let g = group ?? card
        var x: Double, y: Double

        if let anchor = position.anchor {
            let f = anchor.fraction
            let target = CGPoint(x: area.minX + f.x * area.width, y: area.minY + f.y * area.height)
            x = target.x - g.midX
            y = target.y - g.midY
            // Keep the whole group at least `margin` inside the screen.
            let m = position.margin
            x = clamp(x, area.minX + m - g.minX, area.maxX - m - g.maxX)
            y = clamp(y, area.minY + m - g.minY, area.maxY - m - g.maxY)
        } else {
            x = area.minX + min(1, max(0, position.relX)) * max(0, area.width - cardSize.width)
            y = area.minY + min(1, max(0, position.relY)) * max(0, area.height - cardSize.height)
        }
        // Never leave the card itself off-screen, whatever the numbers say.
        x = clamp(x, area.minX, area.maxX - cardSize.width)
        y = clamp(y, area.minY, area.maxY - cardSize.height)
        return CGPoint(x: x, y: y)
    }

    /// The position to store after the card is dropped at `origin`. If the center of the card and clock together
    /// is within `snapDistance` of one of the nine points, that point is stored; otherwise a custom position.
    public static func position(
        forDropAt origin: CGPoint, cardSize: CGSize, group: CGRect? = nil, in area: CGRect,
        keeping base: PositionSettings, snapDistance: Double = 64
    ) -> PositionSettings {
        var result = base
        let g = group ?? CGRect(origin: .zero, size: cardSize)
        if base.snap {
            let center = CGPoint(x: origin.x + g.midX, y: origin.y + g.midY)
            var best: (anchor: ScreenAnchor, distance: Double)?
            for anchor in ScreenAnchor.allCases {
                let f = anchor.fraction
                let point = CGPoint(x: area.minX + f.x * area.width, y: area.minY + f.y * area.height)
                let d = Double(hypot(center.x - point.x, center.y - point.y))
                if d <= snapDistance, d < (best?.distance ?? .infinity) { best = (anchor, d) }
            }
            if let best {
                result.anchor = best.anchor
                return result
            }
        }
        result.anchor = nil
        let freeW = area.width - cardSize.width, freeH = area.height - cardSize.height
        result.relX = freeW > 0 ? min(1, max(0, (origin.x - area.minX) / freeW)) : 0
        result.relY = freeH > 0 ? min(1, max(0, (origin.y - area.minY) / freeH)) : 0
        return result
    }

    /// `value` limited to `low...high`. When the range is empty (the group is bigger than the room), the middle.
    private static func clamp(_ value: Double, _ low: Double, _ high: Double) -> Double {
        low <= high ? min(max(value, low), high) : (low + high) / 2
    }
}
