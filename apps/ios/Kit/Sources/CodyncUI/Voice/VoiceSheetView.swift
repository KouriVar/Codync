import CodyncKit
import SwiftUI

/// The voice sheet: the system's own sheet at three detents — a 76pt pill, half height and full —
/// with the lead bot, the waveform and the microphone inside. Recording, recognition and sending
/// stay in `VoiceSession`; this view only draws them.
public struct VoiceSheetView: View {
    /// The resting detent: 44pt buttons with 16pt of air on every side.
    public static let small: PresentationDetent = .height(76)
    /// Every circle's glyph, against the 44pt button.
    private static let icon: CGFloat = 24

    private let lead: Bot?
    private let session: VoiceSession
    @Binding private var detent: PresentationDetent
    let openSystemSettings: () -> Void

    @Bindable private var bound: VoiceSession
    @Environment(\.accessibilityReduceMotion) private var reduceMotion
    @FocusState private var typing: Bool
    /// Moves the buttons between the pill's row and the half sheet's corners.
    @Namespace private var morph
    @State private var breathing = false
    /// The voice settings open as a second sheet on top of this one: one presenter shows one sheet.
    @State private var showSettings = false

    public init(lead: Bot?, session: VoiceSession, detent: Binding<PresentationDetent>,
                openSystemSettings: @escaping () -> Void) {
        self.lead = lead
        self.session = session
        self._detent = detent
        self._bound = Bindable(session)
        self.openSystemSettings = openSystemSettings
    }

    private var isSmall: Bool { detent == Self.small }

    public var body: some View {
        Group {
            if isSmall {
                pill
            } else {
                tall
            }
        }
        .frame(maxWidth: .infinity, maxHeight: .infinity, alignment: isSmall ? .center : .top)
        .animation(Motion.reduced(Motion.layout, reduceMotion), value: isSmall)
        .animation(Motion.reduced(Motion.layout, reduceMotion), value: session.phase)
        .animation(Motion.reduced(Motion.layout, reduceMotion), value: session.sendFailed)
        .onChange(of: session.phase) { _, phase in
            breathing = phase == .recording && !reduceMotion
        }
        .onChange(of: session.editing) { _, editing in typing = editing }
        .onAppear { breathing = session.phase == .recording && !reduceMotion }
        .sheet(isPresented: $showSettings) {
            VoiceLanguageSheet()
                .presentationDetents([.medium])
                .presentationDragIndicator(.visible)
                .environment(\.dismissModal, DismissModalAction { showSettings = false })
        }
    }

    // MARK: the 76pt pill

    /// No send button here: the words live in the taller sheet, so nothing sends from the pill.
    private var pill: some View {
        HStack(spacing: 12) {
            avatar(36)
                .matchedGeometryEffect(id: "avatar", in: morph)
            waveform
                .matchedGeometryEffect(id: "wave", in: morph)
            settingsButton
                .matchedGeometryEffect(id: "settings", in: morph)
            micButton
                .matchedGeometryEffect(id: "mic", in: morph)
            closeButton
                .matchedGeometryEffect(id: "close", in: morph)
        }
        .padding(.horizontal, 16)
        // No vertical padding: the row centres in whatever the 76pt detent leaves after the system
        // grabber, which is the 16pt of air the measurement asked for.
        .frame(maxWidth: .infinity, maxHeight: .infinity, alignment: .center)
    }

    // MARK: half and full

    private var tall: some View {
        VStack(spacing: 12) {
            HStack(spacing: 12) {
                // Title on the left, buttons on the right, like a sheet's own title bar.
                Text(L10n.tr(title))
                    .font(.system(size: 17, weight: .semibold))
                    .foregroundStyle(session.sendFailed ? Palette.danger : Palette.text)
                    .lineLimit(1)
                    .minimumScaleFactor(0.8)
                Spacer(minLength: 8)
                if session.canSend || session.sending {
                    sendButton
                        .matchedGeometryEffect(id: "send", in: morph)
                }
                closeButton
                    .matchedGeometryEffect(id: "close", in: morph)
            }
            transcript
                .frame(maxWidth: .infinity, maxHeight: .infinity)
            HStack(spacing: 12) {
                waveform
                    .matchedGeometryEffect(id: "wave", in: morph)
                settingsButton
                    .matchedGeometryEffect(id: "settings", in: morph)
                micButton
                    .matchedGeometryEffect(id: "mic", in: morph)
            }
        }
        .padding(.horizontal, 16)
        .padding(.top, 8)
        .padding(.bottom, 16)
    }

