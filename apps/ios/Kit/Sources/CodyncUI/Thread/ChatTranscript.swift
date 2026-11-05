import CodyncKit
import SwiftUI
import UIKit

/// A folded stretch of one turn (thinking + tool calls) that a chat page shows as one line and
/// opens for its details.
public struct TranscriptSummary: Identifiable, Hashable, Sendable {
    public let id: String
    /// The one line shown in the chat, e.g. "思考了 12 秒 · 运行了 3 个命令".
    public let title: String
    /// The full text the details sheet shows.
    public let detail: String

    public init(id: String, title: String, detail: String) {
        self.id = id
        self.title = title
        self.detail = detail
    }
}

/// One row of a borrowed transcript: a message, or a folded turn summary.
public struct TranscriptItem: Identifiable, Sendable {
    public enum Content: Sendable {
        case entry(Entry)
        case summary(TranscriptSummary)
    }

    public let id: String
    public let content: Content
    public let isUserMessage: Bool
    /// Pictures this row shows, loaded by whoever owns the transcript.
    public let images: [TranscriptImageRef]

    public init(entry: Entry, displayRowId: String? = nil, scrollToWhenAdded: Bool? = nil,
                images: [TranscriptImageRef] = []) {
        id = displayRowId ?? entry.id
        content = .entry(entry)
        isUserMessage = scrollToWhenAdded ?? (entry.kind == "user")
        self.images = images
    }

    public init(summary: TranscriptSummary) {
        id = summary.id
        content = .summary(summary)
        isUserMessage = false
        images = []
    }
}

/// The scrolling transcript: the same `ConversationList` every chat page uses. Callers build the
/// rows; this keeps the pull-to-refresh, follow-newest and jump-to-latest behaviour in one place.
struct ChatTranscriptList: View {
    let rows: [ConversationRow]
    @Binding var following: Bool
    var nearTop: (() -> Void)?
    var refresh: (() async -> Void)?

    var body: some View {
        // The collection view asks iOS 26 for its own soft top edge effect (`ConversationList`), so
        // nothing is drawn on top of it.
        ConversationList(rows: rows, following: $following, nearTop: nearTop, refresh: refresh)
    }
}

/// A transcript for a conversation that isn't a Codync bot (DSH): Coe's page layout and bubble
/// styling, without needing a `BotStore`.
public struct ChatTranscriptView: View {
    let items: [TranscriptItem]
    @Binding var following: Bool
    let working: Bool
    let workingTitle: String
    let onOpenSummary: (TranscriptSummary) -> Void
    let nearTop: (() -> Void)?
    let refresh: (() async -> Void)?
    let hasMore: Bool
    let loadingEarlier: Bool
    let historyError: String?
    let accessory: AnyView?
    let sendingRevision: Int
    /// Changes when pictures should be asked for again; empty for a transcript without pictures.
    let imageReloadKey: String
    /// Loads one picture by its `TranscriptImageRef.id`; nil draws no pictures at all.
    let loadImage: (@MainActor (String) async -> Data?)?

    public init(items: [TranscriptItem], following: Binding<Bool>, working: Bool = false,
                workingTitle: String = WorkingPhrase.processing,
                nearTop: (() -> Void)? = nil, refresh: (() async -> Void)? = nil,
                hasMore: Bool = false, loadingEarlier: Bool = false, historyError: String? = nil,
                accessory: AnyView? = nil, sendingRevision: Int = 0,
                onOpenSummary: @escaping (TranscriptSummary) -> Void = { _ in },
                imageReloadKey: String = "", loadImage: (@MainActor (String) async -> Data?)? = nil) {
        self.items = items
        _following = following
        self.working = working
        self.workingTitle = workingTitle
        self.onOpenSummary = onOpenSummary
        self.nearTop = nearTop; self.refresh = refresh
        self.hasMore = hasMore; self.loadingEarlier = loadingEarlier
        self.historyError = historyError; self.accessory = accessory
        self.sendingRevision = sendingRevision
        self.imageReloadKey = imageReloadKey
        self.loadImage = loadImage
    }

    public var body: some View {
        ChatTranscriptList(rows: rows, following: $following, nearTop: nearTop, refresh: refresh)
    }

