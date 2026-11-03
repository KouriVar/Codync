import Foundation

/// Device-only reminders for older hosts that have no mark-unread operation.
/// Account, computer and Bot identity stay separate; normal host unread counts are untouched.
public struct ManualUnreadMarks {
    private var keys: Set<String>
    public init(data: Data) { keys = (try? JSONDecoder().decode(Set<String>.self, from: data)) ?? [] }
    public var data: Data { (try? JSONEncoder().encode(keys)) ?? Data() }

    private func key(_ account: String?, _ computer: String, _ bot: String) -> String {
        let parts = [account ?? "", computer, bot]
        return (try? JSONEncoder().encode(parts).base64EncodedString()) ?? ""
    }
    public func contains(account: String?, computer: String, bot: String) -> Bool {
        keys.contains(key(account, computer, bot))
    }
    public mutating func set(_ unread: Bool, account: String?, computer: String, bot: String) {
        let id = key(account, computer, bot)
        if unread { keys.insert(id) } else { keys.remove(id) }
    }
}
