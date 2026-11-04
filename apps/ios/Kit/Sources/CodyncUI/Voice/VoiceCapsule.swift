import CodyncKit
import SwiftUI

/// The voice capsule: a 72pt glass pill while it rests, and a half-height glass panel once you pull
/// it up — or when the words come back and you want to read them. The words live only in the panel;
/// the resting pill keeps the waveform and the three buttons. Recording, recognition and sending are
/// `VoiceSession`'s business; this view only draws and animates.
public struct VoiceCapsule: View {
    /// The resting pill's height, which is also what the home reserves under it.
    public static let collapsed: CGFloat = 72
    /// How far up the finger has to take it before it stays up (or comes back down).
    private static let snap: CGFloat = 120
    /// Pulled up or let down: one spring for both, slow enough to read as a sheet.
    private static let spring = Animation.spring(response: 0.4, dampingFraction: 0.85)

    private let lead: Bot?
    private let session: VoiceSession
    @Binding private var expanded: Bool
    /// The panel's height when it is up: about 45% of the screen, handed in by the home.
    let panelHeight: CGFloat
    let openSettings: () -> Void
    let openSystemSettings: () -> Void

    @Bindable private var bound: VoiceSession
    @Environment(\.accessibilityReduceMotion) private var reduceMotion
    @FocusState private var typing: Bool
    @Namespace private var morph
    @State private var breathing = false
    /// Where the finger has taken the height, until it lets go.
    @State private var dragging: CGFloat?

    public init(lead: Bot?, session: VoiceSession, expanded: Binding<Bool>, panelHeight: CGFloat,
                openSettings: @escaping () -> Void, openSystemSettings: @escaping () -> Void) {
        self.lead = lead
        self.session = session
        self._expanded = expanded
        self.panelHeight = panelHeight
        self._bound = Bindable(session)
        self.openSettings = openSettings
        self.openSystemSettings = openSystemSettings
    }

    public var body: some View {
        Group {
            if expanded {
                panel
            } else {
                row
            }
        }
        .frame(maxWidth: .infinity)
        .frame(height: height)
        .modifier(VoiceCapsuleGlass(shape: shape))
        .clipShape(shape)
        .contentShape(shape)
        .overlay(alignment: .top) {
            handle.padding(.top, 6)
        }
        // Pull up from the resting pill; once it is up the handle and header take the pull instead,
        // so the transcript can still be scrolled with a finger.
        .gesture(drag, including: expanded ? .none : .all)
        .animation(Motion.reduced(Self.spring, reduceMotion), value: expanded)
        .animation(Motion.reduced(Motion.layout, reduceMotion), value: session.phase)
        .onChange(of: session.phase) { _, phase in
            breathing = phase == .recording && !reduceMotion
            // The words are only ever shown in the panel, so the panel is where they open.
            if phase == .confirming { snap(to: true) }
        }
        .onChange(of: session.editing) { _, editing in typing = editing }
        .onAppear { breathing = session.phase == .recording && !reduceMotion }
    }

    /// A resting pill is a stadium, so its radius is half its height; the panel gets 32.
    private var radius: CGFloat { expanded ? 32 : Self.collapsed / 2 }
    private var shape: RoundedRectangle { RoundedRectangle(cornerRadius: radius, style: .continuous) }
    private var height: CGFloat { dragging ?? (expanded ? panelHeight : Self.collapsed) }

    // MARK: the handle

    private var handle: some View {
        Capsule()
            .fill(Color.secondary.opacity(0.5))
            .frame(width: 36, height: 5)
            .frame(width: 96, height: 24)
            .contentShape(Rectangle())
            .onTapGesture { snap(to: !expanded) }
            .gesture(drag, including: expanded ? .all : .none)
            .accessibilityAddTraits(.isButton)
            .accessibilityLabel(Text(L10n.tr(expanded ? "Collapse" : "Expand")))
    }

    // MARK: resting