    /// TODO: `.large` runs the same layout as `.medium` for now; a continuous call mode belongs here.
    private var waveform: some View {
        VoiceWaveform(level: session.level, paused: session.phase == .paused)
            .frame(maxWidth: .infinity)
    }

    /// "Listening" while it hears, "Send to XX" once the words are in, and the trouble when there is.
    private var title: String {
        if session.sendFailed { return "Sending failed, tap send to retry" }
        switch session.phase {
        case .recording: return "Listening"
        case .paused: return "Recording paused"
        case .confirming, .notice: return lead.map { L10n.tr("Send to") + " " + $0.name } ?? "Send to"
        case .idle: return "Listening"
        }
    }

    // MARK: the words

    @ViewBuilder private var transcript: some View {
        if session.editing {
            TextField(L10n.tr("Say something"), text: $bound.text, axis: .vertical)
                .focused($typing)
                .font(.system(size: 20))
                .foregroundStyle(Palette.text)
                .lineLimit(1...6)
        } else if session.phase == .notice {
            noticeLines
        } else if session.notHeard {
            Text(L10n.tr("Did not catch that, say it again"))
                .font(.system(size: 20))
                .foregroundStyle(Palette.secondary)
                .frame(maxWidth: .infinity, alignment: .leading)
        } else if session.text.isEmpty {
            VStack(alignment: .leading, spacing: 0) {
                Text(L10n.tr("Say something"))
                    .font(.system(size: 20))
                    .foregroundStyle(Palette.tertiary)
                Spacer(minLength: 0)
            }
            .frame(maxWidth: .infinity, alignment: .leading)
            .contentShape(Rectangle())
            .onTapGesture { session.startEditing() }
        } else {
            ScrollViewReader { proxy in
                ScrollView {
                    Text(session.text)
                        .font(.system(size: 20))
                        .foregroundStyle(Palette.text)
                        .frame(maxWidth: .infinity, alignment: .leading)
                        .padding(.bottom, 2)
                        .id("end")
                }
                .scrollIndicators(.hidden)
                // The newest words stay in sight as they are recognized.
                .onChange(of: session.text) { _, _ in
                    withAnimation(Motion.reduced(Motion.fade, reduceMotion)) {
                        proxy.scrollTo("end", anchor: .bottom)
                    }
                }
                .contentShape(Rectangle())
                .onTapGesture { session.startEditing() }
            }
        }
    }

