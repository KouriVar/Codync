import CodyncKit
import SwiftUI

struct BotProfileEditView: View {
    let botId: String
    @State private var session: BotEditSession
    @State private var pickingAvatar = false
    @Environment(BotStore.self) private var model
    @Environment(\.dismiss) private var dismiss

    init(bot: Bot) {
        botId = bot.id
        _session = State(initialValue: BotEditSession(bot))
    }

    var body: some View {
        @Bindable var session = session
        Form {
            Section {
                Button { pickingAvatar = true } label: {
                    CharacterAvatar(shape: session.draft.avatarShape, color: session.draft.avatarColor, size: 88,
                                    customIcon: model.icons["bot:\(botId)"])
                        .overlay(alignment: .bottomTrailing) {
                            RemixIcon("pencil-line")
                                .font(.system(size: 18, weight: .medium))
                                .frame(width: 38, height: 38)
                                .background(.regularMaterial, in: Circle())
                                .offset(x: 8, y: 8)
                        }
                        .frame(maxWidth: .infinity)
                        .padding(.vertical, 24)
                }
                .buttonStyle(.plain)
                .listRowBackground(Color.clear)
                .listRowSeparator(.hidden)
                .accessibilityLabel("编辑头像")
                .listRowInsets(EdgeInsets())
            }
            Section("名称") {
                TextField("名称", text: $session.draft.name)
                    .padding(.vertical, 8)
            }
            .botNativeGroup()
            Section("外观") {
                NavigationLink("头像") { BotAvatarSettingsPage(draft: $session.draft).environment(model) }
                    .padding(.vertical, 8)
            }
            .botNativeGroup()
            if let error = session.error {
                Section { Text(error).foregroundStyle(.red) }.botNativeGroup()
            }
        }
        .disabled(session.saving)
        .botNativePage("编辑 Bot")
        .contentMargins(.top, 0, for: .scrollContent)
        .navigationDestination(isPresented: $pickingAvatar) { BotAvatarSettingsPage(draft: $session.draft).environment(model) }
        .toolbar {
            ToolbarItem(placement: .confirmationAction) {
                Button(session.saving ? "保存中…" : "完成") {
                    Task { if await session.save(to: model) { dismiss() } }
                }
                .buttonStyle(.glassProminent)
                .buttonBorderShape(.capsule)
                .tint(.primary)
                .foregroundStyle(Color(uiColor: .systemBackground))
                .disabled(session.saving || !session.draft.isValid || model.isOffline)
            }
        }
        .onChange(of: model.bots[botId].map(BotDraft.init)) { _, fresh in
            if let fresh { session.rebase(fresh) }
        }
    }
}

private struct BotAvatarSettingsPage: View {
    @Binding var draft: BotDraft
    @Environment(BotStore.self) private var model

    var body: some View {
        Form {
            Section {
                CharacterAvatar(shape: draft.avatarShape, color: draft.avatarColor, size: 88,
                                customIcon: draft.id.flatMap { model.icons["bot:\($0)"] })
                    .frame(maxWidth: .infinity).padding(.vertical, 16)
                AvatarPicker(shape: $draft.avatarShape, color: $draft.avatarColor)
                    .padding(.vertical, 12)
            }
            .botNativeGroup()
            if let id = draft.id {
                Section("自定义头像") { CustomIconEditor(target: "bot:\(id)") }.botNativeGroup()
            }
        }
        .botNativePage("头像")
    }
}
