import Foundation

public struct DSHSubmission: Identifiable, Hashable, Sendable {
    public enum Status: String, Hashable, Sendable { case writing, accepted, failed, unknown }
    public let id: String
    public let text: String
    public private(set) var status: Status
    public private(set) var detail: String
    public private(set) var historyChecked = false
    public private(set) var isRetired = false
    mutating func retire() { isRetired = true }
    var connection: UInt64

    init(text: String, connection: UInt64, available: Bool) {
        id = UUID().uuidString; self.text = text; self.connection = connection
        status = available ? .writing : .failed
        detail = available ? "发送中" : "没有发出去，请连接后手动重试"
    }
    mutating func checkedHistory() { historyChecked = true }
    mutating func receive(_ status: Status, detail: String) {
        guard self.status != .accepted else { return }
        self.status = status; self.detail = detail
    }
}

/// One selected conversation's data. Only Gateway does I/O; all merges are deterministic here.
struct DSHConversationState: Sendable {
    enum RequestKind: Sendable { case older, reconcile }
    struct Request: Sendable {
        let kind: RequestKind
        let before: Int64?
        let generation: UInt64
    }
    let scope: DSHSessionScope
    private(set) var events: [Int64: DSHWireEvent] = [:]
    private(set) var loadedRanges: [ClosedRange<Int64>] = []
    private(set) var cursor: Int64?
    private(set) var streamId: String?
    private(set) var subscriptionId: String?
    private(set) var streamRevision: Int64 = 0
    private(set) var attempt: DSHTranscriptAttempt?
    private(set) var hasMore = false
    private(set) var nextBeforeSeq: Int64?
    private(set) var pageError: String?
    private(set) var requests: [String: Request] = [:]
    private(set) var submissions: [DSHSubmission] = []
    private struct DisplayAnchor: Sendable { let id: String; let afterSeq: Int64 }
    private var aliases: [Int64: DisplayAnchor] = [:]
    private var projectedMessages: [Int64: DSHMessage] = [:]
    private var displaySequences: [Int64] = []
    private(set) var needsBaseline = false
    private var counter: Int64 = 0
    private var awaitingSnapshot = true

    var loadingEarlier: Bool { requests.values.contains { $0.kind == .older } }
    var hasBaseline: Bool { cursor != nil && !awaitingSnapshot }

    mutating func retireStream() {
        attempt = nil; subscriptionId = nil; streamId = nil; cursor = nil
        aliases = [:]; rebuildDisplayOrder(); requests = [:]; awaitingSnapshot = true
    }
    mutating func subscribed(_ id: String) {
        retireStream(); subscriptionId = id
    }
    mutating func resetStream() {
        attempt = nil; streamId = nil; awaitingSnapshot = true
    }
    func owns(_ frame: DSHFrame) -> Bool {
        frame.string("sessionId") == scope.sessionId && subscriptionId != nil
            && frame.string("subscriptionId") == subscriptionId
            && streamId != nil && frame.string("streamId") == streamId && !awaitingSnapshot
    }
    mutating func snapshot(_ input: DSHWireSnapshot) -> Bool {
        guard subscriptionId == input.subscriptionId,
              awaitingSnapshot || streamId == input.streamId else { return false }
        attempt = nil; aliases = [:]; streamId = input.streamId; cursor = input.cursor
        streamRevision = input.revision; awaitingSnapshot = false
        // Unknown surface rewrites invalidate this window, never another session's state.
        if input.events.contains(where: { event in
            (event.surfaceOp != .null && event.surfaceOp.string != "append")
                || events[event.seq].map { $0.contradicts(event) } == true
        }) {
            events = [:]; loadedRanges = []; projectedMessages = [:]
        }
        needsBaseline = false
        for event in input.events { merge(event) }
        guard !needsBaseline else { return false }
        rebuildDisplayOrder()
        recordRange(lower: input.nextBeforeSeq ?? input.events.map(\.seq).min() ?? input.cursor,
                    upper: input.cursor, complete: !input.hasMore)
        hasMore = input.hasMore; nextBeforeSeq = input.nextBeforeSeq; pageError = nil
        if input.rawAttempt != .null {
            guard var active = DSHTranscriptAttempt(raw: input.rawAttempt, scope: scope, streamId: input.streamId),
                  active.startedAfterSeq <= input.cursor,
                  let index = input.rawAttempt["nextIndex"].integer, index >= 0 else { return false }
            active.nextIndex = index; active.restore(input.rawAttempt["stream"].array)
            active.candidates = candidates(for: active)
            bump(); active.revision = counter; attempt = active
        }
        return true
    }
    /// True means admitted (including harmless replay), false means a baseline is needed.
    mutating func event(_ event: DSHWireEvent) -> Bool {
        guard let cursor, !awaitingSnapshot else { return false }
        if event.seq <= cursor {
            // A live replay must not create records omitted from a trimmed baseline.
            if events[event.seq] != nil { merge(event) }
            return !needsBaseline
        }
        guard event.seq == cursor + 1 else { return false }
        guard event.surfaceOp == .null || event.surfaceOp.string == "append" else { return false }
        merge(event)
        guard !needsBaseline else { return false }
        self.cursor = event.seq
        // End settles the whole turn, but never deletes its canonical messages.
        if event.type == "turn/end" { attempt = nil }
        return true
    }
    mutating func stream(_ raw: DSHJSON) -> Bool {
        guard let revision = raw["revision"].integer, hasBaseline else { return false }
        if revision <= streamRevision { return true }
        guard revision == streamRevision + 1 else { return false }
        switch raw["type"].string {
        case "start":
            guard attempt == nil, let streamId,
                  var active = DSHTranscriptAttempt(raw: raw, scope: scope, streamId: streamId),
                  active.startedAfterSeq <= (cursor ?? -1) else { return false }
            active.candidates = candidates(for: active)
            attempt = active
        case "chunk":
            guard var active = attempt, active.id == raw["attemptId"].string,
                  raw["index"].integer == active.nextIndex else { return false }
            active.append(raw["chunk"], time: Self.milliseconds(raw["time"].integer ?? 0))
            active.nextIndex += 1; bump(); active.revision = counter; attempt = active
        case "end":
            guard let active = attempt, active.id == raw["attemptId"].string,
                  raw["index"].integer == active.nextIndex else { return false }
            switch raw["outcome"]["kind"].string {
            case "committed":
                guard let seq = raw["outcome"]["seq"].integer, seq > active.startedAfterSeq,
                      seq <= (cursor ?? -1), let committed = events[seq],
                      committed.type == raw["outcome"]["eventType"].string,
                      ["assistant/message", "assistant/attempt"].contains(committed.type),
                      committed.turn == active.turn, committed.step == active.step else { return false }
                aliases[seq] = DisplayAnchor(id: active.rowId, afterSeq: active.startedAfterSeq)
                rebuildDisplayOrder()
            case "abandoned": break
            default: return false
            }
            attempt = nil
        default: return false
        }
        streamRevision = revision
        return true
    }

