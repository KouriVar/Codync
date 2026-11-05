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
            StatusTitle(text: title)
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

/// The line's words. The title is rebuilt from live data as the turn moves, so it is held back to at
/// most one change a second and cross-faded; the sweep restarts on the new text.
private struct StatusTitle: View {
    let text: String
    @State private var shown: String
    @State private var shimmerStart = Date.now
    @State private var lastChange = Date.now
    @Environment(\.accessibilityReduceMotion) private var reduceMotion

    private static let minimumInterval: TimeInterval = 1

    init(text: String) {
        self.text = text
        _shown = State(initialValue: text)
    }

    var body: some View {
        ZStack(alignment: .leading) {
            ShimmeringText(text: shown, startedAt: shimmerStart,
                           font: .system(size: 16, weight: .regular))
                .id(shown)
                .transition(.opacity)
        }
        .animation(Motion.reduced(.easeInOut(duration: 0.18), reduceMotion), value: shown)
        .task(id: text) {
            guard !text.isEmpty, text != shown else { return }
            let elapsed = Date.now.timeIntervalSince(lastChange)
            if elapsed < Self.minimumInterval {
                try? await Task.sleep(for: .seconds(Self.minimumInterval - elapsed))
                guard !Task.isCancelled else { return }
            }
            shimmerStart = .now
            shown = text
            lastChange = .now
        }
    }
}

/// What a running turn says in one line: the bot's name and a short description built from the data
/// already in hand — the thinking's first sentence, the tool and its file or command. Nothing is
/// generated, and nothing is asked of the model.
public enum WorkingPhrase {
    /// Fallbacks for when there is no detail to name.
    public static let thinking = "思考中"
    /// The model is writing its answer: a `text-delta`, or Coe's non-final `agent` entry.
    public static let typing = "正在输入中"
    /// Nothing could be named: an unclassified tool, or a step with no detail at all.
    public static let processing = "处理会话中"

    /// What a tool step is doing, which decides its verb.
    public enum Verb: Sendable {
        case reading, executing, editing, other

        fileprivate var word: String {
            switch self {
            case .reading: "正在看"
            case .executing: "正在跑"
            case .editing: "正在改"
            case .other: "正在用"
            }
        }

        /// What is said when the detail behind the verb is missing.
        fileprivate var fallback: String {
            switch self {
            case .reading: "正在看文件"
            case .executing: "正在跑命令"
            case .editing: "正在改代码"
            case .other: WorkingPhrase.processing
            }
        }
    }

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
            return summary(of: step.data.text ?? "") ?? thinking
        case "agent":
            return typing
        case "tool":
            let data = step.data
            switch data.toolKind {
            case "think":
                return summary(of: data.text ?? "") ?? thinking
            case "read":
                return tool(.reading, subject: data.locations?.first?.path)
            case "execute":
                return tool(.executing, subject: data.command)
            case "edit", "move", "delete":
                return tool(.editing, subject: data.diffs?.first?.path)
            default:
                return tool(.other, subject: data.title)
            }
        default:
            return processing
        }
    }

    /// "正在看 README.md" / "正在跑 xcodebuild" / "正在改 ChatTranscript.swift" / "正在用 run_code".
    /// A file's own name and a command's first word only; the rest of the argument is never shown.
    public static func tool(_ verb: Verb, subject: String?) -> String {
        let raw = (subject ?? "").trimmingCharacters(in: .whitespacesAndNewlines)
        guard !raw.isEmpty else { return verb.fallback }
        switch verb {
        case .reading, .editing:
            let name = (raw as NSString).lastPathComponent
            return name.isEmpty ? verb.fallback : "\(verb.word) \(name)"
        case .executing:
            guard let word = raw.split(whereSeparator: \.isWhitespace).first.map(String.init),
                  !word.isEmpty else { return verb.fallback }
            return "\(verb.word) \(word)"
        case .other:
            return "\(verb.word) \(raw)"
        }
    }

    /// The first sentence of a piece of thinking, Markdown stripped, cut to about `limit` characters
    /// with an ellipsis. Nil when there is nothing to say.
    public static func summary(of text: String, limit: Int = 16) -> String? {
        let cleaned = plainText(text)
        guard !cleaned.isEmpty else { return nil }
        let sentence = firstSentence(cleaned)
        guard !sentence.isEmpty else { return nil }
        guard sentence.count > limit else { return sentence }
        let clipped = String(sentence.prefix(limit))
            .trimmingCharacters(in: CharacterSet(charactersIn: " \t，,、；;：:。.！!？?…—"))
        return clipped.isEmpty ? nil : clipped + "…"
    }

    /// Kinds that are working steps and nothing else: the chat keeps their data, it just doesn't draw
    /// them. A non-final `agent` entry stays — that is the bot speaking mid-run, which is content.
    public static func isStepOnly(_ entry: Entry) -> Bool {
        switch entry.kind {
        case "thought", "tool", "plan": true
        default: false
        }
    }

    // MARK: Text shaping

    /// Markdown's furniture off a sentence of thinking: fences, inline code, links, list bullets,
    /// emphasis and quotes.
    private static func plainText(_ text: String) -> String {
        var out = text
        out = out.replacingOccurrences(of: "```", with: " ")
        out = out.replacingOccurrences(of: "`", with: "")
        out = out.replacingOccurrences(of: #"!?\[([^\]]*)\]\([^)]*\)"#, with: "$1", options: .regularExpression)
        out = out.replacingOccurrences(of: #"(?m)^\s{0,3}(#{1,6}|[-*+]|\d+\.)\s+"#, with: "", options: .regularExpression)
        out = out.replacingOccurrences(of: #"[*_>#]"#, with: "", options: .regularExpression)
        out = out.replacingOccurrences(of: #"\s+"#, with: " ", options: .regularExpression)
        return out.trimmingCharacters(in: .whitespacesAndNewlines)
    }

    /// Up to the first sentence end. A "." counts only at the end of the text or before a space, so
    /// a file name like "README.md" is not cut in half.
    private static func firstSentence(_ text: String) -> String {
        var out = ""
        var index = text.startIndex
        while index < text.endIndex {
            let character = text[index]
            out.append(character)
            let next = text.index(after: index)
            if "。！？!?".contains(character) { break }
            if character == ".", next == text.endIndex || text[next] == " " { break }
            index = next
        }
        return out.trimmingCharacters(in: .whitespacesAndNewlines)
    }
}
