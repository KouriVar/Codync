import Foundation
import os

private let log = Logger(subsystem: "com.suiyikou.codync.dsh-gateway", category: "gateway")

/// The DSH conversation client: one WebSocket to the mobile gateway, a session list, and one open
/// conversation with its streamed reply. Deliberately small for the first slice — it speaks the
/// legacy single channel (no `X-DSH-Channel`), which every gateway accepts.
@MainActor
public final class DSHGateway: ObservableObject {
    public enum Phase: Equatable, Sendable {
        case idle
        case connecting
        case ready
        case failed(String)
    }

    @Published public private(set) var phase: Phase = .idle
    @Published public private(set) var gatewayName: String = "DSH"
    @Published public private(set) var sessions: [DSHSession] = []
    /// The last message of a session, read lazily for the home's list rows (the `sessions` list
    /// itself carries only titles).
    @Published public private(set) var previews: [String: String] = [:]
    /// The first thing the reader said in each session: what an unnamed session is called.
    @Published public private(set) var firstUserMessages: [String: String] = [:]
    @Published public private(set) var messages: [DSHMessage] = []
    @Published public private(set) var openSessionId: String?
    @Published public private(set) var isStreaming = false
    /// What the running turn is doing right now, for the chat's one status line; nil when nothing
    /// runs (the line disappears). Separate from `isStreaming`: a model attempt ending is not a turn
    /// ending, and a tool running has no attempt at all.
    @Published public private(set) var currentActivity: DSHActivityKind?
    /// Whether the open conversation has a turn under way.
    @Published public private(set) var isRunning = false

    public private(set) var profile: DSHGatewayProfile?

    private var task: URLSessionWebSocketTask?
    private let session: URLSession
    private var reconnectAttempt = 0
    private var reconnectTask: Task<Void, Never>?
    private var heartbeatTask: Task<Void, Never>?
    private var shouldReconnect = false
    /// assistant-stream attempts being written, so a stale chunk from an earlier attempt is ignored.
    private var streamingAttempts = Set<String>()
    /// The requestId of the one history page an open conversation asks for.
    private var openHistoryRequestId: String?
    /// The open turn's start, number and tools, folded into the assistant message it produces.
    private var turnStartedAt: Date?
    private var turnNumber: Int?
    private var turnTools: [DSHTool] = []
    /// The running-turn state behind the status line. Its own generation, seq watermark and attempt
    /// bookkeeping; it never touches `messages` or the body's own handling.
    private var activity = DSHActivityState()

    private var pendingPairing: CheckedContinuation<DSHGatewayProfile, Error>?
    private var pairingTimeoutTask: Task<Void, Never>?

    /// One connection shared by the home list and Settings, so pairing (or disconnect) in one place
    /// drives the other. The home owns whether it connects; Settings only shows its state.
    public static let shared = DSHGateway()

    public init() {
        let config = URLSessionConfiguration.default
        config.waitsForConnectivity = false
        config.timeoutIntervalForRequest = 30
        session = URLSession(configuration: config)
    }

    // MARK: - Connect

    /// Reconnects the last paired gateway, if any. Safe to call on launch and on foreground.
    public func connectLastPaired() {
        // Never disturb a pairing handshake that is already on the wire: the pairing socket is
        // the only thing that can deliver the new token.
        guard pendingPairing == nil else { return }
        if profile == nil {
            guard let saved = DSHCredentialStore.load().first else { return }
            profile = saved
            gatewayName = saved.name
        }
        // Idempotent: a live or connecting socket must not be torn down and rebuilt (that is what
        // turned one cancellation into a reconnect loop).
        if phase == .ready || phase == .connecting { return }
        start()
    }

    public func connect(_ profile: DSHGatewayProfile) {
        self.profile = profile
        gatewayName = profile.name
        start()
    }

    public func disconnect() {
        shouldReconnect = false
        reconnectTask?.cancel()
        reconnectTask = nil
        heartbeatTask?.cancel()
        heartbeatTask = nil
        task?.cancel(with: .goingAway, reason: nil)
        task = nil
        phase = .idle
        isStreaming = false
        activity.endSession()
        syncActivity()
    }

    private func start() {
        guard let profile else { return }
        shouldReconnect = true
        reconnectTask?.cancel()
        reconnectTask = nil
        openSocket(profile: profile, authorization: profile.token, pairing: nil)
    }

    // MARK: - Pairing (scan the QR the Mac's DSH web UI shows)

