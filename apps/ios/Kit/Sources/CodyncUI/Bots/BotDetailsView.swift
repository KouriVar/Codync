import CodyncKit
import SwiftUI

// Retain existing deep-link destinations while the profile itself becomes a native page.
enum DetailsTab: Hashable { case details, library, memory, settings }

struct DetailsRequest: Identifiable, Hashable {
    let id = UUID()
    var tab: DetailsTab = .details
    var routineId: String?
    var botId: String?
}

private enum BotProfilePage: Hashable {
    case edit, routines, library, computer, memory, agent, workspace, capabilities
}

struct BotDetailsView: View {
    let botId: String
    let request: DetailsRequest
    let openArtifact: (ArtifactTarget) -> Void
    @Environment(BotStore.self) private var model
    @State private var page: BotProfilePage?
    @State private var template: EditorRequest?
    @State private var enabledRoutines: Int?
    @State private var routineError: String?
    @State private var openedRequest = false

    init(botId: String, request: DetailsRequest, openArtifact: @escaping (ArtifactTarget) -> Void) {
        self.botId = botId
        self.request = request
        self.openArtifact = openArtifact
    }

    private var bot: Bot? { model.bots[botId] }

    var body: some View {
        List {
            if let bot {
                Section {
                    identity(bot)
                        .listRowInsets(EdgeInsets())
                        .listRowBackground(Color.clear)
                        .listRowSeparator(.hidden)
                }
                Section {
                    NavigationLink { destination(.routines).environment(model) } label: {
                        profileRow("定时任务", symbol: "clock.arrow.circlepath", value: enabledRoutines.map { "\($0) 已开启" } ?? "—")
                    }
                    NavigationLink { destination(.library).environment(model) } label: {
                        profileRow("资料库", symbol: "folder")
                    }
                    .disabled(!model.hasLibrary)
                    NavigationLink { destination(.computer).environment(model) } label: {
                        profileRow("电脑", symbol: "desktopcomputer", value: model.isOffline ? "离线" : model.screen?.agentBot == nil ? "空闲" : "使用中")
                    }
                }
                .botNativeGroup()
                Section {
                    Toggle("通知", isOn: Binding(get: { model.bots[botId]?.notify ?? true }, set: { model.setNotifications(bot, $0) }))
                        .tint(.gray)
                        .disabled(model.isOffline)
                } footer: {
                    Text("Bot 完成或需要等待你处理时通知你")
                }
                .botNativeGroup()
                if let routineError {
                    Section { Text(routineError).font(.footnote).foregroundStyle(.secondary) }.botNativeGroup()
                }
            } else {
                ContentUnavailableView("Bot 暂不可用", systemImage: "person.crop.circle.badge.exclamationmark")
            }
        }
        .listStyle(.insetGrouped)
        .listSectionSpacing(24)
        .contentMargins(.top, 0, for: .scrollContent)
        .safeAreaPadding(.horizontal, 4)
        .environment(\.defaultMinListRowHeight, 52)
        .botNativePage("")
        .toolbar {
            ToolbarItem(placement: .topBarTrailing) {
                Button { 
                    if let bot { template = EditorRequest(BotDraft(bot)) }
                 } label: { RemixImage("share-forward-line", size: 24) }
                .accessibilityLabel(Text("分享 Bot 模板"))
                .buttonBorderShape(.circle)
                .disabled(bot == nil)
            }
            ToolbarSpacer(.fixed, placement: .topBarTrailing)
            ToolbarItem(placement: .topBarTrailing) {
                Menu { 
                    Button {  page = .agent  } label: { Label { Text("指令与智能体") } icon: { RemixIcon("equalizer-line") } }
                    Button {  page = .workspace  } label: { Label { Text("工作区与权限") } icon: { RemixIcon("folder-settings-line") } }
                    Button {  page = .capabilities  } label: { Label { Text("能力与插件") } icon: { RemixIcon("puzzle-line") } }
                    Button {  page = .memory  } label: { Label { Text("记忆") } icon: { RemixIcon("brain-line") } }
                 } label: { RemixImage("more-line", size: 24) }
                    .accessibilityLabel(Text("更多"))
                .menuIndicator(.hidden)
                .buttonBorderShape(.circle)
            }
        }
        .navigationDestination(item: $page) { destination($0).environment(model) }
        .codyncSheet(item: $template) { BotTemplateView(draft: $0.draft) }
        .tracked(.screenViewed(.botDetails))
        .task(id: model.connection == .online) {
            if !openedRequest {
                openedRequest = true
                if request.routineId != nil { page = .routines }
                else {
                    switch request.tab {
                    case .details: break
                    case .library: page = .library
                    case .memory: page = .memory
                    case .settings: page = .edit
                    }
                }
            }
            await loadRoutineCount()
        }
    }

