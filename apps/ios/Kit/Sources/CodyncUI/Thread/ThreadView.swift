import CodyncKit
import SwiftUI
import UIKit

/// One endless conversation with a bot or a group chat. Only deliberate messages show
/// here; tool calls and thinking live in the "Full conversation" sheet. Any message can be
/// quoted in a reply.
public struct ThreadView: View {
    let botId: String

    public init(botId: String) {
        self.botId = botId
        #if DEBUG
        if let preview = ProcessInfo.processInfo.environment["CODYNC_PROFILE_PREVIEW"], ["details", "edit"].contains(preview) {
            _details = State(initialValue: DetailsRequest(tab: preview == "edit" ? .settings : .details))
        }
        #endif
    }
    @Environment(BotStore.self) var model
    @State var showTrace = false
    @AppStorage("manualUnreadConversations") private var manualUnreadData = Data()
    /// The message the composer's next send quotes.
    @State var replyingTo: Entry?
    @State var botChat: BotChatTarget?
    @State var openArtifact: ArtifactTarget?
    @State var openCall: Entry?
    @State var editingGroup = false
    @State var details: DetailsRequest?
    @State var calling = false
    @State var callSpeaking = false
    @State var interruptCall: (() -> Void)?
    /// The chat stays on the newest message until the reader scrolls away.
    @State var following = true
    @State var loadingEarlier = false
    @Environment(\.accessibilityReduceMotion) var reduceMotion
    @Environment(\.dismiss) var dismiss

    var bot: Bot? { model.bots[botId] }

    /// The messages (each platform's own `transcript`, in its `ThreadView+` file) and the
    /// composer, without the platform's top chrome.
    private var chat: some View {
        transcript
        .background(Palette.background)
        .safeAreaInset(edge: .bottom) {
            VStack(spacing: 6) {
                if let mismatch = model.mismatch {
                    // Nothing sent now could be read on the other side.
                    UpdateNeededCard(store: model, mismatch: mismatch)
                        .padding(.horizontal, 16)
                        .padding(.bottom, 8)
                        .transition(.opacity)
                } else {
                    Composer(botId: botId, replyingTo: $replyingTo,
                             onInterrupt: callSpeaking ? interruptCall : nil)
                }
            }
            .animation(Motion.reduced(Motion.layout, reduceMotion), value: model.mismatch)
        }
        // Grok Bot's call: a bar floating over the chat, which stays readable and usable.
        .overlay(alignment: .top) {
            if calling {
                CallView(botId: botId, isSpeaking: $callSpeaking, interrupt: $interruptCall) {
                    withAnimation(Motion.reduced(Motion.layout, reduceMotion)) { calling = false }
                }
                    .padding(.top, 4)
                    .transition(.move(edge: .top).combined(with: .opacity))
            }
        }
        .animation(Motion.reduced(Motion.layout, reduceMotion), value: calling)
    }

    var conversation: some View {
        chrome(chat)
            .readingConversation(botId)
            .onAppear {
                var marks = ManualUnreadMarks(data: manualUnreadData)
                marks.set(false, account: model.storage.accountID, computer: model.computer.id, bot: botId)
                manualUnreadData = marks.data
            }
            .reviewReading(botId: botId, unobscured: following && !calling && !showTrace && botChat == nil
                           && openArtifact == nil && openCall == nil && details == nil && !editingGroup
                           && model.composerDraft(for: botId).isEmpty && model.fileDownloads.export == nil)
            .onChange(of: model.voiceCallRequest, initial: true) { _, _ in
                if model.takeVoiceCallRequest(for: botId) { startShortcutCall() }
            }
            // The details sheet's Library presents its own downloads.
            .fileExportSheet(model, botId: botId, active: details == nil)
            .codyncSheet(isPresented: $showTrace) {
                TraceView(botId: botId)
            }
            .codyncSheet(item: $botChat) { BotConversationView(botId: botId, peerId: $0.id) }
            .codyncSheet(item: $openArtifact) { ArtifactView(target: $0) }
            .codyncSheet(item: $openCall) { CallConversationView(line: $0) }
            .navigationDestination(item: $details) { request in
                BotDetailsView(botId: request.botId ?? botId, request: request) { artifact in
                    details = nil
                    openArtifact = artifact
                }
                // Navigation destinations are hosted outside ChatScreen's local environment.
                .environment(model)
            }
            .codyncSheet(isPresented: $editingGroup) {
                if let bot { GroupEditorView(group: bot) }
            }
    }

