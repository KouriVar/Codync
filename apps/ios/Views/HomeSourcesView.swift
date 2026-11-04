import CodyncKit
import CodyncUI
import DSHKit
import SwiftUI
import UIKit

/// The home: a pinned page first, then one page per selected source (Coe, DS Bot, DSH 对话) in a
/// fixed order. The source selection lives in Settings; the top-right keeps only the "+".
@MainActor
struct HomeSourcesView: View {
    @Environment(AppStore.self) private var app
    @Environment(AccountStore.self) private var accounts
    @Environment(\.accessibilityReduceMotion) private var reduceMotion
    @Environment(\.scenePhase) private var scenePhase
    @Environment(\.openURL) private var openURL

    @ObservedObject private var dsh = DSHGateway.shared

    @AppStorage(HomeSourcePrefs.sourcesKey) private var sourcesRaw = HomeSourcePrefs.defaultRaw
    @AppStorage(HomeSourcePrefs.pinnedKey) private var pinnedRaw = ""

    @State private var searchText = ""
    @State private var creating: NewTarget?
    @State private var confirmDelete: RosterItem?
    @State private var showCameraSheet = false
    /// The voice capsule and what it says to the lead bot.
    @State private var voice = VoiceSession()
    /// The voice sheet is up (it opens on the microphone button).
    @State private var showVoice = false
    /// Which height it rests at: the 76pt pill, half, or full.
    @State private var voiceDetent: PresentationDetent = VoiceSheetView.small
    /// The glass pill that says what was just sent.
    @State private var toast: GlassToastItem?
    @State private var openDSHSession: DSHSession?
    @State private var showDSHConnect = false
    @State private var naming: SectionNaming?
    @State private var sharingTemplate: EditTarget?
    @State private var editing: EditTarget?
    @State private var editingGroup: GroupTarget?
    @AppStorage("manualUnreadConversations") private var manualUnreadData = Data()

    private var enabledSources: Set<HomeSource> {
        #if DEBUG
        if let raw = ProcessInfo.processInfo.environment["CODYNC_HOME_SOURCES"] {
            return HomeSourcePrefs.enabled(from: raw)
        }
        #endif
        return HomeSourcePrefs.enabled(from: sourcesRaw)
    }

    private var enabledOrdered: [HomeSource] { HomeSource.allCases.filter { enabledSources.contains($0) } }

    private var searchQuery: String { searchText.trimmingCharacters(in: .whitespacesAndNewlines) }
    private var isSearching: Bool { !searchQuery.isEmpty }

    // MARK: - Body

