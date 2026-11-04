import CodyncKit
import SwiftUI

/// One confirmation line for the glass pill: already-localized text, an optional icon, an optional tap.
public struct GlassToastItem: Identifiable, Equatable {
    public let id: UUID
    public var icon: String?
    public var text: String
    public var action: (@MainActor () -> Void)?

    public init(id: UUID = UUID(), icon: String? = nil, text: String, action: (@MainActor () -> Void)? = nil) {
        self.id = id
        self.icon = icon
        self.text = text
        self.action = action
    }

    // By id only: the tap closure is not comparable, and one id is one toast.
    public static func == (lhs: Self, rhs: Self) -> Bool { lhs.id == rhs.id }
}

/// iOS's own "Pasted from Safari" pill: the capsule itself, without any placement.
///
/// Its height is the toolbar row's — the same 44pt as the buttons at either end of the navigation bar,
/// so a pill placed on that row lines up with them. Long text truncates rather than growing the pill.
public struct GlassToast: View {
    let item: GlassToastItem

    public init(_ item: GlassToastItem) { self.item = item }

    public var body: some View {
        HStack(spacing: 10) {
            if let icon = item.icon { RemixIcon(icon, size: 20) }
            Text(item.text)
                .font(.subheadline)
                .lineLimit(1)
                .truncationMode(.tail)
        }
        .foregroundStyle(Palette.text)
        .padding(.horizontal, 18)
        .frame(height: ControlMetrics.Size.icon.side)
        .glass(in: Capsule())
        .shadow(color: .black.opacity(0.12), radius: 12, y: 4)
    }
}

public extension View {
    /// Shows `item` as a pill on the navigation bar's row — level with the buttons at either end of it
    /// — until it is tapped or two seconds pass. `topPadding` is measured from that row's top.
    func glassToast(_ item: Binding<GlassToastItem?>, topPadding: CGFloat = 0) -> some View {
        modifier(GlassToastPresenter(item: item, topPadding: topPadding))
    }
}

private struct GlassToastPresenter: ViewModifier {
    @Binding var item: GlassToastItem?
    let topPadding: CGFloat
    @Environment(\.accessibilityReduceMotion) private var reduceMotion
    /// How wide the row is: what the pill may use without reaching the toolbar's buttons.
    @State private var width: CGFloat = 0

    /// 16pt at each edge, then the 44pt button and 8pt of air on both sides: the pill stays between
    /// the avatar on the left and the "+" on the right, and truncates whatever doesn't fit.
    private var maxPillWidth: CGFloat? {
        guard width > 0 else { return nil }
        return max(0, width - 2 * (16 + ControlMetrics.Size.icon.side + 8))
    }

    func body(content: Content) -> some View {
        content
            .onGeometryChange(for: CGFloat.self) { $0.size.width } action: { width = $0 }
            // The overlay's frame already stops at the safe area, so the pill drops below the status
            // bar — the very row the navigation bar's own buttons are laid out in.
            .overlay(alignment: .top) {
                if let toast = item {
                    // The Spacer below takes the rest of the height without drawing, so only the
                    // pill itself takes touches and the screen under it stays usable.
                    VStack(spacing: 0) {
                        GlassToast(toast)
                            .frame(maxWidth: maxPillWidth)
                            .contentShape(Capsule())
                            .onTapGesture { tap(toast) }
                            .accessibilityElement(children: .ignore)
                            .accessibilityAddTraits(toast.action == nil ? [] : .isButton)
                            .accessibilityLabel(Text(toast.text))
                            .transition(.move(edge: .top).combined(with: .opacity))
                        Spacer(minLength: 0)
                    }
                    .padding(.top, topPadding)
                    .padding(.horizontal, 16)
                    .zIndex(1)
                }
            }
            .animation(Motion.reduced(Motion.layout, reduceMotion), value: item?.id)
            // Restarting on the id and stopping on disappear is exactly the auto-dismiss lifetime.
            .task(id: item?.id) {
                guard item != nil else { return }
                do { try await Task.sleep(for: .seconds(2)) } catch { return }
                dismiss()
            }
    }

    private func tap(_ toast: GlassToastItem) {
        toast.action?()
        // The handler may have put up another pill; only clear what this tap was on.
        guard item?.id == toast.id else { return }
        dismiss()
    }

    private func dismiss() {
        withAnimation(Motion.reduced(Motion.layout, reduceMotion)) { item = nil }
    }
}