    /// Open Live Mode from Shortcuts: closes whatever covers the chat, then starts the call.
    private func startShortcutCall() {
        showTrace = false
        botChat = nil
        openArtifact = nil
        editingGroup = false
        details = nil
        if model.fileDownloads.export?.botId == botId { model.fileDownloads.dismissExport() }
        withAnimation(Motion.reduced(Motion.layout, reduceMotion)) { calling = true }
    }

    // MARK: rows

    @ViewBuilder func row(_ item: ChatItem) -> some View {
        switch item.kind {
        case .separator(let date):
            TimeSeparator(date: date)
        case .exchanges(let group):
            BotMessageRow(group: group) { botChat = BotChatTarget(id: group.peerId) }
        case .entry(let e, let groupStart):
            if e.kind == "notice", let id = e.data.routineId {
                RoutineNoticeRow(entry: e) { openRoutine(id) }
            } else {
                ChatRow(entry: e, groupStart: groupStart, chat: bot, openTrace: { showTrace = true },
                        // An update card takes the composer's place, so there's nothing to reply with.
                        reply: e.isReplyable && model.mismatch == nil ? { reply(to: e) } : nil,
                        // In a group, the bot whose agent failed.
                        addFallback: { details = DetailsRequest(botId: e.data.author ?? e.botId) },
                        openArtifact: { openArtifact = ArtifactTarget(botId: e.botId, id: $0.id, title: $0.title) },
                        openCall: { openCall = e })
                    .equatable()
            }
        }
    }

    private func reply(to entry: Entry) {
        withAnimation(Motion.reduced(Motion.layout, reduceMotion)) { replyingTo = entry }
    }

    // MARK: chrome

    private var connectionSymbol: String {
        guard model.connection == .online else { return "wifi.slash" }
        switch model.hostRoute {
        case .relay: return "cloud"
        case .direct: return "wifi"
        case nil: return "network"
        }
    }

    var title: some View {
        HStack(spacing: 7) {
            if let bot {
                let size: CGFloat = 22
                if bot.isGroup { GroupAvatar(members: model.members(of: bot), size: size) } else { CharacterAvatar(bot: bot, size: size) }
            }
            Text(bot?.name ?? "")
                .font(.system(size: 13, weight: .semibold))
                .foregroundStyle(Palette.text)
                .lineLimit(1)
        }
    }

    func openRoutine(_ id: String) {
        withAnimation(Motion.reduced(Motion.layout, reduceMotion)) {
            details = DetailsRequest(tab: .details, routineId: id)
        }
    }
}

// MARK: - Chat model

struct ChatItem: Identifiable {
    enum Kind {
        case separator(Date)
        case entry(Entry, groupStart: Bool)
        /// Main chat only: consecutive bot-to-bot exchanges with one peer.
        case exchanges(BotExchangeGroup)
    }

    let id: String
    let kind: Kind

    /// Chat-visible entries plus time separators (gaps > 1 h) and author grouping. A bot's
    /// messages arrive whole (Grok Bot's `send_message`); what it writes along the way is trace. Runs of
    /// bot exchanges with one peer fold into one item.
    static func build(_ entries: [Entry]) -> [ChatItem] {
        var out: [ChatItem] = []
        var lastDate: Date?
        var lastAuthor: String?
        for slot in BotExchangeGroup.collapse(entries) {
            let date = slot.date
            // Bot-originated messages carry an empty nonce. Their entry IDs
            // distinguish them; only real nonces identify optimistic echoes.
            let id = if case .entry(let e) = slot, e.kind == "user", let nonce = e.data.clientNonce, !nonce.isEmpty { "user-\(nonce)" } else { slot.id }
            if lastDate.map({ date.timeIntervalSince($0) > 3600 }) ?? true {
                out.append(ChatItem(id: "sep-\(id)", kind: .separator(date)))
                lastAuthor = nil
            }
            lastDate = date
            switch slot {
            case .exchanges(let group):
                out.append(ChatItem(id: id, kind: .exchanges(group)))
                lastAuthor = nil
            case .entry(let e):
                // In a group each bot is its own author.
                let author = e.kind == "user" ? "user" : e.kind == "agent" ? "agent:\(e.data.author ?? "")" : e.kind
                out.append(ChatItem(id: id, kind: .entry(e, groupStart: author != lastAuthor)))
                lastAuthor = (author == "user" || e.kind == "agent") ? author : nil
            }
        }
        return out
    }

