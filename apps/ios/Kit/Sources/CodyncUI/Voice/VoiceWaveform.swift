import CodyncKit
import SwiftUI

/// The capsule's waveform: rounded vertical bars that follow your voice, with a slow idle ripple so
/// a silent room still reads as listening. The heights follow the level frame by frame (a spring-like
/// follow kept here rather than a SwiftUI animation, which a per-frame timeline would fight).
struct VoiceWaveform: View {
    let level: Float
    /// Bars are 3pt wide, 3pt apart, 4…24pt tall — what the sheet's 76pt pill can hold.
    private static let barWidth: CGFloat = 3
    private static let gap: CGFloat = 3
    private static let minHeight: CGFloat = 4
    private static let maxHeight: CGFloat = 24

    @Environment(\.accessibilityReduceMotion) private var reduceMotion
    @State private var follow = Follow()

    var body: some View {
        TimelineView(.animation(paused: reduceMotion)) { context in
            Canvas { canvas, size in
                draw(canvas, size: size, time: context.date.timeIntervalSinceReferenceDate)
            }
        }
        .frame(height: Self.maxHeight)
        .accessibilityLabel(Text(L10n.tr("Listening")))
    }

    private func draw(_ canvas: GraphicsContext, size: CGSize, time: TimeInterval) {
        let count = max(1, Int((size.width + Self.gap) / (Self.barWidth + Self.gap)))
        let total = CGFloat(count) * Self.barWidth + CGFloat(count - 1) * Self.gap
        let loudness = Double(follow.step(toward: level, at: time))
        var x = (size.width - total) / 2
        for i in 0..<count {
            let amount = amount(i, of: count, loudness: loudness, time: time)
            let height = Self.minHeight + (Self.maxHeight - Self.minHeight) * amount
            let bar = CGRect(x: x, y: (size.height - height) / 2, width: Self.barWidth, height: height)
            canvas.fill(Path(roundedRect: bar, cornerRadius: Self.barWidth / 2),
                        with: .color(Palette.text.opacity(0.4 + 0.45 * loudness)))
            x += Self.barWidth + Self.gap
        }
    }

    /// How tall this bar should be, 0…1: louder in the middle, quieter at the ends, and never quite
    /// still — the idle ripple is what says the microphone is open before you speak.
    private func amount(_ index: Int, of count: Int, loudness: Double, time: TimeInterval) -> CGFloat {
        let middle = (CGFloat(count) - 1) / 2
        let distance = abs(CGFloat(index) - middle) / max(1, middle)
        let envelope = 1 - 0.45 * distance
        let idle = 0.08 + 0.05 * sin(time * 2.2 + Double(index) * 0.55)
        let voice = min(1, max(0, loudness)) * envelope
        return min(1, max(0.04, max(idle, voice)))
    }

    /// The level as it eases toward each new reading: fast enough to track speech, slow enough that
    /// 18 readings a second still look continuous.
    private final class Follow {
        private var value: Float = 0
        private var last: TimeInterval = 0

        func step(toward target: Float, at time: TimeInterval) -> Float {
            guard last > 0 else {
                last = time
                return target
            }
            let delta = min(0.25, time - last)
            last = time
            // ~90 ms to close most of the gap: a spring's ease-out without overshoot.
            let gain = Float(1 - exp(-delta / 0.09))
            value += (target - value) * gain
            return value
        }
    }
}
