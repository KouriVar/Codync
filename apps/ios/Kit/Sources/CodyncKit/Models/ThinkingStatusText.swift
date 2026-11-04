import Foundation

/// What the bot is doing, in the reader's words: never a tool name, a command or a path.
///
/// The one source for that line: the chat's status row (`ThinkingStatusRow`) and the Live
/// Activity's caption (`BotActivityPresentation.caption`) both read it, so the two can't drift
/// into "bash" here and "跑一下命令" there.
public enum ThinkingStatusText {
    /// The host's activity, turned into a phrase about the work. The host sends tool titles
    /// (`bash`, `read_file`, …) for tool calls; those become "Running a command" and friends, and
    /// a phrase the host already wrote for the reader passes through.
    public static func text(activity: String, needsInput: Bool) -> String {
        if needsInput { return L10n.tr("Waiting for your OK") }
        let raw = activity.trimmingCharacters(in: .whitespacesAndNewlines)
        if raw.isEmpty { return L10n.tr("Typing…") }
        switch raw {
        case "Starting…", "Starting agent…": return L10n.tr("Getting your point")
        default: break
        }
        let localized = L10n.tr(raw)
        if localized != raw { return localized }
        // A Chinese title from a newer host is already written for the reader.
        if raw.contains(where: { $0.unicodeScalars.contains { $0.value > 0x2E7F } }) { return raw }
        // Tool-shaped: say what the step is for, not which tool runs it.
        let tokens = Set(raw.lowercased().split { !$0.isLetter && !$0.isNumber }.map(String.init))
        func has(_ words: Set<String>) -> Bool { !tokens.isDisjoint(with: words) }
        if has(["bash", "sh", "zsh", "shell", "terminal", "command", "exec", "execute", "run", "spawn", "script"]) {
            return L10n.tr("Running a command")
        }
        if has(["write", "edit", "patch", "create", "apply", "replace", "save", "insert"]) {
            return L10n.tr("Editing a file")
        }
        if has(["search", "grep", "find", "web", "fetch", "query", "lookup", "browse", "http"]) {
            return L10n.tr("Looking something up")
        }
        if has(["read", "cat", "view", "list", "ls", "glob", "open", "head", "tail", "file"]) {
            return L10n.tr("Reading a file")
        }
        if has(["todo", "plan", "task", "step", "schedule"]) { return L10n.tr("Planning the steps") }
        return L10n.tr("Working on it")
    }

    // MARK: elapsed time

    /// How long it has been is shown only once it means something: nothing under ten seconds.
    public static let elapsedAfterSeconds = 10
    /// A minute in, the line says so.
    public static let takingAWhileAfterSeconds = 60

    /// The elapsed-time label ("43s"), or nil while it's still too soon to show one.
    public static func elapsed(_ seconds: Int) -> String? {
        seconds >= elapsedAfterSeconds ? "\(seconds)s" : nil
    }

    /// What the line adds once the wait is long enough to mention.
    public static func suffix(seconds: Int) -> String {
        seconds >= takingAWhileAfterSeconds ? L10n.tr("Taking a while, hang on") : ""
    }
}
