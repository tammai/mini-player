import Foundation

/// Where wave bar heights come from.
///
/// A source describes a repeating pattern of `loopDuration` seconds. The card hands that
/// pattern to Core Animation, which animates the bars in the render server without waking
/// the app each frame. (Waking per frame cost 5-7% CPU, against 0.3% with waves off.)
/// A real audio-reactive source cannot be precomputed, so it will need a per-frame path
/// (a display link) added next to this one.
public protocol WaveSource {
    /// Length of the repeating pattern. `levels` must return the same values at `t` and `t + loopDuration`.
    var loopDuration: TimeInterval { get }
    /// Bar levels in 0...1, one per bar.
    func levels(count: Int, at time: TimeInterval) -> [Double]
}

/// Smooth procedural motion. It does not follow the music.
public struct SimulatedWaveSource: WaveSource {
    public let loopDuration: TimeInterval

    public init(loopDuration: TimeInterval = 8) {
        self.loopDuration = loopDuration
    }

    public func levels(count: Int, at time: TimeInterval) -> [Double] {
        // Every frequency is a whole number of cycles per loop, so the pattern repeats seamlessly.
        let w = 2 * Double.pi / loopDuration
        return (0..<max(0, count)).map { i in
            let x = Double(i)
            let a = sin(w * 3 * time + x * 0.55)
            let b = sin(w * 2 * time + x * 1.30 + 1.2)
            let c = sin(w * 5 * time + x * 0.31 + 2.4)
            let v = (a * 0.5 + b * 0.3 + c * 0.2 + 1) / 2
            return min(1, max(0, v))
        }
    }
}
