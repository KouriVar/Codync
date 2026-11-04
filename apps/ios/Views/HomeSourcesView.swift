import CodyncKit
import CodyncUI
import DSHKit
import SwiftUI
import UIKit

/// The home: one list — the pinned conversations — with a search field and one round button under
/// it. Each source's own list (Coe, DS Bot, DSH 对话) is still built here, but nothing opens it for
/// now; the source selection itself still lives in Settings. The top-right keeps only the "+".
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
    /// The field in the bottom bar has the keyboard.
    @FocusState private var searchFocused: Bool
    /// Keyboard up: the bar sits the composer's 12pt above it instead of 28pt above the safe area.
    @State private var keyboardUp = false
    @State private var creating: NewTarget?
    @State private var confirmDelete: RosterItem?
    /// The voice sheet's session and what it says to the lead bot.
    @State private var voice = VoiceSession()
    /// The bar has grown into the voice capsule: the search field has given it its width.
    @State private var voiceOpen = false
    /// The field has folded away completely and left the tree, so none of its glass is left behind.
    @State private var searchCollapsed = false
    /// The row's width inside the bar's 16pt sides: what the capsule grows to.
    @State private var barWidth: CGFloat = 0
    /// The voice sheet is up (a pull up on the capsule opens it).
    @State private var showVoice = false
    /// Which height it rests at: half or full.
    @State private var voiceDetent: PresentationDetent = .medium
    /// The capsule's voice settings: the sheet that page opens for itself.
    @State private var showVoiceSettings = false
    /// A pull down on the capsule with words to lose asks first, as the sheet does.
    @State private var confirmDiscardVoice = false
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
        navigationStack
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
                    // iOS takes the microphone away when the app leaves, so the sheet goes too.
                    showVoice = false
                    voice.discard()
                case .active: syncDSHConnection()
                default: break
                }
            }
            // The voice sheet: on the home's root view, never from a list row — a rebuilt anchor
            // there takes the sheet, and the home with it (C0035, C0136).
            .sheet(isPresented: $showVoice, onDismiss: {
                // Pulled down or sent: the recording is over, and the capsule shrinks back into the
                // round button the way it grew out of it.
                voice.discard()
                voiceDetent = .medium
                closeCapsule()
            }) {
                VoiceSheetView(lead: leadBot?.bot, session: voice,
                               openSystemSettings: { openSystemVoiceSettings() },
                               openSettings: { showVoiceSettings = true })
                    .presentationDetents([.medium, .large], selection: $voiceDetent)
                    // The system's grabber, glass and dismissal are the whole point: no hand-drawn
                    // handle, no custom transition, so it leaves exactly the way it came in.
                    .presentationDragIndicator(.visible)
                    // Pulling down closes the sheet — unless there are words to lose, in which case
                    // the sheet asks first (the gesture in the sheet is what asks).
                    .interactiveDismissDisabled(voice.hasWords)
            }
            // The capsule's own settings. One page presents one sheet, so this lives here rather than
            // inside the sheet above: while the sheet is up, its own settings button opens them.
            .sheet(isPresented: $showVoiceSettings) {
                VoiceLanguageSheet()
                    .presentationDetents([.medium])
                    .presentationDragIndicator(.visible)
                    .environment(\.dismissModal, DismissModalAction { showVoiceSettings = false })
            }
            .glassToast($toast, topPadding: 6)
            .onChange(of: voice.phase) { _, phase in
                switch phase {
                // The words (or a refusal) are read at half height: come up from the capsule.
                case .confirming, .notice:
                    openVoiceSheet()
                case .paused where voice.notHeard:
                    // Nothing heard: the hint only lives in the taller sheet.
                    openVoiceSheet()
                // Sent or cancelled: the sheet has done its work.
                case .idle:
                    if showVoice { showVoice = false }
                default: break
                }
            }
            .onChange(of: voiceDetent) { _, _ in Haptics.selection() }
            .confirmationDialog(L10n.tr("Discard this voice message?"), isPresented: $confirmDiscardVoice,
                                titleVisibility: .visible) {
                Button(L10n.tr("Discard"), role: .destructive) { dismissVoice() }
                Button(L10n.tr("Keep editing"), role: .cancel) {}
            }
            // The bar climbs back the moment the sheet starts down, not after it has gone.
            .onAppear { voice.onSend = { words, files in await sendToLeadBot(words, files: files) } }
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

    /// The home's one stack. The root is the pinned list; a conversation pushes inside it, and the
    /// bottom bar belongs to the root alone, so a pushed page has none of it.
    private var navigationStack: some View {
        NavigationStack(path: path) {
            Group {
                // Typing anything shows the whole home filtered, as the search tab used to; with the
                // field empty it is the pinned list again.
                if isSearching {
                    searchResults
                } else {
                    rosterList(pinnedEntries, pinnedEmpty: true)
                }
            }
            .navigationTitle("")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar { toolbarContent }
            // A bottom inset rather than an overlay: the list keeps clear of it, and a keyboard takes
            // it up so the field and the button rest just above the keys.
            .safeAreaInset(edge: .bottom, spacing: 0) { bottomBar }
            .navigationDestination(for: BotReference.self) { ref in
                ChatScreen(ref: ref)
            }
            .navigationDestination(item: $openDSHSession) { _ in
                DSHConversationView(gateway: dsh)
            }
        }
        .tint(Palette.text)
    }

    private var path: Binding<[BotReference]> {
        Binding(get: { accounts.selection.map { [$0] } ?? [] }, set: { accounts.selection = $0.last })
    }

    /// One list of sessions, in the same row style as before, with the system's soft top edge. The
    /// home's root draws the pinned one; each source draws its own with `hint` and no pinned empty
    /// state, and keeps that shape for when an entry to it comes back.
    private func rosterList(_ entries: [HomeEntry], hint: String? = nil, pinnedEmpty: Bool = false) -> some View {
        List {
            if let hint {
                dshHintRow(hint)
            }
            if entries.isEmpty {
                // The pinned list teaches how to pin; a source list just says there is nothing.
                if pinnedEmpty {
                    pinnedEmptyState
                } else {
                    emptyRow
                }
            }
            ForEach(entries) { entry in
                entryRow(entry)
            }
        }
        .plainRosterList()
        .scrollEdgeEffectStyle(.soft, for: .top)
        .background(Palette.background)
        .refreshable { await refreshAll() }
    }

    /// The filtered home: the same rows, matching by title as you type. What the search tab used to
    /// show, now under the field in place — no push, no sheet.
    private var searchResults: some View {
        List {
            if searchEntries.isEmpty {
                Text(L10n.tr("No matches"))
                    .font(.footnote)
                    .foregroundStyle(Palette.secondary)
                    .frame(maxWidth: .infinity)
                    .padding(.vertical, 40)
                    .rosterRow()
            }
            ForEach(searchEntries) { entry in
                entryRow(entry)
            }
        }
        .plainRosterList()
        .scrollEdgeEffectStyle(.soft, for: .top)
        .background(Palette.background)
    }

    /// Every session of an enabled source whose title matches the search field.
    private var searchEntries: [HomeEntry] {
        guard !searchQuery.isEmpty else { return [] }
        return otherEntries.filter { entry in
            switch entry.kind {
            case .bot(let item):
                return item.bot.name.localizedStandardContains(searchQuery)
            case .dsh(let session):
                return session.title.localizedStandardContains(searchQuery)
            }
        }
    }

    // MARK: - Rows

    /// Every session of an enabled source, pinning aside.
    private var otherEntries: [HomeEntry] {
        enabledOrdered.flatMap { source in
            source == .dsh ? dshEntries : botEntries(for: source)
        }
    }

    private var emptyRow: some View {
        Text("没有会话")
            .font(.footnote)
            .foregroundStyle(Palette.secondary)
            .frame(maxWidth: .infinity)
            .padding(.vertical, 40)
            .rosterRow()
    }

    // MARK: - The bottom bar

    /// The bot the round button speaks to: the one the long-press menu made lead, and the store it
    /// lives on.
    private var leadBot: RosterItem? {
        accounts.roster.first { $0.bot.lead && !$0.bot.isGroup }
    }

    /// The one curve the bar morphs on: the sheet's own settle, so the capsule growing and the
    /// sheet's detents changing read as one move. Reduce Motion swaps the spring for a short fade.
    private static let morph = VoiceSheetView.settle
    private var morphAnimation: Animation { Motion.reduced(Self.morph, reduceMotion) ?? Motion.fade }

    /// The home's one bar, at the conversation page's composer numbers: 16pt at the screen's edges,
    /// 12pt between the field and the round button, 6pt above, and 28pt — or the composer's 12pt
    /// while the keyboard is up — below. The field and the button are one row whose spacing closes as
    /// the button takes the field's width: a search capsule and a growing voice capsule in one glass
    /// container, so their surfaces blend while they cross.
    private var bottomBar: some View {
        GlassEffectContainer(spacing: 12) {
            HStack(spacing: voiceOpen ? 0 : 12) {
                if !(voiceOpen && searchCollapsed) {
                    searchBox
                        .frame(width: searchWidth)
                        .opacity(voiceOpen ? 0 : 1)
                }
                voiceSlot
            }
        }
        .frame(maxWidth: .infinity, alignment: .trailing)
        .padding(.horizontal, 16)
        .padding(.top, 6)
        .padding(.bottom, keyboardUp ? 12 : 28)
        .ignoresSafeArea(.container, edges: keyboardUp ? [] : .bottom)
        // The row inside the 16pt sides: how wide the capsule grows.
        .onGeometryChange(for: CGFloat.self) { $0.size.width } action: { width in
            barWidth = max(0, width - 32)
        }
        .onReceive(NotificationCenter.default.publisher(for: UIResponder.keyboardWillShowNotification)) { _ in
            keyboardUp = true
        }
        .onReceive(NotificationCenter.default.publisher(for: UIResponder.keyboardWillHideNotification)) { _ in
            keyboardUp = false
        }
    }

    /// The field's width is whatever the button is not using, so the two always add up to the row:
    /// the button's 44pt and the 12pt gap now, the whole row and no gap once it has grown. Until the
    /// row has been measured the field keeps its natural, flexible width.
    private var searchWidth: CGFloat? {
        guard barWidth > 0 else { return nil }
        return voiceOpen ? 0 : max(0, barWidth - ControlMetrics.Size.icon.side - 12)
    }

    /// The search field in place: `.searchable` used to push a separate page, and this one stays on
    /// the home — tapping anywhere on the capsule focuses it and brings the keyboard up, and the list
    /// below answers as you type. No clear button of its own: the round button beside it is the one.
    private var searchBox: some View {
        HStack(spacing: 8) {
            RemixIcon("search-line")
                .foregroundStyle(Palette.secondary)
            TextField(L10n.tr("Search chats"), text: $searchText)
                .textFieldStyle(.plain)
                .textInputAutocapitalization(.never)
                .autocorrectionDisabled()
                .focused($searchFocused)
        }
        .font(.body)
        // The composer's own insets: 14pt inside the capsule, and the row it draws against.
        .padding(.horizontal, 14)
        .frame(minHeight: ControlMetrics.Size.compact.hitTarget)
        // The composer's box, corner for corner.
        .glass(in: RoundedRectangle(cornerRadius: 24, style: .continuous), interactive: true)
        .contentShape(RoundedRectangle(cornerRadius: 24, style: .continuous))
        .onTapGesture { searchFocused = true }
    }

    /// The round button and the capsule it becomes: one glass shape, one frame that changes. Closed it
    /// is the app's 44pt icon circle; open it is the 76pt voice capsule, holding the same row the
    /// sheet's old 76pt detent drew. The content is clipped to the shape while it grows.
    private var voiceSlot: some View {
        ZStack {
            if voiceOpen {
                VoicePill(lead: leadBot?.bot, session: voice) { showVoiceSettings = true }
                    .transition(.opacity)
            } else {
                circleGlyphs
            }
        }
        .frame(width: voiceOpen ? (barWidth > 0 ? barWidth : nil) : ControlMetrics.Size.icon.side,
               height: voiceOpen ? VoicePill.height : ControlMetrics.Size.icon.side)
        .clipShape(Capsule())
        .glass(in: Capsule(), interactive: !voiceOpen)
        .contentShape(Capsule())
        .gesture(voiceDrag)
    }

    /// The closed circle's two states in the same place: the microphone while the field is idle, a ✕
    /// that empties it and puts the keyboard away once it has focus. The glass belongs to the slot, so
    /// the swap is only a fade.
    private var circleGlyphs: some View {
        ZStack {
            slotGlyph(L10n.tr("Voice"), glyph: "mic-line", shown: !searchFocused) { beginVoice() }
            slotGlyph(L10n.tr("Close search"), glyph: "close-line", shown: searchFocused) { endSearch() }
        }
        .animation(Motion.reduced(Motion.fade, reduceMotion), value: searchFocused)
    }

    /// One 24pt glyph in the circle the slot draws: `GlassButton`'s own composition, with the glass
    /// lifted to the slot so the shape can grow out of it.
    private func slotGlyph(_ title: String, glyph: String, shown: Bool,
                           action: @escaping () -> Void) -> some View {
        Button(action: action) {
            RemixIcon(glyph, size: ControlMetrics.Size.icon.glyph)
                .foregroundStyle(Palette.text)
                .frame(width: ControlMetrics.Size.icon.side, height: ControlMetrics.Size.icon.side)
                .contentShape(Circle())
        }
        .buttonStyle(PressScale())
        .opacity(shown ? 1 : 0)
        .allowsHitTesting(shown)
        .accessibilityHidden(!shown)
        .accessibilityLabel(Text(title))
    }

    /// The capsule's two moves: a short pull up is the sheet at half height, a short pull down puts
    /// the capsule away again — asking first when there are words or a photo to lose.
    private var voiceDrag: some Gesture {
        DragGesture(minimumDistance: 12)
            .onEnded { value in
                guard voiceOpen, !showVoice else { return }
                if value.translation.height < -30 {
                    openVoiceSheet()
                } else if value.translation.height > 30 {
                    if voice.hasWords { confirmDiscardVoice = true } else { dismissVoice() }
                }
            }
    }

    /// ✕: the words go, the keyboard goes with them, the list comes back whole, and the circle turns
    /// back into the microphone.
    private func endSearch() {
        searchText = ""
        searchFocused = false
    }

    /// No lead bot is a setup problem, not a recording one: say where to fix it instead of opening the mic.
    private func beginVoice() {
        guard !voiceOpen, !showVoice else { return }
        guard leadBot != nil else {
            toast = GlassToastItem(icon: "error-warning-line",
                                   text: L10n.tr("Pick a main bot in Settings first"))
            return
        }
        // The keyboard goes first: the bar must not ride up on it while it grows.
        searchFocused = false
        withAnimation(morphAnimation) { voiceOpen = true }
        // Once the field has folded away it leaves the tree entirely, so no glass of its own is left
        // at zero width to leave a line behind.
        Task { @MainActor in
            try? await Task.sleep(for: .milliseconds(450))
            if voiceOpen { searchCollapsed = true }
        }
        Task { @MainActor in await voice.begin() }
    }

    /// The pull up: the same sheet as before, opened at the half height.
    private func openVoiceSheet() {
        guard voiceOpen, !showVoice else { return }
        voiceDetent = .medium
        showVoice = true
    }

    /// A pull down, or ✕ on the sheet: back to the round button, the words thrown away.
    private func dismissVoice() {
        voice.discard()
        closeCapsule()
    }

    /// The reverse of `beginVoice`: the capsule shrinks back into the circle and the field comes back
    /// to its width. The field returns to the tree first, still zero wide and invisible.
    private func closeCapsule() {
        guard voiceOpen else { return }
        searchCollapsed = false
        withAnimation(morphAnimation) { voiceOpen = false }
    }

    /// The same send a typed message uses, so the bot answers exactly as it would in the chat. The
    /// sheet keeps the words and asks again when it comes back false.
    private func sendToLeadBot(_ words: String, files: [OutgoingFile] = []) async -> Bool {
        guard let lead = leadBot, let store = accounts.store(for: lead.ref.computerId) else { return false }
        guard await store.sendAndConfirm(words, to: lead.bot.id, files: files) else { return false }
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
        // iOS 27 gives a toolbar item an icon-sized inset; a photo inside it is stretched wide in the
        // bar's capsule unless the item asks for its content margins to go.
        if #available(iOS 27.0, *) {
            ToolbarItem(placement: .topBarLeading) { AccountSwitcherButton(avatarSize: 36) }
                .contentMarginsRemoved()
        } else {
            ToolbarItem(placement: .topBarLeading) { AccountSwitcherButton(avatarSize: 36) }
        }
        ToolbarItem(placement: .topBarTrailing) { newBotMenu }
    }

    /// The system's own menu: one entry per source Settings leaves on.
    private var newBotMenu: some View {
        Menu {
            if enabledSources.contains(.coe) {
                Button(action: { newBot(source: .coe) }) {
                    Label { Text(L10n.tr("New Coe chat")) } icon: { RemixIcon("ghost-4-line") }
                }
            }
            if enabledSources.contains(.dsBot) {
                Button(action: { newBot(source: .dsBot) }) {
                    Label { Text(L10n.tr("New DS Bot chat")) } icon: { RemixIcon("deepseek-line") }
                }
            }
            if enabledSources.contains(.dsh) {
                Button(action: { dsh.newSession() }) {
                    Label { Text(L10n.tr("New DSH chat")) } icon: { RemixIcon("chat-ai-line") }
                }
            }
        } label: {
            RemixImage("add-line", size: 24)
        }
        .accessibilityLabel(Text(L10n.tr("New")))
        .disabled(availableStores.isEmpty && !enabledSources.contains(.dsh))
    }

    // MARK: - Empty states

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
                guard let session = dsh.sessions.first(where: { $0.id == key.id }) else { return nil }
                return HomeEntry(kind: .dsh(session))
            case .coe, .dsBot:
                guard let item = accounts.roster.first(where: {
                    $0.bot.id == key.id && HomeSource.of(bot: $0.bot) == key.source
                }) else { return nil }
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
            .map { HomeEntry(kind: .bot($0)) }
    }

    private var dshEntries: [HomeEntry] {
        guard enabledSources.contains(.dsh) || pinnedKeys.contains(where: { $0.source == .dsh }) else { return [] }
        return dsh.sessions
            .filter { !HomeSessionVisibility.isHidden(title: $0.title, isDSH: true) }
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

    /// A new conversation on the named source. Coe and DS Bot share the editor; a DS Bot is that
    /// same bot with a `command` filled in, which is where the editor comes in.
    private func newBot(source: HomeSource) {
        guard let store = onlineStores.first ?? availableStores.first else { return }
        creating = NewTarget(kind: .bot, computerId: store.computer.id, source: source)
    }

    private func newGroup() {
        guard let store = onlineStores.first else { return }
        Task {
            try? await Task.sleep(for: .milliseconds(200))
            creating = NewTarget(kind: .group, computerId: store.computer.id)
        }
    }

    // MARK: - Sheets

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
                                                 set: { creating = NewTarget(kind: .bot, computerId: $0, source: target.source) }))
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
        var source: HomeSource = .coe
        var id: String { "\(kind)-\(computerId)-\(source.rawValue)" }
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