    mutating func register(_ kind: RequestKind, generation: UInt64) -> String? {
        if kind == .older && (!hasMore || loadingEarlier) { return nil }
        if requests.values.contains(where: { $0.kind == kind }) { return nil }
        if kind == .older && nextBeforeSeq.map({ $0 >= 0 }) != true {
            pageError = "较早消息暂未同步：缺少分页游标"; return nil
        }
        let id = UUID().uuidString
        requests[id] = Request(kind: kind, before: kind == .older ? nextBeforeSeq : nil, generation: generation)
        pageError = nil
        return id
    }
    mutating func history(_ frame: DSHFrame, generation: UInt64) -> Bool {
        guard let id = frame.string("requestId"), let request = requests[id], request.generation == generation,
              frame.string("sessionId") == scope.sessionId else { return false }
        requests.removeValue(forKey: id)
        guard frame.int("historyFormatVersion") == scope.format else {
            pageError = "历史格式已改变，请重新连接以重建基线"; return false
        }
        guard let records = frame.array("events"), let more = frame.bool("hasMore") else {
            pageError = "历史消息格式无效"; return false
        }
        let page = records.compactMap(DSHWireEvent.history)
        guard page.count == records.count else {
            pageError = "历史消息格式无效"; return false
        }
        // Older pages may overlap cached windows, but cannot return newer records than requested.
        if let before = request.before, page.contains(where: { $0.seq >= before }) {
            pageError = "较早消息暂未同步：分页范围无效"; return false
        }
        for event in page { merge(event) }
        let next = DSHJSON(frame.json["nextBeforeSeq"] ?? NSNull()).integer
        let upper = request.before.map { $0 - 1 } ?? DSHJSON(frame.json["cursor"] ?? NSNull()).integer ?? -1
        recordRange(lower: next ?? page.map(\.seq).min() ?? upper, upper: upper, complete: !more)
        if request.kind == .older {
            hasMore = more; nextBeforeSeq = next
            if more && next.map({ $0 >= 0 && $0 < (request.before ?? Int64.max) }) != true {
                pageError = "较早消息暂未同步：游标未前进，请重试"
            }
        }
        return true
    }
    mutating func clearPageError() { pageError = nil }
    mutating func markReconciled(_ id: String) {
        if let index = submissions.firstIndex(where: { $0.id == id }) { submissions[index].checkedHistory() }
    }

    mutating func failRequest(_ id: String, message: String) {
        guard requests.removeValue(forKey: id) != nil else { return }
        pageError = message
    }

    mutating func submit(text: String, connection: UInt64, available: Bool) -> String {
        let submission = DSHSubmission(text: text, connection: connection, available: available)
        submissions.append(submission)
        return submission.id
    }
    mutating func delivery(_ id: String, status: DSHSubmission.Status, detail: String) {
        guard let index = submissions.firstIndex(where: { $0.id == id }) else { return }
        submissions[index].receive(status, detail: detail)
    }
    mutating func interruptSending(connection: UInt64) {
        for i in submissions.indices where submissions[i].status == .writing && submissions[i].connection == connection {
            submissions[i].receive(.unknown, detail: "送达待核对，请先查历史，不会自动重发")
        }
    }
    mutating func dismissSubmission(_ id: String) {
        // Keep the old request address for delayed receipts after a manual retry.
        if let index = submissions.firstIndex(where: { $0.id == id }) { submissions[index].retire() }
    }

