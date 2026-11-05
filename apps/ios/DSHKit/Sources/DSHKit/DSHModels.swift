import Foundation

// MARK: - Wire models (dsh-mobile-v1)

/// One row of the gateway's `sessions` reply.
public struct DSHSession: Identifiable, Codable, Hashable, Sendable {
    public var id: String
    public var title: String
    public var running: Bool
    public var workspaceId: String?
    public var updatedAt: Double?

    public init(id: String, title: String, running: Bool = false, workspaceId: String? = nil, updatedAt: Double? = nil) {
        self.id = id
        self.title = title
        self.running = running
        self.workspaceId = workspaceId
        self.updatedAt = updatedAt
    }


    enum CodingKeys: String, CodingKey {
        case id = "sessionId"
        case title
        case running
        case workspaceId
        case updatedAt
        case time
    }

    public init(from decoder: Decoder) throws {
        let c = try decoder.container(keyedBy: CodingKeys.self)
        id = try c.decode(String.self, forKey: .id)
        title = try c.decodeIfPresent(String.self, forKey: .title) ?? "未命名会话"
        running = try c.decodeIfPresent(Bool.self, forKey: .running) ?? false
        workspaceId = try c.decodeIfPresent(String.self, forKey: .workspaceId)
        updatedAt = try c.decodeIfPresent(Double.self, forKey: .updatedAt)
            ?? (try c.decodeIfPresent(Double.self, forKey: .time))
    }

    public func encode(to encoder: Encoder) throws {
        var c = encoder.container(keyedBy: CodingKeys.self)
        try c.encode(id, forKey: .id)
        try c.encode(title, forKey: .title)
        try c.encode(running, forKey: .running)
        try c.encodeIfPresent(workspaceId, forKey: .workspaceId)
        try c.encodeIfPresent(updatedAt, forKey: .updatedAt)
    }
}

/// How a tool result was paired with its call. Only `.exact` may be attributed to a turn: an
/// `orphan` or `ambiguous` result is kept as a fact but closes nothing.
public enum DSHToolMatchState: String, Sendable, Hashable {
    case exact, orphan, ambiguous
}

/// A tool the assistant ran inside one message: what it called, the arguments exactly as the wire
/// delivered them, and the result's metadata. The transcript draws no row for these — the running
/// status line reads structured `tool/call` events instead — but the facts are kept faithfully so a
/// truncated preview is never mistaken for a whole result.
///
/// The call's *typed* arguments (an object kept as an object, a JSON string kept as a string) live on
/// `DSHToolRecord`, the state's authoritative store: tools are no longer attached to assistant
/// messages, so there is no per-message copy that could drift from it.
public struct DSHTool: Identifiable, Hashable, Sendable {
    public let id: String
    public let name: String
    /// The arguments' display text. A JSON string argument keeps its original text.
    public let arguments: String
    public var output: String?
    /// The short preview the server sent next to a long output.
    public var preview: String?
    /// `nil` when the wire said nothing: an unstated failure is not the same as "exited 0".
    public var isError: Bool?
    /// The output was cut server-side; the preview is not the whole result.
    public var outputTruncated: Bool
    public var matchState: DSHToolMatchState

    public init(id: String, name: String, arguments: String = "", output: String? = nil,
                isError: Bool? = nil, preview: String? = nil, outputTruncated: Bool = false,
                matchState: DSHToolMatchState = .exact) {
        self.id = id
        self.name = name
        self.arguments = arguments
        self.output = output
        self.preview = preview
        self.isError = isError
        self.outputTruncated = outputTruncated
        self.matchState = matchState
    }
}

/// One picture a message refers to. The bytes are never kept here: they are fetched with an
/// `attachment` request when the row becomes visible, and cached in memory by
/// `(gatewayId, sessionId, attachmentId)`.
/// One command or skill from the gateway's `commands` catalogue.
public struct DSHCommand: Identifiable, Hashable, Sendable {
    public enum Kind: String, Sendable { case immediate, input, select, unknown }
    public let id: String
    public let name: String
    public let description: String
    /// `commands` or `skills` — the group title it came from.
    public let groupTitle: String
    public let kind: Kind
    /// For `input`: the text inserted into the field (e.g. "/plan ").
    public let insertText: String
    /// For `immediate`: the slash line sent to `command-execute` (e.g. "/compact").
    public let submitText: String
    /// True when the command accepts attached images (`ui.input.images`).
    public let acceptsImages: Bool
}

/// One group of the `commands` reply (`commands`, `skills`, …).
public struct DSHCommandGroup: Identifiable, Hashable, Sendable {
    public let id: String
    public let title: String
    public let commands: [DSHCommand]
}

