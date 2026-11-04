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

    public init(entry: Entry) {
        id = entry.id
        content = .entry(entry)
        isUserMessage = entry.kind == "user"
    }

    public init(summary: TranscriptSummary) {
        id = summary.id
        content = .summary(summary)
        isUserMessage = false
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
        ConversationList(rows: rows, following: $following, nearTop: nearTop, refresh: refresh)
            .overlay(alignment: .top) { ProgressiveTopBlur() }
    }
}

/// A transcript for a conversation that isn't a Codync bot (DSH): Coe's page layout and bubble
/// styling, without needing a `BotStore`.
public struct ChatTranscriptView: View {
    let items: [TranscriptItem]
    @Binding var following: Bool
    let working: Bool
    let onOpenSummary: (TranscriptSummary) -> Void

    public init(items: [TranscriptItem], following: Binding<Bool>, working: Bool = false,
                onOpenSummary: @escaping (TranscriptSummary) -> Void) {
        self.items = items
        _following = following
        self.working = working
        self.onOpenSummary = onOpenSummary
    }

    public var body: some View {
        ChatTranscriptList(rows: rows, following: $following)
    }

    private var rows: [ConversationRow] {
        var out: [ConversationRow] = []
        var lastDate: Date?
        for item in items {
            switch item.content {
            case .entry(let entry):
                let date = Date(timeIntervalSince1970: Double(entry.createdAt) / 1000)
                if lastDate.map({ date.timeIntervalSince($0) > 3600 }) ?? true {
                    out.append(ConversationRow("sep-\(item.id)") { TimeSeparator(date: date) })
                }
                lastDate = date
                out.append(ConversationRow(item.id, isUserMessage: item.isUserMessage) {
                    ChatEntryRow(entry: entry)
                })
            case .summary(let summary):
                out.append(ConversationRow(item.id) {
                    TurnSummaryRow(summary: summary) { onOpenSummary(summary) }
                })
            }
        }
        if working {
            out.append(ConversationRow("working") { typing })
        }
        return out
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

    var body: some View {
        switch entry.kind {
        case "user":
            HStack(spacing: 0) {
                Spacer(minLength: 40)
                Text(entry.data.text ?? "")
                    .font(.body)
                    .textSelection(.enabled)
                    .foregroundStyle(Palette.text)
                    .padding(.horizontal, 16)
                    .padding(.vertical, 10)
                    .background(Palette.bubbleUser, in: RoundedRectangle(cornerRadius: 18, style: .continuous))
            }
            .padding(.top, 12)
        case "agent":
            HStack(spacing: 0) {
                MarkdownText(entry.data.text ?? "").equatable()
                    .padding(.horizontal, 16)
                    .padding(.vertical, 10)
                    .background(Palette.bubbleAgent, in: RoundedRectangle(cornerRadius: 18, style: .continuous))
                Spacer(minLength: 40)
            }
            .frame(maxWidth: .infinity, alignment: .leading)
            .padding(.top, 12)
        default:
            NoticeRow(entry: entry).padding(.top, 10)
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

/// A gradient-faded material at the top edge: the "progressive blur" the roster had, drawn by us
/// because the chat list is a UIKit view and the home's list reaches under the bar.
///
/// The material follows the colour scheme — a thin material over white washes out, so dark mode gets
/// a thicker one — and a systemBackground gradient sits on top of it, which is what makes the edge
/// fade into the bar instead of cutting off at a grey band.
public struct ProgressiveTopBlur: View {
    let height: CGFloat
    @Environment(\.colorScheme) private var colorScheme

    public init(height: CGFloat = 110) {
        self.height = height
    }

    private var material: Material {
        colorScheme == .dark ? .thickMaterial : .ultraThinMaterial
    }

    /// The page's own colour at the very top, thinning out as the blur takes over.
    private var tint: Color {
        Color(uiColor: .systemBackground).opacity(colorScheme == .dark ? 0.85 : 0.5)
    }

    public var body: some View {
        ZStack(alignment: .top) {
            Rectangle()
                .fill(material)
                .mask {
                    LinearGradient(stops: [
                        .init(color: .black, location: 0),
                        .init(color: .black, location: 0.6),
                        .init(color: .clear, location: 1),
                    ], startPoint: .top, endPoint: .bottom)
                }
            LinearGradient(colors: [tint, tint.opacity(0)], startPoint: .top, endPoint: .bottom)
        }
        .frame(height: height)
        .frame(maxHeight: .infinity, alignment: .top)
        .ignoresSafeArea(edges: .top)
        .allowsHitTesting(false)
    }
}