    public func pair(code: DSHPairingCode) async throws -> DSHGatewayProfile {
        let endpoints = code.endpoints
            .map { $0.trimmingCharacters(in: .whitespacesAndNewlines) }
            .filter { !$0.isEmpty }
        guard !endpoints.isEmpty else { throw DSHError.badQRCode("没有可用地址") }
        var lastError: Error?
        for (index, endpoint) in endpoints.enumerated() {
            do {
                return try await attemptPair(endpoint: endpoint, pairingCode: code.pairingCode)
            } catch {
                lastError = error
                // A cancelled URLSession task usually means something else touched the socket;
                // one more try (or the next advertised address) is worth it before giving up.
                if index + 1 < endpoints.count { continue }
                continue
            }
        }
        throw lastError ?? DSHError.transport("配对没有成功")
    }

    private func attemptPair(endpoint: String, pairingCode: String) async throws -> DSHGatewayProfile {
        try await withCheckedThrowingContinuation { continuation in
            pendingPairing = continuation
            pairingTimeoutTask?.cancel()
            pairingTimeoutTask = Task { [weak self] in
                try? await Task.sleep(nanoseconds: 25 * 1_000_000_000)
                await MainActor.run {
                    guard let self, let pending = self.pendingPairing else { return }
                    self.pendingPairing = nil
                    pending.resume(throwing: DSHError.transport("等待网关确认超时（25 秒）。二维码可能已过期，请在 Mac 上重新生成。"))
                    self.task?.cancel(with: .goingAway, reason: nil)
                }
            }
            openSocket(rawEndpoint: endpoint, authorization: nil, pairing: pairingCode)
        }
    }

    // MARK: - Socket

    private func openSocket(profile: DSHGatewayProfile, authorization: String?, pairing: String?) {
        openSocket(rawEndpoint: profile.endpoint, authorization: authorization, pairing: pairing)
    }

    private func openSocket(rawEndpoint: String, authorization: String?, pairing: String?) {
        guard var comps = URLComponents(string: rawEndpoint) else {
            fail(DSHError.transport("地址无效：\(rawEndpoint)"))
            return
        }
        if comps.path.isEmpty { comps.path = "/ws/mobile" }
        guard let url = comps.url else {
            fail(DSHError.transport("地址无效"))
            return
        }

        var request = URLRequest(url: url)
        request.timeoutInterval = 30
        var protocols = ["dsh-mobile-v1"]
        if let pairing { protocols.append("dsh-pair.\(pairing)") }
        request.setValue(protocols.joined(separator: ", "), forHTTPHeaderField: "Sec-WebSocket-Protocol")
        if let authorization, !authorization.isEmpty {
            request.setValue("Bearer \(authorization)", forHTTPHeaderField: "Authorization")
        }
        request.setValue(DSHDeviceIdentity.loadOrCreate(), forHTTPHeaderField: "X-DSH-Device-ID")

        // Cancelling the previous task is what makes an in-flight URLSession report -999
        // ("已取消"); during pairing, the socket we are about to replace IS the pairing socket,
        // so leave it alone unless it is already finished.
        if pendingPairing == nil { task?.cancel(with: .goingAway, reason: nil) }
        let socket = session.webSocketTask(with: request)
        task = socket
        if pairing == nil { phase = .connecting }
        socket.resume()
        receiveLoop(on: socket)
        if pairing == nil {
            startHeartbeat()
            send(["type": "sessions"])
        }
    }

    private func receiveLoop(on socket: URLSessionWebSocketTask) {
        socket.receive { [weak self] result in
            guard let self else { return }
            Task { @MainActor in
                // A cancelled socket's failure can arrive after its replacement is already live;
                // ignoring it is what keeps one reseat from becoming a reconnect loop.
                guard socket === self.task else { return }
                switch result {
                case .failure(let error):
                    self.handleDrop(error)
                case .success(let message):
                    if case .string(let text) = message { self.handleFrame(text) }
                    if case .data(let data) = message, let text = String(data: data, encoding: .utf8) {
                        self.handleFrame(text)
                    }
                    self.receiveLoop(on: socket)
                }
            }
        }
    }

    private func send(_ object: [String: Any]) {
        guard let task, let data = try? JSONSerialization.data(withJSONObject: object),
              let text = String(data: data, encoding: .utf8) else { return }
        task.send(.string(text)) { _ in }
    }

    // MARK: - Frames

