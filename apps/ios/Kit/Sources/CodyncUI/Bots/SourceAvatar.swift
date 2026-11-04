import CodyncKit
import SwiftUI

/// Which kind of source a conversation came from — only what its dot needs to know. Coe's own bots
/// carry none; DSH 编程 is blue, DS Bot is orange.
public enum SourceKind: String, Sendable, CaseIterable {
    case coe
    case dsBot
    case dsh

    /// The dot at the avatar's bottom-right.
    public var dot: Color? {
        switch self {
        case .coe: return nil
        case .dsBot: return Palette.sourceOrange
        case .dsh: return Palette.sourceBlue
        }
    }

    /// 8pt beside a roster avatar, 6pt beside the 24pt face on a conversation's title bar.
    public func dotSize(beside avatar: CGFloat) -> CGFloat { avatar < 32 ? 6 : 8 }
}

/// The face each source shows: one shape and one colour, kept on this device and shared by every
/// conversation from that source. Edited in Settings → 来源外观.
public enum SourceAppearance {
    public static var defaultShape: String { AvatarPalette.shapes.first ?? "blob" }
    public static var defaultColor: String { AvatarPalette.colors.first?.id ?? "black" }

    public static func shapeKey(_ kind: SourceKind) -> String { "sourceShape.\(kind.rawValue)" }
    public static func colorKey(_ kind: SourceKind) -> String { "sourceColor.\(kind.rawValue)" }

    public static func shape(_ kind: SourceKind) -> String {
        UserDefaults.standard.string(forKey: shapeKey(kind)) ?? defaultShape
    }

    public static func color(_ kind: SourceKind) -> String {
        UserDefaults.standard.string(forKey: colorKey(kind)) ?? defaultColor
    }
}

/// A conversation's source face with its dot. The same view is used by the home's rows, a
/// conversation's title bar and the working line, so the three can never disagree.
public struct SourceAvatar: View {
    let kind: SourceKind
    let size: CGFloat

    @AppStorage private var shape: String
    @AppStorage private var color: String

    public init(_ kind: SourceKind, size: CGFloat) {
        self.kind = kind
        self.size = size
        _shape = AppStorage(wrappedValue: SourceAppearance.defaultShape, SourceAppearance.shapeKey(kind))
        _color = AppStorage(wrappedValue: SourceAppearance.defaultColor, SourceAppearance.colorKey(kind))
    }

    public var body: some View {
        CharacterAvatar(shape: shape, color: color, size: size)
            .overlay(alignment: .bottomTrailing) {
                if let dot = kind.dot {
                    SourceDot(color: dot, size: kind.dotSize(beside: size))
                }
            }
            .frame(width: size, height: size)
            .accessibilityHidden(true)
    }
}

/// The dot itself: a small mark ringed in the page's background, in the corner the roster's status
/// dot uses.
public struct SourceDot: View {
    let color: Color
    let size: CGFloat

    public init(color: Color, size: CGFloat) {
        self.color = color
        self.size = size
    }

    public var body: some View {
        Circle()
            .fill(color)
            .frame(width: size, height: size)
            .overlay(Circle().stroke(Palette.background, lineWidth: 1.5))
            .accessibilityHidden(true)
    }
}