    private var row: some View {
        HStack(spacing: 12) {
            avatar(40)
            Group {
                if session.phase == .notice {
                    Text(L10n.tr(session.notice?.message ?? ""))
                        .font(.system(size: 15))
                        .foregroundStyle(Palette.secondary)
                        .lineLimit(2)
                        .frame(maxWidth: .infinity, alignment: .leading)
                } else {
                    VoiceWaveform(level: session.level)
                        .frame(maxWidth: .infinity)
                        .matchedGeometryEffect(id: "wave", in: morph, isSource: !expanded)
                }
            }
            controls
                .matchedGeometryEffect(id: "controls", in: morph, isSource: !expanded)
        }
        .padding(.horizontal, 14)
        .frame(maxHeight: .infinity)
    }

    // MARK: up

    private var panel: some View {
        VStack(spacing: 12) {
            header
                .padding(.top, 4)
                .gesture(drag)
            transcript
                .frame(maxWidth: .infinity, maxHeight: .infinity)
            HStack(spacing: 12) {
                VoiceWaveform(level: session.level)
                    .frame(maxWidth: .infinity)
                    .matchedGeometryEffect(id: "wave", in: morph, isSource: expanded)
                controls
                    .matchedGeometryEffect(id: "controls", in: morph, isSource: expanded)
            }
        }
        .padding(.top, 28)
        .padding(.horizontal, 14)
        .padding(.bottom, 14)
    }

    private var header: some View {
        HStack(spacing: 12) {
            avatar(40)
            Text(L10n.tr(status))
                .font(.system(size: 17, weight: .medium))
                .foregroundStyle(Palette.text)
                .lineLimit(1)
            Spacer(minLength: 8)
        }
        .contentShape(Rectangle())
    }

    /// "Listening" while it hears, otherwise who it is talking to.
    private var status: String {
        switch session.phase {
        case .recording: return "Listening"
        case .paused: return "Recording paused"
        case .confirming, .notice, .idle: return lead?.name ?? "Listening"
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
                .padding(.horizontal, 4)
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
            .padding(.horizontal, 4)
            .contentShape(Rectangle())
            .onTapGesture { session.startEditing() }
        } else {
            ScrollViewReader { proxy in
                ScrollView {
                    Text(session.text)
                        .font(.system(size: 20))
                        .foregroundStyle(Palette.text)
                        .frame(maxWidth: .infinity, alignment: .leading)
                        .padding(.horizontal, 4)
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

    /// A refusal, or "did not catch that": the same lines the resting pill would show, with the
    /// settings jump when there is one.
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
                        .glass(in: Capsule())
                        .contentShape(Capsule())
                }
                .buttonStyle(VoicePress())
            }
            Spacer(minLength: 0)
        }
        .padding(.horizontal, 4)
    }

    // MARK: pieces

