import CodyncKit
import PhotosUI
import SwiftUI
import UniformTypeIdentifiers

/// The message box under a chat: send, or stop while the bot (or the group) is working
/// there. A leading `/` lists commands (a group's act on its bots); in a group, typing `@`
/// suggests its bots.
struct Composer: View {
    let botId: String
    /// The message the next send quotes, shown above the field until sent or cancelled.
    @Binding var replyingTo: Entry?
    /// Interrupts the bot while it is speaking in a voice call.
    var onInterrupt: (() -> Void)?
    /// An artifact's viewer: every message is about the artifact (a reply to its card), from a draft of its own.
    var artifact: Artifact?
    @Environment(BotStore.self) private var model
    @Environment(\.accessibilityReduceMotion) private var reduceMotion
    /// The field owns its text; the store only keeps a copy. A field bound straight to the
    /// store loses a hardware keyboard's IME composition (Zhuyin, Pinyin, Kana) on iPad.
    @State private var input = ComposerText()
    /// Programmatic edits must discard indices into the previous string. Keyboard edits
    /// bind directly to `input.text` so SwiftUI can maintain selection and IME composition.
    private var draft: String {
        get { input.text }
        nonmutating set { input.replace(with: newValue) }
    }
    /// Files going out with the next message.
    @State private var files: [OutgoingFile] = []
    @State private var pickingFiles = false
    @State private var pickingPhotos = false
    @State private var photoItems: [PhotosPickerItem] = []
    @Environment(\.capturePhoto) private var capturePhoto
    @FocusState private var focused: Bool

    private var bot: Bot? { model.bots[botId] }
    private var draftKey: String { artifact.map(BotStore.artifactDraftKey) ?? botId }
    private var working: Bool { bot?.isWorking(in: botId) == true }

    private var isEmpty: Bool { draft.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty && files.isEmpty }

    private var canSend: Bool {
        // Offline computers still take messages when the relay can hold them for it (text only).
        !isEmpty && (model.connection == .online || (model.canQueue && files.isEmpty))
    }

    private var canAttach: Bool { bot != nil }

    private var placeholder: String {
        let name = bot?.name ?? ""
        if let artifact { return L10n.tr("Message about “{title}”").replacingOccurrences(of: "{title}", with: artifact.title) }
        if replyingTo != nil { return L10n.tr("Reply…") }
        if bot?.isGroup == true { return L10n.tr("Ask everyone · @ to ask one bot") }
        let key = working ? "Queue a message for {name}" : "Ask {name}"
        return L10n.tr(key).replacingOccurrences(of: "{name}", with: name)
    }

    /// The `@partial` being typed at the end, if any.
    private var mentionQuery: String? {
        guard bot?.isGroup == true, let at = draft.lastIndex(of: "@") else { return nil }
        let query = draft[draft.index(after: at)...]
        if at > draft.startIndex, !draft[draft.index(before: at)].isWhitespace { return nil }
        return query.contains(where: \.isNewline) || query.count > 24 ? nil : String(query)
    }

    private var suggestions: [Bot] {
        guard let query = mentionQuery else { return [] }
        return members.filter {
            query.isEmpty || $0.name.localizedCaseInsensitiveContains(query)
        }
    }

    /// A group's bots, which its commands act on.
    private var members: [Bot] { bot.map(model.members(of:)) ?? [] }

    /// The bot's `/` commands while the draft is `/partial`.
    private var commands: [SlashCommand] {
        guard let query = SlashCommands.query(draft) else { return [] }
        return SlashCommands.list(for: bot, members: members, query: query, skills: model.installedSkills)
    }

