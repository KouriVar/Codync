import Foundation
import UIKit

/// How strongly the app taps back. "Off" silences every impact the app makes.
public enum HapticsLevel: Int, CaseIterable, Identifiable, Sendable {
    case off = 0
    case light
    case medium
    case strong
    case strongest

    public var id: Int { rawValue }

    public var title: String {
        switch self {
        case .off: return "关"
        case .light: return "轻"
        case .medium: return "中"
        case .strong: return "强"
        case .strongest: return "很强"
        }
    }

    var impactStyle: UIImpactFeedbackGenerator.FeedbackStyle? {
        switch self {
        case .off: return nil
        case .light: return .light
        case .medium: return .medium
        case .strong: return .heavy
        case .strongest: return .rigid
        }
    }
}

/// One place every impact goes through, so Settings → 触感 governs the whole app.
public enum Haptics {
    public static let storageKey = "hapticsLevel"

    public static var level: HapticsLevel {
        // Absent means the default, not .off (integer(forKey:) would return 0).
        guard UserDefaults.standard.object(forKey: storageKey) != nil else { return .medium }
        return HapticsLevel(rawValue: UserDefaults.standard.integer(forKey: storageKey)) ?? .medium
    }

    public static func impact() {
        play(level)
    }

    /// A success/warning/error notification still follows the chosen strength.
    public static func notification() {
        play(level)
    }

    /// Previewing a level in Settings plays it immediately.
    public static func preview(_ level: HapticsLevel) {
        play(level)
    }

    private static func play(_ level: HapticsLevel) {
        guard let style = level.impactStyle else { return }
        UIImpactFeedbackGenerator(style: style).impactOccurred()
    }
}
