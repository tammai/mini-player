import AppKit
import MiniPlayerCore
import SwiftUI

/// Wave bars that stand in for the transport buttons. While playing they loop through the wave
/// source's pattern; when paused they ease down to a flat resting line (0.2s).
///
/// Core Animation drives the layers, so the app does no work per frame. A SwiftUI `Canvas` redrawn
/// by a timeline cost 5-7% CPU while playing; this costs next to nothing. Any change to the shape
/// settings rebuilds the view (the card gives it `.id(settings)`).
struct WaveBars: NSViewRepresentable {
    let playing: Bool
    let settings: WaveSettings
    /// nil means the system label color.
    let color: NSColor?
    var source: WaveSource = SimulatedWaveSource()

    func makeNSView(context: Context) -> WaveLayerView {
        WaveLayerView(settings: settings, source: source)
    }

    func updateNSView(_ view: WaveLayerView, context: Context) {
        view.setColor(color)
        view.setPlaying(playing)
    }
}

final class WaveLayerView: NSView {
    private let settings: WaveSettings
    private let source: WaveSource
    private var bars: [CALayer] = []
    private var table: [[NSNumber]] = []
    private var playing = false
    private var color: NSColor?

    private static let samplesPerLoop = 96
    private static let riseDuration: CFTimeInterval = 0.15
    private static let fallDuration: CFTimeInterval = 0.2

    private var count: Int { settings.count }
    private var barWidth: CGFloat { settings.thickness }
    private var maxHeight: CGFloat { max(settings.maxHeight, settings.thickness) }
    private var isDots: Bool { settings.shape == .dots }
    private var bottomBaseline: Bool { settings.baseline == .bottom }
    private var totalWidth: CGFloat { CGFloat(count) * (barWidth + settings.gap) - settings.gap }

    /// Bars grow in height; dots keep their size and move up and down.
    private var keyPath: String { isDots ? "position.y" : "bounds.size.height" }

    init(settings: WaveSettings, source: WaveSource) {
        self.settings = settings
        self.source = source
        super.init(frame: NSRect(x: 0, y: 0, width: 0, height: settings.maxHeight))
        wantsLayer = true
        buildBars()
        buildTable()
    }

    required init?(coder: NSCoder) { fatalError("not used") }

    override var intrinsicContentSize: NSSize { NSSize(width: totalWidth, height: maxHeight) }

    // MARK: Geometry

    /// The animated value at rest (flat line).
    private var restValue: CGFloat {
        if !isDots { return barWidth }
        return bottomBaseline ? barWidth / 2 : maxHeight / 2
    }

    /// The animated value for a level between 0 and 1.
    private func value(forLevel level: Double) -> CGFloat {
        let l = CGFloat(level)
        let room = maxHeight - barWidth
        if !isDots { return barWidth + room * l }
        return bottomBaseline ? barWidth / 2 + room * l : maxHeight / 2 + (2 * l - 1) * room / 2
    }

    /// Levels for every bar at `time`, mirrored left to right for the mirrored shape.
    private func levels(at time: TimeInterval) -> [Double] {
        let raw = source.levels(count: count, at: time)
        guard settings.shape == .mirrored else { return raw }
        return (0..<count).map { raw[min($0, count - 1 - $0)] }
    }

    private func buildBars() {
        for _ in 0..<count {
            let bar = CALayer()
            bar.cornerRadius = settings.roundness * barWidth / 2
            bar.cornerCurve = .continuous
            bar.bounds = CGRect(x: 0, y: 0, width: barWidth, height: isDots ? barWidth : barWidth)
            // Bars hang from the baseline: the middle, or the bottom edge.
            bar.anchorPoint = (!isDots && bottomBaseline) ? CGPoint(x: 0.5, y: 0) : CGPoint(x: 0.5, y: 0.5)
            layer?.addSublayer(bar)
            bars.append(bar)
        }
        updateColors()
    }

