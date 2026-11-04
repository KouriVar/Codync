import CodyncKit
import Foundation

public extension BotStore {
    /// Sends like the composer does — same entry, same outbox — and reports whether it landed, so the
    /// voice sheet can keep the words when the computer (or the mailbox) never took them.
    func sendAndConfirm(_ text: String, to botId: String, files: [OutgoingFile] = []) async -> Bool {
        guard let delivery = send(text, to: botId, replyTo: nil, nonce: UUID().uuidString, files: files) else { return false }
        let progress = await delivery.value
        if case .failed = progress { return false }
        return true
    }
}
