import CodyncKit
import SwiftUI

/// The voice sheet: the system's own sheet at two detents — half height and full — with the lead bot,
/// the words and the microphone inside. The 76pt face is no longer a detent: it is `VoicePill`, which
/// the home's bottom bar grows into. Recording, recognition and sending stay in `VoiceSession`; this
/// view only draws them. Closing the sheet is what ends a recording: there is no close button at
/// half height on purpose, and pulling the sheet down is the way out.
public struct VoiceSheetView: View {
    /// Every circle's glyph, against the 44pt button.
    private static let icon: CGFloat = ControlMetrics.Size.icon.glyph
    /// The one spring the layout changes on. Public: the home's capsule grows on the same curve, so
    /// the bar and the sheet read as one move.
    public static let settle = Animation.spring(response: 0.35, dampingFraction: 0.9)

    private let lead: Bot?
    private let session: VoiceSession
    let openSystemSettings: () -> Void
    /// The voice settings. They are a sheet, and a page presents one at a time: the page that owns
    /// this sheet owns them, which is the home while the sheet is down and this sheet while it is up.
    let openSettings: () -> Void

    @Bindable private var bound: VoiceSession
    @Environment(\.dismiss) private var dismiss
    @Environment(\.accessibilityReduceMotion) private var reduceMotion
    @FocusState private var typing: Bool
    /// Pulling down with words to lose asks first.
    @State private var confirmDiscard = false
    /// The words page has flipped round to the camera, and where the flip is.
    @State private var showingCamera = false
    @State private var flip: Double = 0
    @State private var camera = VoiceCamera()

    public init(lead: Bot?, session: VoiceSession,
                openSystemSettings: @escaping () -> Void,
                openSettings: @escaping () -> Void) {
        self.lead = lead
        self.session = session
        self._bound = Bindable(session)
        self.openSystemSettings = openSystemSettings
        self.openSettings = openSettings
    }

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
            } else {
                tall
                    .rotation3DEffect(.degrees(flip), axis: (x: 0, y: 1, z: 0))
            }
        }
        .frame(maxWidth: .infinity, maxHeight: .infinity, alignment: .top)
        // The camera page is the only face that runs to the bottom edge; the voice face keeps its
        // safe-area insets, so its buttons stay above the Home indicator.
        .ignoresSafeArea(edges: showingCamera ? .bottom : [])
        // One spring for the layout changes: nothing else animates the layout.
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
        .onChange(of: session.editing) { _, editing in typing = editing }
        // Tapping anywhere that isn't a control puts the keyboard away.
        .onTapGesture { if typing { typing = false } }
    }

    // MARK: half and full

    private var tall: some View {
        VStack(spacing: 12) {
            titleBar
            if let photo = session.attachment {
                attachmentRow(photo)
            }
            // The only thing that gives way when the keyboard comes up: the words, which scroll.
            transcript
                .frame(maxWidth: .infinity, maxHeight: .infinity)
        }
        .padding(.horizontal, 16)
        // 16pt of air above the avatar and the bot's name, on top of the grabber's own inset.
        .padding(.top, 16)
        // The buttons sit in the safe area, so they ride just above the keyboard while it is up and
        // return to the bottom when it goes. The title and the photo keep their places either way.
        .safeAreaInset(edge: .bottom, spacing: 0) {
            HStack(spacing: 12) {
                VoiceWaveColumn(session: session)
                cameraButton
                keyboardButton
                VoiceSettingsButton(action: openSettings)
                VoiceMicButton(session: session)
            }
            .padding(.horizontal, 16)
            .padding(.top, 8)
            .padding(.bottom, 16)
        }
    }

    /// A system sheet's title bar: close on the left, the bot centred, send on the right. The send
    /// side keeps its 44pt when empty, so the title never drifts off centre.
    private var titleBar: some View {
        ZStack {
            HStack(spacing: 6) {
                VoiceAvatar(lead: lead, size: 24, recording: session.phase == .recording)
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
                    Color.clear.frame(width: ControlMetrics.Size.icon.side, height: ControlMetrics.Size.icon.side)
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
                .buttonStyle(PressScale(scale: 0.92))
                .glass(in: Capsule(), interactive: true)
            }
            Spacer(minLength: 0)
        }
    }

    // MARK: pieces

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
                        .frame(width: ControlMetrics.Size.micro.side, height: ControlMetrics.Size.micro.side)
                        .background(Palette.accentFill, in: Circle())
                }
                .buttonStyle(PressScale(scale: 0.92))
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
            .frame(width: ControlMetrics.Size.icon.side, height: ControlMetrics.Size.icon.side)
            .contentShape(Circle())
        }
        .buttonStyle(PressScale(scale: 0.92))
        .glass(in: Circle(), interactive: true, tint: Palette.accentFill)
        .accessibilityLabel(Text(L10n.tr("Send")))
    }

    /// One 44pt glyph: 24pt of Remix, the same weight everywhere.
    private func circleLabel(glyph: String, filled: Bool) -> some View {
        RemixIcon(glyph, size: Self.icon, weight: .medium)
            .foregroundStyle(filled ? Palette.onAccent : Palette.text)
            .frame(width: ControlMetrics.Size.icon.side, height: ControlMetrics.Size.icon.side)
            .contentShape(Circle())
    }

    private func circle(_ icon: String, label: String, tint: Color?, glyph: Color? = nil,
                        action: @escaping () -> Void) -> some View {
        Button(action: action) {
            RemixIcon(icon, size: Self.icon, weight: .medium)
                .foregroundStyle(glyph ?? Palette.text)
                .frame(width: ControlMetrics.Size.icon.side, height: ControlMetrics.Size.icon.side)
                .contentShape(Circle())
        }
        .buttonStyle(PressScale(scale: 0.92))
        .glass(in: Circle(), interactive: true, tint: tint)
        .accessibilityLabel(Text(L10n.tr(label)))
    }
}
