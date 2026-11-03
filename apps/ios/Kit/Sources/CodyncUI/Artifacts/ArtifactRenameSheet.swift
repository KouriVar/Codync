import CodyncKit
import SwiftUI

/// An artifact's new title; the computer trims it and every app shows it.
struct ArtifactRenameSheet: View {
    let artifact: Artifact
    @Environment(BotStore.self) private var model
    @Environment(\.dismissModal) private var dismiss
    @State private var title: String
    @State private var saving = false
    @State private var error: String?
    @FocusState private var focused: Bool

    init(artifact: Artifact) {
        self.artifact = artifact
        _title = State(initialValue: artifact.title)
    }

    private var trimmed: String { title.trimmingCharacters(in: .whitespacesAndNewlines) }

    var body: some View {
        NavigationStack {
            Form {
                Section {
                    TextField(L10n.tr("Artifact title"), text: $title)
                        .focused($focused)
                        .submitLabel(.done)
                        .onSubmit(save)
                }
                if let error {
                    Section {
                        Text(L10n.tr(error)).font(.caption).foregroundStyle(Palette.danger).textSelection(.enabled)
                    }
                }
            }
            .navigationTitle(L10n.tr("Rename artifact"))
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .cancellationAction) {
                    Button(L10n.tr("Cancel")) { dismiss() }
                }
                ToolbarItem(placement: .confirmationAction) {
                    if saving { ProgressView() } else {
                        Button(L10n.tr("Save")) { save() }
                            .disabled(trimmed.isEmpty || trimmed == artifact.title)
                    }
                }
            }
        }
        .tint(.primary)
        .presentationDetents([.medium])
        .onAppear { focused = true }
    }

    private func save() {
        guard !saving, !trimmed.isEmpty, trimmed != artifact.title else { return }
        saving = true
        Task {
            do {
                try await model.renameArtifact(artifact, title: trimmed)
                dismiss()
            } catch {
                self.error = error.localizedDescription
            }
            saving = false
        }
    }
}
