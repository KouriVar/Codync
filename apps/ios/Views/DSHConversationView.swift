import CodyncKit
import CodyncUI
import DSHKit
import PhotosUI
import SwiftUI
import UIKit

/// A DSH conversation, on the same chat page Coe uses: messages as bubbles, and each turn's
/// stable message identities and the existing running-turn status line.
struct DSHConversationView: View {
    @ObservedObject var gateway: DSHGateway
    @State private var following = true
    @State private var confirmResend: DSHSubmission?
    @State private var draft = ""
    @State private var showContextUsage = false
    @State private var showStats = false
    @State private var showingRename = false
    @State private var renameText = ""
    @State private var showingArchive = false
    @State private var moreMessage: String?
    @State private var showFiles = false
    @State private var showSchedules = false
    @State private var showTeam = false
    @State private var showTurnOutline = false
    @State private var filePreview: DSHFilePreview?

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
                           loadImage: { id in await gateway.imageData(attachmentId: id) },
                           onOpenFile: { path in
                               Task {
                                   if let data = await gateway.downloadFile(path: path) {
                                       filePreview = DSHFilePreview(name: (path as NSString).lastPathComponent,
                                                                    data: data, mediaType: nil)
                                   }
                               }
                           })
        .background(Palette.background)
        // The input bar is an inset rather than a stacked row: the transcript runs under it and
        // comes up with the keyboard. It has no backing of its own — only the field's glass — so the
        // messages stay visible behind it, exactly as on Coe's page.
        .safeAreaInset(edge: .bottom, spacing: 0) {
            if let approval = gateway.pendingApproval {
                DSHApprovalCard(gateway: gateway, request: approval)
            } else if let question = gateway.pendingQuestion {
                DSHQuestionCard(gateway: gateway, request: question)
            } else {
                DSHComposer(gateway: gateway, draft: $draft, status: statusLine)
            }
        }
        .navigationTitle("")
        .navigationBarTitleDisplayMode(.inline)
        .toolbar {
            ToolbarItem(placement: .principal) { profile }
            ToolbarItem(placement: .topBarTrailing) {
                Button { gateway.newSession() } label: { Image(systemName: "square.and.pencil") }
                    .accessibilityLabel("新建会话")
            }
            ToolbarItem(placement: .topBarTrailing) { moreMenu }
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
        .sheet(isPresented: $showContextUsage) { DSHContextUsageSheet(gateway: gateway) }
        .sheet(isPresented: $showStats) { DSHStatsSheet(gateway: gateway) }
        .sheet(isPresented: $showFiles) { DSHFilesSheet(gateway: gateway) }
        .sheet(isPresented: $showSchedules) { DSHScheduleSheet(gateway: gateway) }
        .sheet(isPresented: $showTeam) { DSHTeamSheet(gateway: gateway) }
        .sheet(isPresented: $showTurnOutline) { DSHTurnOutlineSheet(gateway: gateway) }
        .sheet(item: $filePreview) { DSHFilePreviewSheet(preview: $0) }
        .alert("重命名", isPresented: $showingRename) {
            TextField("会话名", text: $renameText)
            Button("确定") { Task { _ = await gateway.renameSession(renameText) } }
            Button("取消", role: .cancel) {}
        }
        .alert("归档这个会话？", isPresented: $showingArchive) {
            Button("归档", role: .destructive) {
                Task { if await gateway.archiveSession() { gateway.closeConversation() } }
            }
            Button("取消", role: .cancel) {}
        } message: {
            Text("归档后不会删除，只是从这里收起。")
        }
        .alert("提示", isPresented: Binding(get: { moreMessage != nil }, set: { if !$0 { moreMessage = nil } })) {
            Button("好", role: .cancel) { moreMessage = nil }
        } message: { Text(moreMessage ?? "") }
        .onDisappear { gateway.closeConversation() }
    }

    /// The chat page's "更多" menu: usage, stats, rename, fork and archive — each gated on what the
    /// gateway offers, the destructive one red and confirmed.
    private var moreMenu: some View {
        Menu {
            Button { showContextUsage = true } label: { Label("上下文用量", systemImage: "chart.bar") }
            Button { showStats = true } label: { Label("Token 统计", systemImage: "number") }
            if gateway.supportsFiles {
                Button { showFiles = true } label: { Label("工作区文件", systemImage: "folder") }
            }
            if gateway.supportsSchedule {
                Button { showSchedules = true } label: { Label("定时任务", systemImage: "clock") }
            }
            if gateway.supportsTeam {
                Button { showTeam = true } label: { Label("团队", systemImage: "person.2") }
            }
            if gateway.supportsTurnOutline {
                Button { showTurnOutline = true } label: { Label("轮次导航", systemImage: "list.number") }
            }
            if gateway.capabilities.contains("session-rename") {
                Button {
                    renameText = title
                    showingRename = true
                } label: { Label("重命名", systemImage: "pencil") }
            }
            Button {
                Task {
                    let result = await gateway.forkSession()
                    if let newId = result.sessionId { gateway.open(sessionId: newId) }
                    else { moreMessage = result.message }
                }
            } label: { Label("分叉", systemImage: "arrow.triangle.branch") }
            if gateway.capabilities.contains("session-archive") {
                Divider()
                Button(role: .destructive) { showingArchive = true } label: { Label("归档", systemImage: "archivebox") }
            }
        } label: {
            Image(systemName: "ellipsis")
        }
        .accessibilityLabel("更多")
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
                                  images: Self.images(for: row), files: Self.files(for: row))
        }
    }

    /// One DSH row's delivered files as the transcript's refs.
    private static func files(for row: DSHTranscriptItem) -> [TranscriptFileRef] {
        row.files.map { TranscriptFileRef(id: $0.path, name: $0.name) }
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

    /// The running-turn line, drawn by the shared bottom bar just above the input.
    private var statusLine: AnyView? {
        guard gateway.isRunning else { return nil }
        return AnyView(
            ConversationStatusLine(title: Self.workingTitle(for: gateway.currentActivity)) {
                SourceAvatar(.dsh, size: 24)
            }
        )
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
    /// The running-turn status line, drawn by the shared bar above the input.
    var status: AnyView?

    @FocusState private var focused: Bool
    @State private var showAddSheet = false
    @State private var showModelSheet = false

    // Pictures picked but not sent yet: shown as a thumbnail strip above the input.
    @State private var pendingImages: [DSHPreparedImage] = []
    @State private var pickingPhotos = false
    @State private var pickingFiles = false
    @State private var photoItems: [PhotosPickerItem] = []
    @State private var preparingImages = false
    @State private var attachError: String?
    @Environment(\.capturePhoto) private var capturePhoto

    // Commands: a `select` command opens a small options list.
    @State private var selectedCommand: DSHCommand?
    @State private var commandOptions: [DSHCommandOption] = []
    @State private var tasksExpanded = false
    @State private var editingGoal = false
    @State private var goalObjective = ""
    @State private var confirmClearGoal = false
    @State private var editingQueue: DSHQueueHint?
    @State private var queueEditText = ""
    @State private var confirmRemoveQueue: DSHQueueHint?

    private var trimmed: String { draft.trimmingCharacters(in: .whitespacesAndNewlines) }
    private var isEmpty: Bool { trimmed.isEmpty }

    /// `gateway.phase == .ready` means the transport is up and the input can be used at all.
    private var connected: Bool { gateway.phase == .ready }
    /// A running turn with an empty field shows stop instead of send.
    private var showsStop: Bool { gateway.isRunning && isEmpty && pendingImages.isEmpty && readyFiles.isEmpty }
    /// Files whose upload finished and can go with the next message.
    private var readyFiles: [DSHOutgoingFile] {
        gateway.fileUploads.compactMap { upload in
            guard upload.status == .ready, let receipt = upload.receiptId else { return nil }
            return DSHOutgoingFile(name: upload.name, receiptId: receipt)
        }
    }
    /// Text, a picture or a ready file may be sent when connected and a session is open.
    private var canSend: Bool {
        connected && gateway.openSessionId != nil && (!isEmpty || !pendingImages.isEmpty || !readyFiles.isEmpty)
    }

    var body: some View {
        // The same bottom bar the bot page uses; the chat page only adds its own controls through the
        // frame's slots (the model button in `trailing`) and its two-state mode.
        ConversationBottomBar(
            mode: focused ? .expanded : .capsule,
            accessory: aboveInput,
            leading: AnyView(addButton),
            field: AnyView(field),
            trailing: AnyView(trailing),
            status: status,
            focused: focused
        )
        .onAppear { loadSessionPanels() }
        .onChange(of: gateway.phase) { _, phase in
            if case .ready = phase { loadSessionPanels() }
        }
        .onChange(of: showAddSheet) { _, open in
            if open, gateway.supportsCommands, gateway.commandGroups.isEmpty {
                Task { await gateway.loadCommands() }
            }
        }
        .alert("编辑目标", isPresented: $editingGoal) {
            TextField("目标", text: $goalObjective)
            Button("保存") { Task { await gateway.editGoal(objective: goalObjective, maxGoalRounds: nil) } }
            Button("取消", role: .cancel) {}
        }
        .alert("删除目标？", isPresented: $confirmClearGoal) {
            Button("删除", role: .destructive) { Task { await gateway.clearGoal() } }
            Button("取消", role: .cancel) {}
        } message: { Text("会清空这个会话的目标。") }
        .alert("编辑排队消息", isPresented: Binding(get: { editingQueue != nil },
                                                 set: { if !$0 { editingQueue = nil } })) {
            TextField("内容", text: $queueEditText)
            Button("保存") {
                if let item = editingQueue { gateway.queueUpdate(itemId: item.id, action: "edit", text: queueEditText) }
                editingQueue = nil
            }
            Button("取消", role: .cancel) { editingQueue = nil }
        }
        .alert("删除这条排队消息？", isPresented: Binding(get: { confirmRemoveQueue != nil },
                                                      set: { if !$0 { confirmRemoveQueue = nil } })) {
            Button("删除", role: .destructive) {
                if let item = confirmRemoveQueue { gateway.queueUpdate(itemId: item.id, action: "remove") }
                confirmRemoveQueue = nil
            }
            Button("取消", role: .cancel) { confirmRemoveQueue = nil }
        }
        .sheet(isPresented: $showAddSheet) {
            DSHAddSheet(
                canPhoto: gateway.capabilities.contains("images"),
                canFile: gateway.supportsFileUpload,
                groups: gateway.supportsCommands ? gateway.commandGroups : [],
                commandPending: gateway.supportsCommands && gateway.commandGroups.isEmpty,
                onPhotos: { pickingPhotos = true },
                onCamera: { capturePhoto { image in add(captured: image) } },
                onFiles: { pickingFiles = true },
                onCommand: runCommand
            )
            .presentationDetents([.medium, .large])
        }
        .sheet(isPresented: $showModelSheet) {
            DSHModelSheet(gateway: gateway)
                .presentationDetents([.medium, .large])
        }
        .sheet(item: $selectedCommand) { command in
            DSHCommandOptionsSheet(command: command, options: commandOptions) { option in
                gateway.selectCommandOption(command: command.name, optionId: option.id)
                selectedCommand = nil
            } onCancel: { selectedCommand = nil }
            .presentationDetents([.medium, .large])
        }
        .photosPicker(isPresented: $pickingPhotos, selection: $photoItems,
                      maxSelectionCount: 20, matching: .images)
        .onChange(of: photoItems) { _, items in
            guard !items.isEmpty else { return }
            photoItems = []
            Task { await addPhotos(items) }
        }
        .fileImporter(isPresented: $pickingFiles, allowedContentTypes: [.item], allowsMultipleSelection: true) { result in
            guard case .success(let urls) = result else { return }
            for url in urls { addFile(url) }
        }
        .alert("图片没加上", isPresented: Binding(get: { attachError != nil },
                                              set: { if !$0 { attachError = nil } })) {
            Button("好", role: .cancel) { attachError = nil }
        } message: {
            Text(attachError ?? "")
        }
    }

    /// What sits above the input, from top to bottom: the goal panel, the task list, then the pending
    /// files/pictures or the `/` command menu.
    private var aboveInput: AnyView? {
        let hasFiles = !gateway.fileUploads.isEmpty
        let hasGoal = gateway.supportsGoals && gateway.goal != nil
        let hasTasks = gateway.supportsTasks && !gateway.todos.isEmpty
        let hasAttach = hasFiles || !pendingImages.isEmpty
        let hasQueue = gateway.capabilities.contains("queue-control") && !gateway.queuedMessages.isEmpty
        let hasCommandMenu = !commandSuggestions.isEmpty
        guard hasGoal || hasTasks || hasQueue || hasAttach || hasCommandMenu else { return nil }
        return AnyView(
            VStack(spacing: 6) {
                if hasGoal { goalPanel }
                if hasTasks { taskPanel }
                if hasQueue { queuePanel }
                if hasAttach {
                    VStack(spacing: 4) {
                        if hasFiles { fileCards }
                        if !pendingImages.isEmpty { pendingStrip }
                    }
                } else if hasCommandMenu {
                    commandMenu
                }
            }
        )
    }

    /// Queued messages for the running turn: edit, steer or remove each.
    @ViewBuilder private var queuePanel: some View {
        if !gateway.queuedMessages.isEmpty {
            VStack(alignment: .leading, spacing: 6) {
                Text("排队消息 · \(gateway.queuedMessages.count)")
                    .font(.caption.weight(.semibold)).foregroundStyle(Palette.secondary)
                ForEach(gateway.queuedMessages) { item in
                    HStack(spacing: 8) {
                        Text(item.text).font(.caption).foregroundStyle(Palette.text).lineLimit(2)
                        Spacer(minLength: 0)
                        Button("编辑") { queueEditText = item.text; editingQueue = item }.font(.caption)
                        Button("插话") { gateway.queueUpdate(itemId: item.id, action: "steer") }.font(.caption)
                        Button("删除") { confirmRemoveQueue = item }.font(.caption).foregroundStyle(Palette.danger)
                    }
                }
            }
            .padding(.horizontal, 12).padding(.vertical, 10)
            .frame(maxWidth: .infinity, alignment: .leading)
            .background(Palette.surface, in: RoundedRectangle(cornerRadius: 12, style: .continuous))
            .padding(.horizontal, 10).padding(.top, 8)
        }
    }

    /// The session goal: objective, phase and progress, with pause/resume, edit and delete.
    @ViewBuilder private var goalPanel: some View {
        if let goal = gateway.goal {
            VStack(alignment: .leading, spacing: 6) {
                HStack(spacing: 6) {
                    Text("目标 · " + (goal.phase.isEmpty ? "进行中" : goal.phase))
                        .font(.caption.weight(.semibold)).foregroundStyle(Palette.secondary)
                    Spacer(minLength: 0)
                    Button(goal.phase == "paused" ? "继续" : "暂停") {
                        Task {
                            if goal.phase == "paused" { await gateway.resumeGoal() }
                            else { await gateway.pauseGoal() }
                        }
                    }
                    .font(.caption)
                    Button("编辑") { goalObjective = goal.objective; editingGoal = true }.font(.caption)
                    Button("删除") { confirmClearGoal = true }.font(.caption).foregroundStyle(Palette.danger)
                }
                if !goal.objective.isEmpty {
                    Text(goal.objective).font(.footnote).foregroundStyle(Palette.text).lineLimit(3)
                }
                if let max = goal.maxGoalRounds, let started = goal.roundsStarted {
                    Text("轮次 \(started)/\(max)").font(.caption2).foregroundStyle(Palette.tertiary)
                }
            }
            .padding(.horizontal, 12).padding(.vertical, 10)
            .frame(maxWidth: .infinity, alignment: .leading)
            .background(Palette.surface, in: RoundedRectangle(cornerRadius: 12, style: .continuous))
            .padding(.horizontal, 10).padding(.top, 8)
        }
    }

    /// The session task list (read-only, collapsible).
    @ViewBuilder private var taskPanel: some View {
        if !gateway.todos.isEmpty {
            VStack(alignment: .leading, spacing: 4) {
                Button { tasksExpanded.toggle() } label: {
                    HStack(spacing: 6) {
                        Text("任务清单 · \(gateway.todos.count)").font(.caption.weight(.semibold))
                            .foregroundStyle(Palette.secondary)
                        Image(systemName: tasksExpanded ? "chevron.up" : "chevron.down")
                            .font(.caption2).foregroundStyle(Palette.tertiary)
                        Spacer(minLength: 0)
                    }
                }
                .buttonStyle(.plain)
                if tasksExpanded {
                    ForEach(gateway.todos) { todo in
                        HStack(spacing: 6) {
                            Image(systemName: Self.todoIcon(todo.status)).font(.caption2)
                                .foregroundStyle(Palette.secondary)
                            Text(todo.content).font(.caption).foregroundStyle(Palette.text).lineLimit(2)
                            Spacer(minLength: 0)
                        }
                    }
                }
            }
            .padding(.horizontal, 12).padding(.vertical, 8)
            .frame(maxWidth: .infinity, alignment: .leading)
            .background(Palette.surface, in: RoundedRectangle(cornerRadius: 12, style: .continuous))
            .padding(.horizontal, 10).padding(.top, 8)
        }
    }

    private static func todoIcon(_ status: String) -> String {
        switch status {
        case "completed", "done": return "checkmark.circle"
        case "in_progress", "active": return "circle.dotted"
        default: return "circle"
        }
    }

    /// Cards for files being uploaded or ready: name, size, progress, retry when failed, remove.
    private var fileCards: some View {
        ScrollView(.horizontal, showsIndicators: false) {
            HStack(spacing: 8) {
                ForEach(gateway.fileUploads) { upload in
                    VStack(alignment: .leading, spacing: 4) {
                        HStack(spacing: 6) {
                            Image(systemName: "doc")
                            Text(upload.name).font(.caption).lineLimit(1)
                                .truncationMode(.middle).frame(maxWidth: 120, alignment: .leading)
                            Button { gateway.removeFileUpload(upload.id) } label: {
                                Image(systemName: "xmark").font(.system(size: 10, weight: .bold))
                            }.buttonStyle(.plain)
                        }
                        if upload.status == .ready {
                            Text(ByteCountFormatter.string(fromByteCount: Int64(upload.size), countStyle: .file))
                                .font(.caption2).foregroundStyle(Palette.secondary)
                        } else if upload.status == .failed {
                            HStack(spacing: 8) {
                                Text(upload.error ?? "上传失败").font(.caption2).foregroundStyle(Palette.danger).lineLimit(1)
                                Button("重试") { gateway.retryFileUpload(upload.id) }.font(.caption2)
                            }
                        } else {
                            ProgressView(value: upload.progress).frame(width: 120)
                        }
                    }
                    .padding(.horizontal, 10).padding(.vertical, 8)
                    .background(Palette.surface, in: RoundedRectangle(cornerRadius: 12, style: .continuous))
                }
            }
            .padding(.horizontal, 10)
            .padding(.top, 8)
        }
    }

    /// A leading `/partial` in the field (no space yet), as a lowercase query.
    private var slashQuery: String? {
        guard draft.hasPrefix("/") else { return nil }
        let rest = draft.dropFirst()
        guard !rest.contains(" "), !rest.contains("\n") else { return nil }
        return String(rest).lowercased()
    }

    /// The commands/skills matching the `/` query, plan/goal/compact first.
    private var commandSuggestions: [DSHCommand] {
        guard gateway.supportsCommands, let query = slashQuery else { return [] }
        let all = orderedCommands(gateway.commandGroups.flatMap(\.commands))
        guard !query.isEmpty else { return Array(all.prefix(12)) }
        return all.filter {
            $0.name.lowercased().contains(query) || $0.description.lowercased().contains(query)
        }.prefix(12).map { $0 }
    }

    private var commandMenu: some View {
        VStack(alignment: .leading, spacing: 0) {
            ForEach(commandSuggestions) { command in
                Button { runCommand(command) } label: {
                    HStack(spacing: 8) {
                        VStack(alignment: .leading, spacing: 1) {
                            Text("/" + command.name).font(.subheadline).foregroundStyle(Palette.text)
                            if !command.description.isEmpty {
                                Text(command.description).font(.caption2).foregroundStyle(Palette.secondary).lineLimit(1)
                            }
                        }
                        Spacer(minLength: 0)
                    }
                    .padding(.horizontal, 12).padding(.vertical, 8)
                    .contentShape(Rectangle())
                }
                .buttonStyle(.plain)
            }
        }
        .background(Palette.surface, in: RoundedRectangle(cornerRadius: 16, style: .continuous))
        .padding(.horizontal, 10)
        .padding(.top, 8)
    }

    /// plan / goal / compact first, then the rest, keeping each group's order.
    private func orderedCommands(_ commands: [DSHCommand]) -> [DSHCommand] {
        let pinned = ["plan", "goal", "compact"]
        let head = pinned.compactMap { name in commands.first { $0.name == name } }
        return head + commands.filter { !pinned.contains($0.name) }
    }

    /// Runs a command the way its `ui.kind` says: immediate executes, input fills the field, select
    /// opens its options.
    private func runCommand(_ command: DSHCommand) {
        showAddSheet = false
        switch command.kind {
        case .immediate:
            gateway.executeCommand(command.submitText)
            draft = ""
        case .input:
            draft = command.insertText
        case .select:
            selectedCommand = command
            commandOptions = []
            Task { commandOptions = await gateway.commandOptions(for: command.name) }
        case .unknown:
            break
        }
    }

    /// The pictures picked but not sent yet, above the input: a thumbnail each with a remove ✕.
    private var pendingStrip: some View {
        ScrollView(.horizontal, showsIndicators: false) {
            HStack(spacing: 8) {
                ForEach(Array(pendingImages.enumerated()), id: \.offset) { index, image in
                    ZStack(alignment: .topTrailing) {
                        if let ui = UIImage(data: image.data) {
                            Image(uiImage: ui).resizable().scaledToFill()
                                .frame(width: 64, height: 64)
                                .clipShape(RoundedRectangle(cornerRadius: 12, style: .continuous))
                        } else {
                            RoundedRectangle(cornerRadius: 12, style: .continuous)
                                .fill(Palette.bubbleUser).frame(width: 64, height: 64)
                        }
                        Button { pendingImages.remove(at: index) } label: {
                            Image(systemName: "xmark")
                                .font(.system(size: 12, weight: .bold))
                                .foregroundStyle(.white)
                                .frame(width: 24, height: 24)
                                .background(.black.opacity(0.55), in: Circle())
                        }
                        .buttonStyle(.plain)
                        .padding(2)
                        .accessibilityLabel("移除图片")
                    }
                }
                if preparingImages {
                    ProgressView().frame(width: 64, height: 64)
                }
            }
            .padding(.horizontal, 10)
            .padding(.top, 8)
        }
    }

    /// Loads commands, goal and tasks once the transport is ready (requests are serialised in the
    /// gateway, so firing them together is safe; a not-yet-ready phase just returns empty and is retried).
    private func loadSessionPanels() {
        if gateway.supportsCommands { Task { await gateway.loadCommands() } }
        if gateway.supportsGoals { Task { await gateway.loadGoal() } }
        if gateway.supportsTasks { Task { await gateway.loadTasks() } }
    }

    /// Photos come in as data, are made gateway-safe by the shared processor, then join the strip.
    private func addPhotos(_ items: [PhotosPickerItem]) async {
        preparingImages = true
        defer { preparingImages = false }
        var inputs: [DSHImageInput] = []
        for item in items {
            guard let data = try? await item.loadTransferable(type: Data.self) else { continue }
            inputs.append(DSHImageInput(data: data, name: nil))
        }
        guard !inputs.isEmpty else { return }
        do {
            let prepared = try await DSHImageProcessor.prepare(inputs)
            pendingImages.append(contentsOf: prepared)
        } catch {
            attachError = error.localizedDescription
        }
    }

    /// The camera sheet's still, pushed through the same processor.
    private func add(captured image: UIImage) {
        guard let jpeg = image.jpegData(compressionQuality: 0.9) else { return }
        Task {
            do {
                let prepared = try await DSHImageProcessor.prepare([DSHImageInput(data: jpeg, name: nil)])
                pendingImages.append(contentsOf: prepared)
            } catch {
                attachError = error.localizedDescription
            }
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
        let images = pendingImages.map(DSHOutgoingImage.init)
        let files = readyFiles
        let usedFileIds = gateway.fileUploads.filter { $0.status == .ready }.map(\.id)
        if gateway.send(text: text, images: images, files: files) {
            draft = ""
            pendingImages = []
            usedFileIds.forEach(gateway.removeFileUpload)
        }
    }

    /// Reads a picked file and uploads it in chunks; the card shows progress on `gateway.fileUploads`.
    private func addFile(_ url: URL) {
        let scoped = url.startAccessingSecurityScopedResource()
        defer { if scoped { url.stopAccessingSecurityScopedResource() } }
        guard let data = try? Data(contentsOf: url, options: .mappedIfSafe) else { return }
        let name = url.lastPathComponent
        Task { await gateway.uploadFile(data: data, name: name) }
    }
}

/// The "添加" sheet: the media options the gateway accepts. Photos and camera go through
/// `message.images`; the rest arrive in later steps.
private struct DSHAddSheet: View {
    let canPhoto: Bool
    let canFile: Bool
    let groups: [DSHCommandGroup]
    let commandPending: Bool
    let onPhotos: () -> Void
    let onCamera: () -> Void
    let onFiles: () -> Void
    let onCommand: (DSHCommand) -> Void
    @Environment(\.dismissModal) private var dismiss

    var body: some View {
        NavigationStack {
            ScrollView {
                VStack(alignment: .leading, spacing: 16) {
                    HStack(spacing: 12) {
                        tile("照片", icon: "image-line", enabled: canPhoto, action: onPhotos)
                        tile("拍照", icon: "camera-line", enabled: canPhoto, action: onCamera)
                        tile("文件", icon: "attachment-line", enabled: canFile, action: onFiles)
                    }
                    if !canPhoto && !canFile {
                        Text("这个网关不支持发附件")
                            .font(.footnote).foregroundStyle(Palette.secondary)
                    }
                    if commandPending {
                        Text("命令加载中…").font(.footnote).foregroundStyle(Palette.secondary)
                    }
                    ForEach(groups) { group in
                        VStack(alignment: .leading, spacing: 6) {
                            Text(group.title == "skills" ? "技能" : "命令")
                                .font(.footnote.weight(.semibold)).foregroundStyle(Palette.secondary)
                            ForEach(group.commands) { command in
                                Button { onCommand(command); dismiss() } label: {
                                    HStack(spacing: 8) {
                                        VStack(alignment: .leading, spacing: 1) {
                                            Text("/" + command.name).font(.subheadline).foregroundStyle(Palette.text)
                                            if !command.description.isEmpty {
                                                Text(command.description).font(.caption2)
                                                    .foregroundStyle(Palette.secondary).lineLimit(1)
                                            }
                                        }
                                        Spacer(minLength: 0)
                                        if command.kind == .select {
                                            Image(systemName: "chevron.right").font(.caption2)
                                                .foregroundStyle(Palette.tertiary)
                                        }
                                    }
                                    .padding(.horizontal, 12).padding(.vertical, 8)
                                    .frame(maxWidth: .infinity, alignment: .leading)
                                    .background(Palette.surface, in: RoundedRectangle(cornerRadius: 12, style: .continuous))
                                }
                                .buttonStyle(.plain)
                            }
                        }
                    }
                }
                .padding(16)
            }
            .navigationTitle("添加")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .topBarTrailing) {
                    Button("关闭") { dismiss() }
                }
            }
        }
    }

    private func tile(_ title: String, icon: String, enabled: Bool, action: @escaping () -> Void) -> some View {
        Button(action: action) {
            VStack(spacing: 8) {
                RemixIcon(icon, size: 28).foregroundStyle(enabled ? Palette.text : Palette.tertiary)
                Text(title).font(.footnote).foregroundStyle(enabled ? Palette.text : Palette.tertiary)
            }
            .frame(maxWidth: .infinity, minHeight: 84)
            .background(Palette.surface, in: RoundedRectangle(cornerRadius: 20, style: .continuous))
        }
        .buttonStyle(.plain)
        .disabled(!enabled)
    }
}

