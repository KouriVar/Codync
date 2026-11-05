import Foundation
import CoreFoundation

/// Owned JSON values: history may carry structured arguments, not just strings.
enum DSHJSON: Equatable, Sendable {
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
        return Self.content(payload["content"], type: "text")
    }
    var isUser: Bool {
        let source = payload["source"].string ?? payload["source"]["kind"].string
        return type == "user/message" && (source == nil || source == "user")
    }
    var tools: [DSHTool] {
        let calls = payload["message"].object == nil ? payload["toolCalls"].array
            : payload["message"]["content"].array.filter { $0["type"].string == "tool-call" }
        return calls.compactMap { value in
            guard let id = value["id"].string else { return nil }
            return DSHTool(id: id, name: value["name"].string ?? "tool", arguments: value["arguments"].text)
        }
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
