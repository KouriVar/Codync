import CodyncKit
import SwiftUI

/// The skill a details sheet shows: an installed one, or one from the catalog.
struct SkillRef: Identifiable {
    let id: String
    let name: String
    let description: String
    /// A catalog skill's folder in anthropics/skills; `nil` for an installed skill.
    var source: String?
    var installed = true

    init(_ skill: InstalledSkill) {
        (id, name, description) = (skill.id, skill.name, skill.description)
    }

    init(_ skill: MarketSkill, installed: Bool) {
        (id, name, description, source, self.installed) = ("catalog/\(skill.source)", skill.name, skill.description, skill.source, installed)
    }

    /// What the host's `skillDetails` looks it up by.
    var request: [String: String] { source.map { ["source": $0] } ?? ["id": id] }
}

/// A skill's details (desktop `SkillSheet`): what it tells the bot, its `SKILL.md`, with Add
/// while it isn't installed.
struct SkillSheet: View {
    let skill: SkillRef
    @Environment(BotStore.self) private var model
    @State private var markdown: String?
    @State private var error: String?
    @State private var adding = false

    private var added: Bool {
        guard let source = skill.source else { return true }
        return skill.installed || model.installedSkills.contains { $0.id == source.lowercased() }
    }

    var body: some View {
        NativeExtensionSheet(skill.name, busy: adding, actionTitle: added ? nil : "Add", action: add) {
            Form {
                if !skill.description.isEmpty {
                    NativeFormSection {
                        Text(skill.description).font(.subheadline).foregroundStyle(Palette.secondary)
                    }
                }
                NativeFormSection("Instructions", footer: added ? "Bots read these before using the skill." : "Add it to let bots use these instructions.") {
                    if let markdown {
                        if markdown.isEmpty {
                            Text(L10n.tr("No instructions.")).foregroundStyle(Palette.secondary)
                        } else {
                            MarkdownText(markdown)
                        }
                    } else if error == nil {
                        ProgressView()
                    }
                }
                if let error {
                    NativeFormSection {
                        Text(L10n.tr(error)).font(.footnote).foregroundStyle(Palette.danger)
                    }
                }
            }
        }
        .task {
            do {
                markdown = try await model.skillDetails(skill)
            } catch {
                self.error = error.localizedDescription
            }
        }
    }

    private func add() {
        guard !adding, let source = skill.source else { return }
        adding = true
        error = nil
        Task {
            do {
                try await model.installSkill(source: source)
            } catch {
                self.error = error.localizedDescription
            }
            adding = false
        }
    }
}