/// The options of a `select` command (`model`, `permission`).
private struct DSHCommandOptionsSheet: View {
    let command: DSHCommand
    let options: [DSHCommandOption]
    let onPick: (DSHCommandOption) -> Void
    let onCancel: () -> Void

    var body: some View {
        NavigationStack {
            List {
                if options.isEmpty {
                    Text("选项加载中…").foregroundStyle(Palette.secondary)
                }
                ForEach(options) { option in
                    Button { onPick(option) } label: {
                        HStack {
                            VStack(alignment: .leading, spacing: 2) {
                                Text(option.label).foregroundStyle(Palette.text)
                                if let detail = option.detail, !detail.isEmpty {
                                    Text(detail).font(.caption2).foregroundStyle(Palette.secondary)
                                }
                            }
                            Spacer()
                            if option.selected {
                                Image(systemName: "checkmark").foregroundStyle(Palette.text)
                            }
                        }
                    }
                    .buttonStyle(.plain)
                }
            }
            .navigationTitle("/" + command.name)
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .topBarTrailing) { Button("取消") { onCancel() } }
            }
        }
    }
}

/// The "模型" sheet: reasoning effort, the model list by provider, the agent preset (locked once the
/// session has started) and the permission level. Every write is a gateway request; "设为默认" asks first.
private struct DSHModelSheet: View {
    @ObservedObject var gateway: DSHGateway
    @Environment(\.dismissModal) private var dismiss
    @State private var confirmDefault = false

