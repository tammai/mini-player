import MiniPlayerCore
import SwiftUI

/// The card content. Skeleton: title and artist only. Artwork, progress, times and waves come next.
struct CardView: View {
    @ObservedObject var model: AppModel

    private var title: String {
        model.display == .edit ? "Demo Track" : (model.info?.title ?? "")
    }

    private var artist: String? {
        model.display == .edit ? "Demo Artist" : model.info?.artist
    }

    var body: some View {
        VStack(alignment: .leading, spacing: 4) {
            Text(title)
                .font(.system(size: 20, weight: .semibold))
                .foregroundStyle(.primary)
                .lineLimit(1)
            if let artist {
                Text(artist)
                    .font(.system(size: 15))
                    .foregroundStyle(.secondary)
                    .lineLimit(1)
            }
        }
        .frame(maxWidth: .infinity, maxHeight: .infinity, alignment: .leading)
        .padding(.horizontal, 24)
        .opacity(model.display == .paused ? 0.55 : 1)
        .overlay {
            // Edit mode cue: the card can be dragged.
            if model.display == .edit {
                RoundedRectangle(cornerRadius: 26, style: .continuous)
                    .strokeBorder(.primary.opacity(0.5), style: StrokeStyle(lineWidth: 1.5, dash: [6, 4]))
            }
        }
        .animation(.easeInOut(duration: 0.3), value: model.display)
    }
}