    override func layout() {
        super.layout()
        CATransaction.begin()
        CATransaction.setDisableActions(true)
        for (i, bar) in bars.enumerated() {
            let y: CGFloat = isDots ? restValue : (bottomBaseline ? 0 : bounds.midY)
            bar.position = CGPoint(x: CGFloat(i) * (barWidth + settings.gap) + barWidth / 2, y: y)
        }
        CATransaction.commit()
    }

    // MARK: Color

    func setColor(_ new: NSColor?) {
        guard new != color else { return }
        color = new
        updateColors()
    }

    override func viewDidChangeEffectiveAppearance() {
        super.viewDidChangeEffectiveAppearance()
        updateColors()
    }

    private func updateColors() {
        effectiveAppearance.performAsCurrentDrawingAppearance {
            let cg = (color ?? .labelColor).withAlphaComponent(0.85).cgColor
            for bar in bars { bar.backgroundColor = cg }
        }
    }

    // MARK: Animation

    /// Values sampled across one loop, so the keyframe animation repeats seamlessly.
    private func buildTable() {
        let n = Self.samplesPerLoop
        var rows = Array(repeating: [NSNumber](), count: count)
        for k in 0...n {
            let l = levels(at: source.loopDuration * Double(k) / Double(n))
            for i in 0..<count { rows[i].append(NSNumber(value: Double(value(forLevel: l[i])))) }
        }
        table = rows
    }

    private func currentValue(of bar: CALayer) -> CGFloat {
        (bar.presentation()?.value(forKeyPath: keyPath) as? NSNumber).map { CGFloat(truncating: $0) } ?? restValue
    }

    private func setModelValueToRest(_ bar: CALayer) {
        CATransaction.begin()
        CATransaction.setDisableActions(true)
        bar.setValue(restValue, forKeyPath: keyPath)
        CATransaction.commit()
    }

    func setPlaying(_ newValue: Bool) {
        guard newValue != playing else { return }
        playing = newValue
        newValue ? startWaves() : flatten()
    }

    private func startWaves() {
        let start = Double.random(in: 0..<source.loopDuration)
        let rise = Self.riseDuration
        let phaseAfterRise = (start + rise).truncatingRemainder(dividingBy: source.loopDuration)
        let targets = levels(at: phaseAfterRise)
        let keyTimes = (0...Self.samplesPerLoop).map { NSNumber(value: Double($0) / Double(Self.samplesPerLoop)) }

        for (i, bar) in bars.enumerated() {
            let from = currentValue(of: bar)
            let now = bar.convertTime(CACurrentMediaTime(), from: nil)

            // Ease up from where the bar is to where the loop will be after `rise` seconds.
            let up = CABasicAnimation(keyPath: keyPath)
            up.fromValue = from
            up.toValue = value(forLevel: targets[i])
            up.duration = rise
            up.timingFunction = CAMediaTimingFunction(name: .easeOut)
            up.fillMode = .forwards
            up.isRemovedOnCompletion = false

            let loop = CAKeyframeAnimation(keyPath: keyPath)
            loop.values = table[i]
            loop.keyTimes = keyTimes
            loop.calculationMode = .linear
            loop.duration = source.loopDuration
            loop.repeatCount = .infinity
            loop.timeOffset = phaseAfterRise
            loop.beginTime = now + rise

            bar.removeAllAnimations()
            bar.add(up, forKey: "rise")
            bar.add(loop, forKey: "wave")
        }
    }

    private func flatten() {
        for bar in bars {
            let from = currentValue(of: bar)
            bar.removeAllAnimations()
            setModelValueToRest(bar)

            let down = CABasicAnimation(keyPath: keyPath)
            down.fromValue = from
            down.toValue = restValue
            down.duration = Self.fallDuration
            down.timingFunction = CAMediaTimingFunction(name: .easeOut)
            bar.add(down, forKey: "fall")
        }
    }
}
