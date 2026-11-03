import CodyncKit
import UIKit
import CodyncUI
import SwiftUI

/// Floating home controls, scoped to the roster so a pushed conversation has no bottom bar.
struct HomeBottomBar: View {
    @Binding var searchText: String
    /// Keyboard up: sit just above it; down: keep the 28pt gap to the screen edge.
    @State private var keyboardUp = false
    /// The search field is active: hide the extensions button and turn the camera into Close.
    @State private var searching = false
    @Environment(\.accessibilityReduceMotion) private var reduceMotion
    /// Identities so the glass container can morph elements instead of re-laying them out.
    @Namespace private var glass
    let openCamera: () -> Void
    let openPlugins: () -> Void
    /// One 48pt row for the search capsule and both circles.
    private let iconSize: CGFloat = 24
    private let iconLineWidth: CGFloat = 1.8

    var body: some View {
        GlassEffectContainer(spacing: 12) {
            HStack(spacing: 12) {
                if !searching {
                    Button(action: openPlugins) {
                        RemixIcon("apps-2-line", size: iconSize)
                            .foregroundStyle(Palette.text)
                            .frame(width: 48, height: 48)
                            .glassEffect(.regular.interactive(), in: Circle())
                            // iOS 26's own transition: the circle's glass dissolves with the
                            // container morph instead of a plain removal that stutters.
                            .glassEffectID("extensions", in: glass)
                            .glassEffectTransition(.materialize)
                    }
                    .buttonStyle(.plain)
                    .accessibilityLabel("插件")
                    .help("插件")
                    .transition(.opacity)
                }

                SearchField("搜索", text: $searchText, opaqueBackground: false, active: $searching)
                    .frame(height: 48)
                    .glassEffect(.regular.interactive(), in: Capsule())
                    .glassEffectID("search", in: glass)
                    .submitLabel(.search)
                    .accessibilityLabel("搜索聊天")

                Button(action: searching ? closeSearch : openCamera) {
                    RemixIcon(searching ? "close-line" : "camera-fill", size: iconSize)
                        .foregroundStyle(Palette.text)
                        .frame(width: 48, height: 48)
                        .glassEffect(.regular.interactive(), in: Circle())
                        .glassEffectID("camera", in: glass)
                }
                .buttonStyle(.plain)
                .accessibilityLabel(searching ? "关闭搜索" : "拍照")
                .help(searching ? "关闭搜索" : "拍照")
            }
            .animation(Motion.reduced(.snappy(duration: 0.26), reduceMotion), value: searching)
        }
        // One 16pt margin with the toolbar and the list rows.
        .padding(.horizontal, 16)
        .padding(.top, 10)
        // Match the 12pt spacing between the search field and the two circles.
        .padding(.bottom, keyboardUp ? 12 : 28)
        .ignoresSafeArea(.container, edges: keyboardUp ? [] : .bottom)
        .onReceive(NotificationCenter.default.publisher(for: UIResponder.keyboardWillShowNotification)) { _ in
            keyboardUp = true
        }
        .onReceive(NotificationCenter.default.publisher(for: UIResponder.keyboardWillHideNotification)) { _ in
            keyboardUp = false
        }
    }

    /// The Close button while searching: clear the field and drop the keyboard.
    private func closeSearch() {
        searchText = ""
        searching = false
    }
}

/// A single outlined glyph: font-weight changes must not change its size or spacing.
private struct PluginGlyph: Shape {
    let lineWidth: CGFloat

    func path(in rect: CGRect) -> Path {
        let bounds = rect.insetBy(dx: lineWidth / 2, dy: lineWidth / 2)
        let gap: CGFloat = 3
        let cell = (bounds.width - gap) / 2
        let origins = [
            CGPoint(x: bounds.minX, y: bounds.minY),
            CGPoint(x: bounds.maxX - cell, y: bounds.minY),
            CGPoint(x: bounds.minX, y: bounds.maxY - cell),
        ]
        var path = Path()
        for origin in origins {
            path.addRoundedRect(in: CGRect(origin: origin, size: CGSize(width: cell, height: cell)),
                                cornerSize: CGSize(width: 0.6, height: 0.6))
        }
        let plus = CGRect(x: bounds.maxX - cell, y: bounds.maxY - cell, width: cell, height: cell)
        path.move(to: CGPoint(x: plus.minX, y: plus.midY))
        path.addLine(to: CGPoint(x: plus.maxX, y: plus.midY))
        path.move(to: CGPoint(x: plus.midX, y: plus.minY))
        path.addLine(to: CGPoint(x: plus.midX, y: plus.maxY))
        return path
    }
}
