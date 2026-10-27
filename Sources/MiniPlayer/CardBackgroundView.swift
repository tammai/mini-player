import AppKit
import MiniPlayerCore

/// The layer behind the card's content: Liquid Glass, a frosted blur, or nothing.
///
/// It is a sibling of the content, not its container, so its opacity can change without fading
/// the text, and so it follows the window's size like any other autoresizing subview.
final class CardBackgroundView: NSView {
    override func setFrameSize(_ newSize: NSSize) {
        super.setFrameSize(newSize)
        for view in subviews { view.frame = bounds }
    }

    override func layout() {
        super.layout()
        for view in subviews { view.frame = bounds }
    }

    private var kind: BackgroundKind?
    private var glass: NSGlassEffectView?
    private var frost: NSVisualEffectView?
    private var tint: NSView?

    func apply(_ settings: BackgroundSettings, cornerRadius: CGFloat) {
        if settings.kind != kind { rebuild(for: settings.kind) }
        let tintColor = settings.tintHex.flatMap { RGB(hex: $0) }
            .map { $0.nsColor.withAlphaComponent(settings.tintOpacity) }

        switch settings.kind {
        case .glass:
            glass?.cornerRadius = cornerRadius
            glass?.style = settings.style == .clear ? .clear : .regular
            glass?.tintColor = tintColor
            glass?.alphaValue = settings.opacity
        case .frosted:
            frost?.material = Self.material(for: settings.frost)
            frost?.maskImage = Self.roundedMask(radius: cornerRadius)
            frost?.alphaValue = settings.opacity
            tint?.layer?.backgroundColor = tintColor?.cgColor
            tint?.layer?.cornerRadius = cornerRadius
            tint?.layer?.cornerCurve = .continuous
            tint?.isHidden = tintColor == nil
            tint?.alphaValue = settings.opacity
        case .none:
            break
        }
    }

    private func rebuild(for newKind: BackgroundKind) {
        subviews.forEach { $0.removeFromSuperview() }
        glass = nil; frost = nil; tint = nil
        kind = newKind
        switch newKind {
        case .glass:
            let view = NSGlassEffectView(frame: bounds)
            addSubview(view)
            glass = view
        case .frosted:
            let view = NSVisualEffectView(frame: bounds)
            view.blendingMode = .behindWindow  // blur the wallpaper, not our own content
            view.state = .active               // stay blurred although this window is never key
            addSubview(view)
            frost = view
            let overlay = NSView(frame: bounds)
            overlay.wantsLayer = true
            addSubview(overlay)
            tint = overlay
        case .none:
            break
        }
    }

    private static func material(for frost: FrostMaterial) -> NSVisualEffectView.Material {
        switch frost {
        case .underWindow: .underWindowBackground
        case .sidebar: .sidebar
        case .menu: .menu
        case .popover: .popover
        case .header: .headerView
        case .hud: .hudWindow
        }
    }

    /// A stretchable rounded rectangle, used to round the corners of the frosted blur.
    private static func roundedMask(radius: CGFloat) -> NSImage {
        let r = max(radius, 1)
        let image = NSImage(size: NSSize(width: r * 2 + 1, height: r * 2 + 1), flipped: false) { rect in
            NSColor.black.setFill()
            NSBezierPath(roundedRect: rect, xRadius: r, yRadius: r).fill()
            return true
        }
        image.capInsets = NSEdgeInsets(top: r, left: r, bottom: r, right: r)
        image.resizingMode = .stretch
        return image
    }
}

/// Holds the background and the content and keeps both exactly the size of the window.
///
/// Frames are set explicitly. Autoresizing masks double-counted a shrinking window: after the artwork
/// was hidden, the glass came out 9 pt shorter than the window and left a transparent band on top.
final class CardContainerView: NSView {
    /// Placed the moment the size changes, not on the next layout pass, which can be skipped when
    /// several resizes arrive in quick succession.
    override func setFrameSize(_ newSize: NSSize) {
        super.setFrameSize(newSize)
        for view in subviews { view.frame = bounds }
    }

    override func layout() {
        super.layout()
        for view in subviews { view.frame = bounds }
    }
}

/// The card's current size on screen, shared so the clock can stay within it.
@MainActor
final class CardGeometry: ObservableObject {
    @Published var size = CGSize(width: CardView.baseWidth, height: 164)
    /// The clock's size while it is on the desktop, or nil when it is off or hidden. The card is placed by the
    /// center of the card and clock together, so it needs to know how big the clock is.
    @Published var clockSize: CGSize?
}
