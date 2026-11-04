import CodyncKit
import SwiftUI

/// The voice sheet: the system's own sheet at three detents — a 76pt pill, half height and full —
/// with the lead bot, the waveform and the microphone inside. Recording, recognition and sending
/// stay in `VoiceSession`; this view only draws them.
public struct VoiceSheetView: View {
    /// The resting detent: 44pt buttons with 16pt of air on every side.
    public static let small: PresentationDetent = .height(76)

    private let lead: Bot?
    private let session: VoiceSession
    @Binding private var detent: PresentationDetent
    let openSystemSettings: () -> Void

    @Bindable private var bound: VoiceSession
    @Environment(\.accessibilityReduceMotion) private var reduceMotion
    @FocusState private var typing: Bool
    /// Moves the buttons between the pill's row and the half-sheet's title bar.
    @Namespace private var morph
    @State private var breathing = false
    /// The voice settings open as a second sheet on top of this one: one presenter can only show one.
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

    private var pill: some View {
        HStack(spacing: 12) {
            cancelButton
                .matchedGeometryEffect(id: "cancel", in: morph)
            avatar(36)
                .matchedGeometryEffect(id: "avatar", in: morph)
            waveform
                .matchedGeometryEffect(id: "wave", in: morph)
            settingsButton
                .matchedGeometryEffect(id: "settings", in: morph)
            micButton
                .matchedGeometryEffect(id: "mic", in: morph)
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
                cancelButton
                    .matchedGeometryEffect(id: "cancel", in: morph)
                Spacer(minLength: 8)
                Text(L10n.tr(title))
                    .font(.system(size: 17, weight: .semibold))
                    .foregroundStyle(Palette.text)
                    .lineLimit(1)
                Spacer(minLength: 8)
                micButton
                    .matchedGeometryEffect(id: "mic", in: morph)
            }
            transcript
                .frame(maxWidth: .infinity, maxHeight: .infinity)
            HStack(spacing: 12) {
                waveform
                    .matchedGeometryEffect(id: "wave", in: morph)
                settingsButton
                    .matchedGeometryEffect(id: "settings", in: morph)
            }
        }
        .padding(.horizontal, 16)
        .padding(.top, 8)
        .padding(.bottom, 16)
    }

    /// TODO: `.large` runs the same layout as `.medium` for now; a continuous call mode belongs here.
    private var waveform: some View {
        VoiceWaveform(level: session.level)
            .frame(maxWidth: .infinity)
    }

    /// "Listening" until the words are in, then who they are going to.
    private var title: String {
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

    /// A refusal, or "did not catch that", with the settings jump when there is one.
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
                .modifier(VoiceGlass(tint: nil))
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

    private var cancelButton: some View {
        glassButton("close-line", label: "Cancel", tint: Palette.danger.opacity(0.25), glyph: Palette.danger) {
            session.cancel()
        }
    }

    private var settingsButton: some View {
        glassButton("settings-3-line", label: "Voice settings", tint: nil) {
            Haptics.impact()
            showSettings = true
        }
    }

    /// 44pt: pause while hearing, end while paused, send once the words are in. The countdown is the
    /// ring on its rim.
    private var micButton: some View {
        Button(action: {
            switch session.phase {
            case .confirming: session.sendNow()
            case .paused: Task { await session.end() }
            default: session.toggleMicrophone()
            }
        }) {
            ZStack {
                RemixIcon(glyph, size: 20, weight: .medium)
                    .foregroundStyle(micFilled ? Palette.onAccent : Palette.text)
                if session.phase == .confirming {
                    Circle()
                        .stroke(Palette.text.opacity(0.15), lineWidth: 3)
                    Circle()
                        .trim(from: 0, to: session.editing ? 0 : session.countdown)
                        .stroke(Palette.accentFill, style: StrokeStyle(lineWidth: 3, lineCap: .round))
                        .rotationEffect(.degrees(-90))
                }
            }
            .frame(width: 44, height: 44)
            .contentShape(Circle())
        }
        .buttonStyle(VoicePress())
        .modifier(VoiceGlass(tint: micFilled ? Palette.accentFill : nil))
        .accessibilityLabel(Text(L10n.tr(micLabel)))
    }

    private var glyph: String {
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

    /// Accent glass while it is the thing to press: hearing, and the words waiting to go.
    private var micFilled: Bool {
        switch session.phase {
        case .recording, .confirming: return true
        case .paused, .notice, .idle: return false
        }
    }

    private func glassButton(_ icon: String, label: String, tint: Color?, glyph: Color? = nil,
                             action: @escaping () -> Void) -> some View {
        Button(action: action) {
            RemixIcon(icon, size: 18, weight: .bold)
                .foregroundStyle(glyph ?? Palette.text)
                .frame(width: 44, height: 44)
                .contentShape(Circle())
        }
        .buttonStyle(VoicePress())
        .modifier(VoiceGlass(tint: tint))
        .accessibilityLabel(Text(L10n.tr(label)))
    }
}

/// The sheet's buttons: Liquid Glass on iOS 26, `ultraThinMaterial` with a hairline before that.
private struct VoiceGlass: ViewModifier {
    let tint: Color?

    func body(content: Content) -> some View {
        if #available(iOS 26, *) {
            content.glassEffect(tint.map { Glass.regular.tint($0).interactive() } ?? .regular.interactive(),
                                in: Circle())
        } else {
            content
                .background {
                    Circle().fill(.ultraThinMaterial)
                    if let tint { Circle().fill(tint) }
                }
                .overlay { Circle().strokeBorder(.white.opacity(0.5), lineWidth: 0.5) }
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
