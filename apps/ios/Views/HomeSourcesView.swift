import CodyncKit
import CodyncUI
import DSHKit
import SwiftUI
import UIKit

/// The home: the conversations of every enabled source (Coe, DS Bot, DSH 对话) in one list, or one
/// swipeable page per enabled source. The source switch sits left of the "+" in the top-right.
///
/// The DSH gateway is the shared singleton so Settings shows the same pairing status; the home is
/// the only place that decides whether it connects (an unchecked DSH source keeps the WebSocket off).
@MainActor
struct HomeSourcesView: View {
    @Environment(AppStore.self) private var app
    @Environment(AccountStore.self) private var accounts
    @Environment(\.accessibilityReduceMotion) private var reduceMotion

    @ObservedObject private var dsh = DSHGateway.shared

    @AppStorage(HomeSourcePrefs.sourcesKey) private var sourcesRaw = HomeSourcePrefs.defaultRaw
    @AppStorage(HomeSourcePrefs.layoutKey) private var layoutRaw = HomeLayout.mixed.rawValue

    @State private var searchText = ""
    @State private var creating: NewTarget?
    @State private var confirmDelete: RosterItem?
    @State private var showCameraSheet = false
    @State private var showDSHChat = false
    @State private var showDSHConnect = false
    @State private var page: HomeSource = .coe
    @AppStorage("manualUnreadConversations") private var manualUnreadData = Data()

    private var enabledSources: Set<HomeSource> { HomeSourcePrefs.enabled(from: sourcesRaw) }
    private var layout: HomeLayout { HomeLayout(rawValue: layoutRaw) ?? .mixed }
    private var enabledOrdered: [HomeSource] { HomeSource.allCases.filter { enabledSources.contains($0) } }

    private var searchQuery: String { searchText.trimmingCharacters(in: .whitespacesAndNewlines) }
    private var isSearching: Bool { !searchQuery.isEmpty }

    // MARK: - Body

    var body: some View {
        chromeView
            .refreshable { await refreshAll() }
            .task { syncDSHConnection() }
            .onChange(of: sourcesRaw) { _, _ in sourceSelectionChanged() }
            .onChange(of: availableStores.map(\.selection)) { handleStoreSelections() }
            .sheet(isPresented: $showCameraSheet, content: cameraSheet)
            .sheet(isPresented: $showDSHChat) { DSHChatScreen(gateway: dsh) }
            .sheet(isPresented: $showDSHConnect, content: dshConnectSheet)
            .codyncSheet(item: $creating) { target in creatingSheet(target) }
            .alert(deleteTitle, isPresented: deleteShown, presenting: confirmDelete) { item in
                deleteButtons(item)
            } message: { item in
                deleteMessage(item)
            }
    }

    /// The list plus its bottom bar and top chrome. Kept apart from the sheets so each expression
    /// stays small enough for the type checker.
    private var chromeView: some View {
        baseView
            .navigationTitle("")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar(.visible, for: .navigationBar)
            .toolbar { toolbarContent }
    }

    private var baseView: some View {
        Group {
            if layout == .paged { pagedView } else { mixedView }
        }
        .background(Palette.background)
        .safeAreaInset(edge: .bottom, spacing: 0) { bottomBar }
    }

    private var bottomBar: some View {
        HomeBottomBar(searchText: $searchText, openCamera: { showCameraSheet = true }) {
            if let store = app.currentStore {
                app.marketplace = store.computer.id
            } else {
                app.showComputers = true
            }
        }
    }

    @ToolbarContentBuilder private var toolbarContent: some ToolbarContent {
        ToolbarItem(placement: .topBarLeading) { AccountSwitcherButton() }
        // The source switch, left of the "+": same native-menu appearance as the "+".
        ToolbarItem(placement: .topBarTrailing) { sourceMenu }
        ToolbarItem(placement: .topBarTrailing) { newBotMenu }
    }

    // MARK: - Source menu

    private var sourceMenu: some View {
        Menu {
            ForEach(HomeSource.allCases) { source in
                Toggle(isOn: Binding(get: { enabledSources.contains(source) },
                                    set: { setSource(source, on: $0) })) {
                    Text(source.title)
                }
            }
            Divider()
            Button { sourcesRaw = HomeSourcePrefs.raw(Set(HomeSource.allCases)) } label: { Text("全部显示") }
            Button { sourcesRaw = HomeSourcePrefs.defaultRaw } label: { Text("恢复默认") }
        } label: {
            Image(systemName: "line.3.horizontal.decrease.circle")
                .font(.system(size: 20, weight: .regular))
        }
        .accessibilityLabel(Text("会话来源"))
    }

