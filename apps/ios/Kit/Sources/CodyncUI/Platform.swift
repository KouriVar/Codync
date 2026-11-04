import CodyncKit
import SwiftUI
import UIKit

enum Pasteboard {
    static func copy(_ text: String?) {
        guard let text else { return }
        UIPasteboard.general.string = text
    }
}

extension View {
    func plainTextInput() -> some View {
        textInputAutocapitalization(.never)
            .autocorrectionDisabled()
    }
}

// MARK: - Glass

/// The app's one glass surface. Everything that used to draw its own `Material`, its own
/// `glassEffect` call or its own `#available(iOS 26)` fork goes through this: Liquid Glass is the
/// deployment target, so there is no material fallback to keep in step any more.
///
/// `shape` decides what it is drawn in; `interactive` asks for the system's own press reaction
/// (buttons and menus on top of it); `tint` colours the glass (the voice sheet's live controls).
struct GlassSurface<S: Shape>: ViewModifier {
    let shape: S
    var interactive = false
    var tint: Color?

    func body(content: Content) -> some View {
        content.glassEffect(glass, in: shape)
    }

    private var glass: Glass {
        let base = tint.map { Glass.regular.tint($0) } ?? .regular
        return interactive ? base.interactive() : base
    }
}

extension View {
    /// Liquid Glass in `shape` (content scrolls visibly underneath).
    func glass(in shape: some Shape, interactive: Bool = false, tint: Color? = nil) -> some View {
        modifier(GlassSurface(shape: shape, interactive: interactive, tint: tint))
    }
}
