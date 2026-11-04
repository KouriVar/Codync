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
    let card: (HomeFace) -> AnyView
    /// A card was tapped, or the fingers spread: show that face, full screen.
    let commit: (HomeFace) -> Void

    @Environment(\.accessibilityReduceMotion) private var reduceMotion
    @State private var scrolled: HomeFace?

    /// A card is this much of the screen's width — the wallpaper picker's proportion, with about
    /// 15% of the neighbours showing at each edge.
    static let cardScale: CGFloat = 0.70
    /// The phone screen's own corner, before the shrink. iOS exposes no number for it; this is the
    /// current iPhone display radius.
    static let screenCorner: CGFloat = 55
    /// Between two cards.
    private static let gap: CGFloat = 12
    /// The glass rim drawn around the mini screen.
    private static let rim: CGFloat = 4

    var body: some View {
        GeometryReader { proxy in
            let width = proxy.size.width * Self.cardScale
            // The screen's own aspect: the card is the whole page, so nothing is cropped.
            let height = width * (proxy.size.height / max(proxy.size.width, 1))
            VStack(spacing: 14) {
                Spacer(minLength: 0)
                Text(centered.title)
                    .font(.title3.weight(.semibold))
                    .foregroundStyle(Palette.text)
                    .contentTransition(.opacity)
                    .animation(Motion.reduced(Motion.fade, reduceMotion), value: centered)
                pager(screen: proxy.size, cardWidth: width, cardHeight: height)
                dots
                Spacer(minLength: 16)
            }
            .frame(maxWidth: .infinity, maxHeight: .infinity)
        }
        .background(Palette.background)
        .onAppear { scrolled = centered }
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

    private func pager(screen: CGSize, cardWidth: CGFloat, cardHeight: CGFloat) -> some View {
        ScrollView(.horizontal) {
            LazyHStack(spacing: Self.gap) {
                ForEach(faces) { face in
                    mini(face, screen: screen, cardWidth: cardWidth, cardHeight: cardHeight)
                        .id(face)
                        .onTapGesture { commit(face) }
                }
            }
            .scrollTargetLayout()
        }
        .scrollIndicators(.hidden)
        .scrollTargetBehavior(.viewAligned)
        .scrollPosition(id: $scrolled)
        // The first and last card centre like the ones between them.
        .contentMargins(.horizontal, (screen.width - cardWidth) / 2, for: .scrollContent)
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
    private func mini(_ face: HomeFace, screen: CGSize, cardWidth: CGFloat, cardHeight: CGFloat) -> some View {
        let scale = cardWidth / max(screen.width, 1)
        let corner = Self.screenCorner * scale
        let shape = RoundedRectangle(cornerRadius: corner, style: .continuous)
        let content = card(face)
            .frame(width: screen.width, height: screen.height)
            .scaleEffect(scale, anchor: .topLeading)
            .allowsHitTesting(false)
            .frame(width: cardWidth, height: cardHeight, alignment: .topLeading)
            .clipShape(shape)
            .overlay { shape.strokeBorder(Palette.text.opacity(0.10), lineWidth: 0.5) }
        return content
            .padding(Self.rim)
            .glass(in: RoundedRectangle(cornerRadius: corner + Self.rim, style: .continuous))
            .shadow(color: .black.opacity(0.22), radius: 20, y: 12)
            .contentShape(RoundedRectangle(cornerRadius: corner + Self.rim, style: .continuous))
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