    private func handleFrame(_ text: String) {
        guard let data = text.data(using: .utf8),
              let object = try? JSONSerialization.jsonObject(with: data) as? [String: Any],
              let kind = object["kind"] as? String else { return }
        let frame = DSHFrame(kind: kind, json: object)

        switch kind {
        case "hello":
            handleHello(frame)
        case "paired":
            handlePaired(frame)
        case "sessions":
            sessions = Self.decodeSessions(frame)
            reconnectAttempt = 0
            if phase != .ready { phase = .ready }
            applySessionsHint()
        case "subscribed":
            handleSubscribed(frame)
        case "session-status":
            handleSessionStatus(frame)
        case "history":
            handleHistory(frame)
        case "projection-baseline":
            handleProjectionBaseline(frame)
        case "turn-outline-updated":
            handleTurnOutline(frame)
        case "sent":
            reconnectAttempt = 0
        case "session-created":
            if let id = frame.string("sessionId") { open(sessionId: id) }
        case "event":
            handleEvent(frame)
        case "assistant-stream":
            handleStream(frame)
        case "session-snapshot":
            handleSnapshot(frame)
        case "session-stream-reset":
            isStreaming = false
            streamingAttempts.removeAll()
            activity.applyStreamReset(in: activityEnvelope(frame))
            syncActivity()
        case "error":
            let message = frame.string("message") ?? "未知错误"
            if frame.string("code") == "authentication-required" { requirePairingAgain() }
            else if phase != .ready { phase = .failed(message) }
        default:
            break
        }
    }

    private func handleHello(_ frame: DSHFrame) {
        let version = frame.int("protocolVersion") ?? frame.int("protocol") ?? 0
        if let name = frame.string("gatewayName"), !name.isEmpty { gatewayName = name }
        if version < 3, pendingPairing != nil {
            pendingPairing?.resume(throwing: DSHError.unsupportedProtocol(version))
            pendingPairing = nil
            return
        }
        reconnectAttempt = 0
        if pendingPairing == nil { phase = .ready }
        send(["type": "sessions"])
        // A reconnect while a conversation is open restores that one session only (never a batch).
        if let sessionId = openSessionId {
            send(["type": "subscribe", "sessionId": sessionId, "assistantStream": true])
            let requestId = "reopen-history-\(sessionId)"
            openHistoryRequestId = requestId
            send(["type": "history", "sessionId": sessionId, "maxMessages": 30, "maxBytes": 262_144,
                  "view": "conversation", "requestId": requestId])
        }
    }

    private func handlePaired(_ frame: DSHFrame) {
        guard let continuation = pendingPairing, let token = frame.string("token") else { return }
        pendingPairing = nil
        pairingTimeoutTask?.cancel()
        pairingTimeoutTask = nil
        let device = frame.dict("device")
        let gatewayId = frame.string("gatewayId") ?? device?["id"] as? String ?? UUID().uuidString
        let name = frame.string("gatewayName") ?? "DSH"
        let endpoint = task?.currentRequest?.url?.absoluteString ?? profile?.endpoint ?? ""
        let saved = DSHGatewayProfile(id: gatewayId, name: name, endpoint: endpoint, token: token)
        do {
            try DSHCredentialStore.save(saved)
            profile = saved
            gatewayName = name
            phase = .ready
            continuation.resume(returning: saved)
            send(["type": "sessions"])
        } catch {
            continuation.resume(throwing: error)
        }
    }