    /// A refusal with the settings jump when there is one.
    private var noticeLines: some View {
        VStack(alignment: .leading, spacing: 12) {
            Text(L10n.tr(session.notice?.message ?? ""))
                .font(.system(size: 20))
                .foregroundStyle(Palette.secondary)
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
                        .contentShape(Capsule())
                }
                .buttonStyle(VoicePress())
                .modifier(VoiceGlass(tint: nil, shape: AnyShape(Capsule())))
            }
            Spacer(minLength: 0)
        }
    }

    // MARK: pieces

    /// 36pt, breathing 1.0 → 1.06 inside a halo of the bot's own colour while it listens.
    private func avatar(_ size: CGFloat) -> some View {
        let tint = lead.map { AvatarPalette.color($0.avatarColor) } ?? Palette.secondary
        return ZStack {
            Circle()
                .fill(tint.opacity(0.5))
                .frame(width: size, height: size)
                .blur(radius: breathing ? 8 : 5)
                .scaleEffect(breathing ? 1.22 : 1.05)
                .opacity(breathing ? 0.55 : 0.3)
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
        .accessibilityHidden(true)
    }

    /// The ✕: pale red glass, red glyph, and the anchor everything else moves away from.
    private var closeButton: some View {
        circle("close-line", label: "Close", tint: Palette.danger.opacity(0.25), glyph: Palette.danger) {
            session.cancel()
        }
    }

    private var settingsButton: some View {
        circle("settings-3-line", label: "Voice settings", tint: nil) {
            Haptics.impact()
            showSettings = true
        }
    }

    /// Pause while hearing, hear again while paused. Accent glass while it is the live control.
    private var micButton: some View {
        Button {
            session.toggleMicrophone()
        } label: {
            circleLabel(glyph: micGlyph, filled: session.phase == .recording)
        }
        .buttonStyle(VoicePress())
        .modifier(VoiceGlass(tint: session.phase == .recording ? Palette.accentFill : nil,
                             shape: AnyShape(Circle())))
        .accessibilityLabel(Text(L10n.tr(session.phase == .recording ? "Pause recording" : "Continue recording")))
    }

    /// Sends the words. In automatic mode its rim is the countdown; an empty transcript greys it out.
    private var sendButton: some View {
        Button {
            Task { await session.sendNow() }
        } label: {
            ZStack {
                circleLabel(glyph: "arrow-up-line", filled: true)
                if session.countingDown {
                    Circle()
                        .stroke(Palette.text.opacity(0.15), lineWidth: 3)
                    Circle()
                        .trim(from: 0, to: session.countdown)
                        .stroke(Palette.accentFill, style: StrokeStyle(lineWidth: 3, lineCap: .round))
                        .rotationEffect(.degrees(-90))
                }
            }
            .frame(width: 44, height: 44)
            .contentShape(Circle())
        }
        .buttonStyle(VoicePress())
        .modifier(VoiceGlass(tint: Palette.accentFill, shape: AnyShape(Circle())))
        .disabled(!session.canSend)
        .opacity(session.canSend ? 1 : 0.35)
        .accessibilityLabel(Text(L10n.tr("Send")))
    }

    private var micGlyph: String {
        session.phase == .recording ? "pause-line" : "play-line"
    }

    /// One 44pt glyph: 24pt of Remix, the same weight everywhere.
    private func circleLabel(glyph: String, filled: Bool) -> some View {
        RemixIcon(glyph, size: Self.icon, weight: .medium)
            .foregroundStyle(filled ? Palette.onAccent : Palette.text)
            .frame(width: 44, height: 44)
            .contentShape(Circle())
    }

    private func circle(_ icon: String, label: String, tint: Color?, glyph: Color? = nil,
                        action: @escaping () -> Void) -> some View {
        Button(action: action) {
            RemixIcon(icon, size: Self.icon, weight: .medium)
                .foregroundStyle(glyph ?? Palette.text)
                .frame(width: 44, height: 44)
                .contentShape(Circle())
        }
        .buttonStyle(VoicePress())
        .modifier(VoiceGlass(tint: tint, shape: AnyShape(Circle())))
        .accessibilityLabel(Text(L10n.tr(label)))
    }
}

/// The sheet's glass: Liquid Glass on iOS 26, `ultraThinMaterial` with a hairline before that.
private struct VoiceGlass: ViewModifier {
    let tint: Color?
    let shape: AnyShape

    func body(content: Content) -> some View {
        if #available(iOS 26, *) {
            content.glassEffect(tint.map { Glass.regular.tint($0).interactive() } ?? .regular.interactive(),
                                in: shape)
        } else {
            content
                .background {
                    shape.fill(.ultraThinMaterial)
                    if let tint { shape.fill(tint) }
                }
                .overlay { shape.stroke(.white.opacity(0.5), lineWidth: 0.5) }
        }
    }
}

/// The sheet's press: a deeper squeeze than the rest of the app's buttons.
private struct VoicePress: ButtonStyle {
    func makeBody(configuration: Configuration) -> some View {
        configuration.label
            .scaleEffect(configuration.isPressed ? 0.92 : 1)
            .animation(Motion.press, value: configuration.isPressed)
    }
}
