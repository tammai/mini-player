import AppKit
import MiniPlayerCore
import SwiftUI

/// Album art.
/// - `fit`: the slot follows the image's shape, so a 16:9 YouTube thumbnail stays wide, like Control Center.
/// - `fill`: a square slot; the image fills it and the edges are cropped.
/// Without art it shows a neutral placeholder.
struct ArtworkView: View {
    let image: NSImage?
    let height: CGFloat
    let fit: ArtworkFit

    private var width: CGFloat {
        guard fit == .fit, let image, image.size.height > 0 else { return height }
        return height * min(max(image.size.width / image.size.height, 0.5), 2.4)
    }

    var body: some View {
        Group {
            if let image {
                Image(nsImage: image).resizable().scaledToFill()
            } else {
                ZStack {
                    Rectangle().fill(.primary.opacity(0.12))
                    Image(systemName: "music.note")
                        .font(.system(size: height * 0.28, weight: .light))
                        .foregroundStyle(.secondary)
                }
            }
        }
        .frame(width: width, height: height)
        .clipShape(RoundedRectangle(cornerRadius: 14, style: .continuous))
    }
}
