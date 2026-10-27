import MiniPlayerCore
import SwiftUI

/// The card: artwork on the left; title, artist, waves, progress and times on the right.
struct CardView: View {
    @ObservedObject var model: AppModel

    static let artHeight: CGFloat = 120

    var body: some View {
        HStack(spacing: 18) {
            ArtworkView(image: model.cardArtwork, height: Self.artHeight)
            if let info = model.cardInfo {
                column(for: info)
            } else {
                Spacer()
            }
        }
        .padding(22)
        .frame(maxWidth: .infinity, maxHeight: .infinity, alignment: .leading)
        .opacity(model.display == .paused ? 0.55 : 1)
        .overlay {
            // Edit mode cue: the card can be dragged.
            if model.display == .edit {
                RoundedRectangle(cornerRadius: 28, style: .continuous)
                    .strokeBorder(.primary.opacity(0.5), style: StrokeStyle(lineWidth: 1.5, dash: [6, 4]))
            }
        }
        .animation(.easeInOut(duration: 0.3), value: model.display)
    }

    private func column(for info: NowPlayingInfo) -> some View {
        VStack(alignment: .leading, spacing: 0) {
            MarqueeText(text: info.title, font: .system(size: 19, weight: .semibold), height: 24)
            if let artist = info.artist {
                MarqueeText(text: artist, font: .system(size: 14), height: 19)
                    .foregroundStyle(.secondary)
            }
            Spacer(minLength: 6)
            WaveBars(playing: model.display == .playing || model.display == .edit)
            Spacer(minLength: 6)
            progress(for: info)
        }
        .frame(height: Self.artHeight)
    }

    @ViewBuilder
    private func progress(for info: NowPlayingInfo) -> some View {
        if model.display == .playing {
            // Ticks once a second, and only while playing.
            TimelineView(.periodic(from: .now, by: 1)) { context in
                ProgressRow(info: info, now: context.date)
            }
        } else {
            ProgressRow(info: info, now: .now)
        }
    }
}
