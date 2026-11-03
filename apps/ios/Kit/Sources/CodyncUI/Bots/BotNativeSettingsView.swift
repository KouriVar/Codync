import CodyncKit
import SwiftUI

/// The existing bot capabilities, presented as native grouped settings instead of outlined cards.
struct BotNativeSettingsView: View {
    enum Part {
        case agent, workspace, capabilities
        var title: String {
            switch self {
            case .agent: "指令与智能体"
            case .workspace: "工作区与权限"
            case .capabilities: "能力与插件"
            }
        }
    }
    let botId: String
    let part: Part
    @State private var session: BotEditSession
    @State private var catalog: AgentModels?
    @State private var catalogError: String?
    @State private var retry = 0
    @State private var pickingFolder = false
    @State private var skill: SkillRef?
    @Environment(BotStore.self) private var model
    @Environment(\.dismiss) private var dismiss

    init(bot: Bot, part: Part) {
        botId = bot.id
        self.part = part
        _session = State(initialValue: BotEditSession(bot))
    }

    private var bot: Bot? { model.bots[botId] }
    private var modelState: AgentModelSelection { AgentModelSelection(catalog: catalog, selection: session.draft.model) }
    private var modelChoices: [(String, String)] { modelState.choices }
    private var modelSelection: Binding<String> {
        Binding(get: { modelState.value }, set: {
            let selected = $0.isEmpty ? nil : $0
            guard selected != session.draft.model else { return }
            session.draft.model = selected
            session.draft.modelOptions = [:]
        })
    }
    private var selectedModel: AgentModels.Model? { modelState.selectedModel }
    private var options: [AgentModels.Option] { modelState.options }

    var body: some View {
        @Bindable var session = session
        Form {
            switch part {
            case .agent: agentSections
            case .workspace: workspaceSections
            case .capabilities: capabilitySections
            }
            if let error = session.error { Section { Text(error).foregroundStyle(.red) }.botNativeGroup() }
        }
        .disabled(session.saving)
        .tint(.gray)
        .botNativePage(part.title)
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
        .task(id: "\(session.draft.backend)/\(model.connection == .online)/\(retry)") { await loadCatalog() }
        .task { await model.refreshPlugins() }
        .onChange(of: session.draft.backend) { catalog = nil; catalogError = nil }
        .onChange(of: model.bots[botId].map(BotDraft.init)) { _, fresh in
            if let fresh { session.rebase(fresh) }
        }
        .codyncSheet(isPresented: $pickingFolder) {
            FolderPicker(start: session.draft.cwd.isEmpty ? model.hello?.home : session.draft.cwd) {
                session.draft.cwd = $0
                pickingFolder = false
            }
        }
        .codyncSheet(item: $skill) { SkillSheet(skill: $0) }
    }

    @ViewBuilder private var agentSections: some View {
        @Bindable var session = session
        Section {
            TextField("这个 Bot 应始终遵守的规则", text: $session.draft.description, axis: .vertical)
                .lineLimit(4...10)
        } header: { Text("常驻指令") } footer: { Text("一直生效的规则；针对某次任务的要求写在聊天里。") }
        .botNativeGroup()
        Section("智能体") {
            Picker("智能体", selection: Binding(get: { session.draft.backend }, set: { session.draft.setAgent($0) })) {
                ForEach(model.hello?.backends ?? [], id: \.id) { Text(model.agentLabel($0)).tag($0.id) }
                if !(model.hello?.backends ?? []).contains(where: { $0.id == session.draft.backend }), session.draft.backend != "custom" {
                    Text(model.backendName(session.draft.backend)).tag(session.draft.backend)
                }
                Text("自定义命令").tag("custom")
            }
            .pickerStyle(.navigationLink)
            if session.draft.backend == "custom" {
                TextField("ACP 命令", text: Binding(get: { session.draft.command ?? "" }, set: { session.draft.command = $0.isEmpty ? nil : $0 }))
                    .textInputAutocapitalization(.never).autocorrectionDisabled()
            }
            Picker("模型", selection: modelSelection) {
                ForEach(modelChoices, id: \.0) { Text($0.1).tag($0.0) }
            }
            .pickerStyle(.navigationLink)
            if session.draft.backend == "custom" || catalog?.models.isEmpty != false {
                TextField("模型 ID（留空使用默认）", text: modelSelection)
                    .textInputAutocapitalization(.never).autocorrectionDisabled()
            }
            ForEach(options) { option in
                Picker(option.localizedTitle, selection: Binding(get: { session.draft.modelOptions[option.id] ?? option.default ?? "" }, set: {
                    session.draft.modelOptions[option.id] = $0.isEmpty ? nil : $0
                })) {
                    if option.default == nil { Text("默认").tag("") }
                    ForEach(option.values, id: \.id) { Text(option.localizedName(for: $0)).tag($0.id) }
                }
                .pickerStyle(.navigationLink)
            }
            if catalog?.fastMode == true || session.draft.fastMode == true || bot?.fastModeShown == true {
                Toggle("快速模式", isOn: Binding(get: { session.draft.fastMode ?? false }, set: { session.draft.fastMode = $0 }))
                    .tint(.gray)
                if let refusal = bot?.fastModeRefusal { Text(refusal).font(.footnote).foregroundStyle(.secondary) }
            }
            if let error = selectedModel?.optionsError { Text(error).font(.footnote).foregroundStyle(.secondary) }
            if let rest = bot?.rest(of: session.draft.backend) { Text(rest.line).font(.footnote).foregroundStyle(.secondary) }
            if let hint = model.hello?.backends.first(where: { $0.id == session.draft.backend && !$0.available })?.installHint {
                Text(hint).font(.footnote).foregroundStyle(.secondary)
            }
        }
        .botNativeGroup()
        if let catalogError {
            Section {
                Text(catalogError).font(.footnote).foregroundStyle(.secondary)
                Button("重新加载模型") { retry += 1 }
            }
            .botNativeGroup()
        }
        if session.draft.fallbacks != nil {
            Section("备用智能体") {
                if let bot, let step = bot.agentStep { FallbackBanner(bot: bot, step: step) }
                FallbackList(draft: $session.draft, bot: bot, nativeStyle: true)
            }
            .botNativeGroup()
        }
    }