    var isUserMessage: Bool {
        if case let .entry(entry, _) = kind { entry.kind == "user" } else { false }
    }

}

/// The start of an empty group chat: who's in it and how the room works.
struct GroupIntroCard: View {
    let group: Bot
    @Environment(BotStore.self) private var model

    var body: some View {
        VStack(spacing: 12) {
            GroupAvatar(members: model.members(of: group), size: 72)
            Text(group.name).font(.title2.weight(.semibold)).foregroundStyle(Palette.text)
            let names = model.members(of: group).map(\.name)
            if group.name != names.joined(separator: ", ") {
                Text(names.joined(separator: " · "))
                    .font(.subheadline)
                    .foregroundStyle(Palette.secondary)
                    .multilineTextAlignment(.center)
            }
            if !group.description.isEmpty {
                Text(group.description)
                    .font(.subheadline)
                    .foregroundStyle(Palette.secondary)
                    .multilineTextAlignment(.center)
            }
            Text(L10n.tr("Everyone answers in turn. @mention a bot to ask just that one."))
                .font(.subheadline)
                .foregroundStyle(Palette.secondary)
                .multilineTextAlignment(.center)
                .padding(.top, 4)
        }
        .frame(maxWidth: .infinity)
        .padding(.horizontal, 24)
    }
}

struct IntroCard: View {
    let bot: Bot
    @Environment(BotStore.self) private var model

    var body: some View {
        VStack(spacing: 12) {
            CharacterAvatar(bot: bot, size: 72)
            Text(bot.name).font(.title2.weight(.semibold)).foregroundStyle(Palette.text)
            Text(bot.managedWorkspace
                 ? "\(model.backendName(bot.backend)) · \(L10n.tr("Personal workspace"))"
                 : L10n.tr("{agent} in {path}")
                    .replacingOccurrences(of: "{agent}", with: model.backendName(bot.backend))
                    .replacingOccurrences(of: "{path}", with: bot.cwd))
                .font(.subheadline)
                .foregroundStyle(Palette.secondary)
                .multilineTextAlignment(.center)
            if !bot.description.isEmpty {
                Text(bot.description)
                    .font(.subheadline)
                    .foregroundStyle(Palette.secondary)
                    .multilineTextAlignment(.center)
            }
            Text(L10n.tr("Tell it what you need. You'll get a notification when it's done or needs you."))
                .font(.subheadline)
                .foregroundStyle(Palette.secondary)
                .multilineTextAlignment(.center)
                .padding(.top, 4)
        }
        .frame(maxWidth: .infinity)
        .padding(.horizontal, 24)
    }
}

extension ThreadView {
    public var body: some View {
        conversation
            .tracked(.screenViewed(.chat))
    }

    private var working: Bool { bot?.isWorking(in: botId) == true && !model.isOffline }

