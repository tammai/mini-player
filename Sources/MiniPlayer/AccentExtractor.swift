import AppKit
import MiniPlayerCore

enum AccentExtractor {
    /// Samples the artwork at 32x18 and asks the core for its most prominent colorful hue.
    static func accent(from image: NSImage) -> RGB? {
        guard let cg = image.cgImage(forProposedRect: nil, context: nil, hints: nil),
              let pixels = PixelSampler.pixels(of: cg, width: 32, height: 18) else { return nil }
        return AccentColor.pick(from: pixels)
    }
}

extension RGB {
    var nsColor: NSColor { NSColor(srgbRed: r, green: g, blue: b, alpha: 1) }
}