    private var newBotMenu: some View {
        Menu {
            Button(action: newBot) { Label { Text(L10n.tr("New bot")) } icon: { RemixIcon("add-line") } }
            Button(action: newGroup) { Label { Text(L10n.tr("New group chat")) } icon: { RemixIcon("team-line") } }
                .disabled(onlineStores.isEmpty)
        } label: {
            RemixImage("add-line", size: 24)
        }
        .accessibilityLabel(Text(L10n.tr("New")))
        .disabled(availableStores.isEmpty)
    }

    /// Toggles one source, never letting the last one turn off.
    private func setSource(_ source: HomeSource, on: Bool) {
        var set = enabledSources
        if on {
            set.insert(source)
        } else {
            guard set.count > 1 else { return }
            set.remove(source)
        }
        sourcesRaw = HomeSourcePrefs.raw(set)
    }

    private func sourceSelectionChanged() {
        syncDSHConnection()
        if !enabledOrdered.contains(page), let first = enabledOrdered.first { page = first }
    }

    private func syncDSHConnection() {
        if enabledSources.contains(.dsh) {
            dsh.connectLastPaired()
        } else {
            dsh.disconnect()
        }
    }

    private func refreshAll() async {
        for computer in accounts.computers { accounts.store(for: computer.id)?.restartStream() }
        await accounts.refreshCloud()
    }

    private func handleStoreSelections() {
        for store in availableStores {
            guard let botId = store.selection else { continue }
            store.selection = nil
            accounts.selection = BotReference(accountId: accounts.accountId, computerId: store.computer.id, botId: botId)
        }
    }

    // MARK: - Sheets

    private func cameraSheet() -> some View {
        QuickCaptureSheet(onCapture: attachCapturedPhoto)
            .presentationDetents([.medium, .large])
            .presentationDragIndicator(.visible)
    }

    private func dshConnectSheet() -> some View {
        DSHConnectSheet(gateway: dsh, scan: { onCode in
            AnyView(QRScanner(onCode: onCode, onError: { _ in }, acceptedPrefixes: nil))
        })
    }

    @ViewBuilder private func creatingSheet(_ target: NewTarget) -> some View {
        if let store = accounts.store(for: target.computerId) {
            Group {
                switch target.kind {
                case .bot:
                    NewBotView(computers: computerOptions,
                               computer: Binding(get: { target.computerId },
                                                 set: { creating = NewTarget(kind: .bot, computerId: $0) }))
                case .group:
                    NewGroupView()
                }
            }
            .environment(store)
        }
    }

    private var deleteTitle: String {
        L10n.tr("Delete {name}?").replacingOccurrences(of: "{name}", with: confirmDelete?.bot.name ?? "Bot")
    }

    private var deleteShown: Binding<Bool> {
        Binding(get: { confirmDelete != nil }, set: { if !$0 { confirmDelete = nil } })
    }

    @ViewBuilder private func deleteButtons(_ item: RosterItem) -> some View {
        Button(L10n.tr(item.bot.isGroup ? "Delete group chat" : "Delete bot and its conversation"), role: .destructive) {
            accounts.store(for: item.ref.computerId)?.delete(item.bot)
        }
        Button(L10n.tr("Cancel"), role: .cancel) {}
    }

    private func deleteMessage(_ item: RosterItem) -> Text {
        Text(L10n.tr(item.bot.isGroup ? "Its bots and their own chats stay." : "Files it changed on your computer stay as they are."))
    }

    // MARK: - Mixed list

    private var mixedView: some View {
        List {
            ForEach(mixedEntries) { entry in
                entryRow(entry)
            }
            if let hint = dshHint {
                dshHintRow(hint)
            }
            if mixedEntries.isEmpty && dshHint == nil {
                emptyState
            }
        }
        .plainRosterList()
    }

    // MARK: - Paged list

    private var pagedView: some View {
        VStack(spacing: 0) {
            pageIndicator
            TabView(selection: pageBinding) {
                ForEach(enabledOrdered) { source in
                    sourcePage(source).tag(source)
                }
            }
            .tabViewStyle(.page(indexDisplayMode: .never))
        }
    }

    private var pageBinding: Binding<HomeSource> {
        Binding(get: { enabledOrdered.contains(page) ? page : (enabledOrdered.first ?? .coe) },
                set: { page = $0 })
    }

