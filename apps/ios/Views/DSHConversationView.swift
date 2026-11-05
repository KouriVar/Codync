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
        // The input bar is an inset rather than a stacked row: the transcript runs under it and
        // comes up with the keyboard. It has no backing of its own — only the field's glass — so the
        // messages stay visible behind it, exactly as on Coe's page.
        .safeAreaInset(edge: .bottom, spacing: 0) {
            DSHComposer(gateway: gateway, draft: $draft, status: statusLine)
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
            accessory: attachmentAccessory,
            leading: AnyView(addButton),
            field: AnyView(field),
            trailing: AnyView(trailing),
            status: status,
            focused: focused
        )
        .onAppear { if gateway.supportsCommands, gateway.commandGroups.isEmpty { Task { await gateway.loadCommands() } } }
        .sheet(isPresented: $showAddSheet) {
            DSHAddSheet(
                canPhoto: gateway.capabilities.contains("images"),
                canFile: gateway.supportsFileUpload,
                groups: gateway.supportsCommands ? gateway.commandGroups : [],
                onPhotos: { pickingPhotos = true },
                onCamera: { capturePhoto { image in add(captured: image) } },
                onFiles: { pickingFiles = true },
                onCommand: runCommand
            )
            .presentationDetents([.medium, .large])
        }
        .sheet(isPresented: $showModelSheet) {
            PlaceholderSheet(title: "模型")
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

    /// What sits above the input: pending files and pictures, or the `/` command menu while typing.
    private var attachmentAccessory: AnyView? {
        let hasFiles = !gateway.fileUploads.isEmpty
        if hasFiles || !pendingImages.isEmpty {
            return AnyView(
                VStack(spacing: 4) {
                    if hasFiles { fileCards }
                    if !pendingImages.isEmpty { pendingStrip }
                }
            )
        }
        if !commandSuggestions.isEmpty { return AnyView(commandMenu) }
        return nil
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