    private var currentModelInfo: DSHModel? {
        guard let current = gateway.currentModel else { return nil }
        return gateway.modelGroups.first { $0.id == current.provider }?
            .models.first { $0.id == current.model }
    }
    private var efforts: [DSHReasoningEffort] { currentModelInfo?.reasoning ?? [] }

    var body: some View {
        NavigationStack {
            ScrollView {
                VStack(alignment: .leading, spacing: 20) {
                    if !efforts.isEmpty { effortSection }
                    modelSection
                    if gateway.supportsAgentPreset { agentSection }
                    if !gateway.permissionOptions.isEmpty { permissionSection }
                    if gateway.currentModel != nil { defaultButton }
                }
                .padding(16)
            }
            .navigationTitle("模型")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar { ToolbarItem(placement: .topBarTrailing) { Button("关闭") { dismiss() } } }
            .task {
                await gateway.loadModels()
                if gateway.supportsAgentPreset {
                    await gateway.loadAgentPresets()
                    await gateway.loadSessionAgentPreset()
                }
                await gateway.loadPermissionOptions()
            }
            .alert("设为新会话默认？", isPresented: $confirmDefault) {
                Button("设为默认") {
                    if let current = gateway.currentModel {
                        gateway.saveDefaultModel(provider: current.provider, model: current.model,
                                                 reasoningEffort: current.reasoningEffort)
                    }
                }
                Button("取消", role: .cancel) {}
            } message: {
                Text("以后新建会话会默认用这个模型和思考等级。")
            }
        }
    }