    private var pageIndicator: some View {
        HStack(spacing: 6) {
            ForEach(enabledOrdered) { source in
                Circle()
                    .fill(source == pageBinding.wrappedValue ? Palette.text : Palette.tertiary.opacity(0.35))
                    .frame(width: 6, height: 6)
            }
            Text(pageBinding.wrappedValue.title)
                .font(.caption2)
                .foregroundStyle(Palette.secondary)
                .padding(.leading, 4)
        }
        .frame(maxWidth: .infinity)
        .padding(.top, 8)
    }

    private func sourcePage(_ source: HomeSource) -> some View {
        List {
            if source == .dsh, let hint = dshHint {
                dshHintRow(hint)
            }
            let items = entries(for: source)
            if items.isEmpty && !(source == .dsh && dshHint != nil) {
                Text(source == .dsh ? "还没有 DSH 会话" : "没有会话")
                    .font(.footnote)
                    .foregroundStyle(Palette.secondary)
                    .frame(maxWidth: .infinity)
                    .padding(.vertical, 40)
                    .listRowSeparator(.hidden)
                    .listRowBackground(Color.clear)
            }
            ForEach(items) { entry in
                entryRow(entry)
            }
        }
        .plainRosterList()
    }

    // MARK: - Entries

    private struct HomeEntry: Identifiable {
        enum Kind { case bot(RosterItem); case dsh(DSHSession) }
        let kind: Kind

        var id: String {
            switch kind {
            case .bot(let item): return "b-\(item.ref.computerId)-\(item.ref.botId)"
            case .dsh(let session): return "d-\(session.id)"
            }
        }

        var timestamp: Date {
            switch kind {
            case .bot(let item): return Date(timeIntervalSince1970: Double(item.bot.lastAt) / 1000)
            case .dsh(let session):
                guard let value = session.updatedAt else { return .distantPast }
                let ms = value > 1_000_000_000_000 ? value : value * 1000
                return Date(timeIntervalSince1970: ms / 1000)
            }
        }
    }

    private func entries(for source: HomeSource) -> [HomeEntry] {
        if source == .dsh { return dshEntries }
        return botEntries(for: source)
    }

    private var mixedEntries: [HomeEntry] {
        var entries: [HomeEntry] = []
        for source in HomeSource.allCases where source != .dsh && enabledSources.contains(source) {
            entries.append(contentsOf: botEntries(for: source))
        }
        entries.append(contentsOf: dshEntries)
        return entries.sorted { $0.timestamp > $1.timestamp }
    }

    private func botEntries(for source: HomeSource) -> [HomeEntry] {
        accounts.roster
            .filter { HomeSource.of(bot: $0.bot) == source }
            .filter { !HomeSessionVisibility.isHidden(title: $0.bot.name, isDSH: false) }
            .filter { matchesSearch($0) }
            .map { HomeEntry(kind: .bot($0)) }
    }

    private var dshEntries: [HomeEntry] {
        guard enabledSources.contains(.dsh) else { return [] }
        return dsh.sessions
            .filter { !HomeSessionVisibility.isHidden(title: $0.title, isDSH: true) }
            .filter { !isSearching || $0.title.localizedStandardContains(searchQuery) }
            .sorted { ($0.updatedAt ?? 0) > ($1.updatedAt ?? 0) }
            .map { HomeEntry(kind: .dsh($0)) }
    }

    private func matchesSearch(_ item: RosterItem) -> Bool {
        !isSearching || item.bot.name.localizedStandardContains(searchQuery)
            || (item.bot.lastMessage?.localizedStandardContains(searchQuery) ?? false)
    }

    @ViewBuilder private func entryRow(_ entry: HomeEntry) -> some View {
        switch entry.kind {
        case .bot(let item):
            if let store = accounts.store(for: item.ref.computerId) {
                botRow(item, store: store)
            }
        case .dsh(let session):
            DSHSessionRow(session: session, sourceBadge: layout == .mixed ? badge(.dsh) : nil)
                .contentShape(Rectangle())
                .onTapGesture { openDSH(session) }
                .contextActions {
                    [MenuItem("Copy session ID", icon: "file-copy-line") { UIPasteboard.general.string = session.id }]
                }
                .rosterRow()
        }
    }