    var body: some View {
        chromeView
            .refreshable { await refreshAll() }
            .task {
                syncDSHConnection()
                #if DEBUG
                // Screenshots: CODYNC_OPEN_DSH_SESSION=1 opens the newest DSH conversation.
                if ProcessInfo.processInfo.environment["CODYNC_OPEN_DSH_SESSION"] != nil {
                    for _ in 0..<40 {
                        if let session = dsh.sessions.first { openDSH(session); break }
                        try? await Task.sleep(for: .milliseconds(250))
                    }
                }
                #endif
            }
            .onChange(of: sourcesRaw) { _, _ in syncDSHConnection() }
            .onChange(of: availableStores.map(\.selection)) { handleStoreSelections() }
            // DSH pauses in the background and reconnects when the app comes back.
            .onChange(of: scenePhase) { _, phase in
                switch phase {
                case .background:
                    dsh.disconnect()
                    // iOS stops the microphone when the app leaves: no capsule may stay up.
                    voice.cancel()
                case .active: syncDSHConnection()
                default: break
                }
            }
            .sheet(isPresented: $showCameraSheet, content: cameraSheet)
            // The voice sheet: on the home's root view, never from a list row — a rebuilt anchor
            // there takes the sheet, and the home with it (C0035, C0136).
            .sheet(isPresented: $showVoice, onDismiss: { voiceDetent = VoiceSheetView.small }) {
                VoiceSheetView(lead: leadBot?.bot, session: voice, detent: $voiceDetent,
                               openSystemSettings: { openSystemVoiceSettings() })
                    .presentationDetents([VoiceSheetView.small, .medium, .large], selection: $voiceDetent)
                    // The system's grabber and glass are the whole point: no hand-drawn handle.
                    .presentationDragIndicator(.visible)
                    // At the pill the home stays live; halfway and up it dims and locks itself.
                    .presentationBackgroundInteraction(.enabled(upThrough: VoiceSheetView.small))
                    .interactiveDismissDisabled()
            }
            .glassToast($toast, topPadding: 6)
            .onChange(of: voice.phase) { _, phase in
                switch phase {
                // The words are read at half height: come up if the pill is where it still sits.
                case .confirming, .notice:
                    if showVoice, voiceDetent == VoiceSheetView.small {
                        withAnimation(Motion.reduced(Motion.layout, reduceMotion)) { voiceDetent = .medium }
                    }
                // Sent or cancelled: the sheet has done its work.
                case .idle:
                    if showVoice { showVoice = false }
                default: break
                }
            }
            .onChange(of: voiceDetent) { _, _ in Haptics.selection() }
            .onAppear { voice.onSend = { await sendToLeadBot($0) } }
            .navigationDestination(item: $openDSHSession) { _ in
                DSHConversationView(gateway: dsh)
            }
            .sheet(isPresented: $showDSHConnect, content: dshConnectSheet)
            .codyncSheet(item: $creating) { target in creatingSheet(target) }
            .alert(deleteTitle, isPresented: deleteShown, presenting: confirmDelete) { item in
                deleteButtons(item)
            } message: { item in
                deleteMessage(item)
            }
            .sectionNameDialog($naming)
            .codyncSheet(item: $sharingTemplate) { target in BotTemplateView(draft: target.draft) }
            .codyncSheet(item: $editing) { target in
                if let store = accounts.store(for: target.computerId) {
                    BotEditorView(draft: target.draft).environment(store)
                }
            }
            .codyncSheet(item: $editingGroup) { target in
                if let store = accounts.store(for: target.computerId) {
                    GroupEditorView(group: target.group).environment(store)
                }
            }
    }

    private var chromeView: some View {
        baseView
            .navigationTitle("")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar(.visible, for: .navigationBar)
            // Let the list and the top fade reach under the bar.
            .toolbarBackground(.hidden, for: .navigationBar)
            .toolbar { toolbarContent }
    }

    private var baseView: some View {
        // A paged TabView confines every page to the safe area, so a page's List can never reach
        // under the navigation bar. A horizontal paging ScrollView can, and the blur is mounted on
        // it exactly like the chat page mounts it on its scroll view.
        ScrollView(.horizontal) {
            LazyHStack(spacing: 0) {
                pinnedPage
                    .containerRelativeFrame(.horizontal)
                ForEach(Array(enabledOrdered.enumerated()), id: \.element) { _, source in
                    sourcePage(source)
                        .containerRelativeFrame(.horizontal)
                }
            }
            .scrollTargetLayout()
        }
        .scrollTargetBehavior(.paging)
        .scrollIndicators(.hidden)
        .background(Palette.background)
        .ignoresSafeArea(edges: .top)
        .overlay(alignment: .top) { ProgressiveTopBlur() }
        .safeAreaInset(edge: .bottom, spacing: 0) { bottomBar }
    }

    /// Status bar + inline navigation bar height: the list scrolls under the bar, but its first
    /// row still starts below the avatar and the "+".
    private var topBarInset: CGFloat {
        let status = UIApplication.shared.connectedScenes
            .compactMap { $0 as? UIWindowScene }
            .first?.windows.first(where: \.isKeyWindow)?.safeAreaInsets.top ?? 0
        return status + 44
    }

    private var bottomBar: some View {
        // The bar steps down and fades out with the sheet, and comes back when it closes.
        HomeBottomBar(searchText: $searchText, hidden: showVoice, startVoice: beginVoice) {
            showCameraSheet = true
        }
    }

