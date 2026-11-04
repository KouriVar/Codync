import Foundation
import Security

/// What the DSH web UI encodes into its pairing QR code (payload version 2).
public struct DSHPairingCode: Sendable {
    public let gatewayId: String
    public let gatewayName: String
    public let endpoints: [String]
    public let pairingCode: String
    public let expiresAt: Date?

    /// Decodes the `qrPayload` string. Accepts the raw base64url payload dsh puts in the QR,
    /// or a URL that carries it (some builds encode the payload in a link instead).
    public static func decode(qrPayload: String) throws -> DSHPairingCode {
        let trimmed = qrPayload.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !trimmed.isEmpty else { throw DSHError.badQRCode("内容是空的") }
        guard let data = jsonData(from: trimmed),
              let object = try? JSONSerialization.jsonObject(with: data) as? [String: Any] else {
            throw DSHError.badQRCode("不是 base64url 的 JSON")
        }
        let version = (object["version"] as? NSNumber)?.intValue ?? 0
        guard version == 2 else { throw DSHError.badQRCode("payload 版本 \(version)") }
        guard let code = object["pairingCode"] as? String, !code.isEmpty else {
            throw DSHError.badQRCode("缺少配对码")
        }
        var endpoints: [String] = []
        if let list = object["endpoints"] as? [String] { endpoints = list }
        if let single = object["publicUrl"] as? String, !single.isEmpty, !endpoints.contains(single) {
            endpoints.insert(single, at: 0)
        }
        guard !endpoints.isEmpty else { throw DSHError.badQRCode("没有可用地址") }
        let expiry = (object["expiresAt"] as? NSNumber).map { Date(timeIntervalSince1970: $0.doubleValue / 1000) }
        return DSHPairingCode(
            gatewayId: object["gatewayId"] as? String ?? "",
            gatewayName: object["gatewayName"] as? String ?? "DSH",
            endpoints: endpoints,
            pairingCode: code,
            expiresAt: expiry
        )
    }

    /// The JSON bytes behind the payload: either the payload itself, or a value carried in a URL
    /// (`?payload=…`, `?p=…`, or the whole query when it is the only item), percent-decoded.
    private static func jsonData(from text: String) -> Data? {
        if let direct = base64URLDecode(text) { return direct }
        // A URL form: take the payload out of its query.
        if let comps = URLComponents(string: text) {
            let items = comps.queryItems ?? []
            for key in ["payload", "p", "qrPayload", "code"] {
                if let value = items.first(where: { $0.name == key })?.value,
                   let data = base64URLDecode(value) { return data }
            }
            if items.count == 1, let value = items[0].value, let data = base64URLDecode(value) { return data }
            // A `dsh://<payload>` style link: the last path component.
            if let last = comps.path.split(separator: "/").last, let data = base64URLDecode(String(last)) {
                return data
            }
        }
        return nil
    }

    private static func base64URLDecode(_ value: String) -> Data? {
        let cleaned = value.removingPercentEncoding?
            .trimmingCharacters(in: .whitespacesAndNewlines)
            .filter { !$0.isWhitespace } ?? ""
        guard !cleaned.isEmpty else { return nil }
        var s = cleaned.replacingOccurrences(of: "-", with: "+").replacingOccurrences(of: "_", with: "/")
        let pad = s.count % 4
        if pad > 0 { s += String(repeating: "=", count: 4 - pad) }
        return Data(base64Encoded: s)
    }
}

/// A paired gateway. The token is a credential: it lives in the Keychain, never in defaults.
public struct DSHGatewayProfile: Codable, Hashable, Sendable, Identifiable {
    public var id: String          // gatewayId
    public var name: String
    public var endpoint: String    // ws(s)://host/ws/mobile
    public var token: String

    public init(id: String, name: String, endpoint: String, token: String) {
        self.id = id
        self.name = name
        self.endpoint = endpoint
        self.token = token
    }
}

/// The device's stable identity for the gateway: the same value on every reconnect, so the host
/// can keep one device row instead of one per connection.
enum DSHDeviceIdentity {
    private static let key = "dsh.gateway.deviceID"

    static func loadOrCreate() -> String {
        if let existing = UserDefaults.standard.string(forKey: key), existing.count >= 8 { return existing }
        let id = UUID().uuidString.lowercased()
        UserDefaults.standard.set(id, forKey: key)
        return id
    }
}

/// Keychain-backed store: one item per gateway (account = gateway id).
enum DSHCredentialStore {
    private static let service = "com.suiyikou.codync.dsh-gateway"

    static func save(_ profile: DSHGatewayProfile) throws {
        let blob = try JSONEncoder().encode(profile)
        let query: [String: Any] = [
            kSecClass as String: kSecClassGenericPassword,
            kSecAttrService as String: service,
            kSecAttrAccount as String: profile.id,
        ]
        SecItemDelete(query as CFDictionary)
        var add = query
        add[kSecValueData as String] = blob
        add[kSecAttrAccessible as String] = kSecAttrAccessibleAfterFirstUnlock
        let status = SecItemAdd(add as CFDictionary, nil)
        guard status == errSecSuccess else { throw DSHError.transport("Keychain 写入失败 (\(status))") }
    }

    static func load() -> [DSHGatewayProfile] {
        let query: [String: Any] = [
            kSecClass as String: kSecClassGenericPassword,
            kSecAttrService as String: service,
            kSecReturnData as String: true,
            kSecMatchLimit as String: kSecMatchLimitAll,
        ]
        var result: CFTypeRef?
        guard SecItemCopyMatching(query as CFDictionary, &result) == errSecSuccess,
              let items = result as? [Data] else { return [] }
        let decoder = JSONDecoder()
        return items.compactMap { try? decoder.decode(DSHGatewayProfile.self, from: $0) }
    }

    static func delete(id: String) {
        let query: [String: Any] = [
            kSecClass as String: kSecClassGenericPassword,
            kSecAttrService as String: service,
            kSecAttrAccount as String: id,
        ]
        SecItemDelete(query as CFDictionary)
    }
}
