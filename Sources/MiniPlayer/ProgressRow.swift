import MiniPlayerCore
import SwiftUI

/// Progress bar with elapsed and remaining times. Items without a duration (live streams)
/// show elapsed time only, with no bar. Control Center's exact behavior is still to be checked.
struct ProgressRow: View {
    let info: NowPlayingInfo
    let now: Date
    let accent: Color
    let showBar: Bool
    let showTimes: Bool

    var body: some View {
        let elapsed = info.elapsed(at: now) ?? 0
        let duration = (info.duration ?? 0) > 0 ? info.duration : nil
        VStack(spacing: 5) {
            if showBar, let duration {
                let fraction = min(1, max(0, elapsed / duration))
                GeometryReader { geo in
                    ZStack(alignment: .leading) {
                        Capsule().fill(.primary.opacity(0.2))
                        Capsule().fill(accent)
                            .frame(width: max(5, geo.size.width * fraction))
                            .animation(.linear(duration: 1), value: fraction)
                    }
                }
                .frame(height: 5)
            }
            if showTimes {
                HStack {
                    Text(TimeFormat.clock(elapsed))
                    Spacer()
                    if let duration { Text(TimeFormat.remaining(duration: duration, elapsed: elapsed)) }
                }
                .font(.system(size: 11.5, weight: .medium).monospacedDigit())
                .foregroundStyle(.secondary)
            }
        }
    }
}
