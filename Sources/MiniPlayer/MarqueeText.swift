import AppKit
import MiniPlayerCore
import SwiftUI

/// A single line that scrolls when it is wider than its slot, and stays still when it fits.
/// The animation runs only for text that overflows, and Core Animation drives it, so the app does
/// no work per frame. A SwiftUI `TimelineView` redrawing at 30 fps cost 6-7% CPU.
struct MarqueeText: View {
    let text: String
    let font: Font
    let height: CGFloat
    var secondary = false

    @State private var textWidth: CGFloat = 0

    private let gap: CGFloat = 48

    private var label: some View {
        Text(text).font(font).fixedSize()
            .foregroundStyle(secondary ? AnyShapeStyle(.secondary) : AnyShapeStyle(.primary))
    }

    var body: some View {
        GeometryReader { geo in
            let overflow = textWidth > geo.size.width + 0.5
            ZStack(alignment: .leading) {
                if overflow {
                    ScrollingLine(
                        content: HStack(spacing: gap) { label; label }, textWidth: textWidth,
                        containerWidth: geo.size.width, gap: gap
                    )
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

/// Two copies of the text side by side, slid left by a looping Core Animation: rest at the start,
/// scroll one copy plus the gap, then jump back, which looks seamless because the second copy
/// sits where the first began. The text is drawn once and the GPU moves it.
private struct ScrollingLine<Content: View>: NSViewRepresentable {
    let content: Content
    let textWidth: CGFloat
    let containerWidth: CGFloat
    let gap: CGFloat

    final class Coordinator {
        var animatedFor: [CGFloat] = []
    }

    func makeCoordinator() -> Coordinator { Coordinator() }

    func makeNSView(context: Context) -> NSView {
        let container = NSView()
        let host = NSHostingView(rootView: content)
        host.sizingOptions = []  // the frame below sizes it; the content is wider than the slot
        host.wantsLayer = true
        container.addSubview(host)
        return container
    }

    func updateNSView(_ container: NSView, context: Context) {
        guard let host = container.subviews.first as? NSHostingView<Content> else { return }
        host.rootView = content
        host.frame = NSRect(x: 0, y: 0, width: 2 * textWidth + gap, height: container.bounds.height)
        host.autoresizingMask = [.height]

        let key = [textWidth, containerWidth, gap]
        guard context.coordinator.animatedFor != key, let layer = host.layer else { return }
        context.coordinator.animatedFor = key

        let pause = 2.5, speed = 36.0  // the Marquee defaults
        let cycle = Marquee.cycle(textWidth: textWidth, gap: gap, speed: speed, pause: pause)
        let scroll = CAKeyframeAnimation(keyPath: "transform.translation.x")
        scroll.values = [0, 0, -(textWidth + gap)]
        scroll.keyTimes = [0, NSNumber(value: pause / cycle), 1]
        scroll.calculationMode = .linear
        scroll.duration = cycle
        scroll.repeatCount = .infinity
        layer.removeAllAnimations()
        layer.add(scroll, forKey: "marquee")
    }
}