    // MARK: - The voice capsule

    /// The bot the capsule speaks to: the one the long-press menu made lead, and the store it lives on.
    private var leadBot: RosterItem? {
        accounts.roster.first { $0.bot.lead && !$0.bot.isGroup }
    }

    /// No lead bot is a setup problem, not a recording one: say where to fix it instead of opening the mic.
    private func beginVoice() {
        guard leadBot != nil else {
            toast = GlassToastItem(icon: "error-warning-line",
                                   text: L10n.tr("Pick a main bot in Settings first"))
            return
        }
        voiceDetent = VoiceSheetView.small
        showVoice = true
        Task { await voice.begin() }
    }

    /// The same send a typed message uses, so the bot answers exactly as it would in the chat. The
    /// sheet keeps the words and asks again when it comes back false.
    private func sendToLeadBot(_ words: String) async -> Bool {
        guard let lead = leadBot, let store = accounts.store(for: lead.ref.computerId) else { return false }
        guard await store.sendAndConfirm(words, to: lead.bot.id) else { return false }
        // Stay on the home: the pill says where it went and opens it if tapped.
        toast = GlassToastItem(icon: "check-line", text: L10n.tr("Sent to") + " " + lead.bot.name) {
            accounts.selection = lead.ref
        }
        return true
    }

    private func openSystemVoiceSettings() {
        guard let url = URL(string: UIApplication.openSettingsURLString) else { return }
        openURL(url)
    }

    @ToolbarContentBuilder private var toolbarContent: some ToolbarContent {
        // iOS 27 can keep the native glass rim without the default icon-sized inset around a
        // photo; without this the avatar is stretched inside the bar's capsule.
        if #available(iOS 27.0, *) {
            ToolbarItem(placement: .topBarLeading) { AccountSwitcherButton(avatarSize: 36) }
                .contentMarginsRemoved()
        } else {
            ToolbarItem(placement: .topBarLeading) { AccountSwitcherButton(avatarSize: 36) }
        }
        ToolbarItem(placement: .topBarTrailing) { newBotMenu }
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

    // MARK: - Pages

    private var pinnedPage: some View {
        List {
            if pinnedEntries.isEmpty {
                pinnedEmptyState
            }
            ForEach(pinnedEntries) { entry in
                entryRow(entry)
            }
        }
        .plainRosterList(topInset: topBarInset)
    }

    private func sourcePage(_ source: HomeSource) -> some View {
        List {
            if source == .dsh, let hint = dshHint {
                dshHintRow(hint)
            }
            let items = source == .dsh ? dshEntries : botEntries(for: source)
            if items.isEmpty && !(source == .dsh && dshHint != nil) {
                Text(source == .dsh ? "还没有 DSH 会话" : "没有会话")
                    .font(.footnote)
                    .foregroundStyle(Palette.secondary)
                    .frame(maxWidth: .infinity)
                    .padding(.vertical, 40)
                    .rosterRow()
            }
            ForEach(items) { entry in
                entryRow(entry)
            }
        }
        .plainRosterList(topInset: topBarInset)
    }

    private var pinnedEmptyState: some View {
        VStack(spacing: 10) {
            Image(systemName: "pin").font(.title2)
            Text("长按会话，选『钉在首页』")
                .font(.footnote)
        }
        .foregroundStyle(Palette.secondary)
        .frame(maxWidth: .infinity)
        .padding(.vertical, 64)
        .rosterRow()
    }

    // MARK: - Pins

    private struct PinnedKey {
        let source: HomeSource
        let id: String
    }

    private var pinnedKeys: [PinnedKey] {
        pinnedRaw.split(separator: "\n").compactMap { line in
            let parts = line.split(separator: "|", maxSplits: 1)
            guard parts.count == 2, let source = HomeSource(rawValue: String(parts[0])) else { return nil }
            return PinnedKey(source: source, id: String(parts[1]))
        }
    }

