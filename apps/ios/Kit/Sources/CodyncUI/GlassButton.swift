import CodyncKit
import SwiftUI

/// Every round control's geometry, in one place: four sizes, one shape, three press depths.
/// Change a number here and every button in the app follows.
public enum ControlMetrics {
    /// The five circle sizes. `icon` is the toolbar/list default, `compact` the floating overlays and
    /// the small circles, `bar` the bottom input bars (the conversation's composer and the home's
    /// search field with its voice button), `micro` the little remove badges, `large` only the camera
    /// shutters.
    public enum Size: CaseIterable, Sendable {
        case micro, compact, icon, bar, large

        /// The circle's diameter.
        public var side: CGFloat {
            switch self {
            case .micro: 24
            case .compact: 36
            case .icon: 44
            case .bar: 48
            case .large: 64
            }
        }

        /// The glyph that fills it when the caller does not name one.
        public var glyph: CGFloat {
            switch self {
            case .micro: 14
            case .compact: 18
            case .icon: 24
            case .bar: 24
            case .large: 26
            }
        }

        /// Apple's 44pt minimum: a smaller circle still gets a full-size tap target.
        public var hitTarget: CGFloat { max(44, side) }
    }

    /// The shape round controls are drawn in (a circle, by 穗's call). The one place to change it.
    public enum Shape: Sendable {
        case circle
        case roundedRectangle(CGFloat)

        public func anyShape(side: CGFloat) -> AnyShape {
            switch self {
            case .circle: AnyShape(Circle())
            case let .roundedRectangle(radius): AnyShape(RoundedRectangle(cornerRadius: radius, style: .continuous))
            }
        }
    }

    /// The shape every round control uses.
    public static let shape: Shape = .circle

    /// How far a press squeezes.
    public enum Press: Sendable {
        /// The app's 0.98.
        case standard
        /// 0.92, the voice sheet's deeper squeeze.
        case deep
        /// No feedback at all (the buttons that never had any).
        case none

        public var scale: CGFloat? {
            switch self {
            case .standard: Motion.pressScale
            case .deep: 0.92
            case .none: nil
            }
        }
    }
}

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
    var size: ControlMetrics.Size = .icon
    /// Overrides `size.glyph` when the glyph is not the usual one for that circle.
    var glyphSize: CGFloat?
    var weight: Font.Weight = .medium
    var ink: Color = Palette.text
    var style: Style = .glass()
    var press: ControlMetrics.Press = .standard
    let action: () -> Void

    public init(_ title: String, glyph: Glyph, size: ControlMetrics.Size = .icon,
                glyphSize: CGFloat? = nil, weight: Font.Weight = .medium, ink: Color = Palette.text,
                style: Style = .glass(), press: ControlMetrics.Press = .standard,
                action: @escaping () -> Void) {
        self.title = title
        self.glyph = glyph
        self.size = size
        self.glyphSize = glyphSize
        self.weight = weight
        self.ink = ink
        self.style = style
        self.press = press
        self.action = action
    }

    public var body: some View {
        if let scale = press.scale {
            button.buttonStyle(PressScale(scale: scale))
        } else {
            button.buttonStyle(.plain)
        }
    }

    private var button: some View {
        Button(action: action) {
            GlassGlyph(glyph: glyph, size: size, glyphSize: glyphSize, weight: weight, ink: ink, style: style)
        }
        .accessibilityLabel(Text(title))
        .help(title)
    }
}

/// The circle on its own, for the controls that own their `Button` or `Menu` (the composer's "+",
/// the avatars' edit pencil, a menu's label).
public struct GlassGlyph: View {
    let glyph: GlassButton.Glyph
    var size: ControlMetrics.Size = .icon
    /// Overrides `size.glyph` when the glyph is not the usual one for that circle.
    var glyphSize: CGFloat?
    var weight: Font.Weight = .medium
    var ink: Color = Palette.text
    var style: GlassButton.Style = .glass()

    /// The diameter (from `ControlMetrics`) and the glyph size (its usual one unless overridden).
    private var side: CGFloat { size.side }
    private var drawnSize: CGFloat { glyphSize ?? size.glyph }

    public init(glyph: GlassButton.Glyph, size: ControlMetrics.Size = .icon, glyphSize: CGFloat? = nil,
                weight: Font.Weight = .medium, ink: Color = Palette.text,
                style: GlassButton.Style = .glass()) {
        self.glyph = glyph
        self.size = size
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
                .contentShape(ControlMetrics.shape.anyShape(side: side))
                .glass(in: ControlMetrics.shape.anyShape(side: side), interactive: true, tint: tint)
        case let .filled(fill, fillInk):
            glyphView
                .foregroundStyle(fillInk)
                .frame(width: side, height: side)
                .background(fill, in: ControlMetrics.shape.anyShape(side: side))
                .contentShape(ControlMetrics.shape.anyShape(side: side))
        }
    }

    @ViewBuilder private var glyphView: some View {
        switch glyph {
        case let .remix(name):
            RemixIcon(name, size: drawnSize, weight: weight)
        case let .symbol(name):
            Image(systemName: name).font(.system(size: drawnSize, weight: weight))
        }
    }
}
