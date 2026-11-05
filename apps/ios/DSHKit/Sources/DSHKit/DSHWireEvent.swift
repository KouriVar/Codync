import Foundation
import CoreFoundation

/// Owned JSON values: history may carry structured arguments, not just strings.
enum DSHJSON: Hashable, Sendable {
    case object([String: DSHJSON]), array([DSHJSON]), string(String), number(Double), bool(Bool), null

    init(_ value: Any) {
        switch value {
        case let n as NSNumber:
            self = CFGetTypeID(n) == CFBooleanGetTypeID() ? .bool(n.boolValue) : .number(n.doubleValue)
        case let s as String: self = .string(s)
        case let a as [Any]: self = .array(a.map(DSHJSON.init))
        case let d as [String: Any]: self = .object(d.mapValues(DSHJSON.init))
        default: self = .null
        }
    }

    subscript(_ key: String) -> DSHJSON { if case .object(let d) = self { return d[key] ?? .null }; return .null }
    var string: String? { if case .string(let s) = self { return s }; return nil }
    var bool: Bool? { if case .bool(let b) = self { return b }; return nil }
    var number: Double? { if case .number(let n) = self { return n }; return nil }
    var array: [DSHJSON] { if case .array(let a) = self { return a }; return [] }
    var integer: Int64? {
        guard case .number(let n) = self, n.isFinite, n.rounded() == n,
              abs(n) <= 9_007_199_254_740_991 else { return nil }
        return Int64(n)
    }
    var object: [String: DSHJSON]? { if case .object(let d) = self { return d }; return nil }
    var text: String {
        if let s = string { return s }
        guard let data = try? JSONSerialization.data(withJSONObject: foundationValue, options: [.sortedKeys, .fragmentsAllowed])
        else { return "" }
        return String(data: data, encoding: .utf8) ?? ""
    }
    private var foundationValue: Any {
        switch self {
        case .object(let d): return d.mapValues(\.foundationValue)
        case .array(let a): return a.map(\.foundationValue)
        case .string(let s): return s
        case .number(let n): return n
        case .bool(let b): return b
        case .null: return NSNull()
        }
    }

    /// Missing fields don't erase richer history; explicit null/empty values do.
    func enriched(by newer: DSHJSON) -> DSHJSON {
        guard let a = object, let b = newer.object else { return newer }
        return .object(a.merging(b) { $0.enriched(by: $1) })
    }
}

enum DSHIdentityPart: Encodable {
    case text(String), seq(Int64)
    func encode(to encoder: Encoder) throws {
        var value = encoder.singleValueContainer()
        switch self {
        case .text(let text): try value.encode(text)
        case .seq(let seq): try value.encode(seq)
        }
    }
    var fallback: String {
        switch self {
        case .text(let s): return "s\(s.utf8.count):\(s)"
        case .seq(let n): return "n\(n):"
        }
    }
}

struct DSHSessionScope: Hashable, Sendable {
    let gatewayId: String
    let sessionId: String
    let format: Int

    func identity(_ suffix: [DSHIdentityPart]) -> String {
        let parts = [DSHIdentityPart.text(gatewayId), .text(sessionId)] + suffix
        // Strings and Int64 have a total JSON representation. Even an encoder failure must not
        // collapse distinct identities: the fallback is type-tagged and length-prefixed.
        if let data = try? JSONEncoder().encode(parts) { return String(decoding: data, as: UTF8.self) }
        return "identity:" + parts.map(\.fallback).joined()
    }
}

// MARK: - Tool calls (one call, one result, no whole-turn bucket)

/// A tool call's full address. A result only ever closes the call it names — never the turn — so the
/// turn and step are part of the identity. They are optional because a history result may omit them:
/// an exact match then means "both unknown", and anything looser is settled by the candidate index.
struct DSHToolKey: Hashable, Sendable {
    let gatewayId: String
    let sessionId: String
    let turn: Int?
    let step: Int?
    let callId: String
}

