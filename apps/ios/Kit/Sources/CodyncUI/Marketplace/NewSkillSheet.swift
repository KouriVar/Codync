import CodyncKit
import SwiftUI

struct NewSkillSheet: View {
    @Environment(BotStore.self) private var model
    @Environment(\.dismissModal) private var dismiss
    @State private var name = ""
    @State private var summary = ""
    @State private var instructions = ""
    @State private var saving = false
    @State private var error: String?

    private var ready: Bool {
        !name.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty
            && !instructions.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty
    }

    var body: some View {
        NativeExtensionSheet("New skill", busy: saving, actionTitle: "Save", actionEnabled: ready, action: save) {
            form.disabled(saving)
        }
    }

    private func save() {
        guard !saving, ready else { return }
        saving = true
        error = nil
        Task {
            defer { saving = false }
            do {
                try await model.addSkill(name: name, description: summary, instructions: instructions)
                dismiss()
            } catch { self.error = error.localizedDescription }
        }
    }

    private var form: some View {
        Form {
            NativeFormSection(footer: "The bot sees the name and when to use it, and reads the instructions only when a task fits.") {
                TextField(L10n.tr("Name"), text: $name)
                TextField(L10n.tr("When to use it"), text: $summary, axis: .vertical).lineLimit(2...4)
            }
            NativeFormSection("Instructions") {
                TextField(L10n.tr("Step by step, in plain words…"), text: $instructions, axis: .vertical)
                    .lineLimit(6...20)
            }
            if let error {
                NativeFormSection { Text(L10n.tr(error)).foregroundStyle(Palette.danger) }
            }
        }
        .textFieldStyle(.plain)
    }
}