    private var effortSection: some View {
        VStack(alignment: .leading, spacing: 8) {
            sectionTitle("思考等级")
            HStack(spacing: 8) {
                ForEach(efforts) { effort in
                    let on = (gateway.currentModel?.reasoningEffort ?? efforts.first?.id) == effort.id
                    Button {
                        if let current = gateway.currentModel {
                            gateway.selectModel(provider: current.provider, model: current.model,
                                                reasoningEffort: effort.id)
                        }
                    } label: {
                        Text(effort.name).font(.subheadline)
                            .padding(.horizontal, 14).padding(.vertical, 8)
                            .background(on ? Palette.text : Palette.surface, in: Capsule())
                            .foregroundStyle(on ? Palette.background : Palette.text)
                    }
                    .buttonStyle(.plain)
                }
            }
        }
    }

    private var modelSection: some View {
        VStack(alignment: .leading, spacing: 8) {
            sectionTitle("模型")
            ForEach(gateway.modelGroups) { group in
                Text(group.name).font(.caption).foregroundStyle(Palette.secondary).padding(.top, 4)
                ForEach(group.models) { model in
                    let on = gateway.currentModel?.provider == group.id && gateway.currentModel?.model == model.id
                    Button {
                        let effort = on ? gateway.currentModel?.reasoningEffort : nil
                        gateway.selectModel(provider: group.id, model: model.id, reasoningEffort: effort)
                    } label: {
                        HStack {
                            VStack(alignment: .leading, spacing: 1) {
                                Text(model.name).font(.subheadline).foregroundStyle(Palette.text)
                                if !model.description.isEmpty {
                                    Text(model.description).font(.caption2).foregroundStyle(Palette.secondary).lineLimit(1)
                                }
                            }
                            Spacer()
                            if on { Image(systemName: "checkmark").foregroundStyle(Palette.text) }
                        }
                        .padding(.horizontal, 12).padding(.vertical, 10)
                        .frame(maxWidth: .infinity, alignment: .leading)
                        .background(Palette.surface, in: RoundedRectangle(cornerRadius: 12, style: .continuous))
                    }
                    .buttonStyle(.plain)
                }
            }
        }
    }

