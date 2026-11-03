import CodyncKit
import SwiftUI

/// "Full conversation": everything the agent did — narration, thinking, tool
/// calls with output and diffs, plans — grouped by turn.
public struct TraceView: View {
    let botId: String

    public init(botId: String) { self.botId = botId }
    @Environment(BotStore.self) private var model
    @Environment(\.dismissModal) private var dismiss

    public var body: some View {
        let all = model.chat(botId)
        let turns = Dictionary(grouping: all, by: \.turn)
            .sorted { $0.key < $1.key }
        // The running turn's thoughts start unfolded.
        let running = Entry.runningTurn(all, working: model.bots[botId]?.isWorking(in: botId) == true)
        NavigationStack {
            Form {
                if turns.isEmpty {
                    Section { Text(L10n.tr("Nothing yet.")).foregroundStyle(.secondary) }
                }
                ForEach(turns, id: \.key) { turn, entries in
                    Section {
                        ForEach(entries) { TraceRow(entry: $0, unfolded: turn == running) }
                    } header: {
                        Text(entries.first { $0.kind == "user" }?.data.text ?? "Turn \(turn)").lineLimit(1)
                    }
                }
            }
            .navigationTitle(L10n.tr("Full conversation"))
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .topBarTrailing) { Button(L10n.tr("Close")) { dismiss() } }
            }
            .defaultScrollAnchor(.bottom)
        }
        .tint(.primary)
        .tracked(.screenViewed(.trace))
    }
}

struct TraceRow: View {
    let entry: Entry
    @State private var expanded: Bool

    /// The running turn's thoughts start unfolded, so its reasoning reads as it comes in.
    init(entry: Entry, unfolded: Bool) {
        self.entry = entry
        _expanded = State(initialValue: unfolded)
    }

    var body: some View {
        let d = entry.data
        switch entry.kind {
        case "user":
            Label { Text(d.text ?? "").foregroundStyle(Palette.text) } icon: { RemixIcon("user-fill").foregroundStyle(Palette.secondary) }
                .font(.subheadline)
        case "agent":
            VStack(alignment: .leading, spacing: 4) {
                Text(L10n.tr(d.final == true ? "Reply" : "Said")).font(.caption2.bold()).foregroundStyle(Palette.tertiary)
                MarkdownText(d.text ?? "")
            }
        case "thought":
            Disclosure(isExpanded: $expanded) {
                Text(d.text ?? "").font(.footnote).foregroundStyle(Palette.secondary).textSelection(.enabled)
            } label: {
                Label { Text(L10n.tr("Thinking")) } icon: {
                    ThinkingOrb(size: 16, color: Palette.secondary, animated: false)
                }.font(.subheadline).foregroundStyle(Palette.secondary)
            }
        case "tool":
            ToolRow(data: d)
        case "plan":
            VStack(alignment: .leading, spacing: 6) {
                Label { Text(L10n.tr("Plan")) } icon: { RemixIcon("list-check") }.font(.subheadline.bold())
                ForEach(Array((d.entries ?? []).enumerated()), id: \.offset) { _, item in
                    Label {
                        Text(item.content).strikethrough(item.status == "completed").foregroundStyle(Palette.text)
                    } icon: {
                        Image(systemName: item.status == "completed" ? "checkmark.circle.fill" : item.status == "in_progress" ? "circle.dotted" : "circle")
                            .foregroundStyle(item.status == "completed" ? Palette.accent : Palette.tertiary)
                    }
                    .font(.footnote)
                }
            }
        case "permission":
            Label { Text(d.title ?? "Approval") } icon: { RemixIcon("hand") }
                .font(.subheadline)
                .foregroundStyle(Palette.secondary)
        default:
            Text(L10n.tr(d.text ?? "")).font(.footnote).foregroundStyle(Palette.tertiary)
        }
    }
}

struct ToolRow: View {
    let data: EntryData
    @State private var expanded = false

    private var icon: String {
        switch data.toolKind {
        case "read": "doc.text"
        case "edit": "pencil"
        case "delete": "trash"
        case "move": "arrow.right.doc.on.clipboard"
        case "search": "magnifyingglass"
        case "execute": "terminal"
        case "think": "brain"
        case "fetch": "globe"
        default: "wrench.and.screwdriver"
        }
    }

    private var orb: ThinkingOrb.State {
        switch data.toolKind {
        case "search": .searching
        case "fetch": .connecting
        case "edit": .shaping
        default: .working
        }
    }

    private var hasBody: Bool {
        !(data.output ?? "").isEmpty || !(data.diffs ?? []).isEmpty
    }

    var body: some View {
        if hasBody {
            Disclosure(isExpanded: $expanded) {
                VStack(alignment: .leading, spacing: 8) {
                    ForEach(data.diffs ?? [], id: \.self) { DiffView(diff: $0) }
                    if let out = data.output, !out.isEmpty { CodeBox(text: out) }
                }
            } label: { label }
        } else {
            label
        }
    }

    private var label: some View {
        HStack(spacing: 8) {
            Image(systemName: icon).frame(width: 18).foregroundStyle(Palette.secondary)
            Text(data.title ?? "Tool").font(.subheadline).foregroundStyle(Palette.text).lineLimit(2)
            Spacer(minLength: 4)
            switch data.status {
            case "completed": RemixIcon("check-line").foregroundStyle(Palette.accent)
            case "failed": RemixIcon("close-line").foregroundStyle(Palette.danger)
            default: ThinkingOrb(state: orb, size: 16, color: Palette.secondary)
            }
        }
        .font(.caption)
    }
}