/// The loose address: everything a call and its result always agree on, even when the result dropped
/// its turn/step. It only ever yields *candidates*; picking one is what the ambiguity rule forbids.
struct DSHToolLooseKey: Hashable, Sendable {
    let gatewayId: String
    let sessionId: String
    let callId: String
}

/// One tool call: its arguments exactly as the wire delivered them, plus every result that named it.
/// Results are kept by seq, so a replayed result never becomes a second fact.
struct DSHToolRecord: Sendable {
    let key: DSHToolKey
    var name: String?
    /// The arguments as delivered: an object stays an object, a JSON string stays that string.
    var arguments: DSHJSON?
    /// The display form. A string argument keeps its original text; nothing is thrown away when it
    /// does not parse.
    var argumentsText: String?
    var callSeq: Int64?
    var resultSeqs: [Int64] = []
    var output: String?
    var preview: String?
    var isError: Bool?
    var error: DSHJSON?
    /// The output was cut server-side. A truncated preview is never presented as a complete result.
    var outputTruncated = false
    var matchState: DSHToolMatchState = .exact
}

/// A result that named a call this window never saw, or saw more than once. Kept as a fact for
/// diagnosis; it closes nothing and is never attributed to a turn by guessing.
struct DSHUnmatchedResult: Sendable {
    let seq: Int64
    let looseKey: DSHToolLooseKey
    let turn: Int?
    let step: Int?
    let output: String?
    let preview: String?
    let isError: Bool?
    let error: DSHJSON?
    let outputTruncated: Bool
    var matchState: DSHToolMatchState
}

// MARK: - Message origin (who wrote a user/message)

/// The controlled name a context line shows for the wire's `source.kind`. The wire's set is open —
/// plugins may add `plugin:<name>` — and several built-in values must never reach the screen as they
/// are (`ptc-mode`, `cordis-host-runner`, `dsh-session-title-llm`), so every kind goes through this
/// table and an unrecognised one falls back to the generic "上下文".
enum DSHSourceName {
    static func display(for kind: String) -> String? {
        if kind.hasPrefix("plugin:") { return "插件" }
        switch kind {
        case "schedule": return "定时任务"
        case "agent-instructions": return "智能体指令"
        case "runtime-context": return "运行时上下文"
        case "time-context": return "时间上下文"
        case "tmux-context": return "终端上下文"
        case "skill-catalog": return "技能目录"
        case "skill-invocation": return "技能调用"
        case "session-reference": return "会话引用"
        case "goal", "tool-goal": return "目标"
        case "tool-jobs": return "后台任务"
        case "user-approval": return "授权结果"
        case "user-question-reply": return "问题回复"
        case "agent-message": return "其他智能体"
        case "model-selection": return "模型选择"
        case "plan-mode": return "计划模式"
        case "working-directory": return "工作目录"
        case "cordis-host-runner": return "主机运行器"
        case "ptc-mode": return "工具模式"
        case "dsh-session-title-llm": return "会话标题"
        case "compact-checkpoint": return "上下文压缩"
        case "subagent-settled": return "子任务完成"
        default: return nil
        }
    }
}

/// Who the wire says wrote a `user/message`. Only `.user` may be drawn as the reader's own bubble.
struct DSHMessageOrigin: Sendable, Equatable {
    enum Kind: String, Sendable {
        /// The wire said `source.kind == user`: confirmed, and never hidden by a text heuristic.
        case user
        /// Any other explicit source (a schedule, a tool's context, …): shown as a neutral line.
        case context
        /// Old data with no source field at all. Displayed the old way, but not claimed as the reader.
        case legacy
    }
    let kind: Kind
    /// The original source object, kept verbatim so no later rule has to re-read the envelope.
    let rawSource: DSHJSON?
    /// The controlled source name for the notice line ("schedule", …). Never model text.
    let sourceName: String?
    let confidence: Double
}

// MARK: - Turn termination (how the turn ended)

/// The server's short error, when `turn/end` carried one.
struct DSHTerminationError: Sendable, Equatable {
    let code: String?
    let message: String?
    let status: Int?
}

