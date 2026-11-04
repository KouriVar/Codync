import CodyncKit
import CodyncUI
import SwiftUI

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

    /// A card is this much of the screen's width; the rest is the gap to its neighbours.
    static let miniScale: CGFloat = 0.86
    /// Between two cards.
    private static let gap: CGFloat = 12
    /// The card's own corner.
    private static let corner: CGFloat = 28

    var body: some View {
        GeometryReader { proxy in
            let width = proxy.size.width * Self.miniScale
            let height = min(proxy.size.height * 0.62, width * 1.5)
            VStack(spacing: 16) {
                Spacer(minLength: 8)
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

    /// One card: the face's real list, laid out at the screen's size and shrunk into a rounded
    /// rectangle. The list itself takes no touches — the card's tap is the only thing that answers.
    private func mini(_ face: HomeFace, screen: CGSize, cardWidth: CGFloat, cardHeight: CGFloat) -> some View {
        let content = card(face)
            .frame(width: screen.width, height: screen.height)
            .scaleEffect(cardWidth / max(screen.width, 1), anchor: .topLeading)
            .allowsHitTesting(false)
        return content
            .frame(width: cardWidth, height: cardHeight, alignment: .topLeading)
            .clipShape(RoundedRectangle(cornerRadius: Self.corner, style: .continuous))
            .overlay {
                RoundedRectangle(cornerRadius: Self.corner, style: .continuous)
                    .strokeBorder(Palette.text.opacity(0.08), lineWidth: 1)
            }
            .shadow(color: .black.opacity(0.18), radius: 18, y: 10)
            .contentShape(RoundedRectangle(cornerRadius: Self.corner, style: .continuous))
    }

    private var dots: some View {
        HStack(spacing: 8) {
            ForEach(faces) { face in
                Capsule()
                    .fill(face == centered ? Palette.text : Palette.secondary.opacity(0.35))
                    .frame(width: face == centered ? 18 : 7, height: 7)
            }
        }
        .frame(height: 18)
        .animation(Motion.reduced(Motion.layout, reduceMotion), value: centered)
        .accessibilityHidden(true)
    }
}
