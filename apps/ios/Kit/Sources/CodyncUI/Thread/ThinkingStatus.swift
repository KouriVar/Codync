import CodyncKit
import SwiftUI

/// The waiting line where the reply will appear: the bot's own avatar, what it is doing, and —
/// only after ten seconds — how long. No card, no border, no tool names.
struct ThinkingStatusRow: View {
    let bot: Bot
    @Environment(\.accessibilityReduceMotion) private var reduceMotion

    /// Two states, both from the host's structured `status` (`Bot.needsInput`): a step under way,
    /// or a question waiting on the reader. The host has no third "thinking" field, so the row
    /// does not pretend to tell one apart — the avatar's motion follows `status` alone: a light
    /// sweep while it works, frozen with the warning dot while it waits.
    private var waiting: Bool { bot.needsInput }

    private func seconds(at date: Date) -> Int {
        guard let started = bot.startedAt else { return 0 }
        return max(0, Int(date.timeIntervalSince1970 - Double(started) / 1000))
    }

    private func copy(seconds: Int) -> String {
        ThinkingStatusText.text(activity: bot.activity, needsInput: bot.needsInput)
            + ThinkingStatusText.suffix(seconds: seconds)
    }

    var body: some View {
        TimelineView(.periodic(from: .now, by: 1)) { context in
            let elapsed = seconds(at: context.date)
            HStack(alignment: .center, spacing: 8) {
                avatar
                StatusText(text: copy(seconds: elapsed))
                if let label = ThinkingStatusText.elapsed(elapsed) {
                    Text(label)
                        .font(.system(size: 12).monospacedDigit())
                        .foregroundStyle(Palette.tertiary)
                        .transition(.opacity)
                        .accessibilityHidden(true)
                }
            }
            .animation(Motion.reduced(Motion.fade, reduceMotion), value: ThinkingStatusText.elapsed(elapsed) != nil)
        }
        .accessibilityElement(children: .ignore)
        .accessibilityLabel(Text(copy(seconds: seconds(at: .now))))
        .accessibilityAddTraits(.updatesFrequently)
    }

    /// The bot's halftone face, alive while it works: a light sweep across the glyphs. Reduce
    /// Motion, or a question waiting on the reader, freezes it on one frame.
    private var avatar: some View {
        let still = reduceMotion || waiting
        return TimelineView(.animation(minimumInterval: 1.0 / 20, paused: still)) { timeline in
            let t = timeline.date.timeIntervalSinceReferenceDate
            ZStack(alignment: .topTrailing) {
                CharacterAvatar(bot: bot, size: 32, still: still)
                    .overlay {
                        if !waiting, !reduceMotion {
                            ZStack(alignment: .top) {
                                LinearGradient(colors: [.clear, Palette.text.opacity(0.45), .clear],
                                               startPoint: .top, endPoint: .bottom)
                                    .frame(height: 10)
                                    .offset(y: CGFloat(sin(t * 2 * .pi / 1.2)) * 12 + 7)
                            }
                            .clipShape(Circle())
                        }
                    }
                if waiting {
                    Circle()
                        .fill(Palette.warning)
                        .frame(width: 7, height: 7)
                        .overlay(Circle().stroke(Palette.background, lineWidth: 1.5))
                        .offset(x: 2, y: -2)
                }
            }
            .frame(width: 32, height: 32)
        }
        .frame(width: 32, height: 32)
        .accessibilityHidden(true)
    }
}

/// The status words: 17pt on a 24pt line, swapped with a short cross-fade and held long enough
/// to read. A soft highlight of the primary ink sweeps across the glyphs (1.6s, then a 0.3s
/// rest); only the text animates, the avatar keeps its own motion.
private struct StatusText: View {
    let text: String
    @State private var shown = ""
    @State private var shimmerStart = Date.now
    @Environment(\.accessibilityReduceMotion) private var reduceMotion

    var body: some View {
        ZStack(alignment: .leading) {
            ShimmeringText(text: shown.isEmpty ? text : shown, startedAt: shimmerStart)
                .id(shown)
                .transition(.opacity)
        }
        .animation(Motion.reduced(.easeInOut(duration: 0.18), reduceMotion), value: shown)
        .task(id: text) {
            if shown.isEmpty {
                shown = text
                shimmerStart = .now
                return
            }
            guard text != shown else { return }
            try? await Task.sleep(for: .milliseconds(600))
            guard !Task.isCancelled else { return }
            shimmerStart = .now
            shown = text
        }
        .onAppear { if shown.isEmpty { shown = text } }
    }
}

/// The words in the secondary grey, with a brighter band sweeping left to right.
private struct ShimmeringText: View {
    let text: String
    let startedAt: Date
    @Environment(\.accessibilityReduceMotion) private var reduceMotion

    /// 1.6s across, then a 0.3s rest before the next pass.
    private static let sweep: TimeInterval = 1.6
    private static let rest: TimeInterval = 0.3
    private static let font = Font.system(size: 17)

    var body: some View {
        ZStack(alignment: .leading) {
            Text(text)
                .font(Self.font)
                .foregroundStyle(Palette.secondary)
                .lineLimit(1)
                .truncationMode(.tail)
            if !reduceMotion {
                Text(text)
                    .font(Self.font)
                    .foregroundStyle(Palette.text.opacity(0.95))
                    .lineLimit(1)
                    .truncationMode(.tail)
                    .mask { band }
            }
        }
        .frame(height: 24)
    }

    /// A soft-edged band, about a third of the text wide, carried across the glyphs.
    private var band: some View {
        GeometryReader { proxy in
            let width = proxy.size.width
            let band = width * 1.2
            let cycle = Self.sweep + Self.rest
            TimelineView(.animation(minimumInterval: 1.0 / 30)) { timeline in
                let elapsed = timeline.date.timeIntervalSince(startedAt).truncatingRemainder(dividingBy: cycle)
                let progress = min(1, max(0, elapsed / Self.sweep))
                LinearGradient(stops: [
                    .init(color: .clear, location: 0),
                    .init(color: .white, location: 0.35),
                    .init(color: .white, location: 0.5),
                    .init(color: .white, location: 0.65),
                    .init(color: .clear, location: 1),
                ], startPoint: .leading, endPoint: .trailing)
                .frame(width: band, height: proxy.size.height)
                .offset(x: -band + CGFloat(progress) * (width + band))
            }
        }
    }
}
