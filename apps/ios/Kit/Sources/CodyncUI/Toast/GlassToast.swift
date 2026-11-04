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
        .frame(height: 46)
        .glass(in: Capsule())
        .shadow(color: .black.opacity(0.12), radius: 12, y: 4)
    }
}

public extension View {
    /// Shows `item` as a pill at the top until it is tapped or two seconds pass.
    func glassToast(_ item: Binding<GlassToastItem?>, topPadding: CGFloat = 10) -> some View {
        modifier(GlassToastPresenter(item: item, topPadding: topPadding))
    }
}

private struct GlassToastPresenter: ViewModifier {
    @Binding var item: GlassToastItem?
    let topPadding: CGFloat
    @Environment(\.accessibilityReduceMotion) private var reduceMotion

    func body(content: Content) -> some View {
        content
            // The overlay's frame already stops at the safe area, so the pill drops below the status bar.
            .overlay(alignment: .top) {
                if let toast = item {
                    // The Spacer below takes the rest of the height without drawing, so only the
                    // pill itself takes touches and the screen under it stays usable.
                    VStack(spacing: 0) {
                        GlassToast(toast)
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
