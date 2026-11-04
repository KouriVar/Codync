import CodyncKit
import CodyncUI
import SwiftUI
import UIKit

/// What one card in the source switcher is — and what the home shows once it is picked: the pinned
/// list, or one source's own list.
enum HomeFace: Hashable, Identifiable {
    case pinned
    case source(HomeSource)

    /// Also what `@AppStorage` keeps: `pinned`, or the source's raw value.
    var id: String {
        switch self {
        case .pinned: return "pinned"
        case .source(let source): return source.rawValue
        }
    }

    var stored: String { id }

    init?(stored: String) {
        if stored == HomeFace.pinned.stored {
            self = .pinned
            return
        }
        guard let source = HomeSource(rawValue: stored) else { return nil }
        self = .source(source)
    }

    /// What the card says above it, and the name in the switcher.
    var title: String {
        switch self {
        case .pinned: return "置顶"
        case .source(.coe): return "Coe"
        case .source(.dsBot): return "DS Bot"
        case .source(.dsh): return "DSH 对话"
        }
    }
}

/// The lock screen's wallpaper picker, opened by a pinch instead of a long press: one card per face,
/// the neighbours peeking in from both sides, the name above and page dots below.
///
/// The cards are drawn by the home (`card`): it owns the lists, so a card is the real list shrunk,
/// never a snapshot. Tapping one commits it; two fingers spread apart does the same for the card in
/// the middle.
struct SourceSwitcher: View {
    let faces: [HomeFace]
    /// The card in the middle: the pager keeps it in step as the pages turn.
    @Binding var centered: HomeFace
    /// Draws one card's page: the home lays it out at the window's own size, insets and all.
    let card: (HomeFace, CGSize, EdgeInsets) -> AnyView
    /// A card was tapped, or the fingers spread: show that face, full screen.
    let commit: (HomeFace) -> Void

    @Environment(\.accessibilityReduceMotion) private var reduceMotion
    @State private var scrolled: HomeFace?
    /// The window, measured once: every card is laid out against this one rectangle, so the page and
    /// its card can never disagree about their proportions.
    @State private var window = CGSize.zero
    @State private var insets = EdgeInsets()

    /// A card is this much of the screen's width — about 34% of the screen is left for the two
    /// neighbours, so each shows its edge clearly.
    static let cardScale: CGFloat = 0.66
    /// The phone screen's own corner, before the shrink. iOS exposes no number for it; this is the
    /// current iPhone display radius.
    static let screenCorner: CGFloat = 55
    /// Between two cards.
    private static let gap: CGFloat = 10
    /// The glass edge drawn around the mini screen: one line, not a frame.
    private static let rim: CGFloat = 1.5

    var body: some View {
        GeometryReader { proxy in
            let window = window.width > 0 ? window : proxy.size
            let width = window.width * Self.cardScale
            // The screen's own aspect: the card is the whole page, so nothing is cropped.
            let height = width * (window.height / max(window.width, 1))
            VStack(spacing: 14) {
                Spacer(minLength: 0)
                Text(centered.title)
                    .font(.title3.weight(.semibold))
                    .foregroundStyle(Palette.text)
                    .contentTransition(.opacity)
                    .animation(Motion.reduced(Motion.fade, reduceMotion), value: centered)
                pager(window: window, cardWidth: width, cardHeight: height)
                dots
                Spacer(minLength: 16)
            }
            .frame(maxWidth: .infinity, maxHeight: .infinity)
        }
        .background(Palette.background)
        .onAppear {
            scrolled = centered
            let metrics = Self.windowMetrics()
            window = metrics.size
            insets = metrics.insets
        }
        // Two fingers spread: the card in the middle opens, exactly as tapping it does.
        .gesture(
            MagnifyGesture(minimumScaleDelta: 0.06)
                .onEnded { value in
                    guard value.magnification > 1.08 else { return }
                    commit(centered)
                }
        )
        .accessibilityElement(children: .contain)
    }

