import MiniPlayerCore
import SwiftUI

/// A single line that scrolls when it is wider than its slot, and stays still when it fits.
/// The animation runs only for text that overflows.
struct MarqueeText: View {
    let text: String
    let font: Font
    let height: CGFloat

    @State private var textWidth: CGFloat = 0
    @State private var startedAt = Date()

    private let gap: CGFloat = 48

    private var label: some View { Text(text).font(font).fixedSize() }

    var body: some View {
        GeometryReader { geo in
            let overflow = textWidth > geo.size.width + 0.5
            ZStack(alignment: .leading) {
                if overflow {
                    TimelineView(.animation(minimumInterval: 1.0 / 30)) { context in
                        let offset = Marquee.offset(
                            elapsed: context.date.timeIntervalSince(startedAt),
                            textWidth: textWidth, containerWidth: geo.size.width, gap: gap)
                        HStack(spacing: gap) { label; label }.offset(x: offset)
                    }
                    .mask(edgeFade)
                } else {
                    label
                }
            }
            .frame(width: geo.size.width, height: geo.size.height, alignment: .leading)
            .clipped()
        }
        .frame(height: height)
        .background(alignment: .leading) {
            // Measures the text without affecting layout.
            label
                .background(GeometryReader { Color.clear.preference(key: WidthKey.self, value: $0.size.width) })
                .hidden()
        }
        .onPreferenceChange(WidthKey.self) { textWidth = $0 }
        .id(text)  // a new title starts a fresh measurement and a fresh scroll
    }

    private var edgeFade: some View {
        LinearGradient(stops: [
            .init(color: .black, location: 0), .init(color: .black, location: 0.94), .init(color: .clear, location: 1),
        ], startPoint: .leading, endPoint: .trailing)
    }
}

private struct WidthKey: PreferenceKey {
    static let defaultValue: CGFloat = 0
    static func reduce(value: inout CGFloat, nextValue: () -> CGFloat) { value = max(value, nextValue()) }
}