    @ViewBuilder private var workspaceSections: some View {
        Section("工作区") {
            LabeledContent("电脑", value: model.hostName)
            Button { pickingFolder = true } label: {
                LabeledContent("工作区", value: session.draft.cwd.isEmpty ? "个人工作区" : (session.draft.cwd as NSString).lastPathComponent)
            }
            if !session.draft.cwd.isEmpty { Button("使用个人工作区") { session.draft.cwd = "" } }
        }
        .botNativeGroup()
        if let bot, let creator = bot.createdBy {
            Section("创建信息") {
                LabeledContent("创建者", value: model.bots[creator]?.name ?? "Bot")
                LabeledContent("创建时间", value: Date(milliseconds: bot.createdAt).formatted(date: .abbreviated, time: .omitted))
            }
            .botNativeGroup()
        }
        let approval = ApprovalChoice.choices(permission: session.draft.permission, mode: session.draft.mode, catalog: catalog)
        Section {
            Picker("权限", selection: Binding(get: { approval.selected.id }, set: { session.draft.setApproval($0) })) {
                ForEach(approval.all) { Text(L10n.tr($0.label)).tag($0.id) }
            }
            .pickerStyle(.navigationLink)
        } header: { Text("权限") } footer: {
            Text([approval.selected.note, L10n.tr(approval.selected.detail)].compactMap { $0 }.joined(separator: " "))
        }
        .botNativeGroup()
    }

    @ViewBuilder private var capabilitySections: some View {
        Section("活动") {
            if model.bots.values.contains(where: { $0.manageTeam != nil }) {
                Toggle("管理团队", isOn: Binding(get: { session.draft.manageTeam ?? false }, set: { session.draft.manageTeam = $0 })).tint(.gray)
            }
            if session.draft.offeredToNetwork != nil, model.network?.joined == true {
                Toggle("在网络中可见", isOn: Binding(get: { session.draft.offeredToNetwork ?? true }, set: { session.draft.offeredToNetwork = $0 })).tint(.gray)
            }
            if session.draft.reachableByAssistants != nil, model.network?.assistants == true {
                Toggle("允许云端助手访问", isOn: Binding(get: { session.draft.reachableByAssistants ?? true }, set: { session.draft.reachableByAssistants = $0 })).tint(.gray)
            }
        }
        .botNativeGroup()
        pluginSection("连接器", items: model.installedConnectors.map { ($0.id, $0.name) }, field: \.connectors)
        pluginSection("技能", items: model.installedSkills.map { ($0.id, $0.name) }, field: \.skills)
    }

    private func pluginSection(_ title: String, items: [(String, String)], field: WritableKeyPath<BotDraft, [String]?>) -> some View {
        Section(title) {
            if items.isEmpty { Text("暂无已安装项目，请从首页的插件入口添加。").foregroundStyle(.secondary) }
            ForEach(items, id: \.0) { id, name in
                Toggle(isOn: Binding(get: { session.draft[keyPath: field]?.contains(id) ?? false }, set: { on in
                    var selected = session.draft[keyPath: field] ?? []
                    selected.removeAll { $0 == id }
                    if on { selected.append(id) }
                    session.draft[keyPath: field] = selected
                })) {
                    HStack {
                        Text(name)
                        if title == "技能", let item = model.installedSkills.first(where: { $0.id == id }) {
                            Button { skill = SkillRef(item) } label: { Image(systemName: "info.circle") }
                                .buttonStyle(.borderless)
                                .accessibilityLabel("关于 \(name)")
                        }
                    }
                }
                .tint(.gray)
            }
        }
        .botNativeGroup()
    }

    private func loadCatalog() async {
        guard part != .capabilities, session.draft.backend != "custom", model.connection == .online else { return }
        do {
            let client = try await model.ready()
            let response = try await client.agentModels(session.draft.backend)
            try Task.checkCancellation()
            catalog = response
            catalogError = nil
        } catch is CancellationError { }
        catch { catalogError = error.localizedDescription }
    }
}
