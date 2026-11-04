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

/// A conversation row shown in the DSH chat screen.
public struct DSHMessage: Identifiable, Hashable, Sendable {
    public enum Role: String, Sendable { case user, assistant }
    public let id: String
    public let role: Role
    public var text: String
    public var streaming: Bool

    public init(id: String = UUID().uuidString, role: Role, text: String, streaming: Bool = false) {
        self.id = id
        self.role = role
        self.text = text
        self.streaming = streaming
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
