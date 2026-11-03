import CodyncKit
import SwiftUI

/// Extensions for the bots on one computer (the store in the environment): Agents,
/// Connectors and Skills, one at a time. Each list scrolls; the connectors load more from the
/// registry as their end comes into view (`ConnectorCatalog`). Installing happens on that
/// computer; each bot turns connectors and skills on in its settings.
public struct MarketplaceView: View {
    @Environment(BotStore.self) var model
    @State var search = ""
    @State var connectors = ConnectorCatalog<MarketConnector>()
    @State var skills: [MarketSkill] = []
    @State var loadingSkills = true
    @State var error: String?
    @State var installing: MarketConnector?
    @State var viewingConnector: MarketConnector?
    @State var busySkill: String?
    @State var addingConnector = false
    @State var writingSkill = false
    @State var viewingSkill: SkillRef?
    @State var agent: Backend?
    @State var addingNode = false
    @State var section = ExtensionSection.agents
    @State var showInstalled = false
    @State var showCredentials = false
    @Environment(\.dismissModal) private var dismiss
    @Environment(\.horizontalSizeClass) var sizeClass

    /// Each computer has its own marketplace (the `BotStore` in the environment).
    public init() {}

    var query: String { search.trimmingCharacters(in: .whitespaces) }

    var agents: [Backend] {
        let all = (model.hello?.backends ?? []).filter { $0.available || $0.installed == true || $0.curated == true }
        return query.isEmpty ? all : all.filter { $0.name.localizedCaseInsensitiveContains(query) }
    }

    var shownSkills: [MarketSkill] {
        query.isEmpty ? skills : skills.filter { $0.name.localizedCaseInsensitiveContains(query) || $0.description.localizedCaseInsensitiveContains(query) }
    }

    private var installedCount: Int { model.installedConnectors.count + model.installedSkills.count }

    public var body: some View {
        NavigationStack {
            page
                .environment(model)
                .navigationTitle(L10n.tr("Extensions"))
                .navigationBarTitleDisplayMode(.inline)
                .searchable(text: $search, placement: .navigationBarDrawer(displayMode: .always),
                            prompt: Text(L10n.tr("Search agents, connectors and skills")))
                .toolbar {
                    ToolbarItem(placement: .topBarLeading) {
                        Button { showCredentials = true } label: {
                            Label(L10n.tr("Credentials"), systemImage: "lock.shield")
                        }
                        .buttonBorderShape(.capsule)
                    }
                    ToolbarItem(placement: .topBarTrailing) {
                        Button(L10n.tr("Close"), systemImage: "xmark") { dismiss() }
                            .labelStyle(.iconOnly)
                            .buttonBorderShape(.circle)
                            .keyboardShortcut(.cancelAction)
                    }
                }
                .navigationDestination(isPresented: $showInstalled) {
                    InstalledView().environment(model)
                }
        }
        .tint(.primary)
        .tracked(.screenViewed(.marketplace))
        .task {
            await model.refreshPlugins()
        }
        // Picks up CLIs installed or signed in outside Codync.
        .task {
            await model.refreshBackends()
            #if DEBUG
            switch ProcessInfo.processInfo.environment["CODYNC_MARKET_PREVIEW"] {
            case "agent": agent = model.hello?.backends.first { $0.installed == true && $0.signedIn == true }
            case "connector": addingConnector = true
            case "skill": writingSkill = true
            default: break
            }
            #endif
        }
        .task(id: query) {
            do { try await Task.sleep(for: .milliseconds(300)) } catch { return }
            await loadConnectors()
        }
        .task {
            loadingSkills = true
            do { skills = try await model.marketSkills() } catch { report(error) }
            if !Task.isCancelled { loadingSkills = false }
        }
        .codyncSheet(item: $installing) { item in
            InstallConnectorSheet(item: item) { Task { await loadConnectors() } }
        }
        .codyncSheet(item: $viewingConnector) { item in
            InstallConnectorSheet(item: item, addsAtOnce: false) { Task { await loadConnectors() } }
        }
        .codyncSheet(isPresented: $showCredentials) { CredentialsView() }
        .codyncSheet(isPresented: $addingConnector) { CustomConnectorSheet() }
        .codyncSheet(item: $viewingSkill) { SkillSheet(skill: $0) }
        .codyncSheet(isPresented: $writingSkill) { NewSkillSheet() }
        .codyncSheet(item: $agent) { b in AgentSheet(initial: b) }
        .codyncSheet(isPresented: $addingNode) {
            NativeExtensionSheet("Add Node.js") {
                SetupTerminalView(backend: nil, step: .node) { addingNode = false }.environment(model)
            }
        }
    }

    private var page: some View {
        ScrollView {
            VStack(alignment: .leading, spacing: 20) {
                computerSummary
                Picker(L10n.tr("Extensions sections"), selection: $section) {
                    ForEach(ExtensionSection.allCases) { item in
                        Text(L10n.tr(item.title)).tag(item)
                    }
                }
                .pickerStyle(.segmented)
                sourceLine
                tabBody
                if let error = error ?? connectors.error {
                    Text(L10n.tr(error)).font(.footnote).foregroundStyle(Palette.danger)
                }
            }
            .padding(.horizontal, 20)
            .padding(.top, 12)
            .padding(.bottom, 20)
            .frame(maxWidth: 980)
            .frame(maxWidth: .infinity)
        }
        .scrollDismissesKeyboard(.interactively)
        .background(Color(uiColor: .systemGroupedBackground))
    }

    private var computerSummary: some View {
        HStack(spacing: 10) {
            ComputerBadge(model.computer, size: 28)
            Text(model.hostName)
                .font(.subheadline)
                .foregroundStyle(.secondary)
                .lineLimit(1)
            Spacer(minLength: 8)
            if installedCount > 0 {
                Button { showInstalled = true } label: {
                    Text(L10n.tr("{count} installed").replacingOccurrences(of: "{count}", with: String(installedCount)))
                }
                .font(.subheadline)
                .buttonStyle(.bordered)
                .buttonBorderShape(.capsule)
            }
        }
    }

    private var sourceLine: some View {
        Text(L10n.tr(section.source).replacingOccurrences(of: "{name}", with: model.hostName))
            .font(.footnote)
            .foregroundStyle(.secondary)
            .fixedSize(horizontal: false, vertical: true)
    }

    func agentCard(_ b: Backend) -> some View {
        AgentCard(backend: b) { agent = b }
    }

    private func loadConnectors() async {
        await connectors.load(search: query, fetch: fetchConnectors)
    }

    func loadMoreConnectors() async {
        await connectors.loadMore(fetch: fetchConnectors)
    }

    private func fetchConnectors(search: String, cursor: String?) async throws -> (items: [MarketConnector], next: String?) {
        try await model.marketConnectors(search: search, cursor: cursor)
    }

    /// A load that SwiftUI cancelled is the next load starting, not a failure to show.
    func report(_ error: Error) {
        if error is CancellationError || Task.isCancelled { return }
        self.error = error.localizedDescription
    }
}

enum ExtensionSection: String, CaseIterable, Identifiable {
    case agents, connectors, skills
    var id: String { rawValue }
    var title: String {
        switch self {
        case .agents: "Agents"
        case .connectors: "Connectors"
        case .skills: "Skills"
        }
    }
    var source: String {
        switch self {
        case .agents: "Agents come from the ACP registry and install on {name}."
        case .connectors: "Connectors come from the official MCP Registry and install on {name}."
        case .skills: "Skills come from Anthropic and install on {name}."
        }
    }
}