    /// Persistent messages only (never the streamed tokens).
    private func handleEvent(_ frame: DSHFrame) {
        guard let sid = frame.string("sessionId"), sid == openSessionId,
              let event = frame.dict("event"), let type = event["type"] as? String else { return }
        // The status line's state is folded first, before the body's own handling below; the two
        // never share a watermark, and nothing here returns early into the body's branches.
        applyActivityEvent(frame, payload: event, type: type)
        switch type {
        case "turn/start":
            turnNumber = event["turn"] as? Int
            turnStartedAt = Date()
            turnTools = []
        case "tool/call":
            let callId = event["callId"] as? String ?? UUID().uuidString
            if !turnTools.contains(where: { $0.id == callId }) {
                turnTools.append(DSHTool(id: callId,
                                         name: event["name"] as? String ?? "tool",
                                         arguments: event["arguments"] as? String ?? ""))
            }
        case "tool/result":
            guard let callId = event["callId"] as? String,
                  let index = turnTools.firstIndex(where: { $0.id == callId }) else { return }
            turnTools[index].output = event["preview"] as? String
            turnTools[index].isError = event["isError"] as? Bool ?? false
        case "assistant/message":
            let text = (event["text"] as? String) ?? Self.text(of: event)
            let reasoning = event["reasoning"] as? String ?? ""
            for raw in (event["toolCalls"] as? [[String: Any]] ?? []) {
                guard let callId = raw["id"] as? String, !turnTools.contains(where: { $0.id == callId }) else { continue }
                turnTools.append(DSHTool(id: callId,
                                         name: raw["name"] as? String ?? "tool",
                                         arguments: raw["arguments"] as? String ?? ""))
            }
            guard !text.isEmpty || !reasoning.isEmpty || !turnTools.isEmpty else { return }
            isStreaming = false
            streamingAttempts.removeAll()
            let duration = turnStartedAt.map { max(1, Int(Date().timeIntervalSince($0))) }
            upsertFinishedAssistant(text, reasoning: reasoning, tools: turnTools,
                                    turn: turnNumber, duration: duration)
            refreshSession(sid)
        case "user/message":
            let text = Self.text(of: event)
            // Skip DSH's injected sampled-time line: it is not the user's own message.
            if !text.isEmpty, !DSHSystemMessageFilter.isInjected(text), messages.last?.text != text {
                messages.append(DSHMessage(role: .user, text: text))
                rememberFirstMessage(text, for: sid)
            }
        case "turn/end":
            isStreaming = false
            turnStartedAt = nil
            turnTools = []
        default:
            break
        }
    }

    /// The opening baseline after `subscribe`: a window of recent events. Decoded exactly like a
    /// `history` page so both paths produce the same messages (thinking + tools included).
    private func handleSnapshot(_ frame: DSHFrame) {
        guard let sid = frame.string("sessionId"), sid == openSessionId else { return }
        applyActivitySnapshot(frame)
        let events = frame.array("events") ?? []
        let decoded = Self.decodeHistory(events)
        if !decoded.isEmpty, messages.isEmpty { messages = decoded }
    }

    /// One history page for the session just opened. Ignored if another session is open by now.
    private func handleHistory(_ frame: DSHFrame) {
        guard let sid = frame.string("sessionId"), sid == openSessionId else { return }
        if let requestId = frame.string("requestId"), let expected = openHistoryRequestId, requestId != expected {
            return
        }
        let events = frame.array("events") ?? []
        messages = Self.decodeHistory(events)
        if let first = messages.first(where: { $0.role == .user })?.text {
            rememberFirstMessage(first, for: sid)
        }
    }

    /// Raw host events (`{type, time, data}`) to the messages the chat page shows. `assistant/message`
    /// carries the text, the reasoning and (in history records) the tool calls; `tool/call` and
    /// `tool/result` fill in the tools and their previews.
    /// One session's first user message, kept for the rows that have no title of their own.
    private func rememberFirstMessage(_ text: String, for sessionId: String) {
        guard firstUserMessages[sessionId] == nil else { return }
        firstUserMessages[sessionId] = text
    }

    static func decodeHistory(_ events: [[String: Any]]) -> [DSHMessage] {
        var out: [DSHMessage] = []
        var tools: [DSHTool] = []
        var turn = 0
        var turnStartedAt: Int64?
        for event in events {
            let type = event["type"] as? String ?? ""
            let data = event["data"] as? [String: Any] ?? event
            let time = (event["time"] as? NSNumber)?.int64Value ?? 0
            switch type {
            case "turn/start":
                turn = (data["turn"] as? NSNumber)?.intValue ?? turn
                turnStartedAt = time
                tools = []
            case "tool/call":
                let callId = data["callId"] as? String ?? UUID().uuidString
                if !tools.contains(where: { $0.id == callId }) {
                    tools.append(DSHTool(id: callId,
                                         name: data["name"] as? String ?? "tool",
                                         arguments: data["arguments"] as? String ?? ""))
                }
            case "tool/result":
                guard let callId = data["callId"] as? String,
                      let index = tools.firstIndex(where: { $0.id == callId }) else { continue }
                tools[index].output = data["preview"] as? String
                tools[index].isError = data["isError"] as? Bool ?? false
            case "user/message":
                let text = Self.text(of: data)
                if !text.isEmpty, !DSHSystemMessageFilter.isInjected(text) {
                    out.append(DSHMessage(role: .user, text: text, createdAt: time))
                }
            case "assistant/message":
                let message = data["message"] as? [String: Any]
                var text = ""
                var reasoning = ""
                for block in (message?["content"] as? [[String: Any]] ?? []) {
                    switch block["type"] as? String {
                    case "text": text += block["text"] as? String ?? ""
                    case "reasoning": reasoning += block["text"] as? String ?? ""
                    default: break
                    }
                }
                if text.isEmpty, reasoning.isEmpty, tools.isEmpty { continue }
                let duration = turnStartedAt.map { max(1, Int((time - $0) / 1000)) }
                out.append(DSHMessage(role: .assistant, text: text, reasoning: reasoning,
                                      tools: tools, turn: turn, durationSeconds: duration,
                                      createdAt: time))
                tools = []
            case "turn/end":
                tools = []
                turnStartedAt = nil
            default:
                break
            }
        }
        return out
    }