/// How a turn ended. Only `turn/end` produces one: a failed tool, a non-zero exit code, an automatic
/// retry or a dropped socket is never a turn result.
struct DSHTurnTermination: Sendable, Equatable {
    enum Kind: String, Sendable {
        case error, cancelled, interrupted
        /// A recognised non-error end. The conversation gets no extra line for it.
        case normal
        /// The wire carried no reason at all: the turn did end, but nothing says how.
        case unknown
    }
    let turn: Int?
    let kind: Kind
    /// The reason as it arrived, kept so a re-sync never has to guess what it was.
    let rawReason: DSHJSON?
    let errorInfo: DSHTerminationError?
    let cancelSource: String?
    let endSeq: Int64
}

/// Both wire shapes become one immutable event address. The original payload is retained.
struct DSHWireEvent: Equatable, Sendable {
    enum Completeness: Int, Sendable { case live, history }
    let seq: Int64
    let type: String
    var payload: DSHJSON
    var time: Int64
    var completeness: Completeness
    var surfaceOp: DSHJSON
    var sourceEventSeqs: DSHJSON
    var revision: Int64 = 0

    var turn: Int? { payload["turn"].integer.map(Int.init) }
    var step: Int? { payload["step"].integer.map(Int.init) }
    var reasoning: String {
        if completeness == .history, payload["message"].object != nil {
            return Self.content(payload["message"]["content"], type: "reasoning")
        }
        if let s = payload["reasoning"].string { return s }
        return Self.content(payload["message"]["content"], type: "reasoning")
    }
    var text: String {
        if type == "assistant/message" {
            return payload["message"].object != nil
                ? Self.content(payload["message"]["content"], type: "text") : payload["text"].string ?? ""
        }
        if completeness == .history, payload["content"] != .null {
            return payload["content"].string ?? Self.content(payload["content"], type: "text")
        }
        if let s = payload["text"].string { return s }
        if let s = payload["content"].string { return s }
        // A history user/message may carry its blocks under `message.content`, like an assistant one.
        if payload["message"].object != nil {
            return Self.content(payload["message"]["content"], type: "text")
        }
        return Self.content(payload["content"], type: "text")
    }
    var isUser: Bool { origin.map { $0.kind != .context } ?? false }

    // MARK: Tool calls

    /// The call this event names. A history result carries it inside the message (and may repeat it
    /// in `message.source`); a live one puts it at the top level. `nil` means the event names no call
    /// and therefore cannot be paired.
    var callId: String? { Self.callId(in: payload, history: completeness == .history) }
    static func callId(in payload: DSHJSON, history: Bool) -> String? {
        let top = payload["callId"].string
        let inMessage = payload["message"]["toolCallId"].string
        let inMessageSource = payload["message"]["source"]["callId"].string
            ?? payload["message"]["source"]["toolCallId"].string
        // Some history shapes put the call on the event's own `source` instead of the message's.
        let inSource = payload["source"]["callId"].string ?? payload["source"]["toolCallId"].string
        let value = history
            ? (inMessage ?? inMessageSource ?? top ?? inSource)
            : (top ?? inMessage ?? inMessageSource ?? inSource)
        guard let value, !value.isEmpty else { return nil }
        return value
    }
    var toolName: String? { Self.toolName(in: payload) }
    static func toolName(in payload: DSHJSON) -> String? {
        payload["name"].string ?? payload["message"]["name"].string
    }
    /// The arguments exactly as they arrived. A JSON string argument stays that string; it is never
    /// parsed into an object and never dropped when parsing would fail.
    var toolArguments: DSHJSON? { Self.toolArguments(in: payload) }
    static func toolArguments(in payload: DSHJSON) -> DSHJSON? {
        let top = payload["arguments"]
        let inMessage = payload["message"]["arguments"]
        let value = top != .null ? top : inMessage
        return value == .null ? nil : value
    }
    var toolArgumentsText: String? {
        guard let arguments = toolArguments else { return nil }
        let text = arguments.text
        return text.isEmpty ? nil : text
    }
    /// The result body: the gateway's `output` first, then the result block's own text.
    var toolOutput: String? {
        if let output = payload["output"].string, !output.isEmpty { return output }
        let blocks = payload["message"]["content"] != .null ? payload["message"]["content"] : payload["content"]
        let text = Self.resultText(blocks)
        return text.isEmpty ? nil : text
    }
    /// The short preview the server sends alongside a long output.
    var toolPreview: String? {
        guard let preview = payload["preview"].string, !preview.isEmpty else { return nil }
        return preview
    }
    var toolError: DSHJSON? {
        let top = payload["error"]
        let inMessage = payload["message"]["error"]
        let value = top != .null ? top : inMessage
        return value == .null ? nil : value
    }
    /// Whether the tool reported a failure. `false` here is not the same as "the shell exited 0", so
    /// `nil` is kept when the wire said nothing.
    var toolIsError: Bool? {
        if let flag = payload["message"]["isError"].bool ?? payload["isError"].bool { return flag }
        if toolError != nil { return true }
        let blocks = payload["message"]["content"].array
        if blocks.contains(where: { $0["type"].string == "tool-result" && $0["isError"].bool == true }) {
            return true
        }
        return nil
    }
    /// The output was cut server-side; the preview must not be presented as the whole result.
    var outputTruncated: Bool {
        payload["outputTruncated"].bool ?? payload["message"]["outputTruncated"].bool ?? false
    }

