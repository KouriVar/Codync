import SwiftUI
import UIKit

/// Remix Icon 4.9.1 (Apache-2.0), shipped as one font file plus its codepoint table.
/// Use `RemixIcon("chat-3-line", size: 17)` anywhere an SF Symbol used to be.
public enum RemixFont {
    /// name -> hex codepoint, loaded once from the bundled JSON.
    private static let codepoints: [String: String] = {
        guard let url = Bundle.main.url(forResource: "remixicon-codepoints", withExtension: "json"),
              let data = try? Data(contentsOf: url),
              let map = try? JSONDecoder().decode([String: String].self, from: data)
        else { return [:] }
        return map
    }()

    /// The glyph character for an icon name like "chat-3-line"; empty when the name is unknown.
    public static func glyph(_ name: String) -> String {
        guard let hex = codepoints[name],
              let code = UInt32(hex, radix: 16),
              let scalar = Unicode.Scalar(code)
        else { return "" }
        return String(Character(scalar))
    }

    public static func has(_ name: String) -> Bool { codepoints[name] != nil }

    /// Every bundled icon name (for tooling / pickers).
    public static var allNames: [String] { codepoints.keys.sorted() }
}

/// One Remix Icon, tinted like text and sized like a symbol.
public struct RemixIcon: View {
    let name: String
    var size: CGFloat
    var weight: Font.Weight?

    public init(_ name: String, size: CGFloat = 17, weight: Font.Weight? = nil) {
        self.name = name
        self.size = size
        self.weight = weight
    }

    public var body: some View {
        Text(RemixFont.glyph(name))
            .font(.custom("remixicon", size: size))
            .fontWeight(weight)
            .lineLimit(1)
            .fixedSize()
            .accessibilityHidden(true)
    }
}


