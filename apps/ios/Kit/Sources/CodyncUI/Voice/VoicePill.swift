import CodyncKit
import SwiftUI

/// The voice capsule the home's bottom bar grows into: what the sheet's 76pt detent used to draw, now
/// a view of its own, so the round button can grow into it instead of the sheet carrying it.
///
/// The content, its order and its sizes are the old 76pt face's, unchanged: a 36pt avatar, the
/// waveform, a 44pt settings circle and a 44pt microphone, in a 44pt row with 16pt of air above and
/// below — 76pt in all. No close button and no send: those stay in the taller sheet's title bar.
public struct VoicePill: View {
    /// The capsule's height: the height the sheet's small detent used to rest at.
    public static let height: CGFloat = 76
    /// The row inside it: 76 - 16 - 16, the same 44pt row the bottom bar is.
    public static let rowHeight: CGFloat = height - 32

    private let lead: Bot?
    private let session: VoiceSession
    /// The voice settings. They are a sheet of their own, so whoever owns this capsule owns them.
    private let openSettings: () -> Void

    public init(lead: Bot?, session: VoiceSession, openSettings: @escaping () -> Void) {
        self.lead = lead
        self.session = session
        self.openSettings = openSettings
    }

    public var body: some View {
        HStack(spacing: 12) {
            VoiceAvatar(lead: lead, size: 36, recording: session.phase == .recording)
            VoiceWaveColumn(session: session)
            VoiceSettingsButton(action: openSettings)
            VoiceMicButton(session: session)
        }
        .frame(height: Self.rowHeight)
        .padding(.horizontal, 16)
        .frame(maxWidth: .infinity, minHeight: Self.height, maxHeight: Self.height)
    }
}

// MARK: - The pieces two faces share

/// The lead bot's face: breathing inside a halo of its own colour while it hears, frozen and unlit
/// while it is paused, so the row reads as silent at a glance. 24pt in the sheet's title, 36 in the
/// capsule.
struct VoiceAvatar: View {
    let lead: Bot?
    let size: CGFloat
    /// The microphone is open: breathe.
    let recording: Bool

    @Environment(\.accessibilityReduceMotion) private var reduceMotion
    @State private var breathing = false

    /// Reduce Motion holds it still: the halo is decoration, not state.
    private var wantsBreathing: Bool { recording && !reduceMotion }

    private var tint: Color {
        lead.map { AvatarPalette.color($0.avatarColor) } ?? Palette.secondary
    }

    var body: some View {
        ZStack {
            Circle()
                .fill(tint.opacity(0.5))
                .frame(width: size, height: size)
                .blur(radius: breathing ? 8 : 5)
                .scaleEffect(breathing ? 1.22 : 1.05)
                .opacity(breathing ? 0.55 : 0)
            Group {
                if let lead {
                    CharacterAvatar(bot: lead, size: size, animated: false)
                } else {
                    Circle().fill(Palette.bubbleAgent)
                }
            }
            .scaleEffect(breathing ? 1.06 : 1)
        }
        .frame(width: size, height: size)
        .animation(breathing ? .easeInOut(duration: 1.1).repeatForever(autoreverses: true) : Motion.fade,
                   value: breathing)
        .onAppear { breathing = wantsBreathing }
        .onChange(of: wantsBreathing) { _, wanted in breathing = wanted }
        .accessibilityHidden(true)
    }
}

/// The waveform, with the "a little quiet" hint under it — inside the waveform's own space, so the
/// row never moves.
struct VoiceWaveColumn: View {
    let session: VoiceSession

    @Environment(\.accessibilityReduceMotion) private var reduceMotion

    var body: some View {
        VStack(spacing: 2) {
            VoiceWaveform(level: session.level, paused: session.phase != .recording)
                .frame(maxWidth: .infinity)
            if session.lowVolume {
                Text(L10n.tr("A little quiet"))
                    .font(.system(size: 13))
                    .foregroundStyle(Palette.secondary)
                    .transition(.opacity)
            }
        }
        .animation(Motion.reduced(.easeInOut(duration: 0.25), reduceMotion), value: session.lowVolume)
    }
}

/// The voice settings, as one glass circle: the language and what happens to the words afterwards.
struct VoiceSettingsButton: View {
    let action: () -> Void

    var body: some View {
        Button {
            Haptics.impact()
            action()
        } label: {
            RemixIcon("settings-3-line", size: ControlMetrics.Size.icon.glyph, weight: .medium)
                .foregroundStyle(Palette.text)
                .frame(width: ControlMetrics.Size.icon.side, height: ControlMetrics.Size.icon.side)
                .contentShape(Circle())
        }
        .buttonStyle(PressScale(scale: 0.92))
        .glass(in: Circle(), interactive: true)
        .accessibilityLabel(Text(L10n.tr("Voice settings")))
    }
}

/// Pause while hearing, continue while paused. Accent glass while it is the live control.
struct VoiceMicButton: View {
    let session: VoiceSession

    private var recording: Bool { session.phase == .recording }

    var body: some View {
        Button {
            session.toggleMicrophone()
        } label: {
            RemixIcon(recording ? "pause-line" : "play-line",
                      size: ControlMetrics.Size.icon.glyph, weight: .medium)
                .foregroundStyle(recording ? Palette.onAccent : Palette.text)
                .frame(width: ControlMetrics.Size.icon.side, height: ControlMetrics.Size.icon.side)
                // A play triangle reads left-heavy; nudge it into the circle's optical middle.
                .offset(x: recording ? 0 : 1.5)
                .contentShape(Circle())
        }
        .buttonStyle(PressScale(scale: 0.92))
        .glass(in: Circle(), interactive: true, tint: recording ? Palette.accentFill : nil)
        .accessibilityLabel(Text(L10n.tr(recording ? "Pause recording" : "Continue recording")))
    }
}