    // MARK: the pages

    private func pager(window: CGSize, cardWidth: CGFloat, cardHeight: CGFloat) -> some View {
        ScrollView(.horizontal) {
            LazyHStack(spacing: Self.gap) {
                ForEach(faces) { face in
                    mini(face, window: window, cardWidth: cardWidth, cardHeight: cardHeight)
                        .id(face)
                        .onTapGesture { commit(face) }
                }
            }
            .scrollTargetLayout()
        }
        .scrollIndicators(.hidden)
        .scrollTargetBehavior(.viewAligned)
        .scrollPosition(id: $scrolled)
        // The first and last card centre like the ones between them, so both edges peek alike.
        .contentMargins(.horizontal, (window.width - cardWidth) / 2, for: .scrollContent)
        .frame(height: cardHeight + 24)
        .onChange(of: scrolled) { _, face in
            guard let face, face != centered else { return }
            centered = face
            Haptics.selection()
        }
    }

    /// One card: the whole home screen (its navigation row, the list and the bar — all drawn by the
    /// home) laid out at the screen's size and shrunk, so it is a smaller phone rather than a crop of
    /// one. The glass rim is the app's own surface, not a new one.
    private func mini(_ face: HomeFace, window: CGSize, cardWidth: CGFloat, cardHeight: CGFloat) -> some View {
        let scale = cardWidth / max(window.width, 1)
        let corner = Self.screenCorner * scale
        let shape = RoundedRectangle(cornerRadius: corner, style: .continuous)
        // The page is laid out at the window's own size and shrunk as one piece: nothing is cropped,
        // nothing is padded, and every card is identical.
        let page = card(face, window, insets)
            .frame(width: window.width, height: window.height)
            .scaleEffect(scale, anchor: .topLeading)
            .allowsHitTesting(false)
            .frame(width: cardWidth, height: cardHeight, alignment: .topLeading)
            .clipShape(shape)
        return page
            // One thin glass edge, from the app's own glass surface — no second frame inside it.
            .padding(Self.rim)
            .glass(in: RoundedRectangle(cornerRadius: corner + Self.rim, style: .continuous))
            .shadow(color: .black.opacity(0.22), radius: 20, y: 12)
            .contentShape(RoundedRectangle(cornerRadius: corner + Self.rim, style: .continuous))
    }

    /// The window's size and its safe-area insets, from the window itself: one reading, so a card's
    /// page and the card can never disagree about where the status bar ends.
    private static func windowMetrics() -> (size: CGSize, insets: EdgeInsets) {
        let scene = UIApplication.shared.connectedScenes.compactMap { $0 as? UIWindowScene }.first
        guard let window = scene?.keyWindow ?? scene?.windows.first else { return (.zero, EdgeInsets()) }
        let insets = window.safeAreaInsets
        return (window.bounds.size,
                EdgeInsets(top: insets.top, leading: insets.left, bottom: insets.bottom, trailing: insets.right))
    }

    /// The system's own dots, so the indicator is the one iOS draws rather than a copy of it.
    private var dots: some View {
        PageControl(count: faces.count, current: faces.firstIndex(of: centered) ?? 0)
            .frame(height: 26)
            .accessibilityHidden(true)
    }
}

/// The system's own page dots: `UIPageControl` draws them, this only keeps them in step. It takes no
/// touches — the pages are turned by the scroll view, as before.
private struct PageControl: UIViewRepresentable {
    let count: Int
    let current: Int

    func makeUIView(context: Context) -> UIPageControl {
        let control = UIPageControl()
        control.isUserInteractionEnabled = false
        control.backgroundStyle = .minimal
        control.allowsContinuousInteraction = false
        return control
    }

    func updateUIView(_ control: UIPageControl, context: Context) {
        control.numberOfPages = max(count, 1)
        control.currentPage = current
    }
}