    private func handleStream(_ frame: DSHFrame) {
        guard frame.string("sessionId") == openSessionId, let payload = frame.dict("frame") else { return }
        applyActivityStream(frame, payload: payload)
        switch payload["type"] as? String {
        case "start":
            if let attempt = payload["attemptId"] as? String { streamingAttempts.insert(attempt) }
            isStreaming = true
            if messages.last?.streaming != true {
                messages.append(DSHMessage(role: .assistant, text: "", streaming: true))
            }
        case "chunk":
            guard let attempt = payload["attemptId"] as? String, streamingAttempts.contains(attempt) else { return }
            guard let text = Self.text(ofChunk: payload), !text.isEmpty else { return }
            appendStreaming(text)
        case "end":
            if let attempt = payload["attemptId"] as? String { streamingAttempts.remove(attempt) }
            if streamingAttempts.isEmpty {
                isStreaming = false
                finalizeStreaming()
            }
        default:
            break
        }
    }

    // MARK: - Current activity (the status line's state)

    /// The subscription is confirmed: a new generation. No stream is known until a snapshot names
    /// one, and nothing from the previous subscription survives.
    private func handleSubscribed(_ frame: DSHFrame) {
        guard let sid = frame.string("sessionId"), sid == openSessionId,
              let subscriptionId = frame.string("subscriptionId") else { return }
        activity.applySubscribed(subscriptionId: subscriptionId, streamId: frame.string("streamId"))
        syncActivity()
    }

    /// `{sessionId, running}`: process metadata with no persistent seq, so only a hint.
    private func handleSessionStatus(_ frame: DSHFrame) {
        guard let sid = frame.string("sessionId"), sid == openSessionId,
              let running = frame.bool("running") else { return }
        activity.applySessionStatus(running: running)
        syncActivity()
    }

    /// `sessions[].running` for the open conversation: a fallback for when no baseline has arrived
    /// yet, so a turn already under way is not silently blank until the snapshot lands.
    private func applySessionsHint() {
        guard let sessionId = openSessionId,
              let row = sessions.first(where: { $0.id == sessionId }) else { return }
        activity.applySessionsHint(running: row.running)
        syncActivity()
    }

    /// One persistent event: the status line's state, folded before the body's own handling.
    private func applyActivityEvent(_ frame: DSHFrame, payload: [String: Any], type: String) {
        let event = Self.activityEvent(type: type, from: payload, seq: frame.int("seq"))
        if activity.apply(event, in: activityEnvelope(frame)) { syncActivity() }
    }

    /// One temporary attempt frame. Its `revision`/`index` clock is checked here and never mixed
    /// with the persistent `seq`.
    private func applyActivityStream(_ frame: DSHFrame, payload: [String: Any]) {
        let chunk = payload["chunk"] as? [String: Any]
        let input = DSHActivityFrame(
            type: payload["type"] as? String ?? "",
            attemptId: payload["attemptId"] as? String,
            revision: (payload["revision"] as? NSNumber)?.intValue,
            turn: (payload["turn"] as? NSNumber)?.intValue,
            step: (payload["step"] as? NSNumber)?.intValue,
            index: (payload["index"] as? NSNumber)?.intValue,
            chunkType: chunk?["type"] as? String)
        if activity.apply(input, in: activityEnvelope(frame)) { syncActivity() }
    }

