import CodyncKit
import SwiftUI

/// A new bot, profile first (Grok Bot's Create New Bot): its avatar and name. Everything else
/// starts on the usual defaults and is changed afterwards in the bot's Settings.
public struct NewBotView: View {
    @Environment(BotStore.self) private var model
    @Environment(\.dismissModal) private var dismiss
    @State private var draft = BotDraft()
    @State private var saving = false
    @State private var error: String?
    private let computers: [(id: ComputerID, label: String)]
    @Binding private var computer: ComputerID

    /// `computers` can take the bot; the caller swaps the `BotStore` to match `computer`.
    public init(computers: [(id: ComputerID, label: String)], computer: Binding<ComputerID>) {
        self.computers = computers
        _computer = computer
    }

    public var body: some View {
        CreateForm(title: "New bot", placeholder: "Name your bot", name: $draft.name, saving: saving,
                   canCreate: !saving && model.connection == .online, error: error, create: save) {
            CharacterAvatar(shape: draft.avatarShape, color: draft.avatarColor, size: 96)
        } content: {
            Section(L10n.tr("Appearance")) {
                AvatarPicker(shape: $draft.avatarShape, color: $draft.avatarColor)
                    .padding(.vertical, 8)
            }
            if computers.count > 1 || model.connection != .online {
                Section(L10n.tr("Computer")) {
                    if computers.count > 1 {
                        Picker(L10n.tr("Computer"), selection: $computer) {
                            ForEach(computers, id: \.id) { Text($0.label).tag($0.id) }
                        }
                        .pickerStyle(.navigationLink)
                    }
                    if model.connection != .online {
                        Text(L10n.tr(computers.count > 1
                            ? "Connect this computer to create the bot, or choose another computer."
                            : "Connect this computer to create the bot."))
                            .font(.footnote).foregroundStyle(.secondary)
                    }
                }
            }
        }
    }

    private func save() {
        guard !saving, model.connection == .online else { return }
        saving = true
        error = nil
        var draft = draft
        draft.name = draft.name.trimmingCharacters(in: .whitespacesAndNewlines)
        model.fillDefaults(&draft)
        Task {
            do {
                let bot = try await model.save(draft)
                dismiss()
                model.selection = bot.id
            } catch {
                withAnimation(Motion.fade) { self.error = error.localizedDescription }
            }
            saving = false
        }
    }
}

private extension BotStore {
    /// Picks an installed agent we know (a registry agent nobody chose is never the default);
    /// empty cwd requests a personal workspace from the host. Connectors and skills stay unset:
    /// the host turns on every one it can run.
    func fillDefaults(_ draft: inout BotDraft) {
        if hello?.backends.first(where: { $0.id == draft.backend })?.available != true,
           let first = hello?.backends.first(where: { $0.available && $0.curated == true }) {
            draft.backend = first.id
        }
    }
}

/// A new group chat, laid out like a new bot: who's in it and its name. What it works on is set
/// afterwards in the group editor.
public struct NewGroupView: View {
    @Environment(BotStore.self) private var model
    @Environment(\.dismissModal) private var dismiss
    @State private var name = ""
    @State private var members: [String] = []
    @State private var saving = false
    @State private var error: String?

    public init() {}

    private var picked: [Bot] { members.compactMap { model.bots[$0] } }
    /// "Alice, Bob" when no name is typed.
    private var defaultName: String { picked.map(\.name).joined(separator: ", ") }

    public var body: some View {
        CreateForm(title: "New group chat", placeholder: picked.isEmpty ? "Name your group" : defaultName, name: $name,
                   saving: saving, canCreate: !members.isEmpty && !saving, error: error, create: save) {
            GroupAvatar(members: picked, size: 96)
                .animation(Motion.layout, value: members)
        } content: {
            let bots = model.roster.filter { !$0.isGroup }
            Section {
                if bots.isEmpty {
                    Text(L10n.tr("No bots yet. Create a bot first.")).font(.subheadline).foregroundStyle(.secondary)
                } else {
                    WrapLayout(spacing: 8) {
                        ForEach(bots) { tile($0) }
                    }
                    .padding(.vertical, 8)
                }
            } header: { Text(L10n.tr("Members")) } footer: {
                Text(L10n.tr("Everyone answers in turn unless you @mention someone."))
            }
        }
    }

