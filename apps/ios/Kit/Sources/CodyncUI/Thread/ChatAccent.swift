import CodyncKit
import SwiftUI

/// One Bot color for outgoing messages and the composer. Darker fills keep white text readable.
struct ChatAccent {
    private let swatch: AvatarPalette.Swatch

    init(_ id: String?) {
        swatch = AvatarPalette.colors.first { $0.id == id } ?? AvatarPalette.colors[0]
    }

    private var rgb: (Double, Double, Double) {
        (Double((swatch.hex >> 16) & 255) / 255,
         Double((swatch.hex >> 8) & 255) / 255,
         Double(swatch.hex & 255) / 255)
    }

    // Preserve the hue while reducing luminance enough for white message text.
    private var multiplier: Double {
        let (r, g, b) = rgb
        func linear(_ v: Double) -> Double { v <= 0.04045 ? v / 12.92 : pow((v + 0.055) / 1.055, 2.4) }
        func luminance(_ scale: Double) -> Double {
            0.2126 * linear(r * scale) + 0.7152 * linear(g * scale) + 0.0722 * linear(b * scale)
        }
        var scale = 1.0
        while luminance(scale) > 0.18 { scale -= 0.01 }
        return scale
    }

    var fill: Color {
        let (r, g, b) = rgb
        let scale = multiplier
        return Color(red: r * scale, green: g * scale, blue: b * scale)
    }
    var ink: Color { .white }
}