    var body: some View {
        VStack(alignment: .leading, spacing: 6) {
            if !commands.isEmpty {
                CommandList(commands: commands, pick: run)
                    .padding(.horizontal, 16)
                    .transition(.move(edge: .bottom).combined(with: .opacity))
            }
            if !suggestions.isEmpty {
                ScrollView(.horizontal, showsIndicators: false) {
                    HStack(spacing: 6) {
                        ForEach(suggestions) { member in
                            SuggestionChip(title: member.name) {
                                CharacterAvatar(bot: member, size: 18, animated: false)
                            } action: {
                                mention(member)
                            }
                        }
                    }
                    .padding(.horizontal, 16)
                }
                .transition(.move(edge: .bottom).combined(with: .opacity))
            }
            field
        }
        .animation(Motion.layout, value: suggestions.map(\.id))
        .animation(Motion.layout, value: commands.map(\.id))
    }

    /// Send/stop circle inside the conversation frame: the compact size.
    private var buttonSize: CGFloat { ControlMetrics.Size.compact.side }
    /// The row height, and the tap target of the buttons on both sides of the field.
    private var buttonHitSize: CGFloat { ControlMetrics.Size.compact.hitTarget }
    /// The send/stop arrow: 20pt, a touch smaller than the 24pt glyph of the + beside it.
    private var sendGlyph: CGFloat { 20 }

    /// The bar, in the page's one composer shape: the quote and the attachments sit above the row,
    /// the "+" opens the attachments menu on the left, send/stop/interrupt on the right. The frame's
    /// spacing and keyboard policy come from the shared `ConversationBottomBar`, the same one the
    /// chat page uses.
    private var field: some View {
        ConversationBottomBar(
            mode: .capsule,
            accessory: accessoryBar,
            leading: canAttach ? AnyView(addButton) : AnyView(EmptyView()),
            field: AnyView(box),
            trailing: AnyView(trailingButton)
        )
        // Lines, not the text: an animated transaction on every keystroke breaks IME composition.
        .animation(Motion.layout, value: draft.count(where: \.isNewline))
        .animation(Motion.layout, value: files.map(\.id))
        .animation(Motion.reduced(Motion.layout, reduceMotion), value: replyingTo?.id)
        .dropDestination(for: PickedFile.self) { picked, _ in
            guard canAttach else { return false }
            append(picked.map(\.file))
            return true
        }
        .reviewInterruption(active: focused || pickingFiles || pickingPhotos || !files.isEmpty)
        .fileImporter(isPresented: $pickingFiles, allowedContentTypes: [.item], allowsMultipleSelection: true) { result in
            if case .success(let urls) = result { add(urls) }
        }
            .photosPicker(isPresented: $pickingPhotos, selection: $photoItems, maxSelectionCount: 10, matching: .any(of: [.images, .videos]))
            .onChange(of: photoItems) { _, items in
                guard !items.isEmpty else { return }
                photoItems = []
                Task { await addPhotos(items) }
            }
    }

    /// What sits above the bar: the quoted message and the attachments going out with it.
    private var accessoryBar: AnyView? {
        guard replyingTo != nil || !files.isEmpty else { return nil }
        return AnyView(
            VStack(alignment: .leading, spacing: 6) {
                if let replyingTo { quoteBar(replyingTo) }
                if !files.isEmpty { fileChips }
            }
            .padding(.horizontal, 16)
            .animation(Motion.reduced(Motion.layout, reduceMotion), value: replyingTo?.id)
        )
    }

    private enum Trailing: Equatable {
        case interrupt, stop, send
    }

    private var trailing: Trailing {
        if onInterrupt != nil, draft.isEmpty, files.isEmpty { return .interrupt }
        if working, draft.isEmpty, files.isEmpty { return .stop }
        return .send
    }