    /// A bot to pick: its avatar, ringed once picked, with its name under it.
    private func tile(_ bot: Bot) -> some View {
        let chosen = members.contains(bot.id)
        return Button { toggle(bot.id) } label: {
            VStack(spacing: 4) {
                CharacterAvatar(bot: bot, size: 44, animated: false).choiceRing(chosen)
                Text(bot.name)
                    .font(.caption)
                    .foregroundStyle(chosen ? Palette.text : Palette.secondary)
                    .lineLimit(1)
            }
            .frame(width: 64)
            .contentShape(Rectangle())
        }
        .buttonStyle(.plain)
        .accessibilityLabel(bot.name)
        .accessibilityAddTraits(chosen ? .isSelected : [])
    }

    private func toggle(_ id: String) {
        withAnimation(Motion.layout) {
            if members.contains(id) { members.removeAll { $0 == id } } else { members.append(id) }
        }
    }

    private func save() {
        guard !members.isEmpty, !saving else { return }
        saving = true
        error = nil
        let typed = name.trimmingCharacters(in: .whitespacesAndNewlines)
        let name = typed.isEmpty ? defaultName : typed
        Task {
            do {
                _ = try await model.createGroup(name: name, members: members)
                dismiss()
            } catch {
                withAnimation(Motion.fade) { self.error = error.localizedDescription }
            }
            saving = false
        }
    }
}

/// Shared native creation form: avatar preview, name, option sections and save errors.
private struct CreateForm<Preview: View, Content: View>: View {
    let title: String
    let placeholder: String
    @Binding var name: String
    let saving: Bool
    let canCreate: Bool
    let error: String?
    let create: () -> Void
    @ViewBuilder let preview: Preview
    @ViewBuilder let content: Content
    @FocusState private var naming: Bool

    @Environment(\.dismissModal) private var dismiss

    var body: some View {
        NavigationStack {
            Form {
                Section {
                    preview.frame(maxWidth: .infinity).padding(.vertical, 16)
                        .listRowBackground(Color.clear)
                }
                Section(L10n.tr("Name")) {
                    TextField(L10n.tr(placeholder), text: $name)
                        .submitLabel(.done)
                        .focused($naming)
                        .onSubmit { if canCreate { create() } }
                }
                content
                if let error {
                    Section { Text(L10n.tr(error)).font(.footnote).foregroundStyle(.red) }
                }
            }
            .disabled(saving)
            .scrollDismissesKeyboard(.interactively)
            .navigationTitle(L10n.tr(title))
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .cancellationAction) {
                    Button(action: {  dismiss()  }) { RemixImage("close-line", size: 24) }.accessibilityLabel(Text(L10n.tr("Cancel"))).buttonBorderShape(.circle)
                        .disabled(saving)
                }
                ToolbarItem(placement: .confirmationAction) {
                    Button(action: create) {
                        if saving { ProgressView() } else { Text(L10n.tr("Create")) }
                    }
                    .buttonStyle(.glassProminent)
                    .buttonBorderShape(.capsule)
                    .tint(.primary)
                    .foregroundStyle(Color(uiColor: .systemBackground))
                    .disabled(!canCreate)
                }
            }
        }
        .tint(.primary)
        .interactiveDismissDisabled(saving)
        .onAppear {
            #if DEBUG
            if ProcessInfo.processInfo.environment["CODYNC_CREATE_PREVIEW"] != nil { return }
            #endif
            naming = true
        }
    }
}
