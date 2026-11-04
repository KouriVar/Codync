import CodyncKit
import SwiftUI

/// A glyph in a circle: the app's one round button.
///
/// It exists because the same circle was hand-rolled in half a dozen places — glass on the camera
/// page, material under the screen viewer's buttons, an unlabelled glass circle behind the
/// composer's "+". Everything now goes through here, so a change to the circle is a change in one
/// file.
///
/// `style` picks the fill (glass floating over content, or a solid fill for send/hang up/remove),
/// `press` the squeeze depth — `nil` draws no press feedback, for the buttons that never had any.
public struct GlassButton: View {
    /// What the glyph is: one of the app's Remix icons, or an SF Symbol.
    public enum Glyph {
        case remix(String)
        case symbol(String)
    }

    /// The circle's fill.
    public enum Style {
        /// Liquid Glass.
        case glass(tint: Color? = nil)
        /// A solid fill, with the glyph in `ink` on top.
        case filled(Color, ink: Color)
    }

    let title: String
    let glyph: Glyph
    var side: CGFloat
    var glyphSize: CGFloat
    var weight: Font.Weight = .medium
    var ink: Color = Palette.text
    var style: Style = .glass()
    var press: CGFloat? = Motion.pressScale
    let action: () -> Void

    public init(_ title: String, glyph: Glyph, side: CGFloat, glyphSize: CGFloat,
                weight: Font.Weight = .medium, ink: Color = Palette.text,
                style: Style = .glass(), press: CGFloat? = Motion.pressScale,
                action: @escaping () -> Void) {
        self.title = title
        self.glyph = glyph
        self.side = side
        self.glyphSize = glyphSize
        self.weight = weight
        self.ink = ink
        self.style = style
        self.press = press
        self.action = action
    }

    public var body: some View {
        if let press {
            button.buttonStyle(PressScale(scale: press))
        } else {
            button.buttonStyle(.plain)
        }
    }

    private var button: some View {
        Button(action: action) {
            GlassGlyph(glyph: glyph, side: side, glyphSize: glyphSize, weight: weight, ink: ink, style: style)
        }
        .accessibilityLabel(Text(title))
        .help(title)
    }
}

/// The circle on its own, for the controls that own their `Button` or `Menu` (the composer's "+",
/// the avatars' edit pencil, a menu's label).
public struct GlassGlyph: View {
    let glyph: GlassButton.Glyph
    let side: CGFloat
    let glyphSize: CGFloat
    var weight: Font.Weight = .medium
    var ink: Color = Palette.text
    var style: GlassButton.Style = .glass()

    public init(glyph: GlassButton.Glyph, side: CGFloat, glyphSize: CGFloat,
                weight: Font.Weight = .medium, ink: Color = Palette.text,
                style: GlassButton.Style = .glass()) {
        self.glyph = glyph
        self.side = side
        self.glyphSize = glyphSize
        self.weight = weight
        self.ink = ink
        self.style = style
    }

    public var body: some View {
        switch style {
        case let .glass(tint):
            glyphView
                .foregroundStyle(ink)
                .frame(width: side, height: side)
                .contentShape(Circle())
                .glass(in: Circle(), interactive: true, tint: tint)
        case let .filled(fill, fillInk):
            glyphView
                .foregroundStyle(fillInk)
                .frame(width: side, height: side)
                .background(fill, in: Circle())
                .contentShape(Circle())
        }
    }

    @ViewBuilder private var glyphView: some View {
        switch glyph {
        case let .remix(name):
            RemixIcon(name, size: glyphSize, weight: weight)
        case let .symbol(name):
            Image(systemName: name).font(.system(size: glyphSize, weight: weight))
        }
    }
}