    /// Send, stop or interrupt, with a compact visible circle inside a full-size tap target.
    private var trailingButton: some View {
        let state = trailing
        let enabled = state != .send || canSend
        let (symbol, label): (String, String) = switch state {
        case .interrupt: ("stop-fill", "Interrupt")
        case .stop: ("stop-fill", "Stop")
        case .send: ("arrow-up-line", "Send")
        }
        let fill: Color = switch state {
        case .interrupt: Palette.danger
        case .send: canSend ? ChatAccent(bot?.avatarColor).fill : ChatAccent(bot?.avatarColor).fill.opacity(0.25)
        case .stop: ChatAccent(bot?.avatarColor).fill
        }
        let ink: Color = switch state {
        case .interrupt: .white
        case .send: canSend ? ChatAccent(bot?.avatarColor).ink : Palette.tertiary
        case .stop: ChatAccent(bot?.avatarColor).ink
        }
        return Button {
            switch state {
            case .interrupt: onInterrupt?()
            case .stop: model.stop(botId)
            case .send: submit()
            }
        } label: {
            RemixIcon(symbol, size: sendGlyph)
                .contentTransition(.opacity)
                .foregroundStyle(ink)
                .frame(width: buttonSize, height: buttonSize)
                .background(fill, in: Circle())
                // Wider than the circle for a comfortable tap, but no taller: the frame is the 48pt bar.
                .frame(width: buttonHitSize, height: buttonSize)
                .contentShape(Circle())
        }
        .buttonStyle(PressScale())
        .disabled(!enabled)
        .keyboardShortcut(state == .send ? KeyboardShortcut(.return, modifiers: .command) : nil)
        .accessibilityLabel(label)
        .help(label)
        .animation(Motion.reduced(Motion.morph, reduceMotion), value: state)
        .animation(Motion.reduced(Motion.morph, reduceMotion), value: canSend)
    }

    private var box: some View {
        TextField(placeholder, text: $input.text, selection: $input.selection, axis: .vertical)
            .lineLimit(1...6)
            .font(.body)
            .textFieldStyle(.plain)
            .focused($focused)
            // A hardware keyboard's Return (⌘↩ too) submits the field and ends editing.
            .onSubmit(newline)
        .onChange(of: draftKey, initial: true) {
            draft = model.composerDraft(for: draftKey)
        }
        .onAppear {
            let pending = model.takePendingFiles(for: botId)
            if !pending.isEmpty { append(pending) }
        }
        // Another chat in the same view never inherits the reply.
        .onChange(of: botId) { replyingTo = nil }
        .onChange(of: replyingTo?.id) { if replyingTo != nil { focused = true } }
        .onChange(of: draft) { _, value in
            model.setComposerDraft(value, for: draftKey)
            // Starting a command: list the computer's skills again.
            if value == "/" { Task { await model.refreshPlugins() } }
        }
    }

    /// The quoted message, one line, with a way to drop the reply.
    private func quoteBar(_ target: Entry) -> some View {
        HStack(spacing: 4) {
            QuoteLine(text: target.replyQuote.text)
            Spacer(minLength: 0)
            IconButton("Cancel reply", systemImage: "xmark") { replyingTo = nil }
        }
        .padding(.leading, 18)
        .padding(.trailing, 6)
        .padding(.top, 6)
    }

    /// Photos, files or the clipboard, from a system menu; dropping files on the box works too.
    @ViewBuilder private var addButton: some View {
            DropdownMenu {
                [MenuItem("照片或视频", icon: "image-line") { pickingPhotos = true },
                 MenuItem("拍照", icon: "camera-line") { capturePhoto { image in add(captured: image) } },
                 MenuItem("选择文件", icon: "folder-line") { pickingFiles = true }]
            } label: { addLabel }
                .accessibilityLabel("Add files")
    }

    private var addLabel: some View {
        GlassGlyph(glyph: .remix("add-line"), size: .compact, glyphSize: 24, ink: Palette.text, style: .plain)
            // Wider for a comfortable tap, but no taller than the compact circle: the frame is 48pt.
            .frame(width: ControlMetrics.Size.compact.hitTarget, height: ControlMetrics.Size.compact.side)
            .contentShape(Rectangle())
    }