    /// The server's atomic baseline: identity, watermark, a window of events and any attempt still
    /// being written.
    private func applyActivitySnapshot(_ frame: DSHFrame) {
        let events = (frame.array("events") ?? []).compactMap { record -> DSHActivityEvent? in
            guard let type = record["type"] as? String else { return nil }
            // History/snapshot records wrap the payload in `data`; live events carry it at the top.
            let payload = record["data"] as? [String: Any] ?? record
            return Self.activityEvent(type: type, from: payload,
                                      seq: (record["seq"] as? NSNumber)?.intValue)
        }
        let assistantStream = frame.dict("assistantStream")
        var attempt: DSHActivityAttempt?
        if let active = assistantStream?["activeAttempt"] as? [String: Any],
           let attemptId = active["attemptId"] as? String {
            attempt = DSHActivityAttempt(
                attemptId: attemptId,
                turn: (active["turn"] as? NSNumber)?.intValue,
                step: (active["step"] as? NSNumber)?.intValue,
                nextIndex: (active["nextIndex"] as? NSNumber)?.intValue,
                revision: (assistantStream?["revision"] as? NSNumber)?.intValue,
                lastDeltaType: Self.lastDeltaType(in: active["stream"]))
        }
        let snapshot = DSHActivitySnapshot(
            subscriptionId: frame.string("subscriptionId"),
            streamId: frame.string("streamId"),
            replace: frame.bool("replace") ?? false,
            cursor: frame.int("cursor"),
            hasMore: frame.bool("hasMore") ?? false,
            events: events,
            attempt: attempt)
        activity.applySnapshot(snapshot, runningHint: openSessionId.flatMap { id in
            sessions.first(where: { $0.id == id })?.running
        })
        syncActivity()
    }

    /// Mirrors the reducer onto the two published values the page reads.
    private func syncActivity() {
        let kind = activity.activity
        if currentActivity != kind { currentActivity = kind }
        if isRunning != activity.running { isRunning = activity.running }
    }

    private func activityEnvelope(_ frame: DSHFrame) -> DSHActivityEnvelope {
        DSHActivityEnvelope(sessionId: frame.string("sessionId"),
                            subscriptionId: frame.string("subscriptionId"),
                            streamId: frame.string("streamId"))
    }

    /// One event, reduced to what the activity needs. A history `tool/result` carries its id in
    /// `message.toolCallId` (or `source.callId`), a live one in `callId`.
    static func activityEvent(type: String, from payload: [String: Any], seq: Int?) -> DSHActivityEvent {
        let message = payload["message"] as? [String: Any]
        let source = payload["source"] as? [String: Any]
        return DSHActivityEvent(
            type: type,
            turn: (payload["turn"] as? NSNumber)?.intValue,
            step: (payload["step"] as? NSNumber)?.intValue,
            callId: payload["callId"] as? String
                ?? message?["toolCallId"] as? String
                ?? source?["callId"] as? String,
            toolName: payload["name"] as? String,
            arguments: argumentsText(payload["arguments"]),
            seq: seq)
    }

    /// A tool call's `arguments` are JSON and not guaranteed to be a string: keep a structured
    /// payload as JSON text instead of dropping the call the way `as? String` would.
    static func argumentsText(_ raw: Any?) -> String? {
        switch raw {
        case nil, is NSNull:
            return nil
        case let text as String:
            return text
        case let number as NSNumber:
            return number.stringValue
        default:
            guard let value = raw, JSONSerialization.isValidJSONObject(value),
                  let data = try? JSONSerialization.data(withJSONObject: value) else { return nil }
            return String(data: data, encoding: .utf8)
        }
    }

    /// The compact records a baseline's attempt stream is made of (`text-chunks`,
    /// `reasoning-chunks`, raw `chunk`): what it was last emitting, so the phrase can be restored.
    static func lastDeltaType(in raw: Any?) -> String? {
        guard let records = raw as? [[String: Any]] else { return nil }
        var last: String?
        for record in records {
            switch record["type"] as? String {
            case "text-chunks": last = "text-delta"
            case "reasoning-chunks": last = "reasoning-delta"
            case "chunk":
                if let chunk = record["chunk"] as? [String: Any], let type = chunk["type"] as? String {
                    last = type
                }
            default:
                break
            }
        }
        return last
    }

    // MARK: - Conversation

    public func open(sessionId: String) {
        openSessionId = sessionId
        messages = []
        isStreaming = false
        streamingAttempts.removeAll()
        activity.beginSession(sessionId)
        syncActivity()
        send(["type": "subscribe", "sessionId": sessionId, "assistantStream": true])
        // One page of history for this session, so the transcript is not empty when it opens
        // (the live snapshot only covers what happens after subscribing).
        let requestId = "open-history-\(sessionId)"
        openHistoryRequestId = requestId
        send(["type": "history", "sessionId": sessionId, "maxMessages": 30, "maxBytes": 262_144,
              "view": "conversation", "requestId": requestId])
    }

