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
        HStack(spacing: 10) {
            avatar
            ShimmeringText(text: title, startedAt: .now, font: .system(size: 16, weight: .regular))
                .lineLimit(1)
            Spacer(minLength: 0)
        }
        // One fixed height, so the row appearing or leaving never moves what is under it.
        .frame(height: 24)
        // The row's own cell already adds 16: 8 more puts the avatar's left edge 24 from the screen.
        .padding(.horizontal, 8)
        .accessibilityElement(children: .ignore)
        .accessibilityLabel(Text(title))
        .accessibilityAddTraits(.updatesFrequently)
    }
}

/// What a running turn says in one line: the bot's name and the kind of work it is on. Fixed
/// phrases from the step's own type — never the model's words, never a generated title.
public enum WorkingPhrase {
    /// A step is under way, or the model is reasoning.
    public static let thinking = "思考中"
    /// The model is writing its answer: a `text-delta`, or Coe's non-final `agent` entry.
    public static let typing = "正在输入中"
    /// A tool or step the host didn't classify: anything that isn't one of the kinds below.
    public static let processing = "处理会话中"
    public static let executing = "正在跑命令"
    public static let reading = "正在看文件"
    public static let editing = "正在改代码"

    /// The bot's name and the phrase, in one line: "名字 思考中".
    public static func line(name: String, phrase: String) -> String {
        let trimmed = name.trimmingCharacters(in: .whitespacesAndNewlines)
        return trimmed.isEmpty ? phrase : "\(trimmed) \(phrase)"
    }

    /// Coe's running turn, as its one line: the bot's name and the step under way.
    public static func title(for steps: [Entry], name: String) -> String {
        line(name: name, phrase: phrase(for: steps))
    }

    /// Coe's running steps, the last one being the step under way. `thought`/`tool`/`plan` are the
    /// kinds the host marks as working steps; a tool's `toolKind` says which kind of tool it is.
    /// A non-final `agent` entry is the model writing, which is what "正在输入中" means.
    public static func phrase(for steps: [Entry]) -> String {
        guard let step = steps.last else { return processing }
        switch step.kind {
        case "thought":
            return thinking
        case "agent":
            return typing
        case "tool":
            switch step.data.toolKind {
            case "think": return thinking
            case "execute": return executing
            case "read": return reading
            case "edit", "move", "delete": return editing
            default: return processing
            }
        default:
            return processing
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