    private func botRow(_ item: RosterItem, store: BotStore) -> some View {
        BotRow(bot: item.bot, manuallyUnread: manuallyUnread(item))
            .environment(store)
            // The source badge sits on the avatar's bottom-right, same size/place as the lead
            // agent's star: avatar is 48pt with 16pt vertical row padding.
            .overlay(alignment: .topLeading) {
                if layout == .mixed {
                    SourceBadge(source: HomeSource.of(bot: item.bot))
                        .offset(x: 31, y: 47)
                        .allowsHitTesting(false)
                }
            }
            .contentShape(Rectangle())
            .onTapGesture { accounts.selection = item.ref }
            .contextActions { botMenuItems(item, store: store) }
            .rosterRow()
    }

    private func badge(_ source: HomeSource) -> AnyView {
        AnyView(SourceBadge(source: source))
    }

    private var dshHint: String? {
        guard enabledSources.contains(.dsh) else { return nil }
        if case .failed = dsh.phase { return "DSH 未连接，可在设置里重新配对" }
        return nil
    }

    private func dshHintRow(_ text: String) -> some View {
        HStack(spacing: 6) {
            Image(systemName: "exclamationmark.triangle").font(.caption2)
            Text(text).font(.footnote).lineLimit(2)
            Spacer(minLength: 0)
        }
        .foregroundStyle(Palette.secondary)
        .padding(.vertical, 8)
        .rosterRow()
    }

    private var emptyState: some View {
        VStack(spacing: 12) {
            RemixIcon("search-line").font(.title)
            Text("没有匹配的会话").font(.body)
        }
        .foregroundStyle(Palette.secondary)
        .frame(maxWidth: .infinity)
        .padding(.vertical, 40)
        .rosterRow()
    }

    // MARK: - Actions

    private func openDSH(_ session: DSHSession) {
        dsh.open(sessionId: session.id)
        showDSHChat = true
    }

    private func manuallyUnread(_ item: RosterItem) -> Bool {
        ManualUnreadMarks(data: manualUnreadData)
            .contains(account: accounts.accountId, computer: item.ref.computerId, bot: item.bot.id)
    }

    private func setManuallyUnread(_ unread: Bool, item: RosterItem) {
        var marks = ManualUnreadMarks(data: manualUnreadData)
        marks.set(unread, account: accounts.accountId, computer: item.ref.computerId, bot: item.bot.id)
        manualUnreadData = marks.data
    }

    /// The long-press menu, kept to the essentials the home needs; the full editor lives in the
    /// bot detail flow.
    private func botMenuItems(_ item: RosterItem, store: BotStore) -> [MenuItem] {
        let bot = item.bot
        let unread = bot.unread > 0 || manuallyUnread(item)
        var items = [MenuItem(unread ? "Mark as read" : "Mark as unread",
                              icon: unread ? "mail-open-line" : "mail-unread-line") {
            setManuallyUnread(!unread, item: item)
            if unread { store.markAllRead(bot.id) }
        }, MenuItem(bot.pinned ? "Unpin" : "Pin", icon: bot.pinned ? "unpin-line" : "pushpin-2-line") {
            store.setPinned(bot, !bot.pinned)
        }]
        items.append(MenuItem("Copy ID", icon: "file-copy-line") { UIPasteboard.general.string = bot.id })
        if !bot.lead {
            items.append(MenuItem("Hide", icon: "eye-off-line", destructive: true) { store.setHidden(bot, true) })
        }
        if !bot.lead || store.supportsLeadChoice {
            items.append(MenuItem("Delete", icon: "delete-bin-line", destructive: true, divider: true) { confirmDelete = item })
        }
        return items
    }

    private var onlineStores: [BotStore] {
        availableStores.filter { $0.connection == .online }
    }

    private var availableStores: [BotStore] {
        accounts.computers.compactMap { accounts.store(for: $0.id) }
            .filter { $0.mismatch == nil && !accounts.isStale($0.computer.id) }
    }

    /// The computers a new bot can go to, labelled "(offline)" when it can't take one now.
    private var computerOptions: [(id: ComputerID, label: String)] {
        availableStores.map { store -> (id: ComputerID, label: String) in
            let label = store.connection == .online ? store.hostName : "\(store.hostName) (offline)"
            return (store.computer.id, label)
        }
    }

    private func newBot() {
        guard let store = onlineStores.first ?? availableStores.first else { return }
        creating = NewTarget(kind: .bot, computerId: store.computer.id)
    }

    private func newGroup() {
        guard let store = onlineStores.first else { return }
        Task {
            try? await Task.sleep(for: .milliseconds(200))
            creating = NewTarget(kind: .group, computerId: store.computer.id)
        }
    }