/// One option of a `select` command (`command-options`).
public struct DSHCommandOption: Identifiable, Hashable, Sendable {
    public let id: String
    public let label: String
    public let detail: String?
    public let selected: Bool
}

// MARK: - Models / agent presets / permissions (chat page session controls)

public struct DSHReasoningEffort: Identifiable, Hashable, Sendable {
    public let id: String
    public let name: String
}

public struct DSHModel: Identifiable, Hashable, Sendable {
    public let id: String
    public let name: String
    public let providerId: String
    public let description: String
    public let reasoning: [DSHReasoningEffort]
}

public struct DSHModelGroup: Identifiable, Hashable, Sendable {
    public let id: String
    public let name: String
    public let models: [DSHModel]
}

public struct DSHCurrentModel: Hashable, Sendable {
    public let provider: String
    public let model: String
    public let reasoningEffort: String?
}

public struct DSHAgentPreset: Identifiable, Hashable, Sendable {
    public let id: String
    public let name: String
    public let detail: String?
    public let isDefault: Bool
    public let broken: Bool
}

public struct DSHPermissionOption: Identifiable, Hashable, Sendable {
    public let id: String      // `value`, sent back as `name`
    public let name: String
    public let detail: String?
}

/// One entry of a `file-list` reply (a workspace file or directory).
public struct DSHFileEntry: Identifiable, Hashable, Sendable {
    public var id: String { path }
    public let name: String
    public let path: String
    public let isDirectory: Bool
    public let bytes: Int?
    public let mediaType: String?
}

/// One item of a `schedule-list` reply (read-only display + delete).
public struct DSHSchedule: Identifiable, Hashable, Sendable {
    public let id: String
    public let title: String
    public let detail: String
}

/// One member of an `agent-team` reply (read-only).
public struct DSHTeamMember: Identifiable, Hashable, Sendable {
    public let id: String
    public let name: String
    public let role: String   // "lead" | "teammate"
    public let phase: String
}

public struct DSHImageRef: Identifiable, Hashable, Sendable {
    public let attachmentId: String
    public let mediaType: String
    public let bytes: Int?
    public let width: Int?
    public let height: Int?
    public let name: String?

    public var id: String { attachmentId }

    public init(attachmentId: String, mediaType: String, bytes: Int? = nil,
                width: Int? = nil, height: Int? = nil, name: String? = nil) {
        self.attachmentId = attachmentId
        self.mediaType = mediaType
        self.bytes = bytes
        self.width = width
        self.height = height
        self.name = name
    }
}

/// A picture the reader is sending, already prepared by `DSHImageProcessor`.
public struct DSHOutgoingImage: Hashable, Sendable {
    public let mediaType: String
    public let name: String
    public let data: Data

    public init(mediaType: String, name: String, data: Data) {
        self.mediaType = mediaType
        self.name = name
        self.data = data
    }

    public init(_ prepared: DSHPreparedImage) {
        self.init(mediaType: prepared.mediaType, name: prepared.name, data: prepared.data)
    }
}

/// A file the reader is sending: the gateway only accepts the `receiptId` a finished chunked upload
/// returned, never the bytes on the message.
public struct DSHOutgoingFile: Hashable, Sendable {
    public let name: String
    public let receiptId: String
    public init(name: String, receiptId: String) {
        self.name = name
        self.receiptId = receiptId
    }
}

/// One file upload in progress: shown as a card above the input with progress, retry and remove.
public struct DSHFileUpload: Identifiable, Hashable, Sendable {
    public enum Status: String, Hashable, Sendable { case uploading, ready, failed }
    public let id: String
    public let name: String
    public let size: Int
    public let data: Data
    public var progress: Double
    public var status: Status
    public var receiptId: String?
    public var error: String?

    public init(id: String, name: String, size: Int, data: Data, progress: Double = 0,
                status: Status = .uploading) {
        self.id = id
        self.name = name
        self.size = size
        self.data = data
        self.progress = progress
        self.status = status
    }
}

/// A neutral line in the conversation that is neither the reader nor the model: injected context, or
/// how a turn ended.
public struct DSHNotice: Hashable, Sendable {
    public enum Style: String, Sendable {
        /// A neutral line in the secondary colour: a cancellation, an interruption, an unknown end.
        case info
        /// A failed turn, drawn in the danger colour.
        case error
        /// Injected context from another source: "上下文 · 来源名" over its own text.
        case context
    }
    public let style: Style
    /// The controlled source name for a context line ("schedule", …); nil for a turn notice.
    public let source: String?
    /// The heading line; nil when the notice is one sentence.
    public let title: String?

