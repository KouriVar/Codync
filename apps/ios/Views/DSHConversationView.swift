import CodyncKit
import CodyncUI
import DSHKit
import SwiftUI

/// A DSH conversation, on the same chat page Coe uses: messages as bubbles, and each turn's
/// thinking + tool calls folded into one tappable line that opens its full content.
struct DSHConversationView: View {
    @ObservedObject var gateway: DSHGateway
    @State private var following = true
    @State private var details: TranscriptSummary?
    @State private var draft = ""

    var body: some View {
        ChatTranscriptView(items: items, following: $following, working: gateway.isStreaming) { summary in
            details = summary
        }
        .background(Palette.background)
        // The input bar is an inset rather than a stacked row: the transcript runs under it and
        // comes up with the keyboard.
        .safeAreaInset(edge: .bottom, spacing: 0) {
            ConversationComposer(text: $draft, placeholder: "给 DSH 发一条消息",
                                 canSend: canSend, bottomPadding: 12) {
                send()
            }
            .background(Palette.background)
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
        .sheet(item: $details) { summary in
                NavigationStack {
                    ScrollView {
                        Text(summary.detail.isEmpty ? summary.title : summary.detail)
                            .font(.callout)
                            .textSelection(.enabled)
                            .frame(maxWidth: .infinity, alignment: .leading)
                            .padding(16)
                    }
                    .background(Palette.background)
                    .navigationTitle(summary.title)
                    .navigationBarTitleDisplayMode(.inline)
                .toolbar {
                    ToolbarItem(placement: .cancellationAction) { Button("关闭") { details = nil } }
                }
            }
        }
        .onDisappear { gateway.closeConversation() }
    }

    private var title: String {
        guard let session = gateway.sessions.first(where: { $0.id == gateway.openSessionId }) else {
            return gateway.gatewayName
        }
        return gateway.displayTitle(for: session)
    }

    /// The adapter's rows (user/assistant + a folded summary) become Codync's chat entries; the
    /// summary keeps its own row so the message text reads as usual.
    private var items: [TranscriptItem] {
        var out: [TranscriptItem] = []
        for row in DSHConversationAdapter.transcript(from: gateway.messages) {
            if let summary = row.summary {
                out.append(TranscriptItem(summary: TranscriptSummary(
                    id: summary.id + "-summary",
                    title: summary.title,
                    detail: Self.detailText(for: summary))))
            }
            guard !row.text.isEmpty else { continue }
            let kind = row.kind == .user ? "user" : "agent"
            let entry = Entry(id: row.id, seq: 0, botId: "dsh", rev: 0, kind: kind,
                              turn: 0, data: EntryData(text: row.text),
                              createdAt: row.createdAt, updatedAt: row.createdAt)
            out.append(TranscriptItem(entry: entry))
        }
        return out
    }

    private static func detailText(for summary: DSHSummary) -> String {
        var sections: [String] = []
        if !summary.reasoning.isEmpty {
            sections.append("思考\n\(summary.reasoning)")
        }
        if !summary.tools.isEmpty {
            let rows = summary.tools.map { tool -> String in
                var parts = ["• \(tool.name)\(tool.isError ? "（失败）" : "")"]
                if !tool.arguments.isEmpty { parts.append(tool.arguments) }
                if let output = tool.output, !output.isEmpty { parts.append("→ \(output)") }
                return parts.joined(separator: "\n  ")
            }
            sections.append("工具\n" + rows.joined(separator: "\n\n"))
        }
        return sections.joined(separator: "\n\n")
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

    private var canSend: Bool {
        !draft.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty && gateway.openSessionId != nil
    }

    private func send() {
        let text = draft
        draft = ""
        gateway.send(text: text)
    }
}
