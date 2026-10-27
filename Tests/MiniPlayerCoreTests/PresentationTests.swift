import Foundation
import Testing
@testable import MiniPlayerCore

@Suite struct TimeFormatTests {
    @Test func matchesControlCenter() {
        // From the Control Center screenshot: elapsed 11:29, remaining -03:45:28 on a 3h56m57s track.
        #expect(TimeFormat.clock(689) == "11:29")
        #expect(TimeFormat.remaining(duration: 14217, elapsed: 689) == "-03:45:28")
    }

    @Test func formatsShortAndLongTimes() {
        #expect(TimeFormat.clock(0) == "0:00")
        #expect(TimeFormat.clock(65) == "1:05")
        #expect(TimeFormat.clock(3599) == "59:59")
        #expect(TimeFormat.clock(3600) == "01:00:00")
        #expect(TimeFormat.clock(14217) == "03:56:57")
    }

    @Test func neverGoesNegative() {
        #expect(TimeFormat.clock(-5) == "0:00")
        #expect(TimeFormat.remaining(duration: 100, elapsed: 120) == "-0:00")
    }
}

@Suite struct MarqueeTests {
    @Test func textThatFitsDoesNotMove() {
        #expect(Marquee.offset(elapsed: 5, textWidth: 100, containerWidth: 200) == 0)
        #expect(Marquee.offset(elapsed: 5, textWidth: 200, containerWidth: 200) == 0)
    }

    @Test func restsAtTheStartBeforeScrolling() {
        #expect(Marquee.offset(elapsed: 0, textWidth: 400, containerWidth: 200, pause: 2.5) == 0)
        #expect(Marquee.offset(elapsed: 2.4, textWidth: 400, containerWidth: 200, pause: 2.5) == 0)
    }

    @Test func scrollsLeftAtTheGivenSpeed() {
        let off = Marquee.offset(elapsed: 3.5, textWidth: 400, containerWidth: 200, gap: 48, speed: 36, pause: 2.5)
        #expect(abs(off - -36) < 0.0001)
    }

    @Test func loopsSeamlessly() {
        // One loop scrolls exactly one text width plus the gap, then starts over at rest.
        let travel = 400.0 + 48.0, speed = 36.0, pause = 2.5
        let cycle = pause + travel / speed
        let nearEnd = Marquee.offset(elapsed: cycle - 0.001, textWidth: 400, containerWidth: 200, gap: 48, speed: speed, pause: pause)
        #expect(abs(nearEnd - -travel) < 0.1)
        #expect(Marquee.offset(elapsed: cycle, textWidth: 400, containerWidth: 200, gap: 48, speed: speed, pause: pause) == 0)
    }
}

@Suite struct WaveTests {
    @Test func levelsAreInRangeAndOnePerBar() {
        let source = SimulatedWaveSource()
        for t in stride(from: 0.0, to: 20.0, by: 0.37) {
            let levels = source.levels(count: 16, at: t)
            #expect(levels.count == 16)
            #expect(levels.allSatisfy { (0...1).contains($0) })
        }
    }

    @Test func levelsChangeOverTime() {
        let source = SimulatedWaveSource()
        #expect(source.levels(count: 16, at: 0) != source.levels(count: 16, at: 0.5))
    }

    @Test func thePatternRepeatsSeamlesslyAtTheLoopLength() {
        let source = SimulatedWaveSource(loopDuration: 8)
        for t in [0.0, 1.3, 4.7, 7.9] {
            let now = source.levels(count: 16, at: t)
            let next = source.levels(count: 16, at: t + source.loopDuration)
            for (a, b) in zip(now, next) { #expect(abs(a - b) < 1e-9) }
        }
    }

    @Test func neighbouringBarsDiffer() {
        // Bars must not all move in lockstep, or the effect looks like one pulsing block.
        let levels = SimulatedWaveSource().levels(count: 16, at: 2)
        #expect(Set(levels.map { ($0 * 100).rounded() }).count > 8)
    }
}
