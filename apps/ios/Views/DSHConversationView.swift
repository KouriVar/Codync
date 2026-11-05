import CodyncKit
import CodyncUI
import DSHKit
import SwiftUI

/// A DSH conversation, on the same chat page Coe uses: messages as bubbles, and each turn's
/// stable message identities and the existing running-turn status line.
struct DSHConversationView: View {
    @ObservedObject var gateway: DSHGateway
    @State private var following = true
    @State private var confirmResend: DSHSubmission?
    @State private var draft = ""

    var body: some View {
        ChatTranscriptView(items: items, following: $following,
                           working: gateway.isRunning,
                           workingTitle: Self.workingTitle(for: gateway.currentActivity),
                           nearTop: { Task { await gateway.loadEarlier() } },
                           refresh: { await gateway.refreshConversation() },
                           hasMore: gateway.hasMore, loadingEarlier: gateway.loadingEarlier,
                           historyError: gateway.historyError,
                           accessory: gateway.submissions.isEmpty ? nil : AnyView(sendingStatus),
                           sendingRevision: gateway.submissions.hashValue &+ gateway.queueHints.hashValue &+ (gateway.queueIsKnown ? 1 : 0),
                           imageReloadKey: gateway.phase == .ready ? "ready" : "waiting",
                           loadImage: { id in await gateway.imageData(attachmentId: id) })
        .background(Palette.background)
        // The transcript runs to the screen's bottom edge; the composer (in the inset below) then sits
        // at the home bar's resting position, and the jump arrow and status line — measured from the
        // content's bottom — keep their exact gap to the input's top.
        .ignoresSafeArea(.container, edges: .bottom)
        // The input bar is an inset rather than a stacked row: the transcript runs under it and
        // comes up with the keyboard. It has no backing of its own — only the field's glass — so the
        // messages stay visible behind it, exactly as on Coe's page.
        .safeAreaInset(edge: .bottom, spacing: 0) {
            DSHComposer(gateway: gateway, draft: $draft)
        }
        .navigationTitle("")
        .navigationBarTitleDisplayMode(.inline)
        .toolbar {
            ToolbarItem(placement: .principal) { profile }
            ToolbarItem(placement: .topBarTrailing) {
                Button { gateway.newSession() } label: { Image(systemName: "square.and.pencil") }
                    .accessibilityLabel("新建会话")
            }
        }
        .alert("可能重复发送", isPresented: Binding(get: { confirmResend != nil },
                                                    set: { if !$0 { confirmResend = nil } })) {
            Button("仍要发送") {
                if let item = confirmResend { gateway.resendUnknownSubmission(item.id) }
                confirmResend = nil
            }
            Button("取消", role: .cancel) { confirmResend = nil }
        } message: {
            Text("历史中没有看到不等于服务端未接收。再次发送可能重复执行，请确认后再发。")
        }
        .onDisappear { gateway.closeConversation() }
    }

    private var title: String {
        guard let session = gateway.sessions.first(where: { $0.id == gateway.openSessionId }) else {
            return gateway.gatewayName
        }
        return gateway.displayTitle(for: session)
    }

    private var items: [TranscriptItem] {
        DSHConversationAdapter.transcript(from: gateway.messages).compactMap { row in
            guard let entry = Self.entry(for: row) else { return nil }
            return TranscriptItem(entry: entry, displayRowId: row.displayRowId, scrollToWhenAdded: false,
                                  images: Self.images(for: row))
        }
    }

    /// One DSH row's pictures as the transcript's refs. The id is what the gateway caches a picture
    /// by, so it stays stable across re-renders and the row does not jump when bytes arrive.
    private static func images(for row: DSHTranscriptItem) -> [TranscriptImageRef] {
        row.images.map { ref in
            TranscriptImageRef(id: ref.attachmentId, name: ref.name,
                               pixelWidth: ref.width, pixelHeight: ref.height)
        }
    }