    public func closeConversation() {
        if let openSessionId { send(["type": "unsubscribe"]) }
        openSessionId = nil
        openHistoryRequestId = nil
        messages = []
        isStreaming = false
        activity.endSession()
        syncActivity()
    }

    public func send(text: String) {
        let trimmed = text.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !trimmed.isEmpty else { return }
        guard let sessionId = openSessionId else { return }
        messages.append(DSHMessage(role: .user, text: trimmed))
        send(["type": "message", "sessionId": sessionId, "text": trimmed])
    }

    public func newSession() {
        send(["type": "session-create", "requestId": UUID().uuidString])
    }

    // MARK: - Helpers

    private func appendStreaming(_ text: String) {
        if let index = messages.lastIndex(where: { $0.streaming }) {
            messages[index].text += text
        } else {
            messages.append(DSHMessage(role: .assistant, text: text, streaming: true))
        }
    }

    private func finalizeStreaming() {
        guard let index = messages.lastIndex(where: { $0.streaming }) else { return }
        if messages[index].text.isEmpty { messages.remove(at: index) }
        else { messages[index].streaming = false }
    }

    /// The stream usually commits as an `assistant/message`; replace the temporary bubble with it.
    private func upsertFinishedAssistant(_ text: String, reasoning: String, tools: [DSHTool],
                                         turn: Int?, duration: Int?) {
        if let index = messages.lastIndex(where: { $0.role == .assistant }) {
            messages[index].text = text
            messages[index].streaming = false
            messages[index].reasoning = reasoning
            messages[index].tools = tools
            messages[index].turn = turn
            messages[index].durationSeconds = duration
        } else {
            messages.append(DSHMessage(role: .assistant, text: text, reasoning: reasoning,
                                       tools: tools, turn: turn, durationSeconds: duration))
        }
    }

    private func refreshSession(_ sessionId: String) {
        send(["type": "sessions"])
    }

    /// What a session is called: its own title, or — when the gateway hasn't named it yet — the
    /// first 16 characters of the first thing the reader said in it.
    public func displayTitle(for session: DSHSession) -> String {
        let titled = session.title.trimmingCharacters(in: .whitespacesAndNewlines)
        if !titled.isEmpty, titled != "未命名会话" { return titled }
        if let first = firstUserMessages[session.id] {
            let trimmed = first.trimmingCharacters(in: .whitespacesAndNewlines)
            if !trimmed.isEmpty { return String(trimmed.prefix(16)) }
        }
        return L10nSessionFallback.title
    }

    // MARK: - Session previews

    /// `projection-baseline` (sent on connect) and `turn-outline-updated` carry each session's
    /// turn outline, whose last response is the row's subtitle. No extra round trips.
    private func handleProjectionBaseline(_ frame: DSHFrame) {
        guard let projections = frame.dict("projections") else { return }
        for (sessionId, raw) in projections {
            guard let entry = raw as? [String: Any],
                  let values = entry["values"] as? [String: Any] else { continue }
            applyTurnOutline(values["turnOutline"], sessionId: sessionId)
        }
    }

    private func handleTurnOutline(_ frame: DSHFrame) {
        guard let sessionId = frame.string("sessionId") else { return }
        applyTurnOutline(frame.json["turnOutline"], sessionId: sessionId)
    }

    private func applyTurnOutline(_ raw: Any?, sessionId: String) {
        guard let outline = raw as? [[String: Any]], let last = outline.last else { return }
        let response = (last["response"] as? String)?.trimmingCharacters(in: .whitespacesAndNewlines) ?? ""
        let prompt = (last["prompt"] as? String)?.trimmingCharacters(in: .whitespacesAndNewlines) ?? ""
        let text = response.isEmpty ? prompt : response
        guard !text.isEmpty else { return }
        previews[sessionId] = Self.compactPreview(text)
    }

    static func compactPreview(_ text: String, limit: Int = 120) -> String {
        let oneLine = text.split(whereSeparator: \.isNewline)
            .map { $0.trimmingCharacters(in: .whitespaces) }
            .filter { !$0.isEmpty }
            .joined(separator: " ")
        return oneLine.count > limit ? String(oneLine.prefix(limit)) + "…" : oneLine
    }