    private var agentSection: some View {
        VStack(alignment: .leading, spacing: 8) {
            HStack {
                sectionTitle("Agent 模式")
                if gateway.agentPresetLocked {
                    Text("已锁定").font(.caption2).foregroundStyle(Palette.secondary)
                }
            }
            ForEach(gateway.agentPresets) { preset in
                let on = gateway.agentPresetSelected == preset.id
                Button { gateway.selectAgentPreset(preset.id) } label: {
                    HStack {
                        VStack(alignment: .leading, spacing: 1) {
                            Text(preset.name).font(.subheadline)
                                .foregroundStyle(preset.broken ? Palette.tertiary : Palette.text)
                            if let detail = preset.detail, !detail.isEmpty {
                                Text(detail).font(.caption2).foregroundStyle(Palette.secondary).lineLimit(1)
                            }
                        }
                        Spacer()
                        if on { Image(systemName: "checkmark").foregroundStyle(Palette.text) }
                    }
                    .padding(.horizontal, 12).padding(.vertical, 10)
                    .frame(maxWidth: .infinity, alignment: .leading)
                    .background(Palette.surface, in: RoundedRectangle(cornerRadius: 12, style: .continuous))
                }
                .buttonStyle(.plain)
                .disabled(gateway.agentPresetLocked || preset.broken)
                .opacity(gateway.agentPresetLocked ? 0.5 : 1)
            }
        }
    }

    private var permissionSection: some View {
        VStack(alignment: .leading, spacing: 8) {
            sectionTitle("权限档位")
            ForEach(gateway.permissionOptions) { option in
                Button { gateway.setPermission(option.id) } label: {
                    VStack(alignment: .leading, spacing: 1) {
                        Text(option.name).font(.subheadline).foregroundStyle(Palette.text)
                        if let detail = option.detail, !detail.isEmpty {
                            Text(detail).font(.caption2).foregroundStyle(Palette.secondary).lineLimit(1)
                        }
                    }
                    .padding(.horizontal, 12).padding(.vertical, 10)
                    .frame(maxWidth: .infinity, alignment: .leading)
                    .background(Palette.surface, in: RoundedRectangle(cornerRadius: 12, style: .continuous))
                }
                .buttonStyle(.plain)
            }
        }
    }

    private var defaultButton: some View {
        Button { confirmDefault = true } label: {
            Text("设为新会话默认").font(.subheadline).foregroundStyle(Palette.text)
                .frame(maxWidth: .infinity, minHeight: 44)
                .background(Palette.surface, in: RoundedRectangle(cornerRadius: 12, style: .continuous))
        }
        .buttonStyle(.plain)
    }

    private func sectionTitle(_ text: String) -> some View {
        Text(text).font(.footnote.weight(.semibold)).foregroundStyle(Palette.secondary)
    }
}

/// Context usage: `context-usage` rendered in Chinese, main metrics first, plus a 立即压缩 button.
private struct DSHContextUsageSheet: View {
    @ObservedObject var gateway: DSHGateway
    @Environment(\.dismissModal) private var dismiss
    @State private var tokenRows: [(String, String)] = []
    @State private var pressureRows: [(String, String)] = []
    @State private var loaded = false

