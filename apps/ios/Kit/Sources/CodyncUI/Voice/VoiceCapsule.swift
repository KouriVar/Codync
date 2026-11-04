import CodyncKit
import SwiftUI

/// The voice capsule that takes the bottom bar's place: the lead bot, a waveform on your voice, the
/// settings and the mic on the left, the red cancel on the right. It is the bar's own height, so the
/// home doesn't move when it morphs in; the bar's glass is applied outside, by `HomeBottomBar`.
public struct VoiceCapsule: View {
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
        HStack(spacing: 10) {
            switch session.phase {
            case .recording, .paused: listening
            case .confirming: confirming
            case .notice: notice
            case .idle: EmptyView()
            }
        }
        .padding(.leading, 6)
        .padding(.trailing, 4)
        .frame(height: 48)
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

    private var listening: some View {
        HStack(spacing: 8) {
            avatar
            LevelDots(level: session.level, speaking: false, working: false,
                      color: Palette.text, reduceMotion: reduceMotion)
                .frame(maxWidth: .infinity, maxHeight: 20)
                .accessibilityLabel(Text(L10n.tr(session.phase == .paused ? "Recording paused" : "Listening")))
            circleButton("settings-3-line", label: "Voice settings", action: openSettings)
            micButton
            cancelButton
        }
    }

    private var avatar: some View {
        Group {
            if let lead {
                CharacterAvatar(bot: lead, size: 26, animated: false)
            } else {
                Circle().fill(Palette.bubbleAgent)
                    .frame(width: 26, height: 26)
            }
        }
        .scaleEffect(breathing ? 1.08 : 1)
        .animation(breathing ? .easeInOut(duration: 0.75).repeatForever(autoreverses: true) : Motion.fade,
                   value: breathing)
        .padding(.leading, 4)
        .accessibilityHidden(true)
    }

    /// While hearing it pauses; while paused the same button ends the recording and shows the words.
    private var micButton: some View {
        Button {
            if session.phase == .paused {
                Task { await session.end() }
            } else {
                session.toggleMicrophone()
            }
        } label: {
            RemixIcon(session.phase == .paused ? "stop-fill" : "mic-line", size: 20)
                .foregroundStyle(Palette.text)
                .frame(width: 40, height: 40)
                .background(Palette.text.opacity(session.phase == .paused ? 0.12 : 0.06), in: Circle())
                .contentShape(Circle())
        }
        .buttonStyle(PressScale())
        .accessibilityLabel(Text(L10n.tr(session.phase == .paused ? "End recording" : "Pause recording")))
    }

    // MARK: the words

    private var confirming: some View {
        HStack(spacing: 8) {
            if session.editing {
                TextField(L10n.tr("Transcript"), text: $bound.text, axis: .vertical)
                    .focused($typing)
                    // One line: the capsule keeps the bar's height while you correct it.
                    .lineLimit(1)
                    .font(.subheadline)
                    .foregroundStyle(Palette.text)
                    .submitLabel(.send)
                    .onSubmit { session.sendNow() }
                    .padding(.leading, 6)
                    .frame(maxWidth: .infinity, alignment: .leading)
            } else {
                Text(session.text)
                    .font(.subheadline)
                    .foregroundStyle(Palette.text)
                    .lineLimit(1)
                    .truncationMode(.tail)
                    .padding(.leading, 6)
                    .frame(maxWidth: .infinity, alignment: .leading)
                    .contentShape(Rectangle())
                    .onTapGesture { session.startEditing() }
                    .accessibilityHint(Text(L10n.tr("Tap to edit")))
            }
            sendButton
            cancelButton
        }
    }

    /// The countdown is the ring around it: it drains once and the words go.
    private var sendButton: some View {
        Button { session.sendNow() } label: {
            ZStack {
                Circle()
                    .stroke(Palette.text.opacity(0.12), lineWidth: 2)
                Circle()
                    .trim(from: 0, to: session.editing ? 0 : session.countdown)
                    .stroke(Palette.text.opacity(0.65), style: StrokeStyle(lineWidth: 2, lineCap: .round))
                    .rotationEffect(.degrees(-90))
                RemixIcon("arrow-up-line", size: 18)
                    .foregroundStyle(Palette.onAccent)
                    .frame(width: 30, height: 30)
                    .background(Palette.accentFill, in: Circle())
            }
            .frame(width: 36, height: 36)
            .contentShape(Circle())
        }
        .buttonStyle(PressScale())
        .accessibilityLabel(Text(L10n.tr(session.editing ? "Send" : "Send now")))
    }

    // MARK: stopped early

    private var notice: some View {
        HStack(spacing: 8) {
            Text(L10n.tr(session.notice?.message ?? ""))
                .font(.subheadline)
                .foregroundStyle(Palette.secondary)
                .lineLimit(2)
                .padding(.leading, 10)
                .frame(maxWidth: .infinity, alignment: .leading)
            if session.notice?.offersSettings == true {
                Button(action: openSystemSettings) {
                    Text(L10n.tr("Open Settings"))
                        .font(.subheadline.weight(.medium))
                        .foregroundStyle(Palette.text)
                        .padding(.horizontal, 12)
                        .frame(height: 34)
                        .background(Palette.text.opacity(0.08), in: Capsule())
                }
                .buttonStyle(PressScale())
            }
            cancelButton
        }
    }

    // MARK: pieces

    private func circleButton(_ icon: String, label: String, action: @escaping () -> Void) -> some View {
        Button(action: action) {
            RemixIcon(icon, size: 20)
                .foregroundStyle(Palette.text)
                .frame(width: 40, height: 40)
                .contentShape(Circle())
        }
        .buttonStyle(PressScale())
        .accessibilityLabel(Text(L10n.tr(label)))
    }

    private var cancelButton: some View {
        Button { session.cancel() } label: {
            RemixIcon("close-line", size: 20)
                .foregroundStyle(Palette.danger)
                .frame(width: 40, height: 40)
                .background(Palette.danger.opacity(0.14), in: Circle())
                .contentShape(Circle())
        }
        .buttonStyle(PressScale())
        .accessibilityLabel(Text(L10n.tr("Cancel")))
    }
}
