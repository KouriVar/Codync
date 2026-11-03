import CodyncKit
import SwiftUI

/// A portable settings snapshot, with no conversation identity or runtime state.
public struct BotTemplateView: View {
    @Environment(\.accessibilityReduceMotion) private var reduceMotion
    @State private var copied = false
    private let template: BotDraft
    private let encoded: String?

    public init(draft: BotDraft) {
        var template = draft
        template.id = nil
        template.pinned = nil
        template.hidden = nil
        template.fallbacks = nil
        template.selfFallbacks = nil
        // Who reaches a bot belongs to its computer, not its setup.
        template.offeredToNetwork = nil
        template.reachableByAssistants = nil
        self.template = template
        let encoder = JSONEncoder()
        encoder.outputFormatting = [.prettyPrinted, .sortedKeys, .withoutEscapingSlashes]
        encoded = (try? encoder.encode(template)).flatMap { String(data: $0, encoding: .utf8) }
    }

    public var body: some View {
        NativeExtensionSheet("Create template") {
            Form {
                Section {
                    Text(template.name).font(.headline)
                    Text(L10n.tr("Copy this bot’s settings to reuse as a template. Conversation history and conversation ID are excluded."))
                        .font(.footnote).foregroundStyle(.secondary)
                }
                Section {
                    Text(encoded ?? L10n.tr("Unable to create this template."))
                        .font(.system(.footnote, design: .monospaced))
                        .textSelection(.enabled)
                    Button {
                        Pasteboard.copy(encoded)
                        withAnimation(Motion.reduced(Motion.morph, reduceMotion)) { copied = true }
                    } label: {
                        Label(L10n.tr(copied ? "Copied" : "Copy template"), systemImage: copied ? "checkmark" : "square.on.square")
                    }.disabled(encoded == nil)
                } footer: { Text(L10n.tr("Includes workspace preferences and agent configuration.")) }
            }
        }
    }
}