    public init(style: Style, source: String? = nil, title: String? = nil) {
        self.style = style
        self.source = source
        self.title = title
    }
}

/// A conversation row shown in the DSH chat screen.
public struct DSHMessage: Identifiable, Hashable, Sendable {
    public enum Role: String, Sendable {
        case user, assistant
        /// A neutral line. Never forced into `user` or `assistant`: an injected context must not look
        /// like the reader's own message, and a turn's end is not something the model said.
        case notice
    }
    public let id: String
    public let role: Role
    public let seq: Int64
    public let step: Int?
    public var displayRowId: String
    public let revision: Int64
    public var text: String
    public var streaming: Bool
    /// The assistant's reasoning for this message (the `reasoning` field of `assistant/message`).
    public var reasoning: String
    /// Tools called in this step, in order.
    public var tools: [DSHTool]
    /// Pictures this message carries. A message may hold pictures and no text at all, and it is still
    /// a row: the bytes are fetched separately, so the references are all that live here.
    public var images: [DSHImageRef]
    /// What a `.notice` row is: its style, and the controlled source name when it is a context line.
    public var notice: DSHNotice?
    /// The turn this message belongs to.
    public var turn: Int?
    /// Time from the turn's start to this message.
    public var durationSeconds: Int?
    /// When it was written (ms since epoch).
    public var createdAt: Int64

    public init(id: String, role: Role, text: String, streaming: Bool = false,
                reasoning: String = "", tools: [DSHTool] = [], images: [DSHImageRef] = [],
                notice: DSHNotice? = nil,
                turn: Int? = nil, durationSeconds: Int? = nil,
                createdAt: Int64 = 0, seq: Int64 = 0, step: Int? = nil,
                displayRowId: String? = nil, revision: Int64 = 0) {
        self.id = id
        self.role = role
        self.seq = seq
        self.step = step
        self.displayRowId = displayRowId ?? id
        self.revision = revision
        self.text = text
        self.streaming = streaming
        self.reasoning = reasoning
        self.tools = tools
        self.images = images
        self.notice = notice
        self.turn = turn
        self.durationSeconds = durationSeconds
        self.createdAt = createdAt
    }
}

// MARK: - Transcript conversion

/// A folded stretch of one assistant message: its thinking and the tools it ran.
public struct DSHSummary: Identifiable, Hashable, Sendable {
    public let id: String
    public let title: String
    public let reasoning: String
    public let tools: [DSHTool]

    public init(id: String, title: String, reasoning: String, tools: [DSHTool]) {
        self.id = id
        self.title = title
        self.reasoning = reasoning
        self.tools = tools
    }
}

/// One row of a DSH conversation, already shaped for Codync's chat page: a user/assistant message,
/// with an optional folded summary for the thinking + tools that came with it.
public struct DSHTranscriptItem: Identifiable, Sendable {
    public enum Kind: Sendable { case user, assistant, notice }
    public let id: String
    public let kind: Kind
    public var seq: Int64 = 0
    public var turn: Int = 0
    public var revision: Int64 = 0
    public var displayRowId: String = ""
    public let text: String
    public let summary: DSHSummary?
    /// Pictures this row carries. A row with pictures and no text is still shown.
    public let images: [DSHImageRef]
    /// What a `.notice` row is: its style and, for a context line, its controlled source name.
    public let notice: DSHNotice?
    /// When the message was written (ms since epoch), for the page's time separators.
    public let createdAt: Int64

    public init(id: String, kind: Kind, text: String, summary: DSHSummary?, createdAt: Int64,
                images: [DSHImageRef] = [], notice: DSHNotice? = nil) {
        self.id = id
        self.kind = kind
        self.text = text
        self.summary = summary
        self.images = images
        self.notice = notice
        self.createdAt = createdAt
    }
}

/// Turns DSH's messages into the intermediate rows the host maps onto Codync's chat model.
/// (DSHKit does not depend on CodyncKit: the host owns that last hop.)
public enum DSHConversationAdapter {
    public static func transcript(from messages: [DSHMessage]) -> [DSHTranscriptItem] {
        messages.map { message in
            var row = transcriptItem(from: message)
            row.seq = message.seq; row.turn = message.turn ?? 0
            row.revision = message.revision; row.displayRowId = message.displayRowId
            return row
        }
    }

