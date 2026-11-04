import CodyncKit
import SwiftUI

/// The three conversation sources the home mixes: Codync's own bots (Coe), bots whose non-empty
/// `command` runs a custom ACP bridge (DS Bot), and the sessions DSHKit pulls from the paired
/// DeepSeek Harness gateway (DSH 对话).
enum HomeSource: String, CaseIterable, Identifiable, Sendable {
    case coe
    case dsBot
    case dsh

    var id: String { rawValue }

    var title: String {
        switch self {
        case .coe: return "Coe"
        case .dsBot: return "DS Bot"
        case .dsh: return "DSH 对话"
        }
    }

    /// The avatar badge: Coe shows none, DS Bot a "D", DSH a terminal glyph.
    var badge: HomeBadge? {
        switch self {
        case .coe: return nil
        case .dsBot: return .letter("D")
        case .dsh: return .symbol("terminal")
        }
    }

    var badgeColor: Color {
        switch self {
        case .coe: return Color(hex: 0x4C7DFF)
        case .dsBot: return Color(hex: 0x22B573)
        case .dsh: return Palette.warning
        }
    }

    /// Which source a Codync bot belongs to. A bot with a non-empty `command` runs a custom ACP
    /// program (DS Bot); everything else, including groups (which have no command), is Coe.
    static func of(bot: Bot) -> HomeSource {
        if bot.isGroup { return .coe }
        if let command = bot.command?.trimmingCharacters(in: .whitespacesAndNewlines), !command.isEmpty {
            return .dsBot
        }
        return .coe
    }
}

/// What a source badge draws inside its circle.
enum HomeBadge {
    case letter(String)
    case symbol(String)
}

/// The home's two list layouts, switched in Settings → 调试.
enum HomeLayout: String, CaseIterable, Identifiable {
    case mixed
    case paged

    var id: String { rawValue }
    var title: String { self == .mixed ? "混排" : "分页" }
}

/// `@AppStorage` keys and the default source selection. Stored as a comma-joined raw-value string;
/// the default is Coe only.
enum HomeSourcePrefs {
    static let sourcesKey = "homeEnabledSources"
    static let layoutKey = "homeLayout"
    static let defaultRaw = HomeSource.coe.rawValue

    static func enabled(from raw: String) -> Set<HomeSource> {
        let set = Set(raw.split(separator: ",").compactMap { HomeSource(rawValue: String($0)) })
        // Never allow an empty selection: fall back to the default.
        return set.isEmpty ? [.coe] : set
    }

    static func raw(_ sources: Set<HomeSource>) -> String {
        // Stable order so the stored value doesn't churn between renders.
        HomeSource.allCases.filter { sources.contains($0) }.map(\.rawValue).joined(separator: ",")
    }
}

/// Which session titles are noise that must not appear on the home. One function, so the rule is
/// easy to change later. Hides only; nothing is deleted.
enum HomeSessionVisibility {
    static func isHidden(title: String, isDSH: Bool) -> Bool {
        let trimmed = title.trimmingCharacters(in: .whitespacesAndNewlines)
        if trimmed.hasPrefix("<bot-profile>") { return true }
        if trimmed.hasPrefix("You keep the memory") { return true }
        // DSH sessions with no title yet (the gateway decodes a blank one as "未命名会话").
        if isDSH && (trimmed.isEmpty || trimmed == "未命名会话") { return true }
        return false
    }
}