    // MARK: Origin

    /// Who wrote this `user/message`. A missing source is old data — not proof the reader typed it —
    /// and a source that says anything but `user` is a context injection, never a user bubble.
    var origin: DSHMessageOrigin? {
        guard type == "user/message" else { return nil }
        let top = payload["source"]
        // Some history shapes put the source inside the message instead of on the event.
        let raw = top != .null ? top : payload["message"]["source"]
        // Live sends `source` as the kind string; history sends the whole source object.
        if let kind = raw.string {
            return Self.origin(kind: kind, rawSource: raw)
        }
        if raw.object != nil {
            return Self.origin(kind: raw["kind"].string ?? "", rawSource: raw)
        }
        return DSHMessageOrigin(kind: .legacy, rawSource: nil, sourceName: nil, confidence: 0)
    }
    private static func origin(kind: String, rawSource: DSHJSON) -> DSHMessageOrigin {
        let name = kind.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !name.isEmpty else {
            return DSHMessageOrigin(kind: .legacy, rawSource: rawSource, sourceName: nil, confidence: 0)
        }
        if name == "user" {
            return DSHMessageOrigin(kind: .user, rawSource: rawSource, sourceName: "user", confidence: 1)
        }
        return DSHMessageOrigin(kind: .context, rawSource: rawSource,
                                sourceName: DSHSourceName.display(for: name), confidence: 1)
    }

    // MARK: Termination