    private static func transcriptItem(from message: DSHMessage) -> DSHTranscriptItem {
        switch message.role {
        case .notice:
            return DSHTranscriptItem(id: message.id, kind: .notice, text: message.text,
                                     summary: nil, createdAt: message.createdAt,
                                     images: message.images, notice: message.notice)
        case .user:
            return DSHTranscriptItem(id: message.id, kind: .user, text: message.text,
                                     summary: nil, createdAt: message.createdAt, images: message.images)
        case .assistant:
            let hasDetail = !message.reasoning.isEmpty || !message.tools.isEmpty
            let summary = hasDetail
                ? DSHSummary(id: message.id, title: title(for: message),
                             reasoning: message.reasoning, tools: message.tools)
                : nil
            return DSHTranscriptItem(id: message.id, kind: .assistant, text: message.text,
                                     summary: summary, createdAt: message.createdAt, images: message.images)
        }
    }

    /// "思考了 12 秒 · 运行了 3 个命令".
    static func title(for message: DSHMessage) -> String {
        var parts: [String] = []
        if !message.reasoning.isEmpty {
            parts.append("思考了 \(max(1, message.durationSeconds ?? 1)) 秒")
        }
        if !message.tools.isEmpty {
            parts.append("运行了 \(message.tools.count) 个命令")
        }
        return parts.isEmpty ? "过程" : parts.joined(separator: " · ")
    }
}

/// The `hello` frame's fields this client needs.
public struct DSHHello: Decodable, Sendable {
    public var protocolVersion: Int
    public var gatewayName: String?
    public var capabilities: [String]
    public var authenticated: Bool?

    enum CodingKeys: String, CodingKey {
        case protocolVersion = "protocol"
        case gatewayName, capabilities, authenticated
    }
}

/// A generic frame: `kind` plus the raw JSON, so callers can pluck fields they know.
struct DSHFrame {
    let kind: String
    let json: [String: Any]

    func string(_ key: String) -> String? { json[key] as? String }
    func bool(_ key: String) -> Bool? { json[key] as? Bool }
    func int(_ key: String) -> Int? { (json[key] as? NSNumber)?.intValue }
    func dict(_ key: String) -> [String: Any]? { json[key] as? [String: Any] }
    func array(_ key: String) -> [[String: Any]]? { json[key] as? [[String: Any]] }
}

// MARK: - Injected system messages

/// DSH prepends a sampled-time system line to a turn's user message (for example
/// "Time sampled while preparing turn 6, step 1: …"). It is not something the user typed, so the
/// chat must not draw it as a bubble. One place to grow the rule if DSH adds more such lines.
public enum DSHSystemMessageFilter {
    private static let injectedPrefixes = [
        "time sampled while preparing turn",
        "time sampled",
    ]

    public static func isInjected(_ text: String) -> Bool {
        let trimmed = text.trimmingCharacters(in: .whitespacesAndNewlines).lowercased()
        guard !trimmed.isEmpty else { return false }
        return injectedPrefixes.contains { trimmed.hasPrefix($0) }
    }
}

// MARK: - Current activity (what the one status line under a running turn says)

/// What a running turn is doing, as the fixed phrase the chat's status line shows. Only structured
/// wire evidence is used — turn/step events, the attempt frames, and an explicit tool-name whitelist.
/// The model's own words are never read to guess, and a name outside the whitelist is `processing`.
public enum DSHActivityKind: String, Sendable, Equatable, CaseIterable {
    case thinking
    /// The model is writing its answer (`text-delta`).
    case typing
    case executing
    case reading
    case editing
    case processing
}

extension DSHActivityKind {
    /// Tool names are matched exactly after lowercasing — never `contains`, never by reading the
    /// call's arguments. `run_code`, search/glob/grep/fetch and every unknown or namespaced name are
    /// `processing`: they may wrap more than one kind of work, so the first slice does not guess.
    public static func forTool(named name: String) -> DSHActivityKind {
        switch name.trimmingCharacters(in: .whitespacesAndNewlines).lowercased() {
        case "read", "read_file", "readfile":
            return .reading
        case "write", "write_file", "writefile", "edit", "edit_file", "editfile", "apply_patch":
            return .editing
        case "bash", "pwsh", "shell", "exec", "exec_command", "terminal":
            return .executing
        default:
            return .processing
        }
    }
}

/// What the status line shows right now: the kind of work, plus the one detail that names it.
/// DSHKit never turns this into words — the host app owns the language and the shortening.
public struct DSHActivityDetail: Sendable, Equatable {
    public var kind: DSHActivityKind
    /// The tool being called, when the step is a tool call.
    public var toolName: String?
    /// The call's key argument as it arrived — a file's path, or the command line — taken from the
    /// call's JSON. Left raw: the page takes the file's name or the command's first word.
    public var toolArgument: String?
    /// The reasoning written so far in this attempt, capped. The line's short summary comes from its
    /// first sentence; it is never shown in the transcript.
    public var reasoning: String?

