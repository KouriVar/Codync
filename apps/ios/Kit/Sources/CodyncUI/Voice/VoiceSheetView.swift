import CodyncKit
import SwiftUI

/// The voice sheet: the system's own sheet at three detents — a 76pt pill, half height and full —
/// with the lead bot, the waveform and the microphone inside. Recording, recognition and sending
/// stay in `VoiceSession`; this view only draws them. Closing the sheet is what ends a recording:
/// there is no close button anywhere, because pulling the sheet down is the way out.
public struct VoiceSheetView: View {
    /// The resting detent: 44pt buttons with 16pt of air on every side.
    public static let small: PresentationDetent = .height(76)
    /// Every circle's glyph, against the 44pt button.
    private static let icon: CGFloat = 24
    /// The one spring the layout changes on.
    private static let settle = Animation.spring(response: 0.35, dampingFraction: 0.9)

    private let lead: Bot?
    private let session: VoiceSession
    @Binding private var detent: PresentationDetent
    let openSystemSettings: () -> Void

    @Bindable private var bound: VoiceSession
    @Environment(\.dismiss) private var dismiss
    @Environment(\.accessibilityReduceMotion) private var reduceMotion
    @FocusState private var typing: Bool
    @State private var breathing = false
    /// Pulling down with words to lose asks first.
    @State private var confirmDiscard = false
    /// The voice settings open as a second sheet on top of this one: one presenter shows one sheet.
    @State private var showSettings = false
    /// The words page has flipped round to the camera, and where the flip is.
    @State private var showingCamera = false
    @State private var flip: Double = 0
    @State private var camera = VoiceCamera()

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
            if showingCamera {
                VoiceCameraPage(camera: camera, onBack: { flipCamera(to: false) }) { image in
                    session.attach(image)
                    flipCamera(to: false)
                }
                // The sheet turns over to get here, so this face starts upside down: turn it back.
                .rotation3DEffect(.degrees(180), axis: (x: 0, y: 1, z: 0))
                .rotation3DEffect(.degrees(flip), axis: (x: 0, y: 1, z: 0))
                // Nothing between the camera and the sheet's bottom edge: no safe-area inset to stop it.
                .ignoresSafeArea(edges: .bottom)
            } else if isSmall {
                pill
                    .rotation3DEffect(.degrees(flip), axis: (x: 0, y: 1, z: 0))
            } else {
                tall
                    .rotation3DEffect(.degrees(flip), axis: (x: 0, y: 1, z: 0))
            }
        }
        .frame(maxWidth: .infinity, maxHeight: .infinity, alignment: isSmall ? .center : .top)
        // The camera page is the only face that runs to the bottom edge; the voice faces keep their
        // safe-area insets, so their buttons stay above the Home indicator.
        .ignoresSafeArea(edges: showingCamera ? .bottom : [])
        // One spring for the change between detents: nothing else animates the layout.
        .animation(Motion.reduced(Self.settle, reduceMotion), value: isSmall)
        .animation(Motion.reduced(Self.settle, reduceMotion), value: session.sendFailed)
        // Pulling the sheet down is the way out; with words on screen it asks first.
        .simultaneousGesture(DragGesture(minimumDistance: 24).onEnded { value in
            if value.translation.height > 70, session.hasWords { confirmDiscard = true }
        })
        .confirmationDialog(L10n.tr("Discard this voice message?"), isPresented: $confirmDiscard,
                            titleVisibility: .visible) {
            Button(L10n.tr("Discard"), role: .destructive) { dismiss() }
            Button(L10n.tr("Keep editing"), role: .cancel) {}
        }
        .onChange(of: session.phase) { _, phase in
            breathing = phase == .recording && !reduceMotion
        }
        .onChange(of: session.editing) { _, editing in typing = editing }
        // Tapping anywhere that isn't a control puts the keyboard away; so does 完成 above it.
        .onTapGesture { if typing { typing = false } }
        .toolbar {
            ToolbarItemGroup(placement: .keyboard) {
                Spacer()
                Button(L10n.tr("Done")) { typing = false }
            }
        }
        .onAppear { breathing = session.phase == .recording && !reduceMotion }
        .sheet(isPresented: $showSettings) {
            VoiceLanguageSheet()
                .presentationDetents([.medium])
                .presentationDragIndicator(.visible)
                .environment(\.dismissModal, DismissModalAction { showSettings = false })
        }
    }

    // MARK: the 76pt pill

    /// Avatar, waveform, settings, pause: no send, and no close — the sheet itself is the exit.
    private var pill: some View {
        HStack(spacing: 12) {
            avatar(36)
            waveColumn
            settingsButton
            micButton
        }
        .padding(.horizontal, 16)
        // No vertical padding: the row centres in whatever the 76pt detent leaves after the system
        // grabber, which is the 16pt of air the measurement asked for.
        .frame(maxWidth: .infinity, maxHeight: .infinity, alignment: .center)
    }

    // MARK: half and full

    private var tall: some View {
        VStack(spacing: 12) {
            titleBar
            if let photo = session.attachment {
                attachmentRow(photo)
            }
            transcript
                .frame(maxWidth: .infinity, maxHeight: .infinity)
            HStack(spacing: 12) {
                waveColumn
                cameraButton
                keyboardButton
                settingsButton
                micButton
            }
        }
        .padding(.horizontal, 16)
        // 16pt of air above the avatar and the bot's name, on top of the grabber's own inset.
        .padding(.top, 16)
        .padding(.bottom, 16)
    }

    /// The line, with the "a little quiet" hint under it — inside the waveform's own space, so the
    /// pill's row never moves.
    private var waveColumn: some View {
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

    /// A system sheet's title bar: close on the left, the bot centred, send on the right. The send
    /// side keeps its 44pt when empty, so the title never drifts off centre.
    private var titleBar: some View {
        ZStack {
            HStack(spacing: 6) {
                avatar(24)
                Text(lead?.name ?? L10n.tr("Voice"))
                    .font(.system(size: 17, weight: .semibold))
                    .foregroundStyle(Palette.text)
                    .lineLimit(1)
            }
            HStack(spacing: 12) {
                closeButton
                Spacer(minLength: 0)
                if session.canSend || session.sending {
                    sendButton
                } else {
                    Color.clear.frame(width: 44, height: 44)
                }
            }
        }
    }

    // MARK: the words

    @ViewBuilder private var transcript: some View {
        VStack(alignment: .leading, spacing: 6) {
            if session.sendFailed {
                Text(L10n.tr("Sending failed, tap send to retry"))
                    .font(.footnote)
                    .foregroundStyle(Palette.danger)
            }
            content
        }
    }

    @ViewBuilder private var content: some View {
        if session.editing {
            TextField(L10n.tr("Say something"), text: $bound.text, axis: .vertical)
                .focused($typing)
                .font(.system(size: 20))
                .foregroundStyle(Palette.text)
                .lineLimit(1...6)
        } else if session.phase == .notice {
            noticeLines
        } else if session.notHeard {
            Text(L10n.tr("Did not catch that, get a little closer"))
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
                    proxy.scrollTo("end", anchor: .bottom)
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

    /// 32 or 36pt. Breathing 1.0 → 1.06 inside a halo of the bot's own colour while it hears; frozen
    /// and unlit while it is paused, so the sheet reads as silent at a glance.
    private func avatar(_ size: CGFloat) -> some View {
        let tint = lead.map { AvatarPalette.color($0.avatarColor) } ?? Palette.secondary
        return ZStack {
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
        .accessibilityHidden(true)
    }

    /// The ✕: plain glass, no red — and the way out, asking first when there are words to lose.
    private var closeButton: some View {
        circle("close-line", label: "Close", tint: nil) {
            if session.hasWords {
                confirmDiscard = true
            } else {
                dismiss()
            }
        }
    }

    /// The camera's photo: 64pt, rounded, with a ✕ that takes it back off.
    private func attachmentRow(_ photo: UIImage) -> some View {
        Image(uiImage: photo)
            .resizable()
            .scaledToFill()
            .frame(width: 64, height: 64)
            .clipShape(RoundedRectangle(cornerRadius: 12, style: .continuous))
            .overlay(alignment: .topTrailing) {
                Button { session.attach(nil) } label: {
                    RemixIcon("close-line", size: 14, weight: .bold)
                        .foregroundStyle(Palette.onAccent)
                        .frame(width: 22, height: 22)
                        .background(Palette.accentFill, in: Circle())
                }
                .buttonStyle(VoicePress())
                .offset(x: 6, y: -6)
                .accessibilityLabel(Text(L10n.tr("Remove the photo")))
            }
            .frame(maxWidth: .infinity, alignment: .leading)
    }

    /// The camera: the sheet turns round to its own viewfinder, photo and all.
    private var cameraButton: some View {
        circle("camera-line", label: "Take a photo", tint: nil) {
            flipCamera(to: true)
        }
    }

    /// Half a turn on the Y axis: the content swaps at the edge-on moment, so it reads as one sheet
    /// turning over rather than two views cross-fading.
    private func flipCamera(to camera: Bool) {
        Haptics.impact()
        withAnimation(Motion.reduced(.easeInOut(duration: 0.45), reduceMotion)) {
            flip += 180
        }
        Task { @MainActor in
            try? await Task.sleep(for: .milliseconds(225))
            showingCamera = camera
            if !camera { self.camera.stop() }
        }
    }

    /// The keyboard: stop hearing and type the rest instead.
    private var keyboardButton: some View {
        circle("keyboard-line", label: "Type instead", tint: nil) {
            session.startTyping()
        }
    }

    private var settingsButton: some View {
        circle("settings-3-line", label: "Voice settings", tint: nil) {
            Haptics.impact()
            showSettings = true
        }
    }

    /// Pause while hearing, continue while paused. Accent glass while it is the live control.
    private var micButton: some View {
        Button {
            session.toggleMicrophone()
        } label: {
            circleLabel(glyph: micGlyph, filled: session.phase == .recording)
                // A play triangle reads left-heavy; nudge it into the circle's optical middle.
                .offset(x: session.phase == .recording ? 0 : 1.5)
        }
        .buttonStyle(VoicePress())
        .modifier(VoiceGlass(tint: session.phase == .recording ? Palette.accentFill : nil,
                             shape: AnyShape(Circle())))
        .accessibilityLabel(Text(L10n.tr(session.phase == .recording ? "Pause recording" : "Continue recording")))
    }

    /// Sends the words. In automatic mode its rim is the countdown.
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

/// The sheet's glass: Liquid Glass on iOS 26, `ultraThinMaterial` with a hairline before that. Shared
/// with the camera page, so every circle in the sheet is the same circle.
struct VoiceGlass: ViewModifier {
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