    private var rows: [ConversationRow] {
        var out: [ConversationRow] = []
        if hasMore || loadingEarlier || historyError != nil {
            out.append(ConversationRow("earlier", revision: (historyError ?? "").hashValue &+ (loadingEarlier ? 1 : 0)) {
                Button {
                    if historyError != nil { Task { await refresh?() } }
                    else { nearTop?() }
                } label: {
                    Text(historyError ?? (loadingEarlier ? "正在加载较早消息…" : "加载较早消息"))
                        .font(.footnote).foregroundStyle(Palette.secondary)
                        .frame(maxWidth: .infinity).padding(.vertical, 12)
                }
                .buttonStyle(.plain)
                .disabled(loadingEarlier)
                .onAppear { if historyError == nil { nearTop?() } }
            })
        }
        var lastDate: Date?
        for item in items {
            switch item.content {
            case .entry(let entry):
                let date = Date(timeIntervalSince1970: Double(entry.createdAt) / 1000)
                if lastDate.map({ date.timeIntervalSince($0) > 3600 }) ?? true {
                    out.append(ConversationRow("sep-\(item.id)") { TimeSeparator(date: date) })
                }
                lastDate = date
                out.append(ConversationRow(item.id, isUserMessage: item.isUserMessage,
                                           revision: Self.revision(of: item)) {
                    ChatEntryRow(entry: entry, images: item.images, reloadKey: imageReloadKey,
                                 loadImage: loadImage)
                })
            case .summary:
                // A folded "thinking for 12s · ran 3 commands" line is a step, not the bot talking:
                // it is not drawn and there is nothing to open.
                continue
            }
        }
        if let accessory {
            out.append(ConversationRow("sending-status", revision: accessoryRevision) { accessory })
        }
        return out
    }

    private var accessoryRevision: Int { items.count &+ sendingRevision }

    /// What counts as "this row changed": the entry's own revision plus everything the row draws —
    /// its text, and for a notice its heading/source and style — plus the pictures it shows, so a
    /// growing streaming reply, a notice whose source or style changed, or a picture that arrived
    /// late re-renders alone while the rest of the transcript stays put. This is an in-memory row
    /// version, never persisted, so `Hasher` is fine here.
    private static func revision(of item: TranscriptItem) -> Int {
        var hasher = Hasher()
        if case .entry(let entry) = item.content {
            hasher.combine(entry.data.text ?? "")
            hasher.combine(entry.data.title ?? "")
            hasher.combine(entry.data.style ?? "")
            hasher.combine(entry.rev)
        }
        hasher.combine(item.images.map(\.id).joined(separator: "\u{1F}"))
        return hasher.finalize()
    }

    private var typing: some View {
        HStack(spacing: 5) {
            ForEach(0..<3) { _ in
                Circle().fill(Palette.secondary).frame(width: 5, height: 5)
            }
        }
        .frame(maxWidth: .infinity, alignment: .leading)
        .padding(.leading, 16)
        .padding(.vertical, 10)
    }
}

/// A user/assistant/notice row drawn like the Coe chat's, minus the BotStore-only actions.
private struct ChatEntryRow: View {
    let entry: Entry
    let images: [TranscriptImageRef]
    let reloadKey: String
    let loadImage: (@MainActor (String) async -> Data?)?

    var body: some View {
        switch entry.kind {
        case "user":
            HStack(spacing: 0) {
                Spacer(minLength: 40)
                VStack(alignment: .trailing, spacing: 4) {
                    pictureList
                    // A message that is only pictures has no text to put in a bubble.
                    if let text = entry.data.text, !text.isEmpty {
                        Text(text)
                            .font(.body)
                            .textSelection(.enabled)
                            .foregroundStyle(Palette.text)
                            .padding(.horizontal, 16)
                            .padding(.vertical, 10)
                            .background(Palette.bubbleUser, in: RoundedRectangle(cornerRadius: 18, style: .continuous))
                    }
                }
            }
            .padding(.top, 12)
        case "agent":
            HStack(spacing: 0) {
                VStack(alignment: .leading, spacing: 4) {
                    pictureList
                    if let text = entry.data.text, !text.isEmpty {
                        MarkdownText(text).equatable()
                            .padding(.horizontal, 16)
                            .padding(.vertical, 10)
                            .background(Palette.bubbleAgent, in: RoundedRectangle(cornerRadius: 18, style: .continuous))
                    }
                }
                Spacer(minLength: 40)
            }
            .frame(maxWidth: .infinity, alignment: .leading)
            .padding(.top, 12)
        default:
            // A notice is a neutral line; a picture riding on one (a context photo) still shows, above it.
            VStack(alignment: .leading, spacing: 4) {
                pictureList
                NoticeRow(entry: entry)
            }
            .padding(.top, 10)
        }
    }

    /// The row's pictures, when the transcript knows how to load them.
    @ViewBuilder private var pictureList: some View {
        if let loadImage, !images.isEmpty {
            TranscriptImageList(images: images, reloadKey: reloadKey, load: loadImage)
        }
    }
}

/// One line for a folded turn: tap opens everything it hid.
private struct TurnSummaryRow: View {
    let summary: TranscriptSummary
    let open: () -> Void

    var body: some View {
        Button(action: open) {
            HStack(spacing: 6) {
                Image(systemName: "sparkles").font(.footnote)
                Text(summary.title).font(.footnote)
                Image(systemName: "chevron.right").font(.caption2)
                Spacer(minLength: 0)
            }
            .foregroundStyle(Palette.secondary)
            .padding(.vertical, 6)
            .padding(.horizontal, 16)
            .contentShape(Rectangle())
        }
        .buttonStyle(.plain)
        .accessibilityLabel(summary.title)
    }
}