    private func identity(_ bot: Bot) -> some View {
        VStack(spacing: 14) {
            LeadAgentAvatar(bot: bot, size: 88)
            Text(bot.name).font(.title2.weight(.semibold)).multilineTextAlignment(.center)
            Button("编辑") { page = .edit }
                .font(.body.weight(.medium))
                .buttonStyle(.bordered)
                .buttonBorderShape(.capsule)
                .tint(.gray)
                .foregroundStyle(.primary)
        }
        .frame(maxWidth: .infinity)
        .padding(.top, 24)
        .padding(.bottom, 0)
    }

    private func profileRow(_ title: String, symbol: String, value: String? = nil) -> some View {
        HStack(spacing: 12) {
            Image(systemName: symbol).foregroundStyle(.secondary).frame(width: 22)
            Text(title)
            Spacer(minLength: 8)
            if let value { Text(value).foregroundStyle(.secondary) }
        }
        .padding(.vertical, 4)
    }

    @ViewBuilder private func destination(_ page: BotProfilePage) -> some View {
        if let bot {
            switch page {
            case .edit: BotProfileEditView(bot: bot)
            case .routines: RoutinesView(botId: botId, initialId: request.routineId, nativeStyle: true).botNativePage("定时任务")
            case .library: LibraryView(botId: botId, openArtifact: openArtifact, nativeStyle: true).botNativePage("资料库")
            case .computer: BotComputerPage(botId: botId)
            case .memory: MemoryCard(botId: botId, nativeStyle: true).botNativePage("记忆")
            case .agent: BotNativeSettingsView(bot: bot, part: .agent)
            case .workspace: BotNativeSettingsView(bot: bot, part: .workspace)
            case .capabilities: BotNativeSettingsView(bot: bot, part: .capabilities)
            }
        }
    }

    private func loadRoutineCount() async {
        do {
            let client = try await model.ready()
            enabledRoutines = try await client.routines(botId: botId).routines.filter(\.enabled).count
            routineError = nil
        } catch is CancellationError { }
        catch { routineError = "定时任务暂时无法加载：\(error.localizedDescription)" }
    }
}

extension View {
    func botNativeGroup() -> some View {
        listRowBackground(Color(uiColor: .tertiarySystemGroupedBackground))
    }

    func botNativePage(_ title: String) -> some View {
        navigationTitle(title)
            .navigationBarTitleDisplayMode(.inline)
            .scrollContentBackground(.hidden)
            .background(Color(uiColor: .secondarySystemGroupedBackground))
            .tint(.primary)
    }
}

private struct BotComputerPage: View {
    let botId: String
    @Environment(BotStore.self) private var model

    var body: some View {
        Form {
            Section {
                LabeledContent("电脑", value: model.hostName)
                LabeledContent("状态", value: model.isOffline ? "离线" : "已连接")
            }
            .botNativeGroup()
            if let bot = model.bots[botId], model.screen != nil {
                Section {
                    Toggle("允许 Bot 使用电脑", isOn: Binding(get: { model.bots[botId]?.computer ?? false }, set: { model.setComputer(bot, $0) }))
                        .tint(.gray)
                        .disabled(model.isOffline)
                    Button { 
                        model.screenRequest = model.screen?.agentBot == botId ? ScreenRequest(watching: botId) : ScreenRequest()
                     } label: { Label { Text("查看电脑屏幕") } icon: { RemixIcon("computer-line") } }
                    .disabled(model.isOffline)
                } footer: { Text("屏幕录制与控制权限在 Mac 的 Codync 设置中管理。") }
                .botNativeGroup()
            }
        }
        .botNativePage("电脑")
    }
}