    var body: some View {
        NavigationStack {
            List {
                if !loaded {
                    Text("加载中…").foregroundStyle(Palette.secondary)
                } else if tokenRows.isEmpty && pressureRows.isEmpty {
                    Text("没有上下文用量数据").foregroundStyle(Palette.secondary)
                } else {
                    if !tokenRows.isEmpty { Section("Token 用量") { ForEach(tokenRows, id: \.0) { row in kv(row) } } }
                    if !pressureRows.isEmpty { Section("上下文压力") { ForEach(pressureRows, id: \.0) { row in kv(row) } } }
                }
                Section {
                    Button {
                        gateway.executeCommand("/compact")
                        dismiss()
                    } label: { Label("立即压缩", systemImage: "arrow.down.right.and.arrow.up.left") }
                }
            }
            .navigationTitle("上下文用量")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar { ToolbarItem(placement: .topBarTrailing) { Button("关闭") { dismiss() } } }
            .task {
                if let json = await gateway.loadContextUsage() {
                    tokenRows = DSHMetrics.rows(json["tokenUsage"])
                    pressureRows = DSHMetrics.rows(json["contextPressure"])
                }
                loaded = true
            }
        }
    }

    private func kv(_ row: (String, String)) -> some View {
        HStack { Text(row.0).foregroundStyle(Palette.secondary); Spacer()
            Text(row.1).foregroundStyle(Palette.text) }
    }
}

/// Token usage and execution stats from `session-stats`, in Chinese with main metrics first.
private struct DSHStatsSheet: View {
    @ObservedObject var gateway: DSHGateway
    @Environment(\.dismissModal) private var dismiss
    @State private var statRows: [(String, String)] = []
    @State private var tokenRows: [(String, String)] = []
    @State private var pressureRows: [(String, String)] = []
    @State private var loaded = false

    var body: some View {
        NavigationStack {
            List {
                if !loaded { Text("加载中…").foregroundStyle(Palette.secondary) }
                else if statRows.isEmpty && tokenRows.isEmpty && pressureRows.isEmpty {
                    Text("没有统计数据").foregroundStyle(Palette.secondary)
                } else {
                    if !statRows.isEmpty { Section("执行统计") { ForEach(statRows, id: \.0) { row in kv(row) } } }
                    if !tokenRows.isEmpty { Section("Token 用量") { ForEach(tokenRows, id: \.0) { row in kv(row) } } }
                    if !pressureRows.isEmpty { Section("上下文") { ForEach(pressureRows, id: \.0) { row in kv(row) } } }
                }
            }
            .navigationTitle("Token 统计")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar { ToolbarItem(placement: .topBarTrailing) { Button("关闭") { dismiss() } } }
            .task {
                if let json = await gateway.loadSessionStats() {
                    statRows = DSHMetrics.rows(json["sessionStats"])
                    tokenRows = DSHMetrics.rows(json["tokenUsage"])
                    pressureRows = DSHMetrics.rows(json["contextPressure"])
                }
                loaded = true
            }
        }
    }

    private func kv(_ row: (String, String)) -> some View {
        HStack { Text(row.0).foregroundStyle(Palette.secondary); Spacer()
            Text(row.1).foregroundStyle(Palette.text) }
    }
}

/// Turns a gateway usage/stats dict into ordered, Chinese-labelled, formatted rows. The exact wire keys
/// are undocumented, so unknown keys fall back to the raw name; known keys get a Chinese label and the
/// main metrics (已用占比/总量/输入/输出/缓存/推理) sort first.
private enum DSHMetrics {
    static let labels: [String: String] = [
        "usedpercent": "已用占比", "percent": "已用占比", "utilization": "已用占比", "usage": "已用占比",
        "total": "总量", "totaltokens": "总量", "tokenusage": "总量", "totalusage": "总量", "totaltokenusage": "总量",
        "input": "输入", "inputtokens": "输入", "prompttokens": "输入",
        "uncachedinput": "未缓存输入", "uncachedinputtokens": "未缓存输入",
        "output": "输出", "outputtokens": "输出", "completiontokens": "输出",
        "cacheread": "缓存读取", "cachereadtokens": "缓存读取", "cachedread": "缓存读取",
        "cachewrite": "缓存写入", "cachewritetokens": "缓存写入", "cachedwrite": "缓存写入",
        "reasoning": "推理", "reasoningtokens": "推理",
        "cachehitrate": "缓存命中", "cachehit": "缓存命中", "hitrate": "缓存命中", "cachedpercent": "缓存命中",
        "systemprompt": "系统提示词", "systemprompttokens": "系统提示词",
        "tool": "工具", "tooltokens": "工具", "tools": "工具",
        "conversation": "对话消息", "conversationtokens": "对话消息", "message": "对话消息", "messagetokens": "对话消息",
        "used": "已用", "usedtokens": "已用",
        "limit": "窗口上限", "limittokens": "窗口上限", "window": "窗口上限", "contextwindow": "窗口上限",
        "remaining": "剩余", "remainingtokens": "剩余",
        "estimated": "预计", "estimate": "预计", "estimatedtokens": "预计",
        "turns": "轮次", "steps": "步骤", "llmms": "LLM 耗时(ms)", "toolms": "工具耗时(ms)",
        "ttftms": "首字耗时(ms)", "ttftsteps": "首字步数", "decodems": "解码耗时(ms)",
        "decodetokens": "解码 tokens", "lastturn": "最近轮次", "openstep": "进行中步骤", "pendingcalls": "待处理调用",
    ]
    static let order: [String] = [
        "usedpercent", "percent", "utilization", "usage", "total", "totaltokens", "tokenusage",
        "input", "inputtokens", "prompttokens", "uncachedinput", "uncachedinputtokens",
        "output", "outputtokens", "completiontokens",
        "cacheread", "cachereadtokens", "cachewrite", "cachewritetokens", "cachehitrate", "cachehit", "hitrate",
        "reasoning", "reasoningtokens", "systemprompt", "tool", "conversation", "message",
        "limit", "window", "remaining", "estimated",
        "turns", "steps", "llmms", "toolms", "ttftms", "ttftsteps", "decodems", "decodetokens",
    ]

    static func normalize(_ key: String) -> String { key.lowercased().filter { $0.isLetter || $0.isNumber } }

    static func rows(_ value: Any?) -> [(String, String)] {
        guard let dict = value as? [String: Any] else { return [] }
        var items: [(order: Int, label: String, value: String)] = []
        for (key, raw) in dict {
            if let n = raw as? NSNumber {
                items.append((orderIndex(key), label(key), format(key, n)))
            } else if let str = raw as? String {
                items.append((orderIndex(key), label(key), str))
            } else if let nested = raw as? [String: Any] {
                for (inner, v) in nested {
                    let composite = key + "." + inner
                    if let n = v as? NSNumber { items.append((orderIndex(composite), label(composite), format(composite, n))) }
                    else if let str = v as? String { items.append((orderIndex(composite), label(composite), str)) }
                }
            }
        }
        return items.sorted { $0.order == $1.order ? $0.label < $1.label : $0.order < $1.order }
            .map { ($0.label, $0.value) }
    }

