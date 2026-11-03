import SwiftUI
import UIKit
import CodyncKit

/// What a custom long-press menu shows: a scaled preview card and the menu rows.
public struct CardMenuState: Identifiable {
    public let id = UUID()
    public let preview: AnyView
    public let items: [MenuItem]
    public let anchor: CGRect
    public init(preview: AnyView, items: [MenuItem], anchor: CGRect) {
        self.preview = preview
        self.items = items
        self.anchor = anchor
    }
}

/// A hand-drawn long-press menu that matches the iOS glass menu's corner radius (34) for both the
/// preview card and the panel, drawn with material so it reads as the same glass. Submenus push.
public struct CardMenuOverlay: View {
    let state: CardMenuState
    let dismiss: () -> Void
    @State private var appear = false
    @State private var stack: [[MenuItem]] = []

    public init(state: CardMenuState, dismiss: @escaping () -> Void) {
        self.state = state
        self.dismiss = dismiss
    }

    private var current: [MenuItem] { stack.last ?? state.items }

    public var body: some View {
        GeometryReader { geo in
            ZStack(alignment: .topLeading) {
                Color.black.opacity(0.16)
                    .ignoresSafeArea()
                    .contentShape(Rectangle())
                    .onTapGesture { dismiss() }

                VStack(alignment: .leading, spacing: 12) {
                    state.preview
                        .background(.regularMaterial, in: RoundedRectangle(cornerRadius: 34, style: .continuous))
                        .clipShape(RoundedRectangle(cornerRadius: 34, style: .continuous))
                        .shadow(color: .black.opacity(0.18), radius: 24, y: 12)
                        .scaleEffect(appear ? 1 : 0.92, anchor: .topLeading)
                        .opacity(appear ? 1 : 0)

                    panel
                        .scaleEffect(appear ? 1 : 0.92, anchor: .topLeading)
                        .opacity(appear ? 1 : 0)
                }
                .frame(width: min(320, geo.size.width - 40), alignment: .leading)
                .padding(.leading, 20)
                .offset(y: max(8, min(state.anchor.minY - 6, geo.size.height - 360)))
            }
        }
        .onAppear {
            withAnimation(.spring(response: 0.3, dampingFraction: 0.85)) { appear = true }
        }
    }

    private var panel: some View {
        VStack(alignment: .leading, spacing: 0) {
            if !stack.isEmpty { backRow }
            ForEach(Array(current.enumerated()), id: \.element.id) { index, item in
                if item.divider && index > 0 {
                    Divider().padding(.horizontal, 16)
                }
                menuRow(item)
            }
        }
        .padding(.vertical, 6)
        .frame(maxWidth: .infinity, alignment: .leading)
        .background(.regularMaterial, in: RoundedRectangle(cornerRadius: 34, style: .continuous))
        .clipShape(RoundedRectangle(cornerRadius: 34, style: .continuous))
        .shadow(color: .black.opacity(0.18), radius: 24, y: 12)
    }

    private func menuRow(_ item: MenuItem) -> some View {
        Button {
            if !item.submenu.isEmpty {
                UIImpactFeedbackGenerator(style: .light).impactOccurred()
                withAnimation(.spring(response: 0.28, dampingFraction: 0.9)) { stack.append(item.submenu) }
            } else {
                UISelectionFeedbackGenerator().selectionChanged()
                item.action()
                dismiss()
            }
        } label: {
            HStack(spacing: 14) {
                if let image = item.image {
                    image.frame(width: 22, height: 22)
                } else if let icon = item.icon {
                    Image(systemName: icon).frame(width: 22)
                }
                Text(item.shownTitle())
                Spacer(minLength: 0)
                if !item.submenu.isEmpty {
                    Image(systemName: "chevron.right").font(.footnote.weight(.semibold)).foregroundStyle(.tertiary)
                }
            }
            .foregroundStyle(item.destructive ? Color.red : Color.primary)
            .padding(.horizontal, 18)
            .padding(.vertical, 12)
            .frame(maxWidth: .infinity, alignment: .leading)
            .contentShape(Rectangle())
        }
        .buttonStyle(.plain)
    }

    private var backRow: some View {
        Button {
            UIImpactFeedbackGenerator(style: .light).impactOccurred()
            withAnimation(.spring(response: 0.28, dampingFraction: 0.9)) { _ = stack.popLast() }
        } label: {
            HStack(spacing: 14) {
                Image(systemName: "chevron.left").frame(width: 22)
                Text(L10n.tr("Back"))
                Spacer(minLength: 0)
            }
            .foregroundStyle(Color.primary)
            .padding(.horizontal, 18)
            .padding(.vertical, 12)
            .contentShape(Rectangle())
        }
        .buttonStyle(.plain)
    }
}