    /// How the turn ended. A structured `reasonDetails.kind` wins over a bare `reason`; a conflicting
    /// pair keeps the raw value instead of picking a winner from the assistant's words.
    var termination: DSHTurnTermination? {
        guard type == "turn/end" else { return nil }
        let details = payload["reasonDetails"]
        let reason = payload["reason"]
        // `reasonDetails` is `{kind, error?, reason?:{kind, reason?}}`: the structured kind wins, then
        // its own nested reason, then the event's bare reason.
        let detailsKind = details["kind"].string
            ?? details["reason"]["kind"].string
            ?? details["reason"].string
        let reasonKind = reason.string ?? reason["kind"].string
        let rawKind = detailsKind ?? reasonKind
        let kind = Self.terminationKind(rawKind)
        let errorValue: DSHJSON = {
            for candidate in [details["error"], reason["error"], reason["failure"], details["failure"]]
            where candidate != .null { return candidate }
            return .null
        }()
        var info: DSHTerminationError?
        if errorValue != .null {
            info = DSHTerminationError(code: errorValue["code"].string,
                                       message: errorValue["message"].string ?? errorValue.string,
                                       status: errorValue["status"].integer.map(Int.init))
        }
        // A bare string reason that is not a known kind is the server's own short message.
        if info == nil, kind == .unknown, let text = reason.string,
           !text.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty {
            info = DSHTerminationError(code: nil, message: text, status: nil)
        }
        // `aborted` covers two different endings: the user cancelled, or the host stopped the turn
        // (its parent aborted, the session was disposed, a hook stopped it). Only the cause separates
        // them, so "取消" is never claimed without it.
        let cause = details["reason"]["kind"].string ?? reason["reason"]["kind"].string
            ?? details["cancelSource"].string ?? reason["cancelSource"].string
        let finalKind: DSHTurnTermination.Kind
        if kind == .cancelled, let cause, cause != "user" { finalKind = .interrupted }
        else { finalKind = kind }
        return DSHTurnTermination(turn: turn, kind: finalKind,
                                  rawReason: detailsKind != nil ? details : reason,
                                  errorInfo: info, cancelSource: cause, endSeq: seq)
    }
    /// Only these reasons may end a turn. Everything the wire did not name is `unknown`, and an
    /// unknown reason is never turned into a success or a failure. The set is closed in practice:
    /// `completed`, `blocked`, `max-tokens`, `aborted`, `error`, `interrupted`, `forked`.
    private static func terminationKind(_ raw: String?) -> DSHTurnTermination.Kind {
        switch (raw ?? "").trimmingCharacters(in: .whitespacesAndNewlines).lowercased() {
        case "": return .unknown
        case "error", "failed", "failure", "errored": return .error
        case "aborted", "abort", "cancelled", "canceled", "cancel": return .cancelled
        case "interrupted", "interrupt": return .interrupted
        case "completed", "complete", "normal", "success", "succeeded", "done", "finished", "end",
             "ended", "blocked", "max-tokens", "max_tokens", "forked":
            return .normal
        // A recognised non-error end that this build does not name: still not an error.
        default: return .normal
        }
    }

    /// The one argument the status line can name: a file's path or the command line. The
    /// classification never reads it; only the line's short description does.
    var toolArgument: String? { Self.toolArgument(toolArguments, toolName: toolName) }

    /// Shared by the live event path and the snapshot path so both name a tool the same way.
    static func toolArgument(_ raw: DSHJSON?, toolName: String?) -> String? {
        // `arguments` is JSON and not guaranteed to be an object: a JSON string is parsed for the one
        // key that matters, and an unparsable string simply names nothing.
        guard let object = raw?.object ?? raw?.string.flatMap(parsedObject) else { return nil }
        func text(_ key: String) -> String? {
            guard let value = object[key]?.string, !value.isEmpty else { return nil }
            return value
        }
        switch DSHActivityKind.forTool(named: toolName ?? "") {
        case .reading, .editing:
            for key in ["path", "file_path", "filePath", "filename", "file", "target_file", "targetFile"] {
                if let value = text(key) { return value }
            }
            return nil
        case .executing:
            for key in ["command", "cmd", "script"] {
                if let value = text(key) { return value }
            }
            return nil
        case .thinking, .typing, .processing:
            // A tool outside the whitelist may wrap more than one kind of work, so it names no
            // argument: the line shows the tool's own name instead. Unchanged from C0212.
            return nil
        }
    }
    private static func parsedObject(_ text: String) -> [String: DSHJSON]? {
        guard let data = text.data(using: .utf8),
              let value = try? JSONSerialization.jsonObject(with: data, options: [.fragmentsAllowed])
        else { return nil }
        return DSHJSON(value).object
    }

    /// The rows this event's own step committed. Tools are no longer collected per turn and attached
    /// to every assistant message: the transcript shows no tool bubble, and the status line reads
    /// structured `tool/call` events instead.
    var tools: [DSHTool] { [] }

    // MARK: Pictures