    /// Keeps the socket alive through idle proxies/tunnels (the gateway answers `ping` with `pong`).
    private func startHeartbeat() {
        heartbeatTask?.cancel()
        heartbeatTask = Task { [weak self] in
            while !Task.isCancelled {
                try? await Task.sleep(nanoseconds: 20 * 1_000_000_000)
                guard !Task.isCancelled, let self else { return }
                self.send(["type": "ping"])
            }
        }
    }

    private func handleDrop(_ error: Error) {
        let message = error.localizedDescription
        let ns = error as NSError
        // URLSession does not expose the WebSocket close code; the domain/code and message are
        // the closest thing, and they are what a bug report needs.
        log.error("DSH socket dropped: \(ns.domain, privacy: .public)/\(ns.code) \(message, privacy: .public)")
        heartbeatTask?.cancel()
        heartbeatTask = nil
        if pendingPairing != nil {
            pendingPairing?.resume(throwing: DSHError.transport(message))
            pendingPairing = nil
            pairingTimeoutTask?.cancel()
            pairingTimeoutTask = nil
        }
        phase = .failed(message)
        // A dropped socket must not leave the status line claiming that a tool is still running.
        activity.endSession()
        syncActivity()
        scheduleReconnect()
    }

    private func scheduleReconnect() {
        guard shouldReconnect, profile != nil else { return }
        reconnectAttempt = min(reconnectAttempt + 1, 6)
        let delay = min(pow(2.0, Double(reconnectAttempt)), 30)
        log.notice("DSH reconnecting in \(delay, privacy: .public)s (attempt \(self.reconnectAttempt, privacy: .public))")
        reconnectTask?.cancel()
        reconnectTask = Task { [weak self] in
            try? await Task.sleep(nanoseconds: UInt64(delay * 1_000_000_000))
            await MainActor.run {
                guard let self, self.shouldReconnect, let profile = self.profile else { return }
                self.phase = .connecting
                self.openSocket(profile: profile, authorization: profile.token, pairing: nil)
            }
        }
    }

    private func requirePairingAgain() {
        shouldReconnect = false
        heartbeatTask?.cancel()
        heartbeatTask = nil
        phase = .failed(DSHError.authenticationRequired.localizedDescription)
        if let id = profile?.id { DSHCredentialStore.delete(id: id) }
        profile = nil
        activity.endSession()
        syncActivity()
    }

    private func fail(_ error: Error) {
        phase = .failed(error.localizedDescription)
        activity.endSession()
        syncActivity()
    }

    // MARK: - Decoding helpers

    private static func decodeSessions(_ frame: DSHFrame) -> [DSHSession] {
        // The gateway sends `{kind:"sessions", items:[{sessionId, updatedAt, running, blank,
        // projections:{values:{title}}}]}`.
        let rows = frame.array("items") ?? frame.array("sessions") ?? []
        return rows.compactMap { row in
            guard let id = row["sessionId"] as? String ?? row["id"] as? String else { return nil }
            if row["blank"] as? Bool == true { return nil }
            var title: String?
            if let projections = row["projections"] as? [String: Any],
               let values = projections["values"] as? [String: Any],
               let projected = values["title"] as? String {
                title = projected
            }
            title = title ?? row["title"] as? String
            let trimmed = title?.trimmingCharacters(in: .whitespacesAndNewlines) ?? ""
            return DSHSession(
                id: id,
                title: trimmed.isEmpty ? "未命名会话" : trimmed,
                running: row["running"] as? Bool ?? false,
                workspaceId: row["workspaceId"] as? String,
                updatedAt: (row["updatedAt"] as? NSNumber)?.doubleValue
            )
        }
        .sorted { ($0.updatedAt ?? 0) > ($1.updatedAt ?? 0) }
    }

    /// Text of a message/content payload: `{content:[{type:"text",text}]}` or a plain string.
    static func text(of object: [String: Any]) -> String {
        if let content = object["content"] as? [[String: Any]] {
            return content.compactMap { block in
                (block["type"] as? String) == "text" ? block["text"] as? String : nil
            }.joined()
        }
        if let content = object["content"] as? String { return content }
        return object["text"] as? String ?? ""
    }

    static func text(ofChunk payload: [String: Any]) -> String? {
        if let chunk = payload["chunk"] as? [String: Any] {
            if (chunk["type"] as? String) == "text-delta" { return chunk["text"] as? String ?? chunk["textDelta"] as? String }
            return chunk["text"] as? String
        }
        return payload["text"] as? String
    }
}

/// The name an unnamed, unstarted session gets.
private enum L10nSessionFallback {
    static let title = "未命名会话"
}
