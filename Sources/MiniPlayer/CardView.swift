import AppKit
import MiniPlayerCore
import SwiftUI

/// The card: artwork beside a column of title, artist, waves, progress and times.
/// Everything about its look comes from the config, and changes apply live.
struct CardView: View {
    @ObservedObject var model: AppModel
    @ObservedObject var store: ConfigStore
    /// Tint sampled from the wallpaper behind the card, for `accent.mode = wallpaper`.
    @ObservedObject var accentTint: WallpaperTint
    /// Reports the card's natural size (before scaling) so the window can match it.
    var onContentSize: (CGSize) -> Void

    @State private var contentHeight: CGFloat = 164

    static let baseWidth: CGFloat = 540
    private static let padding: CGFloat = 22

    private var config: Config { store.config }
    private var editing: Bool { model.display == .edit }

    var body: some View {
        let scale = config.card.scale
        content
            .frame(width: Self.baseWidth)
            .fixedSize(horizontal: false, vertical: true)
            .onGeometryChange(for: CGSize.self, of: \.size) { size in
                contentHeight = size.height
                onContentSize(size)
            }
            .scaleEffect(scale, anchor: .topLeading)
            .frame(width: Self.baseWidth * scale, height: contentHeight * scale, alignment: .topLeading)
    }

    // MARK: Layout

    private var content: some View {
        let info = model.cardInfo
        let showArt = config.elements.artwork
        return HStack(spacing: 18) {
            if showArt && config.card.artworkSide == .left { artwork }
            if let info { column(for: info) } else { Spacer() }
            if showArt && config.card.artworkSide == .right { artwork }
        }
        .padding(Self.padding)
        .frame(maxWidth: .infinity, alignment: .leading)
        .overlay(alignment: wavesAlignment) {
            if info != nil, config.elements.waves, config.waves.anchor != .row {
                waves.padding(Self.padding).offset(x: config.waves.offsetX, y: config.waves.offsetY)
            }
        }
        .opacity(model.display == .paused ? 0.55 : 1)
        .overlay {
            // Edit mode cue: the card can be dragged.
            if editing {
                RoundedRectangle(cornerRadius: config.card.cornerRadius, style: .continuous)
                    .strokeBorder(.primary.opacity(0.5), style: StrokeStyle(lineWidth: 1.5, dash: [6, 4]))
            }
        }
        .animation(.easeInOut(duration: 0.3), value: model.display)
    }

    private var artwork: some View {
        ArtworkView(image: model.cardArtwork, height: config.card.artworkSize, fit: config.card.artworkFit)
    }

    /// The text column. Whatever is switched on is stacked with even spacing and centered in the
    /// card's height, so hiding an element never leaves the rest stuck to the top and bottom edges.
    private func column(for info: NowPlayingInfo) -> some View {
        let t = config.text
        let wavesInRow = config.elements.waves && config.waves.anchor == .row
        let showProgress = config.elements.progress || config.elements.times
        return VStack(alignment: .leading, spacing: 10) {
            VStack(alignment: .leading, spacing: 0) {
                MarqueeText(text: info.title, font: font(t.titleSize, .semibold), height: ceil(t.titleSize * 1.3))
                if config.elements.artist, let artist = info.artist {
                    MarqueeText(text: artist, font: font(t.artistSize, .regular), height: ceil(t.artistSize * 1.4), secondary: true)
                }
            }
            if wavesInRow { waves.offset(x: config.waves.offsetX, y: config.waves.offsetY) }
            if showProgress { progress(for: info) }
        }
        // The frame is at least as tall as the artwork; its default alignment centers the stack in it.
        .frame(maxWidth: .infinity, minHeight: config.elements.artwork ? config.card.artworkSize : 0, alignment: .leading)
    }

    @ViewBuilder
    private func progress(for info: NowPlayingInfo) -> some View {
        let make = { (date: Date) in
            ProgressRow(info: info, now: date, accent: accentColor,
                        showBar: config.elements.progress, showTimes: config.elements.times)
        }
        if model.display == .playing {
            // Ticks once a second, and only while playing.
            TimelineView(.periodic(from: .now, by: 1)) { make($0.date) }
        } else {
            make(.now)
        }
    }

    private var waves: some View {
        let w = config.waves
        return WaveBars(playing: model.display == .playing || editing, settings: w, color: waveColor)
            .id(w)
            // A fixed size: left to itself the AppKit view stretches to the card's height and draws
            // its bars in the middle of that, which pushed them away from the text above.
            .frame(width: CGFloat(w.count) * (w.thickness + w.gap) - w.gap, height: max(w.maxHeight, w.thickness))
    }

    private var wavesAlignment: Alignment {
        config.waves.anchor == .bottomRight ? .bottomTrailing : .topTrailing
    }

    // MARK: Style

    private func font(_ size: Double, _ weight: Font.Weight) -> Font {
        if let name = config.text.fontName { return .custom(name, size: size).weight(weight) }
        return .system(size: size, weight: weight)
    }

    /// The accent as a color, or nil to use the system label color.
    private var accent: RGB? {
        switch config.accent.mode {
        case .system: return nil
        case .manual: return RGB(hex: config.accent.hex)
        case .auto: return model.autoAccent ?? (editing ? RGB(hex: config.accent.hex) : nil)
        // Until the wallpaper can be read, the custom color stands in.
        case .wallpaper: return accentTint.color ?? RGB(hex: config.accent.hex)
        }
    }

    private var accentColor: Color {
        accent.map { Color(nsColor: $0.nsColor) } ?? Color.primary.opacity(0.85)
    }

    private var waveColor: NSColor? {
        config.waves.color == .primary ? nil : accent?.nsColor
    }
}
