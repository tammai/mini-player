import AppKit
import SwiftUI

/// Album art. The slot follows the image's aspect ratio, like Control Center does, so 16:9
/// YouTube thumbnails are not cropped to a square. Without art it shows a neutral placeholder.
struct ArtworkView: View {
    let image: NSImage?
    let height: CGFloat

    private var width: CGFloat {
        guard let image, image.size.height > 0 else { return height }
        return height * min(max(image.size.width / image.size.height, 0.75), 1.8)
    }

    var body: some View {
        Group {
            if let image {
                Image(nsImage: image).resizable().scaledToFill()
            } else {
                ZStack {
                    Rectangle().fill(.primary.opacity(0.12))
                    Image(systemName: "music.note")
                        .font(.system(size: 34, weight: .light))
                        .foregroundStyle(.secondary)
                }
            }
        }
        .frame(width: width, height: height)
        .clipShape(RoundedRectangle(cornerRadius: 14, style: .continuous))
    }
}