    /// The pictures this event refers to. Only references live here — the bytes come from an
    /// `attachment` request when the row is on screen. A message may carry pictures and no text.
    var images: [DSHImageRef] { Self.images(in: payload) }
    static func images(in payload: DSHJSON) -> [DSHImageRef] {
        var refs: [DSHImageRef] = []
        var seen = Set<String>()
        func append(_ ref: DSHImageRef?) {
            guard let ref, seen.insert(ref.attachmentId).inserted else { return }
            refs.append(ref)
        }
        // A live event lists them at the top level; a history one keeps them as content blocks, whose
        // attachment object holds the reference.
        for value in payload["images"].array { append(imageRef(value)) }
        let blocks = payload["message"]["content"] != .null ? payload["message"]["content"] : payload["content"]
        for block in blocks.array where block["type"].string == "image" {
            append(imageRef(block["attachment"] != .null ? block["attachment"] : block))
        }
        return refs
    }
    private static func imageRef(_ value: DSHJSON) -> DSHImageRef? {
        guard let id = value["attachmentId"].string, !id.isEmpty else { return nil }
        return DSHImageRef(attachmentId: id,
                           mediaType: value["mediaType"].string ?? "image/jpeg",
                           bytes: value["bytes"].integer.map(Int.init),
                           width: value["width"].integer.map(Int.init),
                           height: value["height"].integer.map(Int.init),
                           name: value["name"].string)
    }

    /// Compare facts, not the different live/history envelope shapes.
    func contradicts(_ other: DSHWireEvent) -> Bool {
        if type != other.type { return true }
        if let a = turn, let b = other.turn, a != b { return true }
        if let a = step, let b = other.step, a != b { return true }
        let isMessage = type == "user/message" || type == "assistant/message"
        return isMessage && hasText && other.hasText && text != other.text
    }
    private var hasText: Bool {
        payload["text"].string != nil || payload["content"] != .null || payload["message"]["content"] != .null
    }

    static func live(_ frame: DSHFrame) -> DSHWireEvent? {
        guard let seq = DSHJSON(frame.json["seq"] ?? NSNull()).integer, seq >= 0,
              let body = frame.dict("event"), let type = body["type"] as? String else { return nil }
        return make(seq, type, body, frame.json, .live)
    }
    static func history(_ record: [String: Any]) -> DSHWireEvent? {
        guard let seq = DSHJSON(record["seq"] ?? NSNull()).integer, seq >= 0,
              let type = record["type"] as? String, let body = record["data"] as? [String: Any] else { return nil }
        return make(seq, type, body, record, .history)
    }
    private static func make(_ seq: Int64, _ type: String, _ body: [String: Any], _ envelope: [String: Any],
                             _ completeness: Completeness) -> DSHWireEvent {
        let time = (envelope["time"] as? NSNumber)?.doubleValue ?? 0
        let milliseconds = time > 10_000_000_000 ? time : time * 1000
        return DSHWireEvent(seq: seq, type: type, payload: DSHJSON(body),
                            time: milliseconds.isFinite && abs(milliseconds) < Double(Int64.max) ? Int64(milliseconds) : 0,
                            completeness: completeness, surfaceOp: DSHJSON(envelope["surfaceOp"] ?? NSNull()),
                            sourceEventSeqs: DSHJSON(envelope["sourceEventSeqs"] ?? NSNull()))
    }
    private static func content(_ value: DSHJSON, type: String) -> String {
        value.array.filter { $0["type"].string == type }.compactMap { $0["text"].string }.joined()
    }
    /// A `tool-result` block keeps its text one level down: `content: [{type: text, text: …}]`. The
    /// current session format lifts those text blocks to the message level instead, so both shapes
    /// are read; a flat block list is taken as text directly.
    private static func resultText(_ value: DSHJSON) -> String {
        let blocks = value.array
        guard !blocks.isEmpty else { return "" }
        let wrapped = blocks.filter { $0["type"].string == "tool-result" }
        if !wrapped.isEmpty {
            return wrapped.map { content($0["content"], type: "text") }.joined()
        }
        return content(value, type: "text")
    }
}