    /// One DSH row as Codync's chat model: a message as its bubble, a notice as one neutral line —
    /// and a context notice never as a user bubble. `NoticeRow` draws only the text, so a context
    /// line's heading rides in the text; its controlled source name and style travel in `EntryData`
    /// so the transcript's row revision changes when they do.
    private static func entry(for row: DSHTranscriptItem) -> Entry? {
        // Pictures may come with no text at all: a photo the reader sent is still a row.
        guard !row.text.isEmpty || !row.images.isEmpty else { return nil }
        var data = EntryData(text: row.text)
        let kind: String
        switch row.kind {
        case .user:
            kind = "user"
        case .assistant:
            kind = "agent"
        case .notice:
            kind = "notice"
            if let notice = row.notice {
                // Not drawn by NoticeRow; the transcript's revision uses it.
                data.title = notice.source
                switch notice.style {
                case .error:
                    // The turn failed: NoticeRow draws this in Palette.danger.
                    data.style = "error"
                case .context:
                    // Injected context: its heading over its own text, never a user bubble. A
                    // context line with no heading still names itself.
                    let heading: String
                    if let title = notice.title, !title.isEmpty { heading = title } else { heading = "上下文" }
                    data.text = heading + "\n" + row.text
                case .info:
                    break
                }
            }
        }
        return Entry(id: row.id, seq: row.seq, botId: "dsh", rev: row.revision, kind: kind,
                     turn: Int64(row.turn), data: data,
                     createdAt: row.createdAt, updatedAt: row.createdAt)
    }

    private var sendingStatus: some View {
        VStack(alignment: .leading, spacing: 12) {
            ForEach(gateway.submissions) { item in
                VStack(alignment: .leading, spacing: 6) {
                    Text(item.detail).font(.footnote).foregroundStyle(Palette.secondary)
                    Text(item.text).font(.callout).lineLimit(3).textSelection(.enabled)
                    if item.status == .unknown && item.historyChecked {
                        Text(gateway.queueIsKnown ? "服务器队列待处理：\(gateway.queueHints.count) 条（仅供核对）"
                             : "服务器队列尚未同步，不能据此认为未接收")
                            .font(.footnote).foregroundStyle(Palette.secondary)
                        ForEach(gateway.queueHints) { hint in
                            Text(hint.text).font(.footnote).lineLimit(3)
                        }
                    }
                    HStack(spacing: 14) {
                        if item.status == .failed {
                            Button("重试") { gateway.retrySubmission(item.id) }
                        }
                        if item.status == .unknown {
                            Button("查历史") { Task { await gateway.reconcileSubmission(item.id) } }
                            if item.historyChecked {
                                Button("已看到，不重发") { gateway.dismissSubmission(item.id) }
                                Button("确认未看到，重发") { confirmResend = item }
                            }
                        }
                        if item.status == .failed || item.historyChecked {
                            Button(draft.isEmpty ? "恢复编辑" : "追加到草稿") {
                                draft = draft.isEmpty ? item.text : draft + "\n" + item.text
                            }
                            Button("移除状态") { gateway.dismissSubmission(item.id) }
                        }
                    }
                    .font(.footnote)
                }
            }
        }
        .padding(.vertical, 10)
        .frame(maxWidth: .infinity, alignment: .leading)
    }

    /// A DSH conversation has no bot of its own, so the line names the model: "DeepSeek 正在看 README.md".
    private static func workingTitle(for activity: DSHActivityDetail?) -> String {
        WorkingPhrase.line(name: "DeepSeek", phrase: phrase(for: activity))
    }

    /// The line's description, built from what the reducer already has: the thinking's first
    /// sentence, the tool and its file or command, or the fixed fallback.
    private static func phrase(for activity: DSHActivityDetail?) -> String {
        guard let activity else { return WorkingPhrase.processing }
        switch activity.kind {
        case .thinking:
            return WorkingPhrase.summary(of: activity.reasoning ?? "") ?? WorkingPhrase.thinking
        case .typing:
            return WorkingPhrase.typing
        case .reading:
            return WorkingPhrase.tool(.reading, subject: activity.toolArgument)
        case .executing:
            return WorkingPhrase.tool(.executing, subject: activity.toolArgument)
        case .editing:
            return WorkingPhrase.tool(.editing, subject: activity.toolArgument)
        case .processing:
            return WorkingPhrase.tool(.other, subject: activity.toolName)
        }
    }

    /// The page's title button, in the bar: a 24pt avatar and the conversation's name at 16pt
    /// semibold, on the same glass capsule Coe's page uses. A DSH conversation has no profile page
    /// of its own, so this one only shows.
    private var profile: some View {
        HStack(spacing: 7) {
            SourceAvatar(.dsh, size: 24)
            Text(title)
                .font(.system(size: 16, weight: .semibold))
                .foregroundStyle(Palette.text)
                .lineLimit(1)
        }
        .padding(.horizontal, 14)
        .frame(height: 44)
        .glass(in: Capsule(), interactive: false)
        .accessibilityElement(children: .combine)
    }
}

