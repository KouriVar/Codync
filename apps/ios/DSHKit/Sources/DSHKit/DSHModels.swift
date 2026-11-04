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

/// A tool the assistant ran inside one message: what it called, and the result's short preview.
public struct DSHTool: Identifiable, Hashable, Sendable {
    public let id: String
    public let name: String
    public let arguments: String
    public var output: String?
    public var isError: Bool

    public init(id: String, name: String, arguments: String = "", output: String? = nil, isError: Bool = false) {
        self.id = id
        self.name = name
        self.arguments = arguments
        self.output = output
        self.isError = isError
    }
}

/// A conversation row shown in the DSH chat screen.
public struct DSHMessage: Identifiable, Hashable, Sendable {
    public enum Role: String, Sendable { case user, assistant }
    public let id: String
    public let role: Role
    public var text: String
    public var streaming: Bool
    /// The assistant's reasoning for this message (the `reasoning` field of `assistant/message`).
    public var reasoning: String
    /// Tools called in this step, in order.
    public var tools: [DSHTool]
    /// The turn this message belongs to.
    public var turn: Int?
    /// Time from the turn's start to this message.
    public var durationSeconds: Int?
    /// When it was written (ms since epoch).
    public var createdAt: Int64

    public init(id: String = UUID().uuidString, role: Role, text: String, streaming: Bool = false,
                reasoning: String = "", tools: [DSHTool] = [], turn: Int? = nil, durationSeconds: Int? = nil,
                createdAt: Int64 = Int64(Date().timeIntervalSince1970 * 1000)) {
        self.id = id
        self.role = role
        self.text = text
        self.streaming = streaming
        self.reasoning = reasoning
        self.tools = tools
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
    public enum Kind: Sendable { case user, assistant }
    public let id: String
    public let kind: Kind
    public let text: String
    public let summary: DSHSummary?
    /// When the message was written (ms since epoch), for the page's time separators.
    public let createdAt: Int64

    public init(id: String, kind: Kind, text: String, summary: DSHSummary?, createdAt: Int64) {
        self.id = id
        self.kind = kind
        self.text = text
        self.summary = summary
        self.createdAt = createdAt
    }
}

/// Turns DSH's messages into the intermediate rows the host maps onto Codync's chat model.
/// (DSHKit does not depend on CodyncKit: the host owns that last hop.)
public enum DSHConversationAdapter {
    public static func transcript(from messages: [DSHMessage]) -> [DSHTranscriptItem] {
        messages.map { message in
            if message.role == .user {
                return DSHTranscriptItem(id: message.id, kind: .user, text: message.text,
                                         summary: nil, createdAt: message.createdAt)
            }
            let hasDetail = !message.reasoning.isEmpty || !message.tools.isEmpty
            let summary = hasDetail
                ? DSHSummary(id: message.id, title: title(for: message),
                             reasoning: message.reasoning, tools: message.tools)
                : nil
            return DSHTranscriptItem(id: message.id, kind: .assistant, text: message.text,
                                     summary: summary, createdAt: message.createdAt)
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