    private var pinnedEntries: [HomeEntry] {
        pinnedKeys.compactMap { key -> HomeEntry? in
            switch key.source {
            case .dsh:
                guard let session = dsh.sessions.first(where: { $0.id == key.id }),
                      !isSearching || session.title.localizedStandardContains(searchQuery) else { return nil }
                return HomeEntry(kind: .dsh(session))
            case .coe, .dsBot:
                guard let item = accounts.roster.first(where: {
                    $0.bot.id == key.id && HomeSource.of(bot: $0.bot) == key.source
                }), matchesSearch(item) else { return nil }
                return HomeEntry(kind: .bot(item))
            }
        }
    }

    private func isPinned(_ source: HomeSource, _ id: String) -> Bool {
        pinnedKeys.contains { $0.source == source && $0.id == id }
    }

    private func togglePin(_ source: HomeSource, _ id: String) {
        var keys = pinnedKeys
        if let index = keys.firstIndex(where: { $0.source == source && $0.id == id }) {
            keys.remove(at: index)
        } else {
            keys.append(PinnedKey(source: source, id: id))
        }
        pinnedRaw = keys.map { "\($0.source.rawValue)|\($0.id)" }.joined(separator: "\n")
    }

    private func pinMenuItem(_ source: HomeSource, _ id: String) -> MenuItem {
        let pinned = isPinned(source, id)
        return MenuItem(pinned ? "从首页移除" : "钉在首页", icon: pinned ? "pin.slash" : "pin") {
            togglePin(source, id)
        }
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
    }

    private func botEntries(for source: HomeSource) -> [HomeEntry] {
        accounts.roster
            .filter { HomeSource.of(bot: $0.bot) == source }
            .filter { !HomeSessionVisibility.isHidden(title: $0.bot.name, isDSH: false) }
            .filter { matchesSearch($0) }
            .map { HomeEntry(kind: .bot($0)) }
    }