// MARK: - DSH composer

/// The DSH chat page's input bar, in the same one-glass frame Coe's page uses.
///
/// It has two states: a capsule until the field is focused (＋ on the left, send on the right), then
/// the expanded two-row box (the field on top, model and send below). Collapsing the keyboard or
/// losing focus returns it to the capsule with the draft kept. Send turns into stop while a turn runs
/// with an empty field; a disconnected gateway greys all three controls.
struct DSHComposer: View {
    @ObservedObject var gateway: DSHGateway
    @Binding var draft: String

    @FocusState private var focused: Bool
    @State private var showAddSheet = false
    @State private var showModelSheet = false

    private var trimmed: String { draft.trimmingCharacters(in: .whitespacesAndNewlines) }
    private var isEmpty: Bool { trimmed.isEmpty }

    /// `gateway.phase == .ready` means the transport is up and the input can be used at all.
    private var connected: Bool { gateway.phase == .ready }
    /// A running turn with an empty field: the send slot shows stop instead.
    private var showsStop: Bool { gateway.isRunning && isEmpty }
    /// Text may be sent when connected, a session is open, and there is something to send.
    private var canSend: Bool { connected && gateway.openSessionId != nil && !isEmpty }

    var body: some View {
        // The same bottom bar the bot page uses; the chat page only adds its own controls through the
        // frame's slots (the model button in `trailing`) and its two-state mode.
        ConversationBottomBar(
            mode: focused ? .expanded : .capsule,
            leading: AnyView(addButton),
            field: AnyView(field),
            trailing: AnyView(trailing)
        )
        .sheet(isPresented: $showAddSheet) {
            PlaceholderSheet(title: "添加")
                .presentationDetents([.medium, .large])
        }
        .sheet(isPresented: $showModelSheet) {
            PlaceholderSheet(title: "模型")
                .presentationDetents([.medium, .large])
        }
    }

    /// The bare field. No glass of its own — the frame supplies the glass.
    private var field: some View {
        TextField("给 DSH 发一条消息", text: $draft, axis: .vertical)
            .font(.body)
            .lineLimit(1...6)
            .textFieldStyle(.plain)
            .focused($focused)
    }

    /// ＋ on the left in both states.
    private var addButton: some View {
        GlassButton("添加", glyph: .remix("add-line"), size: .compact, glyphSize: 24,
                    ink: connected ? Palette.text : Palette.tertiary, style: .plain) {
            showAddSheet = true
        }
        .disabled(!connected)
    }

    /// The model control: model button + send (or stop) in the expanded box; in the capsule only send.
    @ViewBuilder private var trailing: some View {
        if focused {
            HStack(spacing: 6) {
                modelButton
                sendButton
            }
        } else {
            sendButton
        }
    }

    private var modelButton: some View {
        GlassButton("模型", glyph: .remix("robot-2-line"), size: .compact, glyphSize: 24,
                    ink: connected ? Palette.text : Palette.tertiary, style: .plain) {
            showModelSheet = true
        }
        .disabled(!connected)
    }

    private var sendButton: some View {
        Group {
            if showsStop {
                GlassButton("停止", glyph: .remix("stop-fill"), size: .compact, glyphSize: 20,
                            style: .filled(Palette.accentFill, ink: Palette.onAccent)) {
                    gateway.cancelTurn()
                }
            } else {
                let enabled = canSend
                GlassButton("发送", glyph: .remix("arrow-up-line"), size: .compact, glyphSize: 20,
                            style: .filled(enabled ? Palette.accentFill : Palette.accentDim,
                                           ink: enabled ? Palette.onAccent : Palette.tertiary)) {
                    guard enabled else { return }
                    send()
                }
                .disabled(!enabled)
            }
        }
    }

    private func send() {
        let text = draft
        if gateway.send(text: text) { draft = "" }
    }
}

/// A sheet with only a title and a one-line "coming soon" placeholder, centred.
private struct PlaceholderSheet: View {
    let title: String

    var body: some View {
        VStack(spacing: 12) {
            Text(title).font(.title3.weight(.semibold)).foregroundStyle(Palette.text)
            Text("即将上线").font(.body).foregroundStyle(Palette.secondary)
        }
        .frame(maxWidth: .infinity, maxHeight: .infinity)
        .background(Palette.background)
    }
}