    private static func orderIndex(_ key: String) -> Int {
        let nk = normalize(key).split(separator: ".").last.map(String.init) ?? normalize(key)
        if let index = order.firstIndex(of: nk) { return index }
        return order.count + 1
    }
    private static func label(_ key: String) -> String {
        let nk = normalize(key).split(separator: ".").last.map(String.init) ?? normalize(key)
        return labels[nk] ?? key
    }
    private static func format(_ key: String, _ n: NSNumber) -> String {
        let nk = normalize(key)
        let d = n.doubleValue
        if nk.contains("percent") || nk.contains("rate") || nk.contains("utilization") || nk.contains("ratio") {
            let pct = d <= 1.0 ? d * 100 : d
            return trimmed(pct) + "%"
        }
        if nk.contains("token") || nk.contains("input") || nk.contains("output") || nk.contains("cache")
            || nk.contains("reasoning") || nk.contains("total") || abs(d) >= 1000 {
            return grouped(Int64(d.rounded())) + " tok"
        }
        return trimmed(d)
    }
    private static func trimmed(_ d: Double) -> String {
        d == d.rounded() ? String(Int64(d)) : String(format: "%.1f", d)
    }
    private static func grouped(_ v: Int64) -> String {
        let f = NumberFormatter(); f.numberStyle = .decimal; f.groupingSeparator = ","
        return f.string(from: NSNumber(value: v)) ?? "\(v)"
    }
}

/// Browse the session's workspace (`file-list`) and preview a file (`file-download-open/read`).
private struct DSHFilesSheet: View {
    @ObservedObject var gateway: DSHGateway
    @Environment(\.dismissModal) private var dismiss
    @State private var stack: [String] = ["."]
    @State private var entries: [DSHFileEntry] = []
    @State private var loading = false
    @State private var preview: DSHFilePreview?
    private var path: String { stack.last ?? "." }

    var body: some View {
        NavigationStack {
            List {
                if stack.count > 1 {
                    Button { stack.removeLast() } label: { Label("上一级", systemImage: "chevron.up") }
                }
                ForEach(entries) { entry in
                    Button {
                        if entry.isDirectory {
                            stack.append(entry.path)
                        } else {
                            Task {
                                if let data = await gateway.downloadFile(path: entry.path) {
                                    preview = DSHFilePreview(name: entry.name, data: data, mediaType: entry.mediaType)
                                }
                            }
                        }
                    } label: {
                        HStack {
                            Image(systemName: entry.isDirectory ? "folder" : "doc")
                            Text(entry.name).lineLimit(1)
                            Spacer()
                            if let bytes = entry.bytes {
                                Text(ByteCountFormatter.string(fromByteCount: Int64(bytes), countStyle: .file))
                                    .font(.caption2).foregroundStyle(Palette.secondary)
                            }
                        }
                    }
                    .buttonStyle(.plain)
                }
                if loading { HStack { Spacer(); ProgressView(); Spacer() } }
                if !loading && entries.isEmpty { Text("空目录").foregroundStyle(Palette.secondary) }
            }
            .navigationTitle(path == "." ? "工作区文件" : path)
            .navigationBarTitleDisplayMode(.inline)
            .toolbar { ToolbarItem(placement: .topBarTrailing) { Button("关闭") { dismiss() } } }
            .task(id: path) {
                loading = true
                entries = await gateway.listFiles(path: path)
                loading = false
            }
            .sheet(item: $preview) { DSHFilePreviewSheet(preview: $0) }
        }
    }
}

private struct DSHFilePreview: Identifiable {
    let id = UUID()
    let name: String
    let data: Data
    let mediaType: String?
}

private struct DSHFilePreviewSheet: View {
    let preview: DSHFilePreview
    @Environment(\.dismissModal) private var dismiss

    var body: some View {
        NavigationStack {
            ScrollView {
                if let image = UIImage(data: preview.data) {
                    Image(uiImage: image).resizable().scaledToFit().padding()
                } else if let text = String(data: preview.data, encoding: .utf8) {
                    Text(text).font(.system(.footnote, design: .monospaced))
                        .frame(maxWidth: .infinity, alignment: .leading)
                        .padding().textSelection(.enabled)
                } else {
                    Text("无法预览（\(preview.data.count) 字节）").foregroundStyle(Palette.secondary).padding()
                }
            }
            .navigationTitle(preview.name)
            .navigationBarTitleDisplayMode(.inline)
            .toolbar { ToolbarItem(placement: .topBarTrailing) { Button("关闭") { dismiss() } } }
        }
    }
}

/// This session's scheduled tasks (`schedule-list`), with delete + confirm.
private struct DSHScheduleSheet: View {
    @ObservedObject var gateway: DSHGateway
    @Environment(\.dismissModal) private var dismiss
    @State private var items: [DSHSchedule] = []
    @State private var deleteTarget: DSHSchedule?
    @State private var editTarget: DSHSchedule?
    @State private var editTitle = ""
    @State private var editPrompt = ""

    var body: some View {
        NavigationStack {
            List {
                if items.isEmpty { Text("没有定时任务").foregroundStyle(Palette.secondary) }
                ForEach(items) { item in
                    HStack {
                        VStack(alignment: .leading, spacing: 1) {
                            Text(item.title)
                            if !item.detail.isEmpty {
                                Text(item.detail).font(.caption2).foregroundStyle(Palette.secondary)
                            }
                        }
                        Spacer()
                        Button { editTarget = item; editTitle = item.title; editPrompt = "" } label: {
                            Image(systemName: "pencil")
                        }
                        .buttonStyle(.plain)
                        Button(role: .destructive) { deleteTarget = item } label: {
                            Image(systemName: "trash")
                        }
                        .buttonStyle(.plain)
                    }
                }
            }
            .navigationTitle("定时任务")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar { ToolbarItem(placement: .topBarTrailing) { Button("关闭") { dismiss() } } }
            .task { items = await gateway.listSchedules() }
            .alert("删除这个定时任务？", isPresented: Binding(get: { deleteTarget != nil },
                                                           set: { if !$0 { deleteTarget = nil } })) {
                Button("删除", role: .destructive) {
                    if let target = deleteTarget {
                        Task {
                            if await gateway.deleteSchedule(target.id) {
                                items = await gateway.listSchedules()
                            }
                        }
                    }
                    deleteTarget = nil
                }
                Button("取消", role: .cancel) { deleteTarget = nil }
            }
            .alert("编辑定时任务", isPresented: Binding(get: { editTarget != nil },
                                                   set: { if !$0 { editTarget = nil } })) {
                TextField("标题", text: $editTitle)
                TextField("提示词（可选）", text: $editPrompt)
                Button("保存") {
                    if let target = editTarget {
                        Task {
                            if await gateway.updateSchedule(target.id, title: editTitle,
                                                            prompt: editPrompt.isEmpty ? nil : editPrompt) {
                                items = await gateway.listSchedules()
                            }
                        }
                    }
                    editTarget = nil
                }
                Button("取消", role: .cancel) { editTarget = nil }
            }
        }
    }
}

/// The team's members (`agent-team`), read-only.
private struct DSHTeamSheet: View {
    @ObservedObject var gateway: DSHGateway
    @Environment(\.dismissModal) private var dismiss
    @State private var members: [DSHTeamMember] = []

    var body: some View {
        NavigationStack {
            List {
                if members.isEmpty { Text("没有团队成员").foregroundStyle(Palette.secondary) }
                ForEach(members) { member in
                    HStack {
                        Text(member.name)
                        Spacer()
                        Text(member.role + (member.phase.isEmpty ? "" : " · " + member.phase))
                            .font(.caption).foregroundStyle(Palette.secondary)
                    }
                }
            }
            .navigationTitle("团队")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar { ToolbarItem(placement: .topBarTrailing) { Button("关闭") { dismiss() } } }
            .task { members = await gateway.loadAgentTeam() }
        }
    }
}