    private var fileChips: some View {
        ScrollView(.horizontal, showsIndicators: false) {
            HStack(spacing: 6) {
                ForEach(files) { file in
                    ComposerAttachment(file: file) {
                        withAnimation(Motion.reduced(Motion.layout, reduceMotion)) {
                            files.removeAll { $0.id == file.id }
                        }
                    }
                }
            }
            .padding(.horizontal, 10)
            .padding(.top, 8)
        }
    }

    private func add(_ urls: [URL]) {
        append(urls.compactMap { url in
            let scoped = url.startAccessingSecurityScopedResource()
            defer { if scoped { url.stopAccessingSecurityScopedResource() } }
            return (try? Data(contentsOf: url, options: .mappedIfSafe)).map { OutgoingFile.prepared(name: url.lastPathComponent, data: $0) }
        })
    }

    /// The camera sheet's still, pushed straight into the composer.
    private func add(captured image: UIImage) {
        guard let jpeg = image.jpegData(compressionQuality: 0.85) else { return }
        let file = OutgoingFile(name: "photo-\(Int(Date.now.timeIntervalSince1970)).jpg", data: jpeg)
        withAnimation(Motion.reduced(Motion.layout, reduceMotion)) { append([file]) }
    }

    private func append(_ new: [OutgoingFile]) {
        guard canAttach else { return }
        for file in new {
            guard file.data.count <= OutgoingFile.maxSize else {
                model.lastError = "\(file.name) is larger than 100 MB."
                continue
            }
            files.append(file)
        }
    }

        /// Photos go out as JPEG: HEIC isn't something every agent can read.
        private func addPhotos(_ items: [PhotosPickerItem]) async {
            let stamp = Int(Date.now.timeIntervalSince1970)
            var picked: [OutgoingFile] = []
            for (i, item) in items.enumerated() {
                guard let data = try? await item.loadTransferable(type: Data.self) else { continue }
                if let movie = item.supportedContentTypes.first(where: { $0.conforms(to: .movie) }) {
                    picked.append(OutgoingFile(name: "video-\(stamp)-\(i + 1).\(movie.preferredFilenameExtension ?? "mov")", data: data))
                } else if let jpeg = ImageData.jpeg(data) {
                    picked.append(OutgoingFile(name: "photo-\(stamp)-\(i + 1).jpg", data: jpeg))
                }
            }
            append(picked)
        }

    private func mention(_ member: Bot) {
        guard let at = draft.lastIndex(of: "@") else { return }
        draft = String(draft[..<at]) + "@\(member.name) "
        focused = true
    }

    private func run(_ command: SlashCommand) {
        guard let bot else { return }
        switch command.action {
        case .fast:
            model.toggleFastMode(bot)
            draft = ""
        case .skill(let id):
            draft = "/\(id) "
        }
        focused = true
    }

    /// Return on a hardware keyboard: a new line at the cursor, and the field keeps the keyboard.
    /// An empty box gets none, also right after ⌘↩ sent it (the field submits after the shortcut).
    private func newline() {
        focused = true
        input.insertNewline()
    }

    private func submit() {
        if files.isEmpty, let command = SlashCommands.builtIn(for: bot, members: members, draft: draft) { return run(command) }
        guard canSend else { return }
        withAnimation(Motion.reduced(Motion.conversation, reduceMotion)) {
            guard model.sendComposerDraft(to: botId, draft: draftKey, replyTo: artifact?.replyQuote ?? replyingTo?.replyQuote,
                                          files: files) else { return }
            draft = ""
            files = []
            replyingTo = nil
        }
    }
}

/// One suggestion above the box: a bot to @mention.
private struct SuggestionChip<Icon: View>: View {
    let title: String
    @ViewBuilder let icon: Icon
    let action: () -> Void

    var body: some View {
        Button(action: action) {
            HStack(spacing: 6) {
                icon
                Text(title).font(.subheadline).foregroundStyle(Palette.text)
            }
            .padding(.horizontal, 10)
            .padding(.vertical, 6)
            .background(Palette.surface, in: Capsule())
        }
        .buttonStyle(PressScale())
    }
}
