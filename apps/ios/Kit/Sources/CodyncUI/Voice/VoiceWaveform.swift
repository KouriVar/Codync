import CodyncKit
import SwiftUI

/// The sheet's waveform, drawn as one line rather than bars: a quiet track with a short band sliding
/// along it while nothing is said, and a travelling sine once there is a voice. Everything is drawn
/// in a `Canvas` off a timeline, so a frame costs no view-tree work.
///
/// - The line is 4pt, round-capped, `.primary` (black on light, white on dark).
/// - Silent: a 0.25 track with a 15%-long band sliding end to end (1.2s each way), and no wave.
/// - Speaking: the track and band fade out, the line becomes a sine — 8pt at most, 40pt a wavelength,
///   flowing right one wavelength a second, its ends pulled to zero so it meets the line it grew from.
/// - Paused: whatever shape it had, frozen, at 0.4.
struct VoiceWaveform: View {
    let level: Float
    /// The recording is paused: hold the shape and stop the flow.
    var paused = false

    /// The tallest the wave gets: an 8pt swing inside the 24pt strip.
    private static let amplitude: CGFloat = 8
    private static let wavelength: CGFloat = 40
    private static let secondsPerWavelength: Double = 1
    private static let bandTravel: Double = 1.2
    private static let thickness: CGFloat = 4
    private static let height: CGFloat = 24

    @Environment(\.accessibilityReduceMotion) private var reduceMotion
    @State private var motion = Motion()

    var body: some View {
        TimelineView(.animation(paused: reduceMotion)) { context in
            Canvas { canvas, size in
                draw(canvas, size: size, time: context.date.timeIntervalSinceReferenceDate)
            }
        }
        .frame(height: Self.height)
        .accessibilityLabel(Text(L10n.tr(paused ? "Recording paused" : "Listening")))
    }

    private func draw(_ canvas: GraphicsContext, size: CGSize, time rawTime: TimeInterval) {
        guard size.width > 0, size.height > 0 else { return }
        let time = motion.clock(rawTime, paused: paused)
        let voice = motion.voice(at: time, level: level)
        let loudness = motion.loudness(at: time, level: level)
        let alpha = paused ? 0.4 : 1
        let middle = size.height / 2

        // The quiet track and its travelling band: they fade as the wave takes over.
        let calm = 1 - voice
        if calm > 0.01 {
            var track = Path()
            track.move(to: CGPoint(x: 0, y: middle))
            track.addLine(to: CGPoint(x: size.width, y: middle))
            canvas.stroke(track, with: .color(.primary.opacity(0.25 * calm * alpha)),
                          style: StrokeStyle(lineWidth: Self.thickness, lineCap: .round))

            let band = size.width * 0.15
            let travel = size.width - band
            // easeInOut there and back, one crossing every 1.2s.
            let phase = (time.truncatingRemainder(dividingBy: Self.bandTravel * 2)) / Self.bandTravel
            let eased = phase < 1 ? Self.easeInOut(phase) : 1 - Self.easeInOut(phase - 1)
            let start = travel * CGFloat(eased)
            var bandPath = Path()
            bandPath.move(to: CGPoint(x: start, y: middle))
            bandPath.addLine(to: CGPoint(x: start + band, y: middle))
            canvas.stroke(bandPath, with: .color(.primary.opacity(calm * alpha)),
                          style: StrokeStyle(lineWidth: Self.thickness, lineCap: .round))
        }

        // The wave itself: a straight line whose swing grows with the voice, so the two states pass
        // through the same shape.
        let swing = Self.amplitude * CGFloat(voice * loudness)
        if voice > 0.01 {
            var path = Path()
            let step: CGFloat = 2
            var x: CGFloat = 0
            while x <= size.width {
                let envelope = sin(.pi * x / size.width)
                let phase = 2 * .pi * (Double(x) / Double(Self.wavelength)) - 2 * .pi * time / Self.secondsPerWavelength
                let y = middle + swing * envelope * CGFloat(sin(phase))
                if x == 0 {
                    path.move(to: CGPoint(x: x, y: y))
                } else {
                    path.addLine(to: CGPoint(x: x, y: y))
                }
                x += step
            }
            canvas.stroke(path, with: .color(.primary.opacity(voice * alpha)),
                          style: StrokeStyle(lineWidth: Self.thickness, lineCap: .round, lineJoin: .round))
        }
    }

    private static func easeInOut(_ t: Double) -> Double {
        t < 0.5 ? 2 * t * t : 1 - pow(-2 * t + 2, 2) / 2
    }

    /// The state the line is in, kept across frames: the clock, the debounce between quiet and voice,
    /// and the two smoothed values that make the change a 0.25s cross-fade rather than a jump.
    private final class Motion {
        /// Anything above this is a voice rather than the room.
        private static let threshold: Float = 0.14
        /// Quiet for this long before the wave gives way to the track: no flicker between the two.
        private static let hold: TimeInterval = 0.3
        /// Where the wave is between 0 (straight) and 1 (full).
        private var voice: Double = 0
        /// How loud, smoothed: the swing follows the voice without jumping 18 times a second.
        private var loudness: Double = 0
        private var lastLoud: TimeInterval = -.infinity
        private var last: TimeInterval = 0
        /// The clock stops while paused, so the shape holds and the band stops moving.
        private var frozen: TimeInterval = 0

        func clock(_ time: TimeInterval, paused: Bool) -> TimeInterval {
            if paused { return frozen }
            frozen = time
            return time
        }

        func voice(at time: TimeInterval, level: Float) -> Double {
            if level > Self.threshold { lastLoud = time }
            let target: Double = time - lastLoud < Self.hold ? 1 : 0
            voice = ease(voice, toward: target, at: time, tau: 0.08)
            return voice
        }

        func loudness(at time: TimeInterval, level: Float) -> Double {
            let target = Double(min(1, max(0, level)))
            loudness = ease(loudness, toward: target, at: time, tau: 0.12)
            return loudness
        }

        /// An exponential follow: `tau` is roughly the time to close most of the gap.
        private func ease(_ value: Double, toward target: Double, at time: TimeInterval, tau: Double) -> Double {
            guard last > 0 else {
                last = time
                return target
            }
            let delta = min(0.25, max(0, time - last))
            let gain = 1 - exp(-delta / tau)
            return value + (target - value) * gain
        }
    }
}