/// SF Symbol -> Remix Icon name, for code that still passes a `systemImage:` string
/// (IconButton, menu items, dynamic labels). Anything not listed keeps the SF Symbol.
public enum RemixSymbolMap {
    public static let remixes: [String: String] = [
        "apple.logo": "apple-fill",
        "arrow.clockwise": "refresh-line",
        "arrow.counterclockwise": "restart-line",
        "arrow.down": "arrow-down-line",
        "arrow.down.circle": "arrow-down-circle-line",
        "arrow.down.circle.fill": "arrow-down-circle-fill",
        "arrow.left.arrow.right": "arrow-left-right-line",
        "arrow.right": "arrow-right-line",
        "arrow.triangle.2.circlepath": "refresh-line",
        "arrow.triangle.branch": "git-branch-line",
        "arrow.turn.down.right": "corner-down-right-line",
        "arrow.up": "arrow-up-line",
        "arrow.up.right": "arrow-right-up-line",
        "battery.100percent": "battery-fill",
        "battery.75percent": "battery-low-fill",
        "book.pages": "book-open-line",
        "books.vertical": "book-2-line",
        "brain": "brain-line",
        "bubble.left.and.bubble.right": "chat-3-line",
        "calendar": "calendar-line",
        "camera.fill": "camera-fill",
        "chart.bar": "bar-chart-line",
        "checklist": "list-check",
        "checkmark": "check-line",
        "checkmark.circle.fill": "checkbox-circle-fill",
        "checkmark.seal": "verified-badge-line",
        "chevron.down": "arrow-down-s-line",
        "chevron.left": "arrow-left-s-line",
        "chevron.right": "arrow-right-s-line",
        "chevron.up": "arrow-up-s-line",
        "clock": "time-line",
        "clock.arrow.circlepath": "history-line",
        "cloud": "cloud-line",
        "cloud.sun.fill": "sun-cloudy-fill",
        "cursorarrow.motionlines": "cursor-line",
        "desktopcomputer": "computer-line",
        "desktopcomputer.trianglebadge.exclamationmark": "computer-line",
        "doc.text": "file-text-line",
        "ellipsis": "more-line",
        "exclamationmark": "error-warning-line",
        "exclamationmark.circle": "error-warning-line",
        "exclamationmark.circle.fill": "error-warning-fill",
        "exclamationmark.triangle.fill": "alert-fill",
        "eye": "eye-line",
        "figure.run": "run-line",
        "flask.fill": "flask-fill",
        "folder": "folder-line",
        "folder.badge.gearshape": "folder-settings-line",
        "hand.raised": "hand",
        "hand.raised.fill": "hand",
        "info.circle": "information-line",
        "key": "key-line",
        "key.fill": "key-fill",
        "laptopcomputer": "macbook-line",
        "lock.fill": "lock-fill",
        "lock.rectangle": "lock-line",
        "lock.shield": "shield-check-line",
        "magnifyingglass": "search-line",
        "paperclip": "attachment-line",
        "pencil": "pencil-line",
        "person.2": "team-line",
        "person.crop.circle.badge.checkmark": "user-follow-line",
        "person.crop.circle.badge.exclamationmark": "user-unfollow-line",
        "person.fill": "user-fill",
        "photo": "image-line",
        "pin.fill": "pushpin-fill",
        "play.circle.fill": "play-circle-fill",
        "plus": "add-line",
        "plus.circle": "add-circle-line",
        "puzzlepiece.extension": "puzzle-line",
        "qrcode.viewfinder": "qr-scan-line",
        "safari": "global-line",
        "shippingbox": "inbox-archive-line",
        "slider.horizontal.3": "equalizer-line",
        "square.and.arrow.up": "share-forward-line",
        "square.grid.2x2": "grid-line",
        "star.fill": "star-fill",
        "stop.fill": "stop-fill",
        "terminal": "terminal-line",
        "text.bubble": "chat-1-line",
        "trash": "delete-bin-line",
        "waveform": "voiceprint-line",
        "wifi": "wifi-line",
        "wifi.exclamationmark": "signal-wifi-error-line",
        "wifi.slash": "wifi-off-line",
        "xmark": "close-line",
        "xmark.circle": "close-circle-line",
        "xmark.circle.fill": "close-circle-fill"
    ]

    public static func remix(for systemImage: String) -> String? { remixes[systemImage] }
}


public extension RemixFont {
    /// The glyph rendered into a template image, so toolbars lay it out like an SF Symbol
    /// (a plain Text-based icon keeps its font advance width and widens the glass button).
    static func image(_ name: String, size: CGFloat = 20) -> UIImage? {
        let glyph = glyph(name)
        guard !glyph.isEmpty else { return nil }
        let font = UIFont(name: "remixicon", size: size) ?? UIFont.systemFont(ofSize: size)
        let text = NSAttributedString(string: glyph, attributes: [.font: font, .foregroundColor: UIColor.black])
        let bounds = text.boundingRect(with: CGSize(width: size * 2, height: size * 2),
                                       options: [.usesLineFragmentOrigin, .usesFontLeading], context: nil)
        let canvas = CGSize(width: max(1, ceil(bounds.width)), height: max(1, ceil(bounds.height)))
        let renderer = UIGraphicsImageRenderer(size: canvas)
        let image = renderer.image { _ in text.draw(at: CGPoint(x: -bounds.minX, y: -bounds.minY)) }
        return image.withRenderingMode(.alwaysTemplate)
    }
}

/// A Remix glyph as a `View` that sizes like an image (for toolbars and menus).
public struct RemixImage: View {
    let name: String
    var size: CGFloat

    public init(_ name: String, size: CGFloat = 20) {
        self.name = name
        self.size = size
    }

    public var body: some View {
        if let image = RemixFont.image(name, size: size) {
            Image(uiImage: image).renderingMode(.template).resizable().scaledToFit()
                .frame(width: size, height: size)
        } else {
            RemixIcon(name, size: size)
        }
    }
}