    private func attachCapturedPhoto(_ image: UIImage) {
        showCameraSheet = false
        guard let store = app.currentStore, let jpeg = image.jpegData(compressionQuality: 0.85) else { return }
        let candidates = accounts.roster.filter { $0.ref.computerId == store.computer.id && !$0.bot.isGroup }
        guard let target = candidates.first(where: { $0.bot.lead }) ?? candidates.first else { return }
        store.attachPendingFile(OutgoingFile(name: "photo-\(Int(Date.now.timeIntervalSince1970)).jpg", data: jpeg),
                                to: target.bot.id)
        accounts.selection = target.ref
    }

    private struct NewTarget: Identifiable {
        enum Kind { case bot, group }
        let kind: Kind
        let computerId: ComputerID
        var id: String { "\(kind)-\(computerId)" }
    }
}

// MARK: - List row styling

private extension View {
    /// A roster row with the home's insets and no separator, on the home's background.
    func rosterRow() -> some View {
        listRowInsets(EdgeInsets(top: 0, leading: 16, bottom: 0, trailing: 16))
            .listRowSeparator(.hidden)
            .listRowBackground(Color.clear)
    }

    /// The shared plain-list styling the roster used.
    func plainRosterList() -> some View {
        listStyle(.plain)
            .contentMargins(.top, 12, for: .scrollContent)
            .scrollContentBackground(.hidden)
            .environment(\.defaultMinListRowHeight, 0)
            .scrollDismissesKeyboard(.interactively)
    }
}

// MARK: - Source badge

/// A tiny source mark at the avatar's bottom-right, matching the lead agent's star size/position.
struct SourceBadge: View {
    let source: HomeSource

    var body: some View {
        Text(source.badgeLetter)
            .font(.system(size: 9, weight: .bold, design: .rounded))
            .foregroundStyle(.white)
            .frame(width: 17, height: 17)
            .background(source.badgeColor, in: Circle())
            .overlay(Circle().stroke(Palette.background, lineWidth: 2))
            .accessibilityLabel(source.title)
    }
}

// MARK: - DSH session row

/// A DSH conversation in the home list: styled like `BotRow` so the mixed list reads as one.
struct DSHSessionRow: View {
    let session: DSHSession
    let sourceBadge: AnyView?

    @ScaledMetric(relativeTo: .body) private var avatar: CGFloat = 48
    @ScaledMetric(relativeTo: .body) private var rowPadding: CGFloat = 16
    @ScaledMetric(relativeTo: .body) private var titleSize: CGFloat = 17.5
    @ScaledMetric(relativeTo: .subheadline) private var previewSize: CGFloat = 15.5
    @ScaledMetric(relativeTo: .footnote) private var timeSize: CGFloat = 13

    var body: some View {
        HStack(spacing: 14) {
            RoundedRectangle(cornerRadius: avatar * 0.34, style: .continuous)
                .fill(Palette.surface)
                .frame(width: avatar, height: avatar)
                .overlay {
                    Image(systemName: "sparkles")
                        .font(.system(size: avatar * 0.42))
                        .foregroundStyle(Palette.warning)
                }
                .overlay(alignment: .bottomTrailing) {
                    if let sourceBadge { sourceBadge }
                }
            VStack(alignment: .leading, spacing: 3) {
                HStack(alignment: .firstTextBaseline) {
                    Text(session.title)
                        .font(.system(size: titleSize, weight: .semibold))
                        .foregroundStyle(Color(uiColor: .label))
                        .lineLimit(1)
                    Spacer(minLength: 8)
                    if let date {
                        Text(RelativeTime.day(date))
                            .font(.system(size: timeSize))
                            .foregroundStyle(Color(uiColor: .tertiaryLabel))
                            .fixedSize(horizontal: true, vertical: false)
                    }
                }
                Text(session.running ? "运行中" : "DSH 对话")
                    .font(.system(size: previewSize))
                    .foregroundStyle(session.running ? Palette.warning : Color(uiColor: .secondaryLabel))
                    .lineLimit(1)
            }
        }
        .frame(maxWidth: .infinity, alignment: .leading)
        .padding(.vertical, rowPadding)
        .contentShape(Rectangle())
        .accessibilityElement(children: .combine)
    }

    private var date: Date? {
        guard let value = session.updatedAt else { return nil }
        let ms = value > 1_000_000_000_000 ? value : value * 1000
        return Date(timeIntervalSince1970: ms / 1000)
    }
}