    public init(kind: DSHActivityKind, toolName: String? = nil, toolArgument: String? = nil,
                reasoning: String? = nil) {
        self.kind = kind
        self.toolName = toolName
        self.toolArgument = toolArgument
        self.reasoning = reasoning
    }
}

/// Who a frame belongs to. A frame carrying another session, subscription or stream is from an
/// earlier connection and must not touch the current state.
public struct DSHActivityEnvelope: Sendable, Equatable {
    public var sessionId: String?
    public var subscriptionId: String?
    public var streamId: String?

    public init(sessionId: String? = nil, subscriptionId: String? = nil, streamId: String? = nil) {
        self.sessionId = sessionId
        self.subscriptionId = subscriptionId
        self.streamId = streamId
    }
}

/// One persistent event, reduced to the fields the activity needs. `seq` is the session's persistent
/// order; the attempt's `revision`/`index` are a second clock and are never compared with it.
public struct DSHActivityEvent: Sendable, Equatable {
    public var type: String
    public var turn: Int?
    public var step: Int?
    public var callId: String?
    public var toolName: String?
    /// The call's key argument, taken from its JSON (a file's path, or the command line). The
    /// classification never reads it; the status line's short description does.
    public var toolArgument: String?
    public var seq: Int?

    public init(type: String, turn: Int? = nil, step: Int? = nil, callId: String? = nil,
                toolName: String? = nil, toolArgument: String? = nil, seq: Int? = nil) {
        self.type = type
        self.turn = turn
        self.step = step
        self.callId = callId
        self.toolName = toolName
        self.toolArgument = toolArgument
        self.seq = seq
    }
}

/// One temporary attempt frame (`assistant-stream.frame`).
public struct DSHActivityFrame: Sendable, Equatable {
    public var type: String
    public var attemptId: String?
    public var revision: Int?
    public var turn: Int?
    public var step: Int?
    public var index: Int?
    /// `reasoning-delta` / `text-delta` / anything else the host sends.
    public var chunkType: String?
    /// The chunk's text: kept only for reasoning, which the status line summarizes. A text delta's
    /// words go to the transcript, never here.
    public var text: String?

    public init(type: String, attemptId: String? = nil, revision: Int? = nil, turn: Int? = nil,
                step: Int? = nil, index: Int? = nil, chunkType: String? = nil, text: String? = nil) {
        self.type = type
        self.attemptId = attemptId
        self.revision = revision
        self.turn = turn
        self.step = step
        self.index = index
        self.chunkType = chunkType
        self.text = text
    }
}

/// A still-open attempt restored from a server baseline.
public struct DSHActivityAttempt: Sendable, Equatable {
    public var attemptId: String
    public var turn: Int?
    public var step: Int?
    public var nextIndex: Int?
    public var revision: Int?
    /// The last thing the compact stream recorded, when it is a delta kind.
    public var lastDeltaType: String?

    public init(attemptId: String, turn: Int? = nil, step: Int? = nil, nextIndex: Int? = nil,
                revision: Int? = nil, lastDeltaType: String? = nil) {
        self.attemptId = attemptId
        self.turn = turn
        self.step = step
        self.nextIndex = nextIndex
        self.revision = revision
        self.lastDeltaType = lastDeltaType
    }
}

/// A server baseline (`session-snapshot`): the identity, the persistent watermark, a window of
/// events and the attempt still being written, if any.
public struct DSHActivitySnapshot: Sendable, Equatable {
    public var subscriptionId: String?
    public var streamId: String?
    public var replace: Bool
    public var cursor: Int?
    public var hasMore: Bool
    public var events: [DSHActivityEvent]
    public var attempt: DSHActivityAttempt?

    public init(subscriptionId: String? = nil, streamId: String? = nil, replace: Bool = false,
                cursor: Int? = nil, hasMore: Bool = false, events: [DSHActivityEvent] = [],
                attempt: DSHActivityAttempt? = nil) {
        self.subscriptionId = subscriptionId
        self.streamId = streamId
        self.replace = replace
        self.cursor = cursor
        self.hasMore = hasMore
        self.events = events
        self.attempt = attempt
    }
}

