import CodyncKit
import SwiftUI

/// The voice bar as it looks while it is open in place: a 76pt glass pill with the lead bot, the line
/// waveform, the voice settings and pause — the same pieces as the sheet's smallest detent. Pull it up
/// to take the whole sheet; pull it down to put it away.
public struct VoiceMiniBar: View {
    static let height: CGFloat = 76

    private let lead: Bot?
    private let session: VoiceSession
    let openSettings: () -> Void
    let onRaise: () -> Void
    let onCollapse: () -> Void

    @Environment(\.accessibilityReduceMotion) private var reduceMotion
    @GestureState private var pull: CGFloat = 0

    public init(lead: Bot?, session: VoiceSession, openSettings: @escaping () -> Void,
                onRaise: @escaping () -> Void, onCollapse: @escaping () -> Void) {
        self.lead = lead
        self.session = session
        self.openSettings = openSettings
        self.onRaise = onRaise
        self.onCollapse = onCollapse
    }

    public var body: some View {
        HStack(spacing: 12) {
            avatar
            VoiceWaveform(level: session.level, paused: session.phase != .recording)
                .frame(maxWidth: .infinity)
            circle("settings-3-line", label: "Voice settings", tint: nil, glyph: Palette.text) {
                Haptics.impact()
                openSettings()
            }
            circle(session.phase == .recording ? "pause-line" : "play-line",
                   label: session.phase == .recording ? "Pause recording" : "Continue recording",
                   tint: session.phase == .recording ? Palette.accentFill : nil,
                   glyph: session.phase == .recording ? Palette.onAccent : Palette.text) {
                session.toggleMicrophone()
            }
            .offset(x: 0)
        }
        .padding(.horizontal, 14)
        .frame(height: Self.height)
        .frame(maxWidth: .infinity)
        .glassEffect(.regular.interactive(), in: Capsule())
        .offset(y: -max(0, pull) * 0.3)
        .gesture(
            DragGesture()
                .updating($pull) { value, state, _ in state = value.translation.height }
                .onEnded { value in
                    if value.translation.height < -40 {
                        onRaise()
                    } else if value.translation.height > 40 {
                        onCollapse()
                    }
                }
        )
    }

    /// The bot, breathing while it hears.
    private var avatar: some View {
        Group {
            if let lead {
                CharacterAvatar(bot: lead, size: 36, animated: false)
            } else {
                Circle().fill(Palette.bubbleAgent)
            }
        }
        .frame(width: 36, height: 36)
        .clipShape(Circle())
        .accessibilityHidden(true)
    }

    /// A 44pt glass circle, the same as the sheet's.
    private func circle(_ icon: String, label: String, tint: Color?, glyph: Color,
                        action: @escaping () -> Void) -> some View {
        Button(action: action) {
            RemixIcon(icon, size: 24, weight: .medium)
                .foregroundStyle(glyph)
                .frame(width: 44, height: 44)
                .contentShape(Circle())
        }
        .buttonStyle(MiniPress())
        .modifier(MiniGlass(tint: tint))
        .accessibilityLabel(Text(L10n.tr(label)))
    }

    private struct MiniGlass: ViewModifier {
        let tint: Color?

        func body(content: Content) -> some View {
            if #available(iOS 26, *) {
                content.glassEffect(tint.map { Glass.regular.tint($0).interactive() } ?? .regular.interactive(),
                                    in: Circle())
            } else {
                content
                    .background(Circle().fill(.ultraThinMaterial))
                    .overlay(Circle().strokeBorder(.white.opacity(0.5), lineWidth: 0.5))
            }
        }
    }

    private struct MiniPress: ButtonStyle {
        func makeBody(configuration: Configuration) -> some View {
            configuration.label
                .scaleEffect(configuration.isPressed ? 0.92 : 1)
                .animation(Motion.press, value: configuration.isPressed)
        }
    }
}