    var messages: [DSHMessage] {
        let suppressed = attempt?.candidates ?? []
        var rows = displaySequences.compactMap { seq -> DSHMessage? in
            guard !suppressed.contains(seq), var row = projectedMessages[seq] else { return nil }
            row.displayRowId = aliases[seq]?.id ?? row.id
            return row
        }
        if let active = attempt, !active.text.isEmpty {
            let row = DSHMessage(id: active.rowId, role: .assistant, text: active.text, streaming: true,
                                 reasoning: active.reasoning, turn: active.turn, createdAt: active.time,
                                 seq: active.startedAfterSeq, step: active.step, revision: active.revision)
            // The temporary reply belongs after its starting cursor, not after an unrelated future turn.
            let position = rows.firstIndex { (aliases[$0.seq]?.afterSeq ?? $0.seq) > active.startedAfterSeq } ?? rows.endIndex
            rows.insert(row, at: position)
        }
        return rows
    }

    private func candidates(for active: DSHTranscriptAttempt) -> Set<Int64> {
        Set(events.values.filter {
            ["assistant/message", "assistant/attempt"].contains($0.type)
                && $0.turn == active.turn && $0.step == active.step && $0.seq > active.startedAfterSeq
        }.map(\.seq))
    }

    private mutating func merge(_ incoming: DSHWireEvent) {
        var value = incoming
        if let old = events[incoming.seq] {
            if old.contradicts(incoming) { needsBaseline = true }
            guard old.type == incoming.type else { pageError = "消息序号冲突，正在重新同步"; return }
            value.payload = incoming.completeness.rawValue >= old.completeness.rawValue
                ? old.payload.enriched(by: incoming.payload) : incoming.payload.enriched(by: old.payload)
            value.completeness = maxCompleteness(old.completeness, incoming.completeness)
            if value.time == 0 { value.time = old.time }
            if value.surfaceOp == .null { value.surfaceOp = old.surfaceOp }
            if value.sourceEventSeqs == .null { value.sourceEventSeqs = old.sourceEventSeqs }
            value.revision = old.revision
            if value == old { return }
        }
        bump(); value.revision = counter; events[value.seq] = value
        let hadProjection = projectedMessages[value.seq] != nil
        projectedMessages[value.seq] = project(value)
        if hadProjection != (projectedMessages[value.seq] != nil) { rebuildDisplayOrder() }
        if var active = attempt, ["assistant/message", "assistant/attempt"].contains(value.type),
           value.turn == active.turn, value.step == active.step, value.seq > active.startedAfterSeq {
            active.candidates.insert(value.seq); attempt = active
        }
    }
    private func project(_ event: DSHWireEvent) -> DSHMessage? {
        guard event.isUser || event.type == "assistant/message" else { return nil }
        let text = event.text
        guard !text.isEmpty, !(event.isUser && DSHSystemMessageFilter.isInjected(text)) else { return nil }
        let id = scope.identity([.seq(event.seq)])
        return DSHMessage(id: id, role: event.isUser ? .user : .assistant, text: text,
                          reasoning: event.reasoning, tools: event.tools, turn: event.turn,
                          createdAt: event.time, seq: event.seq, step: event.step, revision: event.revision)
    }
    private mutating func rebuildDisplayOrder() {
        displaySequences = projectedMessages.keys.sorted { a, b in
            let left = aliases[a]?.afterSeq ?? a, right = aliases[b]?.afterSeq ?? b
            if left != right { return left < right }
            // A committed entry at the starting cursor stays before the attempt anchored after it.
            if (aliases[a] == nil) != (aliases[b] == nil) { return aliases[a] == nil }
            return a < b
        }
    }
    private func maxCompleteness(_ a: DSHWireEvent.Completeness, _ b: DSHWireEvent.Completeness) -> DSHWireEvent.Completeness {
        a.rawValue > b.rawValue ? a : b
    }
    private mutating func bump() { counter += 1 }
    private mutating func recordRange(lower: Int64, upper: Int64, complete: Bool) {
        let low = complete ? 0 : lower
        guard upper >= low, low >= 0 else { return }
        var ranges = (loadedRanges + [low...upper]).sorted { $0.lowerBound < $1.lowerBound }
        loadedRanges = []
        while !ranges.isEmpty {
            let next = ranges.removeFirst()
            if let last = loadedRanges.last, next.lowerBound <= last.upperBound + 1 {
                loadedRanges[loadedRanges.count - 1] = last.lowerBound...max(last.upperBound, next.upperBound)
            } else { loadedRanges.append(next) }
        }
    }
    private static func milliseconds(_ time: Int64) -> Int64 { time > 10_000_000_000 ? time : time * 1000 }
}
