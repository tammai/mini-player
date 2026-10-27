import AppKit
import MiniPlayerCore

enum AccentExtractor {
    /// Samples the artwork at 32x18 and asks the core for its most prominent colorful hue.
    static func accent(from image: NSImage) -> RGB? {
        guard let cg = image.cgImage(forProposedRect: nil, context: nil, hints: nil),
              let space = CGColorSpace(name: CGColorSpace.sRGB) else { return nil }
        let w = 32, h = 18
        var bytes = [UInt8](repeating: 0, count: w * h * 4)
        let drawn = bytes.withUnsafeMutableBytes { buffer -> Bool in
            guard let context = CGContext(
                data: buffer.baseAddress, width: w, height: h, bitsPerComponent: 8, bytesPerRow: w * 4,
                space: space, bitmapInfo: CGImageAlphaInfo.premultipliedLast.rawValue) else { return false }
            context.interpolationQuality = .medium
            context.draw(cg, in: CGRect(x: 0, y: 0, width: w, height: h))
            return true
        }
        guard drawn else { return nil }
        let pixels = stride(from: 0, to: bytes.count, by: 4).compactMap { i -> RGB? in
            let alpha = Double(bytes[i + 3]) / 255
            guard alpha > 0.5 else { return nil }
            // Premultiplied: divide the alpha back out.
            return RGB(r: Double(bytes[i]) / 255 / alpha, g: Double(bytes[i + 1]) / 255 / alpha, b: Double(bytes[i + 2]) / 255 / alpha)
        }
        return AccentColor.pick(from: pixels)
    }
}

extension RGB {
    var nsColor: NSColor { NSColor(srgbRed: r, green: g, blue: b, alpha: 1) }
}
