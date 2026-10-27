import AppKit
import MiniPlayerCore
import SwiftUI

/// Rounded bars that stand in for the transport buttons. While playing they loop through the
/// wave source's pattern; when paused they ease down to a flat resting line (0.2s).
///
/// Core Animation drives the bars, so the app does no work per frame. A SwiftUI `Canvas` redrawn
/// by a timeline cost 5-7% CPU while playing; this costs next to nothing.
struct WaveBars: NSViewRepresentable {
    let playing: Bool

    var count = 16
    var barWidth: CGFloat = 5
    var gap: CGFloat = 4
    var maxHeight: CGFloat = 22
    var source: WaveSource = SimulatedWaveSource()

    func makeNSView(context: Context) -> WaveLayerView {
        WaveLayerView(count: count, barWidth: barWidth, gap: gap, maxHeight: maxHeight, source: source)
    }

    func updateNSView(_ view: WaveLayerView, context: Context) {
        view.setPlaying(playing)
    }
}

final class WaveLayerView: NSView {
    private let count: Int
    private let barWidth: CGFloat
    private let gap: CGFloat
    private let maxHeight: CGFloat
    private let source: WaveSource
    private var bars: [CALayer] = []
    private var heightTable: [[NSNumber]] = []
    private var playing = false

    private static let samplesPerLoop = 96
    private static let riseDuration: CFTimeInterval = 0.15
    private static let fallDuration: CFTimeInterval = 0.2

    private var restHeight: CGFloat { barWidth }
    private var totalWidth: CGFloat { CGFloat(count) * (barWidth + gap) - gap }

    init(count: Int, barWidth: CGFloat, gap: CGFloat, maxHeight: CGFloat, source: WaveSource) {
        self.count = count
        self.barWidth = barWidth
        self.gap = gap
        self.maxHeight = maxHeight
        self.source = source
        super.init(frame: NSRect(x: 0, y: 0, width: 0, height: maxHeight))
        wantsLayer = true
        buildBars()
        buildHeightTable()
    }

    required init?(coder: NSCoder) { fatalError("not used") }

    override var intrinsicContentSize: NSSize { NSSize(width: totalWidth, height: maxHeight) }

    // MARK: Layout and appearance

    private func buildBars() {
        for _ in 0..<count {
            let bar = CALayer()
            bar.cornerRadius = barWidth / 2
            bar.cornerCurve = .continuous
            bar.bounds = CGRect(x: 0, y: 0, width: barWidth, height: restHeight)
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
            bar.position = CGPoint(x: CGFloat(i) * (barWidth + gap) + barWidth / 2, y: bounds.midY)
        }
        CATransaction.commit()
    }

    override func viewDidChangeEffectiveAppearance() {
        super.viewDidChangeEffectiveAppearance()
        updateColors()
    }

    private func updateColors() {
        effectiveAppearance.performAsCurrentDrawingAppearance {
            let color = NSColor.labelColor.withAlphaComponent(0.8).cgColor
            for bar in bars { bar.backgroundColor = color }
        }
    }

    // MARK: Animation

    /// Bar heights sampled across one loop, so the keyframe animation repeats seamlessly.
    private func buildHeightTable() {
        let n = Self.samplesPerLoop
        var table = Array(repeating: [NSNumber](), count: count)
        for k in 0...n {
            let levels = source.levels(count: count, at: source.loopDuration * Double(k) / Double(n))
            for i in 0..<count {
                table[i].append(NSNumber(value: Double(height(forLevel: levels[i]))))
            }
        }
        heightTable = table
    }

    private func height(forLevel level: Double) -> CGFloat {
        restHeight + (maxHeight - restHeight) * CGFloat(level)
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
        let targets = source.levels(count: count, at: phaseAfterRise)
        let keyTimes = (0...Self.samplesPerLoop).map { NSNumber(value: Double($0) / Double(Self.samplesPerLoop)) }

        for (i, bar) in bars.enumerated() {
            let from = bar.presentation()?.bounds.size.height ?? restHeight
            let now = bar.convertTime(CACurrentMediaTime(), from: nil)

            // Ease up from where the bar is to where the loop will be after `rise` seconds.
            let up = CABasicAnimation(keyPath: "bounds.size.height")
            up.fromValue = from
            up.toValue = height(forLevel: targets[i])
            up.duration = rise
            up.timingFunction = CAMediaTimingFunction(name: .easeOut)
            up.fillMode = .forwards
            up.isRemovedOnCompletion = false

            let loop = CAKeyframeAnimation(keyPath: "bounds.size.height")
            loop.values = heightTable[i]
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
            let from = bar.presentation()?.bounds.size.height ?? restHeight
            bar.removeAllAnimations()
            CATransaction.begin()
            CATransaction.setDisableActions(true)
            bar.bounds = CGRect(x: 0, y: 0, width: barWidth, height: restHeight)
            CATransaction.commit()

            let down = CABasicAnimation(keyPath: "bounds.size.height")
            down.fromValue = from
            down.toValue = restHeight
            down.duration = Self.fallDuration
            down.timingFunction = CAMediaTimingFunction(name: .easeOut)
            bar.add(down, forKey: "fall")
        }
    }
}