struct DSHWireSnapshot: Sendable {
    let subscriptionId: String
    let streamId: String
    let cursor: Int64
    let revision: Int64
    let events: [DSHWireEvent]
    let rawAttempt: DSHJSON
    let hasMore: Bool
    let nextBeforeSeq: Int64?

    init?(_ frame: DSHFrame, format: Int) {
        guard frame.int("historyFormatVersion") == format,
              let sub = frame.string("subscriptionId"), let stream = frame.string("streamId"),
              let cursor = DSHJSON(frame.json["cursor"] ?? NSNull()).integer, cursor >= -1,
              let baseline = frame.dict("assistantStream"),
              let revision = DSHJSON(baseline["revision"] ?? NSNull()).integer, revision >= 0 else { return nil }
        guard let records = frame.array("events"), let more = frame.bool("hasMore") else { return nil }
        let events = records.compactMap(DSHWireEvent.history)
        guard events.count == records.count, events.allSatisfy({ $0.seq <= cursor }) else { return nil }
        self.subscriptionId = sub; self.streamId = stream; self.cursor = cursor; self.revision = revision
        self.events = events; rawAttempt = DSHJSON(baseline["activeAttempt"] ?? NSNull())
        hasMore = more
        nextBeforeSeq = DSHJSON(frame.json["nextBeforeSeq"] ?? NSNull()).integer
    }
}

/// A transient attempt has its own clock and row identity, never a persistent seq.
struct DSHTranscriptAttempt: Sendable {
    let id: String
    let rowId: String
    let startedAfterSeq: Int64
    let turn: Int
    let step: Int
    var nextIndex: Int64 = 0
    var text = ""
    var reasoning = ""
    var time: Int64 = 0
    var revision: Int64 = 0
    var candidates = Set<Int64>()
    var chunks: [DSHJSON] = []

    init?(raw: DSHJSON, scope: DSHSessionScope, streamId: String) {
        guard let id = raw["attemptId"].string, !id.isEmpty,
              let after = raw["startedAfterSeq"].integer, after >= -1,
              let turn = raw["turn"].integer, turn >= 0, let step = raw["step"].integer, step >= 0 else { return nil }
        self.id = id; self.startedAfterSeq = after; self.turn = Int(turn); self.step = Int(step)
        rowId = scope.identity([.text("attempt"), .text(streamId), .text(id)])
    }
    mutating func append(_ chunk: DSHJSON, time: Int64) {
        chunks.append(chunk)
        switch chunk["type"].string {
        case "text-delta": text += chunk["text"].string ?? chunk["textDelta"].string ?? ""
        case "reasoning-delta": reasoning += chunk["text"].string ?? chunk["textDelta"].string ?? ""
        default: break
        }
        if self.time == 0 { self.time = time }
    }
    mutating func restore(_ records: [DSHJSON]) {
        for record in records {
            if time == 0, let t = record["time0"].integer ?? record["time"].integer,
               t >= 0, t <= Int64.max / 1000 { time = t > 10_000_000_000 ? t : t * 1000 }
            switch record["type"].string {
            case "text-chunks": text += record["texts"].array.compactMap(\.string).joined()
            case "reasoning-chunks": reasoning += record["texts"].array.compactMap(\.string).joined()
            case "chunk": append(record["chunk"], time: record["time"].integer ?? 0)
            default: break
            }
        }
    }
}

/// Queue entries are read-only hints, never proof that an identical local submission was delivered.
public struct DSHQueueHint: Identifiable, Hashable, Sendable {
    public let id: String
    public let text: String
    public let placement: String

    static func decode(_ raw: [[String: Any]]) -> [DSHQueueHint] {
        raw.compactMap { item in
            let value = DSHJSON(item)
            guard let id = value["id"].string else { return nil }
            let text = value["message"]["content"].array
                .filter { $0["type"].string == "text" }.compactMap { $0["text"].string }.joined()
            return DSHQueueHint(id: id, text: text, placement: value["placement"].string ?? "queued")
        }
    }
}
