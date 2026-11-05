import CodyncKit
import SwiftUI

/// The one line under a running turn: the bot's face and a short title that the light sweeps across.
/// The steps themselves are never shown — no folded "thinking for 12s · ran 3 commands" line, no way
/// to open one — so this says only what kind of work is under way, and it disappears when the turn
/// ends.
public struct ConversationStatusLine: View {
    private let title: String
    private let avatar: AnyView

    /// A Codync bot's line: its own face.
    public init(bot: Bot, title: String) {
        self.title = title
        avatar = AnyView(
            CharacterAvatar(bot: bot, size: 24, animated: false)
                .frame(width: 24, height: 24)
                .clipShape(Circle())
        )
    }

    /// Anything without a `Bot` (a DSH gateway): whatever face the page draws.
    public init<Avatar: View>(title: String, @ViewBuilder avatar: () -> Avatar) {
        self.title = title
        self.avatar = AnyView(avatar())
    }

    public var body: some View {
        HStack(spacing: 8) {
            avatar
            ShimmeringText(text: title, startedAt: .now, font: .footnote)
                .lineLimit(1)
            Spacer(minLength: 0)
        }
        // One fixed height, so the row appearing or leaving never moves what is under it.
        .frame(height: 24)
        .padding(.horizontal, 16)
        .padding(.vertical, 6)
        .accessibilityElement(children: .ignore)
        .accessibilityLabel(Text(title))
        .accessibilityAddTraits(.updatesFrequently)
    }
}

/// What a running turn says in one line: the kind of work it is on. Fixed phrases from the step's
/// own type — never the model's words, never a generated title.
public enum WorkingPhrase {
    public static let generic = "在处理"
    public static let thinking = "在想"
    public static let executing = "在跑命令"
    public static let reading = "在看文件"
    public static let editing = "在改代码"

    /// Coe's running steps, the last one being the step under way. `thought`/`tool`/`plan` are the
    /// kinds the host marks as working steps; a tool's `toolKind` says which kind of tool it is.
    public static func title(for steps: [Entry]) -> String {
        guard let step = steps.last else { return generic }
        switch step.kind {
        case "thought":
            return thinking
        case "tool":
            switch step.data.toolKind {
            case "think": return thinking
            case "execute": return executing
            case "read": return reading
            case "edit", "move", "delete": return editing
            default: return generic
            }
        default:
            return generic
        }
    }

    /// Kinds that are working steps and nothing else: the chat keeps their data, it just doesn't draw
    /// them. A non-final `agent` entry stays — that is the bot speaking mid-run, which is content.
    public static func isStepOnly(_ entry: Entry) -> Bool {
        switch entry.kind {
        case "thought", "tool", "plan": true
        default: false
        }
    }
}