/// The running state behind the status line: a pure reducer over the frames above. It knows nothing
/// about SwiftUI, colours or the transcript's messages, and it never changes what the body shows.
public struct DSHActivityState: Sendable, Equatable {
    public private(set) var sessionId: String?
    public private(set) var subscriptionId: String?
    public private(set) var streamId: String?
    public private(set) var running = false
    public private(set) var turn: Int?
    public private(set) var step: Int?
    /// The highest persistent seq folded in: a replay at or below it is ignored.
    public private(set) var lastSeq: Int?

    private var kind: DSHActivityKind?
    private var attemptId: String?
    private var attemptRevision: Int?
    private var attemptNextIndex: Int?
    private var pending: [Pending] = []
    /// The reasoning written so far in the current attempt. Only ever summarized into the status
    /// line's title; it is not a message and never reaches the transcript.
    private var reasoning = ""
    private static let reasoningLimit = 400
    /// Streams that were reset: their frames can never be trusted again.
    private var deadStreams: Set<String> = []

    private struct Pending: Sendable, Equatable {
        var callId: String
        var kind: DSHActivityKind
        var name: String?
        var argument: String?
    }

    public init() {}

    /// What the status line says right now; nil when no turn is running (the line disappears).
    public var activity: DSHActivityDetail? {
        guard running else { return nil }
        let call = pending.last
        return DSHActivityDetail(kind: call?.kind ?? kind ?? .processing,
                                 toolName: call?.name,
                                 toolArgument: call?.argument,
                                 reasoning: reasoning.isEmpty ? nil : reasoning)
    }

    /// A persistent event or a baseline has been folded in: from then on a bare `session-status`
    /// cannot change what is shown, only the subscription's own events can.
    private var hasBaseline: Bool { lastSeq != nil }

    // MARK: Generation (opened / closed / disconnected)

    /// A conversation was opened: nothing from the previous one survives.
    public mutating func beginSession(_ sessionId: String) {
        self = DSHActivityState()
        self.sessionId = sessionId
    }

    /// The conversation was closed, the socket dropped, or connecting failed.
    public mutating func endSession() {
        self = DSHActivityState()
    }

    /// The gateway confirmed a subscription: a new generation, and no stream until a snapshot names
    /// one. Anything still believed about the previous subscription is dropped.
    public mutating func applySubscribed(subscriptionId: String, streamId: String? = nil) {
        self.subscriptionId = subscriptionId
        self.streamId = streamId
        deadStreams.removeAll()
        pending.removeAll()
        clearAttempt()
        turn = nil
        step = nil
        lastSeq = nil
        reasoning = ""
        kind = running ? .processing : nil
    }

    // MARK: Weak hints (no persistent seq)

    /// `sessions[].running`: a fallback only while there is no trusted baseline, and never a reason
    /// to claim that a specific tool is running.
    public mutating func applySessionsHint(running: Bool) {
        guard !hasBaseline, !self.running, running else { return }
        self.running = true
        kind = .processing
    }

    /// `session-status` carries no seq, so it is a hint. `true` must not revive a finished turn;
    /// `false` clears the fine state — it is the way out of a lost `turn/end` — but it is never a
    /// completion signal for the conversation itself.
    public mutating func applySessionStatus(running: Bool) {
        if running {
            guard !hasBaseline else { return }
            self.running = true
            kind = .processing
        } else {
            stop()
        }
    }

    // MARK: Persistent events

    /// Folds one persistent event. Returns false when the frame belongs to another generation or is
    /// a replay, so nothing changed.
    @discardableResult
    public mutating func apply(_ event: DSHActivityEvent, in envelope: DSHActivityEnvelope) -> Bool {
        guard accept(envelope) else { return false }
        var degraded = false
        if let seq = event.seq {
            if let last = lastSeq {
                if seq <= last { return false }
                if seq > last + 1 {
                    degraded = true
                    degrade()
                }
            }
            lastSeq = seq
        }
        switch event.type {
        case "turn/start":
            running = true
            kind = .thinking
            pending.removeAll()
            clearAttempt()
            reasoning = ""
            turn = event.turn ?? turn
            step = event.step
        case "step/start":
            running = true
            if pending.isEmpty { kind = .thinking }
            turn = event.turn ?? turn
            step = event.step ?? step
        case "step/end":
            // A step ending is not a turn ending: keep the line up.
            running = true
            if pending.isEmpty { kind = .processing }
        case "tool/call":
            running = true
            guard !degraded else { break }
            guard let callId = event.callId, !callId.isEmpty else {
                // No id means the call cannot be paired with its result: stay generic rather than
                // invent a key that would never match.
                if pending.isEmpty { kind = .processing }
                break
            }
            let toolKind = DSHActivityKind.forTool(named: event.toolName ?? "")
            if let index = pending.firstIndex(where: { $0.callId == callId }) {
                pending[index].kind = toolKind
                pending[index].name = event.toolName
                pending[index].argument = event.toolArgument
            } else {
                pending.append(Pending(callId: callId, kind: toolKind,
                                       name: event.toolName, argument: event.toolArgument))
            }
            turn = event.turn ?? turn
            step = event.step ?? step
        case "tool/result":
            running = true
            guard !degraded else { break }
            if let callId = event.callId, !callId.isEmpty {
                pending.removeAll { $0.callId == callId }
            }
            if pending.isEmpty { kind = .processing }
        case "assistant/message":
            // One committed step: never hides the line.
            running = true
            if pending.isEmpty { kind = .processing }
        case "turn/end":
            stop()
        default:
            // An unknown type still advanced the watermark above; it changes nothing else.
            break
        }
        return true
    }