    private var dshEntries: [HomeEntry] {
        guard enabledSources.contains(.dsh) || pinnedKeys.contains(where: { $0.source == .dsh }) else { return [] }
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
            DSHSessionRow(session: session, preview: dsh.previews[session.id],
                          sourceBadge: AnyView(SourceBadge(source: .dsh)))
                .contentShape(Rectangle())
                .onTapGesture { openDSH(session) }
                .contentShape(.contextMenuPreview, RoundedRectangle(cornerRadius: 34, style: .continuous))
                .contextActions(preview: { DSHSessionMenuPreview(session: session, message: dshPreviewText(session)) }) {
                    dshMenuItems(session)
                }
                .rosterRow()
        }
    }

    private func botRow(_ item: RosterItem, store: BotStore) -> some View {
        let source = HomeSource.of(bot: item.bot)
        return BotRow(bot: item.bot, manuallyUnread: manuallyUnread(item))
            .environment(store)
            // Only DS Bot carries a badge; the source badge sits where the lead agent's star
            // does (avatar is 48pt with 16pt vertical row padding).
            .overlay(alignment: .topLeading) {
                if source.badge != nil {
                    SourceBadge(source: source)
                        .offset(x: 31, y: 47)
                        .allowsHitTesting(false)
                }
            }
            .contentShape(Rectangle())
            .onTapGesture { accounts.selection = item.ref }
            .contentShape(.contextMenuPreview, RoundedRectangle(cornerRadius: 34, style: .continuous))
            .contextActions(quick: quickActions(item, store: store),
                            preview: { BotMenuPreview(bot: item.bot).environment(store) }) {
                botMenuItems(item, store: store)
            }
            .rosterRow()
    }

    private var dshHint: String? {
        guard enabledSources.contains(.dsh) || pinnedKeys.contains(where: { $0.source == .dsh }) else { return nil }
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

    // MARK: - Actions

    private func openDSH(_ session: DSHSession) {
        dsh.open(sessionId: session.id)
        openDSHSession = session
    }

    /// DSH connects when its page is on, or when a pinned DSH conversation needs it.
    private func syncDSHConnection() {
        let needed = enabledSources.contains(.dsh) || pinnedKeys.contains { $0.source == .dsh }
        if needed {
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

    private func manuallyUnread(_ item: RosterItem) -> Bool {
        ManualUnreadMarks(data: manualUnreadData)
            .contains(account: accounts.accountId, computer: item.ref.computerId, bot: item.bot.id)
    }

    private func setManuallyUnread(_ unread: Bool, item: RosterItem) {
        var marks = ManualUnreadMarks(data: manualUnreadData)
        marks.set(unread, account: accounts.accountId, computer: item.ref.computerId, bot: item.bot.id)
        manualUnreadData = marks.data
    }

    /// The three icon-only shortcuts on top: pin, read/unread, edit.
    private func quickActions(_ item: RosterItem, store: BotStore) -> [QuickAction] {
        let bot = item.bot
        let unread = bot.unread > 0 || manuallyUnread(item)
        return [
            QuickAction(bot.pinned ? "取消置顶" : "置顶",
                        icon: bot.pinned ? "unpin-line" : "pushpin-2-line") {
                store.setPinned(bot, !bot.pinned)
            },
            QuickAction(unread ? "标为已读" : "标为未读",
                        icon: unread ? "mail-open-line" : "mail-unread-line") {
                setManuallyUnread(!unread, item: item)
                if unread { store.markAllRead(bot.id) }
            },
            QuickAction("编辑", icon: "edit-line") {
                if bot.isGroup {
                    editingGroup = GroupTarget(computerId: item.ref.computerId, group: bot)
                } else {
                    editing = EditTarget(computerId: item.ref.computerId, draft: BotDraft(bot))
                }
            },
        ]
    }

    /// The rest of the menu, by how often it is used. Delete/hide sit under "更多" so they are
    /// hard to hit by accident.
    private func botMenuItems(_ item: RosterItem, store: BotStore) -> [MenuItem] {
        let bot = item.bot
        var items = [pinMenuItem(HomeSource.of(bot: bot), bot.id)]
        if store.supportsSections {
            items.append(MenuItem("新建分组", icon: "folder-add-line") {
                naming = SectionNaming(title: "新建分组", name: "") { store.setSection(bot, to: $0) }
            })
            items.append(sectionMenu(bot, store: store))
        }
        items.append(MenuItem("分享为模板", icon: "share-forward-line") {
            sharingTemplate = EditTarget(computerId: item.ref.computerId, draft: BotDraft(bot))
        })
        if !bot.lead && !bot.isGroup && store.supportsLeadChoice {
            items.append(MenuItem("设为主 Bot", icon: "star-line") { store.setLead(bot) })
        }
        items.append(MenuItem("复制 ID", icon: "file-copy-line") { UIPasteboard.general.string = bot.id })

        var more: [MenuItem] = []
        if !bot.lead {
            more.append(MenuItem("隐藏", icon: "eye-off-line", destructive: true) { store.setHidden(bot, true) })
        }
        if !bot.lead || store.supportsLeadChoice {
            more.append(MenuItem("删除", icon: "delete-bin-line", destructive: true) { confirmDelete = item })
        }
        if !more.isEmpty {
            items.append(MenuItem("更多", icon: "more-line", submenu: more))
        }
        return items
    }

    /// "移到分组 ▸": the computer's other sections, a new one, and out of its own.
    private func sectionMenu(_ bot: Bot, store: BotStore) -> MenuItem {
        var rows = store.sections.filter { $0 != bot.section }.map { name in
            MenuItem(name, icon: "inbox-line", verbatim: true) { store.setSection(bot, to: name) }
        }
        rows.append(MenuItem("新建分组…", icon: "add-line", divider: !rows.isEmpty) {
            naming = SectionNaming(title: "新建分组", name: "") { store.setSection(bot, to: $0) }
        })
        if bot.section != nil {
            rows.append(MenuItem("从分组移除", icon: "indeterminate-circle-line") {
                store.setSection(bot, to: nil)
            })
        }
        return MenuItem("移到分组", icon: "inbox-line", submenu: rows)
    }

    /// A DSH session only supports what the gateway can do: pin to the home and copy its id.
    private func dshMenuItems(_ session: DSHSession) -> [MenuItem] {
        [pinMenuItem(.dsh, session.id),
         MenuItem("复制 ID", icon: "file-copy-line") { UIPasteboard.general.string = session.id }]
    }

    private func dshPreviewText(_ session: DSHSession) -> String {
        if let preview = dsh.previews[session.id], !preview.isEmpty { return preview }
        return session.running ? "运行中" : "还没有消息"
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
    func plainRosterList(topInset: CGFloat) -> some View {
        listStyle(.plain)
            .contentMargins(.top, topInset + 12, for: .scrollContent)
            .scrollContentBackground(.hidden)
            .environment(\.defaultMinListRowHeight, 0)
            .scrollDismissesKeyboard(.interactively)
    }
}

// MARK: - DSH long-press card

/// The DSH counterpart of `BotMenuPreview`: title and the session's last message, in the same card.
struct DSHSessionMenuPreview: View {
    let session: DSHSession
    let message: String
    @Environment(\.colorScheme) private var colorScheme

    private var cardBackground: Color {
        colorScheme == .dark ? Color(red: 0x14 / 255, green: 0x14 / 255, blue: 0x14 / 255) : Color(uiColor: .systemBackground)
    }
    private var bubbleBackground: Color {
        colorScheme == .dark ? Color(red: 0x23 / 255, green: 0x23 / 255, blue: 0x23 / 255) : Color(uiColor: .secondarySystemGroupedBackground)
    }

    var body: some View {
        VStack(alignment: .leading, spacing: 0) {
            HStack(spacing: 10) {
                RoundedRectangle(cornerRadius: 10, style: .continuous)
                    .fill(Palette.surface)
                    .frame(width: 30, height: 30)
                    .overlay {
                        Image(systemName: "sparkles")
                            .font(.system(size: 13))
                            .foregroundStyle(Palette.warning)
                    }
                Text(session.title).font(.headline).lineLimit(1)
                Spacer(minLength: 0)
            }
            .padding(16)

            Text(message)
                .font(.body)
                .lineLimit(8)
                .frame(maxWidth: .infinity, alignment: .leading)
                .padding(.horizontal, 14)
                .padding(.vertical, 12)
                .background(bubbleBackground, in: RoundedRectangle(cornerRadius: 22, style: .continuous))
                .padding(.horizontal, 16)
                .padding(.top, 2)
                .padding(.bottom, 16)
        }
        .frame(width: 320)
        .background(cardBackground)
    }
}

// MARK: - Source badge

/// A tiny source mark at the avatar's bottom-right, matching the lead agent's star size/position.
struct SourceBadge: View {
    let source: HomeSource

    var body: some View {
        badgeContent
            .foregroundStyle(.white)
            .frame(width: 17, height: 17)
            .background(source.badgeColor, in: Circle())
            .overlay(Circle().stroke(Palette.background, lineWidth: 2))
            .accessibilityLabel(source.title)
    }

    @ViewBuilder private var badgeContent: some View {
        switch source.badge {
        case .letter(let letter):
            Text(letter).font(.system(size: 9, weight: .bold, design: .rounded))
        case .symbol(let name):
            Image(systemName: name).font(.system(size: 9, weight: .bold))
        case nil:
            EmptyView()
        }
    }
}

// MARK: - DSH session row

/// A DSH conversation in the home list: styled like `BotRow` so the mixed list reads as one.
struct DSHSessionRow: View {
    let session: DSHSession
    /// The last message in the session, when the gateway has given us one.
    let preview: String?
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
                Text(subtitle)
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

    private var subtitle: String {
        if let preview, !preview.isEmpty { return preview }
        return session.running ? "运行中" : "DSH 对话"
    }

    private var date: Date? {
        guard let value = session.updatedAt else { return nil }
        let ms = value > 1_000_000_000_000 ? value : value * 1000
        return Date(timeIntervalSince1970: ms / 1000)
    }
}