/// A tool-approval card that stands in for the input while the gateway waits for a decision.
private struct DSHApprovalCard: View {
    @ObservedObject var gateway: DSHGateway
    let request: DSHApprovalRequest

    var body: some View {
        VStack(alignment: .leading, spacing: 10) {
            HStack(spacing: 6) {
                Image(systemName: "lock.shield").foregroundStyle(Palette.danger)
                Text("需要授权").font(.subheadline.weight(.semibold)).foregroundStyle(Palette.text)
                Spacer(minLength: 0)
                if !request.toolName.isEmpty {
                    Text(request.toolName).font(.caption).foregroundStyle(Palette.secondary)
                }
            }
            if let reason = request.reason, !reason.isEmpty {
                Text(reason).font(.footnote).foregroundStyle(Palette.text).textSelection(.enabled)
            }
            HStack(spacing: 10) {
                Button { gateway.respondApproval(request, outcome: "allowed-once") } label: {
                    Text("允许一次").font(.subheadline).foregroundStyle(Palette.background)
                        .frame(maxWidth: .infinity, minHeight: 40)
                        .background(Palette.text, in: RoundedRectangle(cornerRadius: 10, style: .continuous))
                }.buttonStyle(.plain)
                Button { gateway.respondApproval(request, outcome: "rejected") } label: {
                    Text("拒绝").font(.subheadline).foregroundStyle(Palette.danger)
                        .frame(maxWidth: .infinity, minHeight: 40)
                        .background(Palette.background, in: RoundedRectangle(cornerRadius: 10, style: .continuous))
                }.buttonStyle(.plain)
            }
        }
        .padding(16)
        .background(Palette.surface, in: RoundedRectangle(cornerRadius: 20, style: .continuous))
        .padding(.horizontal, 16).padding(.top, 6).padding(.bottom, 12)
    }
}

/// A user-question card that stands in for the input while the agent asks. Single/multi select plus a
/// free-text answer; submitting sends `question-answer`, skipping sends `question-cancel`.
private struct DSHQuestionCard: View {
    @ObservedObject var gateway: DSHGateway
    let request: DSHQuestionRequest
    @State private var selections: [String: Set<String>] = [:]
    @State private var customs: [String: String] = [:]

    var body: some View {
        VStack(alignment: .leading, spacing: 12) {
            ScrollView {
                VStack(alignment: .leading, spacing: 14) {
                    ForEach(request.questions) { question in
                        VStack(alignment: .leading, spacing: 8) {
                            if let header = question.header, !header.isEmpty {
                                Text(header).font(.caption).foregroundStyle(Palette.secondary)
                            }
                            Text(question.question).font(.subheadline.weight(.semibold)).foregroundStyle(Palette.text)
                            if let detail = question.detail, !detail.isEmpty {
                                Text(detail).font(.caption2).foregroundStyle(Palette.secondary)
                            }
                            ForEach(question.options, id: \.label) { option in
                                let on = selections[question.id]?.contains(option.label) ?? false
                                Button { toggle(question, option.label) } label: {
                                    HStack(alignment: .top, spacing: 8) {
                                        Image(systemName: icon(on: on, multi: question.multiSelect))
                                            .foregroundStyle(on ? Palette.text : Palette.secondary)
                                        VStack(alignment: .leading, spacing: 1) {
                                            Text(option.label).font(.footnote).foregroundStyle(Palette.text)
                                            if let d = option.description, !d.isEmpty {
                                                Text(d).font(.caption2).foregroundStyle(Palette.secondary)
                                            }
                                        }
                                        Spacer(minLength: 0)
                                    }
                                    .frame(maxWidth: .infinity, alignment: .leading)
                                }.buttonStyle(.plain)
                            }
                            TextField("自定义回答", text: Binding(get: { customs[question.id] ?? "" },
                                                              set: { customs[question.id] = $0 }))
                                .textFieldStyle(.roundedBorder).font(.footnote)
                        }
                        .padding(10).frame(maxWidth: .infinity, alignment: .leading)
                        .background(Palette.background.opacity(0.5), in: RoundedRectangle(cornerRadius: 12, style: .continuous))
                    }
                }
            }
            .frame(maxHeight: 320)
            HStack(spacing: 10) {
                Button { submit() } label: {
                    Text("提交").font(.subheadline).foregroundStyle(Palette.background)
                        .frame(maxWidth: .infinity, minHeight: 40)
                        .background(Palette.text, in: RoundedRectangle(cornerRadius: 10, style: .continuous))
                }.buttonStyle(.plain)
                Button { gateway.cancelQuestion(request) } label: {
                    Text("跳过").font(.subheadline).foregroundStyle(Palette.text)
                        .frame(maxWidth: .infinity, minHeight: 40)
                        .background(Palette.background, in: RoundedRectangle(cornerRadius: 10, style: .continuous))
                }.buttonStyle(.plain)
            }
        }
        .padding(16)
        .background(Palette.surface, in: RoundedRectangle(cornerRadius: 20, style: .continuous))
        .padding(.horizontal, 16).padding(.top, 6).padding(.bottom, 12)
    }

    private func icon(on: Bool, multi: Bool) -> String {
        multi ? (on ? "checkmark.square.fill" : "square") : (on ? "largecircle.fill.circle" : "circle")
    }

    private func toggle(_ question: DSHQuestion, _ label: String) {
        var set = selections[question.id] ?? []
        if question.multiSelect {
            if set.contains(label) { set.remove(label) } else { set.insert(label) }
        } else {
            set = [label]
            customs[question.id] = ""
        }
        selections[question.id] = set
    }

    private func submit() {
        var answers: [[String: Any]] = []
        for question in request.questions {
            let selected = question.options.map(\.label).filter { selections[question.id]?.contains($0) ?? false }
            var answer: [String: Any] = ["id": question.id, "selected": selected]
            if let custom = customs[question.id], !custom.isEmpty {
                if question.multiSelect || selected.isEmpty { answer["custom"] = custom }
            }
            answers.append(answer)
        }
        gateway.answerQuestion(request, answers: answers)
    }
}

/// A read-only list of the session's turns from the turn outline (turn-outline-v1). Precise
/// scroll-to-position is not wired (the shared transcript has no scroll-to-seq API), so this lists
/// each turn's prompt/response excerpt for scanning.
private struct DSHTurnOutlineSheet: View {
    @ObservedObject var gateway: DSHGateway
    @Environment(\.dismissModal) private var dismiss

    var body: some View {
        NavigationStack {
            List {
                if gateway.turnOutline.isEmpty {
                    Text("没有轮次数据").foregroundStyle(Palette.secondary)
                }
                ForEach(gateway.turnOutline) { turn in
                    VStack(alignment: .leading, spacing: 2) {
                        Text("第 \(turn.turn) 轮").font(.caption.weight(.semibold)).foregroundStyle(Palette.secondary)
                        let preview = (turn.response.isEmpty ? turn.prompt : turn.response)
                            .trimmingCharacters(in: .whitespacesAndNewlines)
                        if !preview.isEmpty {
                            Text(preview).font(.footnote).foregroundStyle(Palette.text).lineLimit(2)
                        }
                    }
                }
            }
            .navigationTitle("轮次导航")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar { ToolbarItem(placement: .topBarTrailing) { Button("关闭") { dismiss() } } }
        }
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