    // MARK: Attempt frames

    /// Folds one `assistant-stream` frame. An attempt ending is not a turn ending, and an abandoned
    /// attempt is not a turn ending either.
    @discardableResult
    public mutating func apply(_ frame: DSHActivityFrame, in envelope: DSHActivityEnvelope) -> Bool {
        guard accept(envelope) else { return false }
        var degraded = false
        switch frame.type {
        case "start":
            running = true
            attemptId = frame.attemptId
            attemptRevision = frame.revision
            attemptNextIndex = nil   // a start carries no index
            turn = frame.turn ?? turn
            step = frame.step ?? step
            reasoning = ""           // a new attempt thinks from the start
            if pending.isEmpty { kind = .thinking }
        case "chunk":
            guard let attempt = frame.attemptId else { return false }
            if let current = attemptId, current != attempt { return false }
            running = true
            attemptId = attempt
            if let expected = attemptRevision, let revision = frame.revision, revision != expected + 1 {
                degraded = true
                degrade()
            } else if let expected = attemptNextIndex, let index = frame.index, index != expected {
                degraded = true
                degrade()
            }
            attemptRevision = frame.revision ?? attemptRevision
            if let index = frame.index { attemptNextIndex = index + 1 }
            // The reasoning is only ever the status line's material: the transcript's text comes
            // from text deltas alone (see `DSHGateway.text(ofChunk:)`).
            if !degraded, frame.chunkType == "reasoning-delta", let text = frame.text {
                appendReasoning(text)
            }
            if pending.isEmpty, !degraded {
                switch frame.chunkType {
                case "reasoning-delta": kind = .thinking
                case "text-delta": kind = .typing
                default: break
                }
            }
        case "end":
            if let attempt = frame.attemptId, let current = attemptId, current != attempt { return false }
            if let expected = attemptNextIndex, let index = frame.index, index != expected {
                degrade()
            }
            clearAttempt()
            if running, pending.isEmpty { kind = .processing }
        default:
            break
        }
        return true
    }

    // MARK: Server baseline

    /// Installs a `session-snapshot`. Only a window that covers a whole turn may fold pending calls;
    /// a clipped one keeps the coarse running signal and shows the generic phrase.
    public mutating func applySnapshot(_ snapshot: DSHActivitySnapshot, runningHint: Bool? = nil) {
        if let subscription = snapshot.subscriptionId { subscriptionId = subscription }
        // A baseline does not carry the attempt's reasoning as a sentence: the line falls back to
        // "思考中" until the next reasoning delta arrives.
        reasoning = ""
        if let stream = snapshot.streamId, stream != streamId {
            // A new stream replaces what the old one left behind; the old one is never read again.
            streamId = stream
            deadStreams.removeAll()
            pending.removeAll()
            clearAttempt()
        }
        if snapshot.replace {
            pending.removeAll()
            clearAttempt()
            turn = nil
            step = nil
        }

        let seqs = snapshot.events.compactMap(\.seq)
        let contiguous = zip(seqs, seqs.dropFirst()).allSatisfy { pair in pair.1 == pair.0 + 1 }
        let startsAtTurnStart = snapshot.events.first?.type == "turn/start"
        let coversCursor = snapshot.cursor.map { (seqs.max() ?? 0) + 1 >= $0 } ?? true
        let complete = !snapshot.events.isEmpty && !snapshot.hasMore && contiguous
            && startsAtTurnStart && coversCursor

        if complete {
            lastSeq = nil            // fold from a clean watermark: this window is the baseline
            for event in snapshot.events {
                apply(event, in: DSHActivityEnvelope())
            }
        } else {
            // The window cannot say which tool is running. Keep only what its turn/start and
            // turn/end say about whether anything runs at all.
            pending.removeAll()
            clearAttempt()
            turn = nil
            step = nil
            var sawTurn = false
            for event in snapshot.events {
                switch event.type {
                case "turn/start": sawTurn = true; running = true
                case "turn/end": sawTurn = true; stop()
                default: break
                }
            }
            // With no turn in the window, the session list is the only thing that can say whether
            // one is open.
            if !sawTurn, let hint = runningHint { running = hint }
            if running { kind = .processing }
        }

        // The cursor is the new persistent watermark. Never move it backwards: a baseline that
        // arrives after live events must not turn the next event into a false gap.
        if let cursor = snapshot.cursor { lastSeq = max(lastSeq ?? cursor, cursor) }
        else if let last = seqs.max() { lastSeq = max(lastSeq ?? last, last) }

        // An open attempt means the turn is still under way; no attempt does not mean it stopped.
        // A window whose last word is turn/end wins over a contradicting attempt record.
        let windowEnded = snapshot.events.last?.type == "turn/end"
        if let attempt = snapshot.attempt, !windowEnded {
            running = true
            attemptId = attempt.attemptId
            attemptRevision = attempt.revision
            attemptNextIndex = attempt.nextIndex
            turn = attempt.turn ?? turn
            step = attempt.step ?? step
            if pending.isEmpty {
                switch attempt.lastDeltaType {
                case "text-delta": kind = .typing
                default: kind = .thinking
                }
            }
        }
    }

