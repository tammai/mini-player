#!/usr/bin/env swift
// Draws the app icon and writes Resources/AppIcon.icns. Run it again after changing the drawing:
//   swift scripts/make-icon.swift
import AppKit

func draw(size: Int) -> Data {
    let s = CGFloat(size) / 1024
    let rep = NSBitmapImageRep(bitmapDataPlanes: nil, pixelsWide: size, pixelsHigh: size, bitsPerSample: 8,
                               samplesPerPixel: 4, hasAlpha: true, isPlanar: false,
                               colorSpaceName: .deviceRGB, bytesPerRow: 0, bitsPerPixel: 0)!
    NSGraphicsContext.saveGraphicsState()
    NSGraphicsContext.current = NSGraphicsContext(bitmapImageRep: rep)
    let ctx = NSGraphicsContext.current!.cgContext
    ctx.scaleBy(x: s, y: s)

    // macOS icon grid: an 824-point rounded square centered in the 1024 canvas.
    let tile = CGRect(x: 100, y: 100, width: 824, height: 824)
    let tilePath = NSBezierPath(roundedRect: tile, xRadius: 185, yRadius: 185)

    ctx.saveGState()
    ctx.setShadow(offset: CGSize(width: 0, height: -12), blur: 28, color: NSColor.black.withAlphaComponent(0.3).cgColor)
    NSColor(srgbRed: 0.3, green: 0.6, blue: 0.62, alpha: 1).setFill()
    tilePath.fill()
    ctx.restoreGState()

    // The wallpaper: a soft teal sky, like the screenshot.
    ctx.saveGState()
    tilePath.addClip()
    let sky = NSGradient(colors: [NSColor(srgbRed: 0.62, green: 0.82, blue: 0.82, alpha: 1),
                                  NSColor(srgbRed: 0.27, green: 0.52, blue: 0.58, alpha: 1)])!
    sky.draw(in: tile, angle: -90)

    // The glass card.
    let card = CGRect(x: 200, y: 330, width: 624, height: 364)
    let cardPath = NSBezierPath(roundedRect: card, xRadius: 110, yRadius: 110)
    ctx.saveGState()
    ctx.setShadow(offset: CGSize(width: 0, height: -14), blur: 30, color: NSColor.black.withAlphaComponent(0.18).cgColor)
    NSColor.white.withAlphaComponent(0.42).setFill()
    cardPath.fill()
    ctx.restoreGState()
    NSColor.white.withAlphaComponent(0.7).setStroke()
    cardPath.lineWidth = 5
    cardPath.stroke()

    // Artwork square on the left.
    let art = CGRect(x: 250, y: 380, width: 264, height: 264)
    let artPath = NSBezierPath(roundedRect: art, xRadius: 52, yRadius: 52)
    NSGradient(colors: [NSColor(srgbRed: 1.0, green: 0.62, blue: 0.4, alpha: 1),
                        NSColor(srgbRed: 0.93, green: 0.3, blue: 0.5, alpha: 1)])!.draw(in: artPath, angle: -50)

    // Wave bars on the right.
    let heights: [CGFloat] = [70, 130, 200, 120, 160, 90, 50]
    let barWidth: CGFloat = 26, gap: CGFloat = 16
    var x: CGFloat = 556
    for h in heights {
        let bar = CGRect(x: x, y: art.midY - h / 2, width: barWidth, height: h)
        NSColor(srgbRed: 0.12, green: 0.27, blue: 0.3, alpha: 0.85).setFill()
        NSBezierPath(roundedRect: bar, xRadius: barWidth / 2, yRadius: barWidth / 2).fill()
        x += barWidth + gap
        if x > card.maxX - 40 { break }
    }
    ctx.restoreGState()

    // A top-edge highlight on the tile.
    ctx.saveGState()
    tilePath.addClip()
    NSGradient(colors: [NSColor.white.withAlphaComponent(0.28), NSColor.white.withAlphaComponent(0)])!
        .draw(in: CGRect(x: 100, y: 640, width: 824, height: 284), angle: -90)
    ctx.restoreGState()

    NSGraphicsContext.restoreGraphicsState()
    return rep.representation(using: .png, properties: [:])!
}

let fm = FileManager.default
let root = URL(fileURLWithPath: fm.currentDirectoryPath)
let iconset = fm.temporaryDirectory.appendingPathComponent("AppIcon-\(ProcessInfo.processInfo.processIdentifier).iconset")
try? fm.removeItem(at: iconset)
try fm.createDirectory(at: iconset, withIntermediateDirectories: true)
for base in [16, 32, 128, 256, 512] {
    try draw(size: base).write(to: iconset.appendingPathComponent("icon_\(base)x\(base).png"))
    try draw(size: base * 2).write(to: iconset.appendingPathComponent("icon_\(base)x\(base)@2x.png"))
}
let out = root.appendingPathComponent("Resources/AppIcon.icns")
let task = Process()
task.executableURL = URL(fileURLWithPath: "/usr/bin/iconutil")
task.arguments = ["-c", "icns", iconset.path, "-o", out.path]
try task.run()
task.waitUntilExit()
try? fm.removeItem(at: iconset)
print(task.terminationStatus == 0 ? "Wrote \(out.path)" : "iconutil failed")
