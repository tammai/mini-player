import MiniPlayerCore
import SwiftUI

/// A large translucent clock with the date beside it, in the style of the iOS lock screen.
/// It never grows past the player's width or height: if the settings ask for more, it is scaled down.
struct ClockView: View {
    @ObservedObject var store: ConfigStore
    @ObservedObject var geometry: CardGeometry
    /// Reports the clock's final (possibly scaled-down) size so its window can match it.
    var onSize: (CGSize) -> Void

    @State private var natural = CGSize.zero

    private var clock: ClockSettings { store.config.clock }

    /// 1 when the clock fits inside the card, less when it has to shrink.
    private var fit: Double { ClockLayout.fitScale(content: natural, limit: geometry.size) }

    var body: some View {
        let scale = fit
        content
            .onGeometryChange(for: CGSize.self, of: \.size) { natural = $0 }
            .scaleEffect(scale, anchor: .topLeading)
            .frame(width: natural.width * scale, height: natural.height * scale, alignment: .topLeading)
            .onChange(of: natural) { report() }
            .onChange(of: fit) { report() }
    }

    private func report() {
        onSize(CGSize(width: natural.width * fit, height: natural.height * fit))
    }

    private var content: some View {
        let c = clock
        let tint = (RGB(hex: c.colorHex) ?? RGB(r: 1, g: 1, b: 1)).nsColor
        let dateAbove = c.datePlacement == .above
        let spacing = -c.size * 0.06 + c.dateGap
        return TimelineView(.everyMinute) { context in
            VStack(alignment: horizontalAlignment, spacing: spacing) {
                if c.showDate && dateAbove { date(context.date) }
                Text(ClockFormatter.time(context.date, format: c.format))
                    .font(font(c.size, .semibold, condensed: true))
                    .monospacedDigit()
                if c.showDate && !dateAbove { date(context.date) }
            }
            // Lighter toward the bottom, like glass catching light.
            .foregroundStyle(LinearGradient(
                colors: [Color(nsColor: tint).opacity(c.opacity * 0.75), Color(nsColor: tint).opacity(c.opacity)],
                startPoint: .top, endPoint: .bottom))
            .shadow(color: .black.opacity(0.12), radius: c.size * 0.05, y: 2)
            .fixedSize()
            .padding(c.size * 0.12)  // room for the shadow so it is not clipped
        }
    }

    private func date(_ date: Date) -> some View {
        Text(ClockFormatter.day(date))
            .font(font(clock.size * 0.2, .semibold, condensed: false))
            .offset(x: clock.dateOffsetX)
    }

    private var horizontalAlignment: HorizontalAlignment {
        switch clock.dateAlignment {
        case .left: .leading
        case .center: .center
        case .right: .trailing
        }
    }

    private func font(_ size: Double, _ weight: Font.Weight, condensed: Bool) -> Font {
        if let name = clock.fontName { return .custom(name, size: size).weight(weight) }
        let base = Font.system(size: size, weight: weight)
        return condensed ? base.width(.compressed) : base
    }
}