    /// 40pt, breathing 1.0 → 1.06 inside a halo of the bot's own colour while it listens.
    private func avatar(_ size: CGFloat) -> some View {
        let tint = lead.map { AvatarPalette.color($0.avatarColor) } ?? Palette.secondary
        return ZStack {
            Circle()
                .fill(tint.opacity(0.5))
                .frame(width: size, height: size)
                .blur(radius: breathing ? 9 : 5)
                .scaleEffect(breathing ? 1.2 : 1.04)
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

    /// 40pt settings, 48pt mic (the one you reach for), 40pt cancel, 8pt apart — one glass container,
    /// so the three rims read as one family.
    private var controls: some View {
        GlassEffectContainer(spacing: 8) {
            HStack(spacing: 8) {
                glassButton("settings-3-line", diameter: 40, icon: 18, label: "Voice settings", tint: nil) {
                    Haptics.impact()
                    openSettings()
                }
                micButton
                glassButton("close-line", diameter: 40, icon: 18, label: "Cancel",
                            tint: Palette.danger.opacity(0.25), glyph: Palette.danger) {
                    session.cancel()
                }
            }
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
                // The countdown is the ring just outside the glass, so the button keeps its shape.
                if session.phase == .confirming {
                    Circle()
                        .stroke(Palette.text.opacity(0.12), lineWidth: 3)
                    Circle()
                        .trim(from: 0, to: session.editing ? 0 : session.countdown)
                        .stroke(Palette.accentFill, style: StrokeStyle(lineWidth: 3, lineCap: .round))
                        .rotationEffect(.degrees(-90))
                }
                RemixIcon(micGlyph, size: 20, weight: .medium)
                    .foregroundStyle(micFilled ? Palette.onAccent : Palette.text)
                    .frame(width: 48, height: 48)
            }
            .frame(width: 52, height: 52)
            .contentShape(Circle())
        }
        .buttonStyle(VoicePress())
        .modifier(VoiceGlass(tint: micFilled ? Palette.accentFill : nil))
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

    /// Accent glass while it is the thing to press: hearing, and the words waiting to go.
    private var micFilled: Bool {
        switch session.phase {
        case .recording, .confirming: return true
        case .paused, .notice, .idle: return false
        }
    }

    private func glassButton(_ icon: String, diameter: CGFloat, icon iconSize: CGFloat, label: String,
                             tint: Color?, glyph: Color? = nil,
                             action: @escaping () -> Void) -> some View {
        Button(action: action) {
            RemixIcon(icon, size: iconSize, weight: .bold)
                .foregroundStyle(glyph ?? Palette.text)
                .frame(width: diameter, height: diameter)
                .contentShape(Circle())
        }
        .buttonStyle(VoicePress())
        .modifier(VoiceGlass(tint: tint))
        .accessibilityLabel(Text(L10n.tr(label)))
    }

    // MARK: the drag

    private var drag: some Gesture {
        DragGesture(minimumDistance: 8)
            .onChanged { value in
                let base = expanded ? panelHeight : Self.collapsed
                dragging = min(panelHeight, max(Self.collapsed, base - value.translation.height))
            }
            .onEnded { value in
                let base = expanded ? panelHeight : Self.collapsed
                let taken = (dragging ?? base) - Self.collapsed
                // A flick counts even when the finger did not travel the whole way.
                let flungUp = value.predictedEndTranslation.height < -160
                let flungDown = value.predictedEndTranslation.height > 160
                let open = expanded
                    ? !(panelHeight - Self.collapsed - taken > Self.snap || flungDown)
                    : (taken > Self.snap || flungUp)
                dragging = nil
                snap(to: open)
            }
    }

    private func snap(to open: Bool) {
        guard open != expanded else { return }
        Haptics.impact()
        withAnimation(Motion.reduced(Self.spring, reduceMotion)) {
            expanded = open
        }
    }
}

/// The capsule's glass itself. iOS 26 draws it; before that a material with a 0.5pt white edge and a
/// top highlight standing in for the same sense of a pane.
private struct VoiceCapsuleGlass<S: InsettableShape>: ViewModifier {
    let shape: S

    func body(content: Content) -> some View {
        if #available(iOS 26, *) {
            content.glassEffect(.regular.interactive(), in: shape)
        } else {
            content
                .background(shape.fill(.ultraThinMaterial))
                .overlay(shape.strokeBorder(.white.opacity(0.5), lineWidth: 0.5))
                .overlay {
                    shape
                        .fill(LinearGradient(colors: [.white.opacity(0.28), .clear],
                                             startPoint: .top, endPoint: .center))
                        .allowsHitTesting(false)
                }
        }
    }
}

/// The three circles' glass: Liquid Glass on iOS 26, `ultraThinMaterial` with a hairline and a top
/// highlight before it.
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
                .overlay {
                    Circle()
                        .fill(LinearGradient(colors: [.white.opacity(0.28), .clear],
                                             startPoint: .top, endPoint: .center))
                        .allowsHitTesting(false)
                }
        }
    }
}

/// The capsule's press: a deeper squeeze than the rest of the app's buttons.
private struct VoicePress: ButtonStyle {
    func makeBody(configuration: Configuration) -> some View {
        configuration.label
            .scaleEffect(configuration.isPressed ? 0.92 : 1)
            .animation(Motion.press, value: configuration.isPressed)
    }
}