    /// iPhone's messages: all this device has, earlier ones from the computer as the reader
    /// scrolls up; the chat follows the newest message until they scroll away, and a reply is
    /// revealed steadily as it's written.
    var transcript: some View {
        // What voice calls carried shows in each call's conversation, not in the chat.
        let items = ChatItem.build(model.chat(botId).hidingCalls())
        var rows: [ConversationRow] = []
        if moreOnComputer {
            rows.append(ConversationRow("earlier") {
                Spinner(size: 14)
                    .frame(maxWidth: .infinity)
                    .padding(.vertical, 14)
                    .accessibilityLabel("Loading earlier messages")
                    // A chat shorter than the screen never scrolls, so showing the row is the trigger.
                    .onAppear { showEarlier() }
            })
        }
        if items.isEmpty, let bot {
            rows.append(ConversationRow("intro") {
                if bot.isGroup { GroupIntroCard(group: bot).padding(.top, 40) } else { IntroCard(bot: bot).padding(.top, 40) }
            })
        }
        rows += items.map { item in ConversationRow(item.id, isUserMessage: item.isUserMessage) { row(item) } }
        // Offline, "working" is only what the computer last said; don't show it as live.
        if let bot, working {
            rows.append(ConversationRow("working") {
                // Each turn starts folded.
                WorkingIndicator(bot: bot, steps: Entry.workingSteps(model.chat(botId)))
                    .id(bot.startedAt)
                    .padding(.top, 6)
            })
        }
        // Pull to refresh reconnects, like Reconnect in the computer menu, until the link is back.
        return ConversationList(rows: rows, following: $following, nearTop: { showEarlier() }, refresh: {
            model.restartStream()
            _ = try? await model.ready()
        })
    }

    private var moreOnComputer: Bool {
        model.canLoadOlder(botId)
    }

    /// The reader scrolled up to the top: fetch earlier messages from the computer.
    private func showEarlier() {
        guard moreOnComputer, !loadingEarlier else { return }
        loadingEarlier = true
        Task {
            await model.loadOlder(botId)
            loadingEarlier = false
        }
    }

    /// The system navigation bar: the title opens details; More holds the computer-screen action.
    func chrome(_ content: some View) -> some View {
        content
            .navigationBarTitleDisplayMode(.inline)
            // Our own 44pt back circle; the system one draws a 17pt chevron.
            .navigationBarBackButtonHidden(true)
            .toolbar(.visible, for: .navigationBar)
            .toolbar {
                ToolbarItem(placement: .topBarLeading) {
                    Button { dismiss() } label: { RemixImage("arrow-left-s-line", size: 24) }
                        .buttonBorderShape(.circle)
                        .accessibilityLabel("返回")
                }
                ToolbarItem(placement: .principal) {
                    header
                }
                ToolbarItem(placement: .topBarTrailing) { moreButton }
            }
            // The hidden system back button takes the edge swipe with it: put it back.
            .background(SwipeBackEnabler().frame(width: 0, height: 0))
    }

    /// Like Grok Bot: the bot at the top opens its details (a group's editor for a group).
    var header: some View {
        // .buttonStyle(.glass) adds its own padding around the label and made the capsule a few
        // points taller than the toolbar circles. Draw the glass ourselves at exactly 42pt.
        Button(action: openDetails) {
            title
                .padding(.horizontal, 14)
                .frame(height: 42)
                .glassEffect(.regular.interactive(), in: Capsule())
                .contentShape(Capsule())
        }
            .buttonStyle(.plain)
            .accessibilityLabel(L10n.tr("{name}, view details").replacingOccurrences(of: "{name}", with: bot?.name ?? ""))
    }

    private func openDetails() {
        if bot?.isGroup == true { editingGroup = true } else { details = DetailsRequest() }
    }

    /// Keep screen access in the native menu and preserve watching a bot before taking over.
    private var moreButton: some View {
        let operating = model.screen?.agentBot == botId
        return Menu {
            if model.screen != nil {
                Button { 
                    model.screenRequest = operating ? ScreenRequest(watching: botId) : ScreenRequest()
                 } label: { Label { Text(operating ? "查看正在操作的电脑屏幕" : "查看电脑屏幕") } icon: { RemixIcon("computer-line") } }
            }
            Label(L10n.tr(model.connectionLabel), systemImage: connectionSymbol)
            Text(model.hostName)
        } label: {
            RemixImage("more-line", size: 24)
        }
        .menuIndicator(.hidden)
        .buttonBorderShape(.circle)
        .accessibilityLabel("更多")
        .help("更多")
    }
}
