import CodyncKit
import SwiftUI

/// The voice capsule that takes the bottom bar's place: a thick Grok-style pill, 88pt tall, with the
/// lead bot on the left, the waveform (or the words) filling the middle, and settings / mic / cancel
/// on the right. The bar's glass, stroke and shadow are applied outside, by `HomeBottomBar`.
public struct VoiceCapsule: View {
    /// Half the capsule: the corner radius, and what the buttons sit inside.
    static let height: CGFloat = 88

    private let lead: Bot?
    private let session: VoiceSession
    let openSettings: () -> Void
    let openSystemSettings: () -> Void
    @Bindable private var bound: VoiceSession
    @Environment(\.accessibilityReduceMotion) private var reduceMotion
    @FocusState private var typing: Bool
    @State private var breathing = false

    public init(lead: Bot?, session: VoiceSession,
                openSettings: @escaping () -> Void, openSystemSettings: @escaping () -> Void) {
        self.lead = lead
        self.session = session
        self._bound = Bindable(session)
        self.openSettings = openSettings
        self.openSystemSettings = openSystemSettings
    }

    public var body: some View {
        HStack(spacing: 16) {
            switch session.phase {
            case .recording, .paused: hearing
            case .confirming: confirming
            case .notice: notice
            case .idle: EmptyView()
            }
        }
        .padding(.horizontal, 16)
        .frame(height: Self.height)
        .frame(maxWidth: .infinity)
        .contentShape(Capsule())
        .animation(Motion.reduced(Motion.layout, reduceMotion), value: session.phase)
        .animation(Motion.reduced(Motion.layout, reduceMotion), value: session.editing)
        .onChange(of: session.phase) { _, phase in
            breathing = phase == .recording && !reduceMotion
        }
        // The keyboard comes up for a correction and leaves when the words send themselves.
        .onChange(of: session.editing) { _, editing in typing = editing }
        .onAppear { breathing = session.phase == .recording && !reduceMotion }
    }

    // MARK: hearing

    private var hearing: some View {
        HStack(spacing: 16) {
            avatar
            VoiceWaveform(level: session.level)
                .frame(maxWidth: .infinity)
            controls
        }
    }

    /// 48pt, breathing 1.0 → 1.06 with a soft halo of the bot's own colour while it listens.
    private var avatar: some View {
        let tint = lead.map { AvatarPalette.color($0.avatarColor) } ?? Palette.secondary
        return ZStack {
            Circle()
                .fill(tint.opacity(0.5))
                .frame(width: 48, height: 48)
                .blur(radius: breathing ? 10 : 6)
                .scaleEffect(breathing ? 1.22 : 1.05)
                .opacity(breathing ? 0.55 : 0.3)
            Group {
                if let lead {
                    CharacterAvatar(bot: lead, size: 48, animated: false)
                } else {
                    Circle().fill(Palette.bubbleAgent)
                }
            }
            .scaleEffect(breathing ? 1.06 : 1)
        }
        .frame(width: 60, height: 60)
        .animation(breathing ? .easeInOut(duration: 1.1).repeatForever(autoreverses: true) : Motion.fade,
                   value: breathing)
        .accessibilityHidden(true)
    }

    // MARK: the words

    private var confirming: some View {
        HStack(spacing: 16) {
            // The bot stays put, so only the middle of the pill changes between hearing and reading.
            avatar
            if session.editing {
                TextField(L10n.tr("Transcript"), text: $bound.text, axis: .vertical)
                    .focused($typing)
                    .lineLimit(1...2)
                    .font(.system(size: 17))
                    .foregroundStyle(Palette.text)
                    .submitLabel(.send)
                    .onSubmit { session.sendNow() }
                    .frame(maxWidth: .infinity, alignment: .leading)
            } else {
                Text(session.text)
                    .font(.system(size: 17))
                    .foregroundStyle(Palette.text)
                    .lineLimit(2)
                    // Longer than two lines loses its front, not its end.
                    .truncationMode(.head)
                    .frame(maxWidth: .infinity, alignment: .leading)
                    .contentShape(Rectangle())
                    .onTapGesture { session.startEditing() }
                    .accessibilityHint(Text(L10n.tr("Tap to edit")))
            }
            controls
        }
    }

    // MARK: stopped early

