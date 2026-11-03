import CodyncKit
import Observation

/// A native editor commits on Done and rebases untouched settings from the live host.
@MainActor @Observable
final class BotEditSession {
    var draft: BotDraft
    private var base: BotDraft
    private(set) var saving = false
    private(set) var error: String?

    init(_ bot: Bot) {
        let draft = BotDraft(bot)
        self.draft = draft
        base = draft
    }

    func rebase(_ fresh: BotDraft) {
        draft = draft.rebased(from: base, onto: fresh)
        base = fresh
    }

    func save(to store: BotStore) async -> Bool {
        guard draft.isValid, !saving else { return false }
        guard let id = draft.id, let latest = store.bots[id] else {
            error = "Bot 已不可用，无法保存。"
            return false
        }
        rebase(BotDraft(latest))
        saving = true
        defer { saving = false }
        do {
            let saved = try await store.save(draft.normalized)
            draft = BotDraft(saved)
            base = draft
            error = nil
            return true
        } catch {
            self.error = error.localizedDescription
            return false
        }
    }
}