    /// `session-stream-reset`: this stream is dead, its fine state with it. Nothing is claimed about
    /// the turn — if it is still running the line falls back to the generic phrase and waits for the
    /// server's next baseline.
    public mutating func applyStreamReset(in envelope: DSHActivityEnvelope) {
        guard accept(envelope) else { return }
        if let stream = streamId { deadStreams.insert(stream) }
        streamId = nil
        pending.removeAll()
        clearAttempt()
        kind = running ? .processing : nil
    }

    // MARK: Internals

    /// Accepts a frame only for this session/subscription/stream, adopting the first stream id seen
    /// on a generation that has none yet.
    private mutating func accept(_ envelope: DSHActivityEnvelope) -> Bool {
        if let session = envelope.sessionId, let current = sessionId, session != current { return false }
        if let subscription = envelope.subscriptionId, let current = subscriptionId,
           subscription != current { return false }
        if let stream = envelope.streamId {
            if deadStreams.contains(stream) { return false }
            if let current = streamId, stream != current { return false }
            if streamId == nil { streamId = stream }
        }
        return true
    }

    /// A seq/revision gap: the fine state cannot be trusted, so drop it and show the generic phrase
    /// until the server sends a new baseline. Tools are never stitched across the gap.
    private mutating func degrade() {
        pending.removeAll()
        clearAttempt()
        turn = nil
        step = nil
        reasoning = ""
        if running { kind = .processing }
    }

    private mutating func stop() {
        running = false
        kind = nil
        pending.removeAll()
        clearAttempt()
        turn = nil
        step = nil
        reasoning = ""
    }

    private mutating func clearAttempt() {
        attemptId = nil
        attemptRevision = nil
        attemptNextIndex = nil
    }

    /// Keeps only the start of the attempt's reasoning: the line shows its first sentence, so the
    /// rest is never needed (and a long turn must not grow this without bound).
    private mutating func appendReasoning(_ text: String) {
        guard reasoning.count < Self.reasoningLimit else { return }
        reasoning += text
        if reasoning.count > Self.reasoningLimit {
            reasoning = String(reasoning.prefix(Self.reasoningLimit))
        }
    }
}

// MARK: - Errors

public enum DSHError: LocalizedError {
    case badQRCode(String)
    case unsupportedProtocol(Int)
    case pairingRejected(String)
    case authenticationRequired
    case gatewayDisabled
    case notConfigured
    case transport(String)

    public var errorDescription: String? {
        switch self {
        case .badQRCode(let why): return "配对码无法识别：\(why)"
        case .unsupportedProtocol(let v): return "网关协议版本是 \(v)，这个 App 需要 3。"
        case .pairingRejected(let why): return "配对被拒绝：\(why)"
        case .authenticationRequired: return "网关不再接受这台设备的凭证，请重新配对。"
        case .gatewayDisabled: return "网关已关闭移动入口。"
        case .notConfigured: return "还没有连接 DSH。"
        case .transport(let why): return "连接 DSH 失败：\(why)"
        }
    }
}
