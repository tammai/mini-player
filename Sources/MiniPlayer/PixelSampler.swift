import AppKit
import MiniPlayerCore

enum PixelSampler {
    /// `image` scaled down to `width` x `height` and read back as colors. Used to boil artwork and the wallpaper
    /// behind the clock down to a handful of pixels. Mostly transparent pixels are left out.
    static func pixels(of image: CGImage, width: Int, height: Int) -> [RGB]? {
        guard let space = CGColorSpace(name: CGColorSpace.sRGB) else { return nil }
        var bytes = [UInt8](repeating: 0, count: width * height * 4)
        let drawn = bytes.withUnsafeMutableBytes { buffer -> Bool in
            guard let context = CGContext(
                data: buffer.baseAddress, width: width, height: height, bitsPerComponent: 8, bytesPerRow: width * 4,
                space: space, bitmapInfo: CGImageAlphaInfo.premultipliedLast.rawValue) else { return false }
            context.interpolationQuality = .medium
            context.draw(image, in: CGRect(x: 0, y: 0, width: width, height: height))
            return true
        }
        guard drawn else { return nil }
        return stride(from: 0, to: bytes.count, by: 4).compactMap { i -> RGB? in
            let alpha = Double(bytes[i + 3]) / 255
            guard alpha > 0.5 else { return nil }
            // Premultiplied: divide the alpha back out.
            return RGB(r: Double(bytes[i]) / 255 / alpha, g: Double(bytes[i + 1]) / 255 / alpha, b: Double(bytes[i + 2]) / 255 / alpha)
        }
    }
}