    private var notice: some View {
        HStack(spacing: 16) {
            Text(L10n.tr(session.notice?.message ?? ""))
                .font(.system(size: 17))
                .foregroundStyle(Palette.secondary)
                .lineLimit(2)
                .frame(maxWidth: .infinity, alignment: .leading)
            if session.notice?.offersSettings == true {
                Button {
                    Haptics.impact()
                    openSystemSettings()
                } label: {
                    Text(L10n.tr("Open Settings"))
                        .font(.system(size: 17, weight: .medium))
                        .foregroundStyle(Palette.text)
                        .padding(.horizontal, 16)
                        .frame(height: 44)
                        .background(Palette.text.opacity(0.08), in: Capsule())
                        .contentShape(Capsule())
                }
                .buttonStyle(VoicePress())
            }
            cancelButton
        }
    }

    // MARK: right-hand controls

    /// 44pt settings, 52pt mic (the one you reach for), 44pt cancel, 10pt apart.
    private var controls: some View {
        HStack(spacing: 10) {
            circleButton("settings-3-line", size: 44, icon: 20, label: "Voice settings") {
                Haptics.impact()
                openSettings()
            }
            micButton
            cancelButton
        }
    }

    private var micButton: some View {
        Button(action: {
            switch session.phase {
            case .confirming: session.sendNow()
            case .paused: Task { await session.end() }
            default: session.toggleMicrophone()
            }
        }) {
            ZStack {
                // The countdown is this ring, draining once around the button.
                if session.phase == .confirming {
                    Circle()
                        .stroke(Palette.text.opacity(0.12), lineWidth: 3)
                    Circle()
                        .trim(from: 0, to: session.editing ? 0 : session.countdown)
                        .stroke(Palette.accentFill, style: StrokeStyle(lineWidth: 3, lineCap: .round))
                        .rotationEffect(.degrees(-90))
                }
                Circle()
                    .fill(micFilled ? Palette.accentFill : Palette.text.opacity(0.08))
                RemixIcon(micGlyph, size: 22, weight: .medium)
                    .foregroundStyle(micFilled ? Palette.onAccent : Palette.text)
            }
            // The ring sits 4pt outside the 52pt button.
            .frame(width: 60, height: 60)
            .contentShape(Circle())
        }
        .buttonStyle(VoicePress())
        .accessibilityLabel(Text(L10n.tr(micLabel)))
    }

    private var micGlyph: String {
        switch session.phase {
        case .confirming: return "arrow-up-line"
        case .paused: return "mic-fill"
        default: return "pause-line"
        }
    }

    private var micLabel: String {
        switch session.phase {
        case .confirming: return session.editing ? "Send" : "Send now"
        case .paused: return "End recording"
        default: return "Pause recording"
        }
    }

    /// Accent while it is the thing to press: hearing, and the words waiting to go.
    private var micFilled: Bool {
        switch session.phase {
        case .recording, .confirming: return true
        case .paused, .notice, .idle: return false
        }
    }

    private var cancelButton: some View {
        Button {
            session.cancel()
        } label: {
            RemixIcon("close-line", size: 18, weight: .bold)
                .foregroundStyle(Palette.danger)
                .frame(width: 44, height: 44)
                .background(Palette.danger.opacity(0.14), in: Circle())
                .contentShape(Circle())
        }
        .buttonStyle(VoicePress())
        .accessibilityLabel(Text(L10n.tr("Cancel")))
    }

    private func circleButton(_ icon: String, size: CGFloat, icon iconSize: CGFloat, label: String,
                              action: @escaping () -> Void) -> some View {
        Button(action: action) {
            RemixIcon(icon, size: iconSize)
                .foregroundStyle(Palette.text)
                .frame(width: size, height: size)
                .background(Palette.text.opacity(0.07), in: Circle())
                .contentShape(Circle())
        }
        .buttonStyle(VoicePress())
        .accessibilityLabel(Text(L10n.tr(label)))
    }
}

/// The capsule's press: a deeper squeeze than the rest of the app's buttons, so a 44pt circle under a
/// thumb gives something back.
private struct VoicePress: ButtonStyle {
    func makeBody(configuration: Configuration) -> some View {
        configuration.label
            .scaleEffect(configuration.isPressed ? 0.92 : 1)
            .animation(Motion.press, value: configuration.isPressed)
    }
}
