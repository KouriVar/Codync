import CryptoKit
import Foundation
import os
import Network

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
    @Published public private(set) var currentActivity: DSHActivityDetail?
    /// Whether the open conversation has a turn under way.
    @Published public private(set) var isRunning = false
    /// What the gateway said it can do in its `hello`. Replaced on every hello and cleared when the
    /// connection retires, so a picture is never sent to a gateway that never offered `images`.
    @Published public private(set) var capabilities: [String] = []

    /// A gateway that did not announce `images` must not be sent one.
    public var supportsImages: Bool { capabilities.contains("images") }

    /// The command/skill catalogue from the last `commands` reply (empty until loaded).
    @Published public private(set) var commandGroups: [DSHCommandGroup] = []
    /// A gateway that did not announce `commands` shows no command menu.
    public var supportsCommands: Bool { capabilities.contains("commands") }
    /// A gateway that did not announce `file-upload-v1` cannot take file attachments.
    public var supportsFileUpload: Bool { capabilities.contains("file-upload-v1") }

    /// Files being uploaded (or ready to send), shown as cards above the input.
    @Published public private(set) var fileUploads: [DSHFileUpload] = []

    // Session controls for the model sheet.
    @Published public private(set) var modelGroups: [DSHModelGroup] = []
    @Published public private(set) var currentModel: DSHCurrentModel?
    @Published public private(set) var agentPresets: [DSHAgentPreset] = []
    @Published public private(set) var agentPresetSelected: String?
    @Published public private(set) var agentPresetLocked = false
    @Published public private(set) var permissionOptions: [DSHPermissionOption] = []
    public var supportsAgentPreset: Bool { capabilities.contains("session-agent-preset") }

    // In-session panels.
    @Published public private(set) var goal: DSHGoal?
    @Published public private(set) var todos: [DSHTodo] = []
    public var supportsGoals: Bool { capabilities.contains("goals") }
    public var supportsTasks: Bool { capabilities.contains("tasks") }

    // Cards that replace the input while a tool needs approval or the user is asked a question.
    @Published public private(set) var pendingApproval: DSHApprovalRequest?
    /// The open session's turn outline (turn-outline-v1), for the read-only turn navigator.
    @Published public private(set) var turnOutline: [DSHTurnOutline] = []
    public var supportsTurnOutline: Bool { capabilities.contains("turn-outline-v1") }
    @Published public private(set) var pendingQuestion: DSHQuestionRequest?

    /// The single outstanding request/reply (commands, options, …). The UI serialises them.
    private var commandAwaiter: CheckedContinuation<DSHFrame, Never>?
    private static let requestKinds: Set<String> = [
        "commands", "command-executed", "command-options", "command-selected",
        "file-upload-opened", "file-upload-chunk-accepted", "file-upload-completed", "file-upload-cancelled",
        "models", "select-model", "agent-presets", "session-agent-preset", "select-agent-preset",
        "permission-options", "permission", "save-default-model",
        "context-usage", "session-stats", "fork", "session-renamed", "session-archived",
        "file-list", "file-download-opened", "file-download-chunk", "file-download-cancelled",
        "schedule-list", "schedule-delete", "agent-team", "subagents",
        "goal", "goal-edit", "goal-pause", "goal-resume", "goal-clear", "tasks",
    ]

    public private(set) var profile: DSHGatewayProfile?

    private var task: URLSessionWebSocketTask?
    private let session: URLSession
    private var reconnectAttempt = 0
    private var reconnectTask: Task<Void, Never>?
    private var heartbeatTask: Task<Void, Never>?
    private var shouldReconnect = false
    @Published public private(set) var hasMore = false
    @Published public private(set) var loadingEarlier = false
    @Published public private(set) var historyError: String?
    @Published public private(set) var submissions: [DSHSubmission] = []
    @Published public private(set) var queueHints: [DSHQueueHint] = []
    /// The open session's queued messages (running turn), shown above the input with edit/remove/steer.
    @Published public private(set) var queuedMessages: [DSHQueueHint] = []
    @Published public private(set) var queueIsKnown = false
    private var gatewayQueues: [String: [DSHQueueHint]] = [:]
    private var hasQueueBaseline = false
    private var conversations: [DSHSessionScope: DSHConversationState] = [:]
    private var selectedScope: DSHSessionScope?
    private var conversation: DSHConversationState? {
        get { selectedScope.flatMap { conversations[$0] } }
        set { if let scope = selectedScope { conversations[scope] = newValue } }
    }
    private var connectionGeneration: UInt64 = 0
    private var selectionGeneration: UInt64 = 0
    private var validatedGatewayId: String?
    private var inFlightSubscription: (sessionId: String?, generation: UInt64)?
    private var operationTimeouts: [String: Task<Void, Never>] = [:]
    private var historyOutcomes: [String: Bool] = [:]
    private var creationRequests: [String: UInt64] = [:]
    private let networkMonitor = NWPathMonitor()
    private var networkAvailable = true

    /// The running-turn state behind the status line. Its own generation, seq watermark and attempt
    /// bookkeeping; it never touches `messages` or the body's own handling.
    private var activity = DSHActivityState()

    private var pendingPairing: CheckedContinuation<DSHGatewayProfile, Error>?
    private var pairingTimeoutTask: Task<Void, Never>?

    /// Pictures by (gatewayId, sessionId, attachmentId), in memory only: a picture is never written to
    /// disk, and reopening a conversation fetches it again. Bounded so a long scroll cannot grow it
    /// without end.
    private var imageCache: [DSHAttachmentKey: Data] = [:]
    private var imageCacheOrder: [DSHAttachmentKey] = []
    private var imageCacheBytes = 0
    /// Callers waiting for one picture, resumed once its frame arrives or the wait times out.
    private var imageWaiters: [DSHAttachmentKey: [CheckedContinuation<Data?, Never>]] = [:]
    /// Requests on the wire. Only a few run at once; the rest wait here.
    private var imageInFlight: Set<DSHAttachmentKey> = []
    private var imageQueue: [DSHAttachmentKey] = []
    private static let imageConcurrency = 3
    private static let imageCacheLimit = 32 * 1024 * 1024
    private static let imageCacheCount = 24

    /// One connection shared by the home list and Settings, so pairing (or disconnect) in one place
    /// drives the other. The home owns whether it connects; Settings only shows its state.
    public static let shared = DSHGateway()

    public init() {
        let config = URLSessionConfiguration.default
        config.waitsForConnectivity = false
        config.timeoutIntervalForRequest = 30
        session = URLSession(configuration: config)
        networkMonitor.pathUpdateHandler = { [weak self] path in
            Task { @MainActor in self?.networkAvailable = path.status == .satisfied }
        }
        networkMonitor.start(queue: DispatchQueue(label: "com.suiyikou.codync.dsh-network"))
    }

    deinit { networkMonitor.cancel() }

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
        if self.profile?.id != profile.id { closeConversation() }
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
        retireConnection()
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
        retireConnection()
        let socket = session.webSocketTask(with: request)
        socket.maximumMessageSize = 64 * 1024 * 1024
        task = socket
        if pairing == nil { phase = .connecting }
        socket.resume()
        receiveLoop(on: socket)
        if pairing == nil {
            startHeartbeat()
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

    @discardableResult
    private func send(_ object: [String: Any], completion: ((Error?) -> Void)? = nil) -> Bool {
        guard let socket = task, let data = try? JSONSerialization.data(withJSONObject: object),
              let text = String(data: data, encoding: .utf8) else { return false }
        let generation = connectionGeneration
        socket.send(.string(text)) { [weak self] error in
            Task { @MainActor in
                guard let self, socket === self.task, generation == self.connectionGeneration else { return }
                if let completion { completion(error) }
                else if let error { log.error("DSH control frame send failed: \(error.localizedDescription, privacy: .public)") }
            }
        }
        return true
    }

    // MARK: - Frames

    private func handleFrame(_ text: String) {
        guard let data = text.data(using: .utf8),
              let object = try? JSONSerialization.jsonObject(with: data) as? [String: Any],
              let kind = object["kind"] as? String else { return }
        let frame = DSHFrame(kind: kind, json: object)

        // A pending request/reply (commands, options, …): hand it its frame before the event switch.
        if Self.requestKinds.contains(kind) || (kind == "error" && commandAwaiter != nil) {
            resolveCommandAwaiter(frame)
        }

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
        case "approval-requested":
            guard frame.string("sessionId") == openSessionId else { return }
            pendingApproval = Self.decodeApproval(frame)
        case "approval-resolved":
            guard frame.string("sessionId") == openSessionId else { return }
            if pendingApproval?.approvalId == frame.string("approvalId") { pendingApproval = nil }
        case "question-requested":
            guard frame.string("sessionId") == openSessionId else { return }
            pendingQuestion = Self.decodeQuestion(frame)
        case "question-resolved":
            guard frame.string("sessionId") == openSessionId else { return }
            pendingQuestion = nil
        case "goal-updated":
            guard frame.string("sessionId") == openSessionId else { return }
            goal = Self.decodeGoal(frame.json["goal"])
        case "tasks-updated":
            guard frame.string("sessionId") == openSessionId else { return }
            todos = Self.decodeTodos(frame.json["todos"])
        case "session-agent-preset-updated":
            // The gateway pushes the lock (and any preset change) when a turn starts.
            guard frame.string("sessionId") == openSessionId else { return }
            if let locked = frame.bool("locked") { agentPresetLocked = locked }
            if let preset = frame.string("agentPreset") { agentPresetSelected = preset }
        case "history":
            handleHistory(frame)
        case "projection-baseline":
            handleProjectionBaseline(frame)
        case "turn-outline-updated":
            handleTurnOutline(frame)
        case "session-queues":
            guard validatedGatewayId != nil, let queues = frame.dict("queues") as? [String: [[String: Any]]] else { return }
            gatewayQueues = queues.mapValues(DSHQueueHint.decode)
            queuedMessages = openSessionId.flatMap { queues[$0].map(DSHQueueHint.decode) } ?? []
            hasQueueBaseline = true
            publishConversation()
        case "session-queue":
            guard validatedGatewayId != nil, let sid = frame.string("sessionId"), let rows = frame.array("items") else { return }
            gatewayQueues[sid] = DSHQueueHint.decode(rows)
            if sid == openSessionId { queuedMessages = DSHQueueHint.decode(rows) }
            publishConversation()
        case "queue-item-updated":
            break
        case "sent":
            if let id = frame.string("requestId") { updateDelivery(id, status: .accepted, detail: "已接收") }
            reconnectAttempt = 0
        case "attachment":
            handleAttachment(frame)
        case "session-created":
            if let request = frame.string("requestId"), creationRequests.removeValue(forKey: request) == selectionGeneration,
               let id = frame.string("sessionId") { open(sessionId: id) }
        case "event":
            handleEvent(frame)
        case "assistant-stream":
            handleStream(frame)
        case "session-snapshot":
            handleSnapshot(frame)
        case "session-stream-reset":
            guard conversation?.owns(frame) == true else { return }
            conversation?.resetStream()
            activity.applyStreamReset(in: activityEnvelope(frame))
            syncActivity(); publishConversation()
            if frame.bool("retrying") == false { historyError = frame.string("message") ?? "会话暂时不能同步" }
        case "error":
            handleProtocolError(frame)
        default:
            break
        }
    }

    private func handleHello(_ frame: DSHFrame) {
        let version = frame.int("protocolVersion") ?? frame.int("protocol") ?? 0
        guard version >= 3, frame.int("historyFormatVersion") == 4,
              let gatewayId = frame.string("gatewayId"), !gatewayId.isEmpty,
              profile == nil || profile?.id == gatewayId else {
            pendingPairing?.resume(throwing: DSHError.transport("网关身份或历史格式不匹配，请重新配对。"))
            pendingPairing = nil
            shouldReconnect = false
            task?.cancel(with: .policyViolation, reason: nil)
            task = nil
            retireConnection()
            fail(DSHError.transport("网关身份或历史格式不匹配，请重新配对。"))
            return
        }
        validatedGatewayId = gatewayId
        if let name = frame.string("gatewayName"), !name.isEmpty { gatewayName = name }
        // The gateway's own claim about what it accepts; a picture is gated on it, never assumed.
        capabilities = (frame.json["capabilities"] as? [String]) ?? []
        reconnectAttempt = 0
        if pendingPairing == nil { phase = .ready }
        send(["type": "sessions"])
        if let sessionId = openSessionId {
            selectScope(gatewayId: gatewayId, sessionId: sessionId)
            activity.beginSession(sessionId)
            requestSubscription()
        }
    }

    private func handlePaired(_ frame: DSHFrame) {
        guard let continuation = pendingPairing, let token = frame.string("token") else { return }
        pendingPairing = nil
        pairingTimeoutTask?.cancel()
        pairingTimeoutTask = nil
        guard let gatewayId = frame.string("gatewayId"), !gatewayId.isEmpty else {
            continuation.resume(throwing: DSHError.transport("网关没有提供稳定身份，请更新网关后重新配对。"))
            return
        }
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

    private func handleEvent(_ frame: DSHFrame) {
        guard conversation?.owns(frame) == true, let event = DSHWireEvent.live(frame) else { return }
        guard conversation?.event(event) == true else { resubscribe(); return }
        // Both projections pass the very same session/subscription/stream gate, and the status line
        // reads the same parsed event as the transcript: one callId, one tool name, one argument.
        applyActivityEvent(frame, event: event)
        if event.isUser, !event.text.isEmpty, let sid = openSessionId { rememberFirstMessage(event.text, for: sid) }
        if event.type == "assistant/message" { send(["type": "sessions"]) }
        publishConversation()
    }

    private func handleSnapshot(_ frame: DSHFrame) {
        guard frame.string("sessionId") == openSessionId,
              frame.string("subscriptionId") == conversation?.subscriptionId,
              let scope = selectedScope, let snapshot = DSHWireSnapshot(frame, format: scope.format) else { return }
        if conversation?.hasBaseline == true {
            if conversation?.streamId != snapshot.streamId { resubscribe() }
            return
        }
        guard conversation?.snapshot(snapshot) == true else { resubscribe(); return }
        operationTimeouts.removeValue(forKey: "snapshot")?.cancel()
        applyActivitySnapshot(frame)
        publishConversation()
    }

    private func handleHistory(_ frame: DSHFrame) {
        guard let id = frame.string("requestId"), let request = conversation?.requests[id],
              request.generation == selectionGeneration, frame.string("sessionId") == openSessionId else { return }
        let accepted = conversation?.history(frame, generation: selectionGeneration) == true
        historyOutcomes[id] = accepted
        operationTimeouts.removeValue(forKey: id)?.cancel()
        publishConversation()
        if conversation?.needsBaseline == true { historyOutcomes[id] = false; resubscribe() }
        else if !accepted, frame.int("historyFormatVersion") != selectedScope?.format { resubscribe() }
    }

    private func handleStream(_ frame: DSHFrame) {
        guard conversation?.owns(frame) == true, let payload = frame.dict("frame") else { return }
        guard conversation?.stream(DSHJSON(payload)) == true else { resubscribe(); return }
        applyActivityStream(frame, payload: payload)
        publishConversation()
    }

    private func rememberFirstMessage(_ text: String, for sessionId: String) {
        guard firstUserMessages[sessionId] == nil else { return }
        firstUserMessages[sessionId] = text
    }

    // MARK: - Current activity (the status line's state)

    /// The subscription is confirmed: a new generation. No stream is known until a snapshot names
    /// one, and nothing from the previous subscription survives.
    private func handleSubscribed(_ frame: DSHFrame) {
        guard let pending = inFlightSubscription, frame.string("sessionId") == pending.sessionId else { return }
        inFlightSubscription = nil
        operationTimeouts.removeValue(forKey: "subscribe")?.cancel()
        guard pending.generation == selectionGeneration, pending.sessionId == openSessionId else {
            requestSubscription(); return
        }
        guard let subscriptionId = frame.string("subscriptionId"), openSessionId != nil else { return }
        conversation?.subscribed(subscriptionId)
        activity.applySubscribed(subscriptionId: subscriptionId)
        scheduleTimeout("snapshot", seconds: 15) { [weak self] in
            self?.handleDrop(DSHError.transport("等待会话快照超时"))
        }
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

    /// One persistent event: the status line's state, folded before the body's own handling. It is fed
    /// the structured event only — never a notice the transcript generated — so the tool whitelist and
    /// the running state can't be driven by an invented message.
    private func applyActivityEvent(_ frame: DSHFrame, event: DSHWireEvent) {
        let input = DSHActivityEvent(type: event.type, turn: event.turn, step: event.step,
                                     callId: event.callId, toolName: event.toolName,
                                     toolArgument: event.toolArgument, seq: Int(event.seq))
        if activity.apply(input, in: activityEnvelope(frame)) { syncActivity() }
    }

    /// One temporary attempt frame. Its `revision`/`index` clock is checked here and never mixed
    /// with the persistent `seq`.
    private func applyActivityStream(_ frame: DSHFrame, payload: [String: Any]) {
        let chunk = payload["chunk"] as? [String: Any]
        let chunkType = chunk?["type"] as? String
        let input = DSHActivityFrame(
            type: payload["type"] as? String ?? "",
            attemptId: payload["attemptId"] as? String,
            revision: (payload["revision"] as? NSNumber)?.intValue,
            turn: (payload["turn"] as? NSNumber)?.intValue,
            step: (payload["step"] as? NSNumber)?.intValue,
            index: (payload["index"] as? NSNumber)?.intValue,
            chunkType: chunkType,
            text: chunkType == "reasoning-delta"
                ? (chunk?["text"] as? String ?? chunk?["textDelta"] as? String) : nil)
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
        let detail = activity.activity
        if currentActivity != detail { currentActivity = detail }
        if isRunning != activity.running { isRunning = activity.running }
    }

    private func activityEnvelope(_ frame: DSHFrame) -> DSHActivityEnvelope {
        DSHActivityEnvelope(sessionId: frame.string("sessionId"),
                            subscriptionId: frame.string("subscriptionId"),
                            streamId: frame.string("streamId"))
    }

    /// One event, reduced to what the activity needs. A history `tool/result` carries its id in
    /// `message.toolCallId` (or `source.callId`), a live one in `callId`. Both this path and the live
    /// path read `DSHWireEvent`, so a call is named the same way in both.
    static func activityEvent(type: String, from payload: [String: Any], seq: Int?) -> DSHActivityEvent {
        let value = DSHJSON(payload)
        let name = DSHWireEvent.toolName(in: value)
        return DSHActivityEvent(
            type: type,
            turn: value["turn"].integer.map(Int.init),
            step: value["step"].integer.map(Int.init),
            callId: DSHWireEvent.callId(in: value, history: true),
            toolName: name,
            toolArgument: DSHWireEvent.toolArgument(DSHWireEvent.toolArguments(in: value), toolName: name),
            seq: seq)
    }

    /// The one argument the status line can name: a file's path or the command line. `arguments` is
    /// JSON and not guaranteed to be a string, so it is read as an object (a JSON string is parsed
    /// too). Which key matters depends on the tool's own kind; nothing else is read from it.
    static func toolArgument(_ raw: Any?, toolName: String?) -> String? {
        DSHWireEvent.toolArgument(DSHJSON(raw ?? NSNull()), toolName: toolName)
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
        selectionGeneration &+= 1
        conversation?.retireStream()
        openSessionId = sessionId
        if let gatewayId = validatedGatewayId { selectScope(gatewayId: gatewayId, sessionId: sessionId) }
        else { selectedScope = nil }
        activity.beginSession(sessionId)
        syncActivity(); publishConversation()
        requestSubscription()
    }

    public func closeConversation() {
        selectionGeneration &+= 1
        conversation?.retireStream()
        openSessionId = nil; selectedScope = nil
        activity.endSession()
        syncActivity(); publishConversation()
        requestSubscription()
    }

    /// Returns whether the local intent was saved; only then may the caller clear its draft. Pictures
    /// may go alone, with no text. A gateway that never offered `images` is refused, and a message over
    /// the local frame budget is refused rather than split.
    @discardableResult public func send(text: String, images: [DSHOutgoingImage] = [],
                                        files: [DSHOutgoingFile] = []) -> Bool {
        let trimmed = text.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !trimmed.isEmpty || !images.isEmpty || !files.isEmpty,
              openSessionId != nil, conversation != nil else { return false }
        guard images.isEmpty || supportsImages else { return false }
        guard files.isEmpty || supportsFileUpload else { return false }
        guard imageSendProblem(text: trimmed, images: images) == nil else { return false }
        let available = phase == .ready && task != nil && networkAvailable && validatedGatewayId != nil
        guard let id = conversation?.submit(text: trimmed, images: images, files: files,
                                            connection: connectionGeneration,
                                            available: available) else { return false }
        publishConversation()
        guard available else { return true }
        var payload: [String: Any] = ["type": "message", "sessionId": openSessionId!, "requestId": id]
        if !trimmed.isEmpty { payload["text"] = trimmed }
        if !images.isEmpty {
            payload["images"] = images.map {
                ["mediaType": $0.mediaType, "name": $0.name, "data": $0.data.base64EncodedString()]
            }
        }
        if !files.isEmpty {
            payload["files"] = files.map { ["receiptId": $0.receiptId] }
        }
        if !send(payload, completion: { [weak self] error in
            if let error { self?.updateDelivery(id, status: .unknown, detail: "送达待核对：" + error.localizedDescription) }
        }) {
            updateDelivery(id, status: .failed, detail: "没有发出去：无法编码发送内容")
            return true
        }
        scheduleTimeout(id, seconds: 30) { [weak self] in
            self?.updateDelivery(id, status: .unknown, detail: "送达待核对：等待回执超时，请先查历史")
        }
        return true
    }

    /// Why these pictures cannot go, or nil when they can. The composer shows this before sending; the
    /// gateway refuses the send either way, so nothing oversized ever reaches the wire.
    public func imageSendProblem(text: String, images: [DSHOutgoingImage]) -> DSHImageError? {
        guard !images.isEmpty else { return nil }
        guard supportsImages else { return .unsupportedByGateway }
        let bytes = DSHImageProcessor.messageByteCount(text: text, images: images)
        return bytes > DSHImageProcessor.maxMessageBytes ? .messageTooLarge(bytes) : nil
    }

    // MARK: - Commands & skills

    /// Loads the command/skill catalogue for the open session. No-op when the gateway doesn't offer it.
    public func loadCommands() async {
        guard supportsCommands, phase == .ready, let sid = openSessionId else { commandGroups = []; return }
        guard let frame = await requestFrame(["type": "commands", "sessionId": sid, "locale": "zh-CN"],
                                             expecting: "commands"), frame.kind == "commands" else { return }
        commandGroups = Self.decodeCommandGroups(frame)
    }

    /// Runs an `immediate` command (or a `/` line the reader typed). The turn's own events follow.
    public func executeCommand(_ line: String) {
        guard supportsCommands, let sid = openSessionId else { return }
        send(["type": "command-execute", "sessionId": sid, "line": line])
    }

    /// The options of a `select` command (`model`, `permission`).
    public func commandOptions(for command: String) async -> [DSHCommandOption] {
        guard supportsCommands, phase == .ready, let sid = openSessionId else { return [] }
        guard let frame = await requestFrame(
            ["type": "command-options", "sessionId": sid, "command": command],
            expecting: "command-options"), frame.kind == "command-options" else { return [] }
        let options = frame.json["options"] as? [[String: Any]] ?? []
        return options.compactMap { option in
            guard let id = option["id"] as? String else { return nil }
            return DSHCommandOption(id: id,
                                    label: option["label"] as? String ?? id,
                                    detail: (option["detail"] as? String) ?? (option["description"] as? String),
                                    selected: option["selected"] as? Bool ?? false)
        }
    }

    public func selectCommandOption(command: String, optionId: String) {
        guard supportsCommands, let sid = openSessionId else { return }
        send(["type": "command-select", "sessionId": sid, "command": command, "optionId": optionId])
    }

    private func requestFrame(_ payload: [String: Any], expecting kind: String) async -> DSHFrame? {
        guard send(payload) else { return nil }
        let frame = await withCheckedContinuation { commandAwaiter = $0 }
        return (frame.kind == kind || frame.kind == "error") ? frame : nil
    }

    private func resolveCommandAwaiter(_ frame: DSHFrame) {
        commandAwaiter?.resume(returning: frame)
        commandAwaiter = nil
    }

    static func decodeCommandGroups(_ frame: DSHFrame) -> [DSHCommandGroup] {
        let groups = frame.json["groups"] as? [[String: Any]] ?? []
        return groups.compactMap { group in
            guard let title = group["title"] as? String else { return nil }
            let items = group["items"] as? [[String: Any]] ?? []
            let commands = items.compactMap { item -> DSHCommand? in
                guard let name = item["name"] as? String else { return nil }
                let ui = item["ui"] as? [String: Any] ?? [:]
                let kindRaw = ui["kind"] as? String ?? "unknown"
                return DSHCommand(
                    id: item["id"] as? String ?? name,
                    name: name,
                    description: item["description"] as? String ?? "",
                    groupTitle: title,
                    kind: DSHCommand.Kind(rawValue: kindRaw) ?? .unknown,
                    insertText: ui["insertText"] as? String ?? "/\(name) ",
                    submitText: ui["submitText"] as? String ?? "/\(name)",
                    acceptsImages: (ui["images"] as? Bool) ?? false)
            }
            return DSHCommandGroup(id: group["id"] as? String ?? title, title: title, commands: commands)
        }
    }

    // MARK: - File upload (chunked)

    /// Uploads a file in chunks and records it on `fileUploads` with progress; the finished receipt is
    /// what `message.files` will carry. Gated on `file-upload-v1`.
    public func uploadFile(data: Data, name: String) async {
        guard supportsFileUpload, phase == .ready, let sid = openSessionId else { return }
        let local = UUID().uuidString
        fileUploads.append(DSHFileUpload(id: local, name: name, size: data.count, data: data))
        await runUpload(local: local, data: data, name: name, sessionId: sid)
    }

    public func retryFileUpload(_ id: String) {
        guard let upload = fileUploads.first(where: { $0.id == id }), let sid = openSessionId else { return }
        setUpload(id) { $0.status = .uploading; $0.progress = 0; $0.error = nil }
        Task { await runUpload(local: id, data: upload.data, name: upload.name, sessionId: sid) }
    }

    public func removeFileUpload(_ id: String) {
        fileUploads.removeAll { $0.id == id }
    }

    private func setUpload(_ id: String, _ mutate: (inout DSHFileUpload) -> Void) {
        if let index = fileUploads.firstIndex(where: { $0.id == id }) { mutate(&fileUploads[index]) }
    }

    private func runUpload(local: String, data: Data, name: String, sessionId: String) async {
        func fail(_ message: String) {
            setUpload(local) { $0.status = .failed; $0.error = message }
        }
        let sha = SHA256.hash(data: data).map { String(format: "%02x", $0) }.joined()
        let opened = await requestFrame(
            ["type": "file-upload-open", "requestId": UUID().uuidString, "sessionId": sessionId,
             "name": name, "size": data.count, "sha256": sha], expecting: "file-upload-opened")
        guard let opened, opened.kind == "file-upload-opened", let uploadId = opened.string("uploadId") else {
            fail(opened?.string("message") ?? "上传开始失败"); return
        }
        let chunkBytes = max(1, opened.int("chunkBytes") ?? 256 * 1024)
        var offset = 0
        while offset < data.count {
            let end = min(offset + chunkBytes, data.count)
            let chunk = data.subdata(in: offset..<end)
            let ack = await requestFrame(
                ["type": "file-upload-chunk", "requestId": UUID().uuidString, "uploadId": uploadId,
                 "offset": offset, "data": chunk.base64EncodedString()], expecting: "file-upload-chunk-accepted")
            guard let ack, ack.kind == "file-upload-chunk-accepted", let next = ack.int("nextOffset") else {
                fail(ack?.string("message") ?? "上传中断"); return
            }
            offset = next
            setUpload(local) { $0.progress = Double(min(offset, data.count)) / Double(max(1, data.count)) }
        }
        let finished = await requestFrame(
            ["type": "file-upload-finish", "requestId": UUID().uuidString, "uploadId": uploadId],
            expecting: "file-upload-completed")
        guard let finished, finished.kind == "file-upload-completed",
              let receipt = finished.string("receiptId") else {
            fail(finished?.string("message") ?? "上传完成失败"); return
        }
        setUpload(local) { $0.status = .ready; $0.progress = 1; $0.receiptId = receipt }
    }

    // MARK: - Models / agent preset / permission (chat page session controls)

    public func loadModels() async {
        guard phase == .ready, let sid = openSessionId,
              let frame = await requestFrame(["type": "models", "sessionId": sid], expecting: "models"),
              frame.kind == "models" else { return }
        let groups = frame.json["groups"] as? [[String: Any]] ?? []
        modelGroups = groups.compactMap { group in
            guard let gid = group["id"] as? String else { return nil }
            let models = (group["models"] as? [[String: Any]] ?? []).compactMap { m -> DSHModel? in
                guard let id = m["id"] as? String else { return nil }
                let reasoning = m["reasoning"] as? [String: Any] ?? [:]
                let efforts = (reasoning["efforts"] as? [[String: Any]] ?? []).compactMap { e -> DSHReasoningEffort? in
                    guard let eid = e["id"] as? String else { return nil }
                    return DSHReasoningEffort(id: eid, name: e["name"] as? String ?? eid)
                }
                return DSHModel(id: id, name: m["name"] as? String ?? id, providerId: gid,
                                description: m["description"] as? String ?? "", reasoning: efforts)
            }
            return DSHModelGroup(id: gid, name: group["name"] as? String ?? gid, models: models)
        }
        if let current = frame.json["current"] as? [String: Any],
           let provider = current["provider"] as? String, let model = current["model"] as? String {
            currentModel = DSHCurrentModel(provider: provider, model: model,
                                           reasoningEffort: current["reasoningEffort"] as? String)
        }
    }

    public func selectModel(provider: String, model: String, reasoningEffort: String?) {
        guard let sid = openSessionId else { return }
        var payload: [String: Any] = ["type": "select-model", "sessionId": sid,
                                      "provider": provider, "model": model]
        if let effort = reasoningEffort, !effort.isEmpty { payload["reasoningEffort"] = effort }
        send(payload)
        currentModel = DSHCurrentModel(provider: provider, model: model, reasoningEffort: reasoningEffort)
    }

    public func saveDefaultModel(provider: String, model: String, reasoningEffort: String?) {
        var payload: [String: Any] = ["type": "save-default-model", "provider": provider, "model": model]
        if let effort = reasoningEffort, !effort.isEmpty { payload["reasoningEffort"] = effort }
        send(payload)
    }

    public func loadAgentPresets() async {
        guard supportsAgentPreset,
              let frame = await requestFrame(["type": "agent-presets"], expecting: "agent-presets"),
              frame.kind == "agent-presets" else { return }
        let presets = frame.json["presets"] as? [[String: Any]] ?? []
        agentPresets = presets.compactMap { p in
            guard let id = p["id"] as? String else { return nil }
            return DSHAgentPreset(id: id, name: p["name"] as? String ?? id,
                                  detail: p["description"] as? String,
                                  isDefault: p["isDefault"] as? Bool ?? false,
                                  broken: p["broken"] as? Bool ?? false)
        }
    }

    public func loadSessionAgentPreset() async {
        guard supportsAgentPreset, let sid = openSessionId,
              let frame = await requestFrame(["type": "session-agent-preset", "sessionId": sid],
                                             expecting: "session-agent-preset"),
              frame.kind == "session-agent-preset" else { return }
        if let preset = frame.string("agentPreset") { agentPresetSelected = preset }
        if let locked = frame.bool("locked") { agentPresetLocked = locked }
    }

    public func selectAgentPreset(_ preset: String) {
        guard supportsAgentPreset, let sid = openSessionId else { return }
        send(["type": "select-agent-preset", "sessionId": sid, "agentPreset": preset])
        agentPresetSelected = preset
    }

    public func loadPermissionOptions() async {
        var payload: [String: Any] = ["type": "permission-options"]
        if let sid = openSessionId { payload["sessionId"] = sid }
        guard let frame = await requestFrame(payload, expecting: "permission-options"),
              frame.kind == "permission-options" else { return }
        let options = frame.json["options"] as? [[String: Any]] ?? []
        permissionOptions = options.compactMap { o in
            guard let value = o["value"] as? String else { return nil }
            return DSHPermissionOption(id: value, name: o["name"] as? String ?? value,
                                       detail: o["description"] as? String)
        }
    }

    public func setPermission(_ name: String) {
        guard let sid = openSessionId else { return }
        send(["type": "permission", "sessionId": sid, "name": name])
    }

    /// Edits, removes or steers a queued message (`action` = edit|remove|steer). The push
    /// `session-queue` then replaces the list; the receipt is not the final state.
    public func queueUpdate(itemId: String, action: String, text: String? = nil) {
        guard capabilities.contains("queue-control"), let sid = openSessionId else { return }
        var payload: [String: Any] = ["type": "queue-update", "sessionId": sid,
                                      "itemId": itemId, "action": action]
        if let text, !text.isEmpty { payload["text"] = text }
        send(payload)
    }

    // MARK: - Approval & question cards

    /// `outcome` is `allowed-once` or `rejected`.
    public func respondApproval(_ approval: DSHApprovalRequest, outcome: String) {
        guard let sid = openSessionId else { return }
        send(["type": "approval-response", "rpcId": approval.rpcId, "sessionId": sid,
              "approvalId": approval.approvalId, "outcome": outcome])
        if pendingApproval?.approvalId == approval.approvalId { pendingApproval = nil }
    }

    /// `answers` is `[{id, selected:[String], custom?:String}]`, in question order.
    public func answerQuestion(_ request: DSHQuestionRequest, answers: [[String: Any]]) {
        guard let sid = openSessionId else { return }
        send(["type": "question-answer", "rpcId": request.rpcId, "sessionId": sid, "answers": answers])
        pendingQuestion = nil
    }

    public func cancelQuestion(_ request: DSHQuestionRequest) {
        guard let sid = openSessionId else { return }
        send(["type": "question-cancel", "rpcId": request.rpcId, "sessionId": sid])
        pendingQuestion = nil
    }

    static func decodeApproval(_ frame: DSHFrame) -> DSHApprovalRequest? {
        guard let approvalId = frame.string("approvalId") else { return nil }
        var reason = frame.string("reason")
        if let display = frame.dict("displayReason") {
            reason = (display["zh-CN"] as? String)
                ?? (display.keys.sorted().compactMap { display[$0] as? String }.first)
                ?? reason
        }
        return DSHApprovalRequest(rpcId: frame.string("rpcId") ?? "",
                                  approvalId: approvalId,
                                  toolName: frame.string("toolName") ?? "",
                                  reason: reason)
    }

    static func decodeQuestion(_ frame: DSHFrame) -> DSHQuestionRequest? {
        guard let rpcId = frame.string("rpcId") else { return nil }
        let items = frame.array("questions") ?? frame.json["questions"] as? [[String: Any]] ?? []
        let questions = items.compactMap { q -> DSHQuestion? in
            guard let id = q["id"] as? String, let text = q["question"] as? String else { return nil }
            let options = (q["options"] as? [[String: Any]] ?? []).compactMap { o -> DSHQuestionOption? in
                guard let label = o["label"] as? String else { return nil }
                return DSHQuestionOption(label: label, description: o["description"] as? String)
            }
            return DSHQuestion(id: id, header: q["header"] as? String, question: text,
                               detail: q["detail"] as? String, options: options,
                               multiSelect: q["multiSelect"] as? Bool ?? false)
        }
        return DSHQuestionRequest(rpcId: rpcId, questions: questions)
    }

    // MARK: - More menu (usage, stats, fork, rename, archive)

    /// The raw `context-usage` reply (`tokenUsage`, `contextPressure`, …) for the usage sheet.
    public func loadContextUsage() async -> [String: Any]? {
        guard phase == .ready, let sid = openSessionId,
              let frame = await requestFrame(["type": "context-usage", "sessionId": sid],
                                             expecting: "context-usage"), frame.kind == "context-usage"
        else { return nil }
        return frame.json
    }

    /// The raw `session-stats` reply (`sessionStats`, `tokenUsage`, …) for the stats sheet.
    public func loadSessionStats() async -> [String: Any]? {
        guard phase == .ready, let sid = openSessionId,
              let frame = await requestFrame(["type": "session-stats", "sessionId": sid],
                                             expecting: "session-stats"), frame.kind == "session-stats"
        else { return nil }
        return frame.json
    }

    /// Forks the session; on success returns the new session id. `fork-unavailable` means a turn is in
    /// progress. No `atSeq`, so no `historyFormatVersion` is needed.
    public func forkSession() async -> (sessionId: String?, message: String?) {
        guard let sid = openSessionId,
              let frame = await requestFrame(["type": "fork", "sessionId": sid], expecting: "fork")
        else { return (nil, "分叉失败") }
        if frame.kind == "fork", let newId = frame.string("sessionId") { return (newId, nil) }
        if frame.string("code") == "fork-unavailable" { return (nil, "本轮还在进行，稍后再分叉") }
        return (nil, frame.string("message") ?? "分叉失败")
    }

    public func renameSession(_ title: String) async -> Bool {
        guard let sid = openSessionId else { return false }
        let frame = await requestFrame(["type": "session-rename", "sessionId": sid, "title": title],
                                       expecting: "session-renamed")
        return frame?.kind == "session-renamed"
    }

    public func archiveSession() async -> Bool {
        guard let sid = openSessionId else { return false }
        let frame = await requestFrame(["type": "session-archive", "sessionId": sid],
                                       expecting: "session-archived")
        return frame?.kind == "session-archived"
    }

    // MARK: - Workspace files / schedules / agent team

    public var supportsFiles: Bool { capabilities.contains("file-downloads") }
    public var supportsSchedule: Bool { capabilities.contains("schedule-management") }
    public var supportsTeam: Bool { capabilities.contains("agent-team-v1") }

    /// One directory of the workspace (`path` is relative to the session cwd).
    public func listFiles(path: String) async -> [DSHFileEntry] {
        guard supportsFiles, phase == .ready, let sid = openSessionId,
              let frame = await requestFrame(["type": "file-list", "sessionId": sid, "path": path,
                                              "requestId": UUID().uuidString], expecting: "file-list"),
              frame.kind == "file-list" else { return [] }
        let entries = frame.json["entries"] as? [[String: Any]] ?? []
        return entries.compactMap { e in
            guard let name = e["name"] as? String, let p = e["path"] as? String else { return nil }
            return DSHFileEntry(name: name, path: p,
                                isDirectory: (e["kind"] as? String) == "directory",
                                bytes: (e["bytes"] as? NSNumber)?.intValue,
                                mediaType: e["mediaType"] as? String)
        }
    }

    /// Downloads one workspace file: open a transfer, then read chunks until eof.
    public func downloadFile(path: String) async -> Data? {
        guard supportsFiles, phase == .ready, let sid = openSessionId,
              let opened = await requestFrame(["type": "file-download-open", "sessionId": sid, "path": path,
                                               "requestId": UUID().uuidString], expecting: "file-download-opened"),
              opened.kind == "file-download-opened", let transferId = opened.string("transferId")
        else { return nil }
        var data = Data()
        var offset = 0
        while true {
            guard let chunk = await requestFrame(["type": "file-download-read", "transferId": transferId,
                                                  "offset": offset], expecting: "file-download-chunk"),
                  chunk.kind == "file-download-chunk" else { return nil }
            if let encoded = chunk.string("data"), let part = Data(base64Encoded: encoded) {
                data.append(part)
                offset += part.count
            }
            if chunk.bool("eof") == true { break }
            if chunk.string("data") == nil { break }
        }
        return data
    }

    public func listSchedules() async -> [DSHSchedule] {
        guard supportsSchedule, phase == .ready, let sid = openSessionId,
              let frame = await requestFrame(["type": "schedule-list", "sessionId": sid],
                                             expecting: "schedule-list"), frame.kind == "schedule-list"
        else { return [] }
        let items = frame.json["items"] as? [[String: Any]] ?? []
        return items.compactMap { item in
            guard let id = item["id"] as? String else { return nil }
            return DSHSchedule(id: id, title: item["title"] as? String ?? id,
                               detail: Self.scheduleDetail(item))
        }
    }

    public func deleteSchedule(_ id: String) async -> Bool {
        guard supportsSchedule, let sid = openSessionId,
              let frame = await requestFrame(["type": "schedule-delete", "sessionId": sid, "id": id],
                                             expecting: "schedule-delete"), frame.kind == "schedule-delete"
        else { return false }
        return frame.bool("deleted") == true
    }

    public func loadAgentTeam() async -> [DSHTeamMember] {
        guard supportsTeam, phase == .ready, let sid = openSessionId,
              let frame = await requestFrame(["type": "agent-team", "sessionId": sid],
                                             expecting: "agent-team"), frame.kind == "agent-team"
        else { return [] }
        let members = ((frame.json["agentTeam"] as? [String: Any])?["members"] as? [[String: Any]]) ?? []
        return members.compactMap { m in
            guard let id = m["id"] as? String else { return nil }
            return DSHTeamMember(id: id, name: m["name"] as? String ?? id,
                                 role: m["role"] as? String ?? "", phase: m["phase"] as? String ?? "")
        }
    }

    // MARK: - Goal & tasks (in-session panels)

    public func loadGoal() async {
        guard supportsGoals, phase == .ready, let sid = openSessionId,
              let frame = await requestFrame(["type": "goal", "sessionId": sid], expecting: "goal"),
              frame.kind == "goal" else { goal = nil; return }
        goal = Self.decodeGoal(frame.json["goal"])
    }

    public func loadTasks() async {
        guard supportsTasks, phase == .ready, let sid = openSessionId,
              let frame = await requestFrame(["type": "tasks", "sessionId": sid], expecting: "tasks"),
              frame.kind == "tasks" else { todos = []; return }
        todos = Self.decodeTodos(frame.json["todos"])
    }

    public func pauseGoal() async { await goalMutation("goal-pause", extra: [:]) }
    public func resumeGoal() async { await goalMutation("goal-resume", extra: [:]) }
    public func clearGoal() async {
        guard let payload = goalPayload([:]) else { return }
        _ = await requestFrame(payload.merging(["type": "goal-clear"]) { _, b in b }, expecting: "goal-clear")
        await loadGoal()
    }
    public func editGoal(objective: String?, maxGoalRounds: Int?) async {
        var extra: [String: Any] = [:]
        if let objective, !objective.isEmpty { extra["objective"] = objective }
        if let maxGoalRounds { extra["maxGoalRounds"] = maxGoalRounds }
        guard !extra.isEmpty else { return }
        await goalMutation("goal-edit", extra: extra)
    }

    private func goalMutation(_ type: String, extra: [String: Any]) async {
        guard let payload = goalPayload(extra) else { return }
        _ = await requestFrame(payload.merging(["type": type]) { _, b in b }, expecting: type)
        await loadGoal()
    }

    /// `{sessionId, ref:{id,revision}}` plus extras; the ref is the latest the client saw.
    private func goalPayload(_ extra: [String: Any]) -> [String: Any]? {
        guard let g = goal, let sid = openSessionId else { return nil }
        var payload: [String: Any] = ["sessionId": sid, "ref": ["id": g.id, "revision": g.revision]]
        for (k, v) in extra { payload[k] = v }
        return payload
    }

    static func decodeGoal(_ value: Any?) -> DSHGoal? {
        guard let g = value as? [String: Any], let id = g["id"] as? String else { return nil }
        let goal = g["goal"] as? [String: Any] ?? g
        return DSHGoal(id: id,
                       revision: (g["revision"] as? NSNumber)?.intValue ?? 0,
                       objective: goal["objective"] as? String ?? "",
                       phase: goal["phase"] as? String ?? "",
                       maxGoalRounds: (goal["maxGoalRounds"] as? NSNumber)?.intValue,
                       roundsStarted: (g["roundsStarted"] as? NSNumber)?.intValue)
    }

    static func decodeTodos(_ value: Any?) -> [DSHTodo] {
        guard let items = value as? [[String: Any]] else { return [] }
        return items.enumerated().compactMap { index, item in
            guard let content = item["content"] as? String else { return nil }
            return DSHTodo(index: index, content: content, status: item["status"] as? String ?? "")
        }
    }

    /// A one-line summary of a schedule's timing for the list row.
    private static func scheduleDetail(_ item: [String: Any]) -> String {
        if let kind = item["kind"] as? String { return kind }
        for key in ["time", "expression", "scheduledAt", "afterSeconds", "everySeconds"] {
            if let v = item[key] { return "\(key): \(v)" }
        }
        return ""
    }

    // MARK: - Pictures (attachment fetch)

    /// The bytes of one picture, fetched once and then read from the in-memory cache. Returns nil when
    /// it cannot be fetched; the row keeps its placeholder and may ask again after a reconnect.
    public func imageData(for ref: DSHImageRef) async -> Data? {
        await imageData(attachmentId: ref.attachmentId)
    }

    /// The same fetch by bare attachment id, which is what a picture row holds.
    public func imageData(attachmentId: String) async -> Data? {
        guard let gatewayId = validatedGatewayId, let sessionId = openSessionId else { return nil }
        let key = DSHAttachmentKey(gatewayId: gatewayId, sessionId: sessionId, attachmentId: attachmentId)
        if let data = imageCache[key] { return data }
        return await withCheckedContinuation { continuation in
            imageWaiters[key, default: []].append(continuation)
            enqueueImage(key)
        }
    }

    private func enqueueImage(_ key: DSHAttachmentKey) {
        guard !imageInFlight.contains(key), !imageQueue.contains(key) else { return }
        imageQueue.append(key)
        pumpImages()
    }

    /// Starts as many attachment requests as the concurrency limit allows. The rest wait their turn.
    private func pumpImages() {
        while imageInFlight.count < Self.imageConcurrency, !imageQueue.isEmpty {
            let key = imageQueue.removeFirst()
            guard imageInFlight.insert(key).inserted else { continue }
            guard phase == .ready, task != nil, networkAvailable else { finishImage(key, data: nil); continue }
            // The gateway does not echo a requestId for attachments: the reply is matched by
            // sessionId + attachmentId against this connection's own bookkeeping.
            let sent = send(["type": "attachment", "sessionId": key.sessionId,
                             "attachmentId": key.attachmentId])
            if !sent { finishImage(key, data: nil); continue }
            scheduleTimeout(Self.attachmentTimeoutId(key), seconds: 20) { [weak self] in
                self?.finishImage(key, data: nil)
            }
        }
    }

    private func finishImage(_ key: DSHAttachmentKey, data: Data?) {
        imageInFlight.remove(key)
        operationTimeouts.removeValue(forKey: Self.attachmentTimeoutId(key))?.cancel()
        if let data { storeImage(key, data) }
        for waiter in imageWaiters.removeValue(forKey: key) ?? [] { waiter.resume(returning: data) }
        pumpImages()
    }

    private func storeImage(_ key: DSHAttachmentKey, _ data: Data) {
        if let old = imageCache[key] {
            imageCacheBytes -= old.count
        } else {
            imageCacheOrder.append(key)
        }
        imageCache[key] = data
        imageCacheBytes += data.count
        while imageCacheBytes > Self.imageCacheLimit || imageCacheOrder.count > Self.imageCacheCount {
            guard let oldest = imageCacheOrder.first else { break }
            imageCacheOrder.removeFirst()
            if let removed = imageCache.removeValue(forKey: oldest) { imageCacheBytes -= removed.count }
        }
    }

    private func handleAttachment(_ frame: DSHFrame) {
        guard let gatewayId = validatedGatewayId,
              let sessionId = frame.string("sessionId"),
              let attachment = frame.dict("attachment"),
              let attachmentId = attachment["attachmentId"] as? String,
              let encoded = frame.string("data") else { return }
        let key = DSHAttachmentKey(gatewayId: gatewayId, sessionId: sessionId, attachmentId: attachmentId)
        // Only a picture this connection actually asked for, and only while it is still waiting: an
        // unrequested or already-finished reply must not pollute the cache.
        guard imageInFlight.contains(key), imageWaiters[key] != nil else { return }
        let expected = (attachment["bytes"] as? NSNumber)?.intValue
        Task { [weak self] in
            // A few megabytes of Base64 must not be decoded on the main actor.
            let data = await Task.detached(priority: .userInitiated) { () -> Data? in
                guard let decoded = Data(base64Encoded: encoded) else { return nil }
                // The decoded length has to agree with what the gateway said it holds; a mismatch
                // leaves the placeholder rather than showing the wrong bytes.
                if let expected, expected != decoded.count { return nil }
                return decoded
            }.value
            guard let self, self.imageInFlight.contains(key) else { return }
            self.finishImage(key, data: data)
        }
    }

    private static func attachmentTimeoutId(_ key: DSHAttachmentKey) -> String {
        "attachment:\(key.sessionId):\(key.attachmentId)"
    }

    public func retrySubmission(_ id: String) {
        guard let submission = conversation?.submissions.first(where: { $0.id == id }), submission.status == .failed else { return }
        // The frozen pictures are re-sent exactly as they were: never re-compressed into a new payload.
        if send(text: submission.text, images: submission.images, files: submission.files) {
            conversation?.dismissSubmission(id); publishConversation()
        }
    }

    public func resendUnknownSubmission(_ id: String) {
        guard let submission = conversation?.submissions.first(where: { $0.id == id }),
              submission.status == .unknown, submission.historyChecked else { return }
        if send(text: submission.text, images: submission.images, files: submission.files) {
            conversation?.dismissSubmission(id); publishConversation()
        }
    }

    public func dismissSubmission(_ id: String) {
        guard conversation?.submissions.first(where: { $0.id == id })?.status != .writing else { return }
        conversation?.dismissSubmission(id); publishConversation()
    }

    public func reconcileSubmission(_ id: String) async {
        guard conversation?.submissions.contains(where: { $0.id == id && $0.status == .unknown }) == true else { return }
        if await requestHistory(.reconcile) {
            conversation?.markReconciled(id)
            publishConversation()
        }
    }

    public func loadEarlier() async {
        guard conversation?.pageError == nil else { return }
        for _ in 0..<3 {
            guard conversation?.hasMore == true, conversation?.loadingEarlier == false else { return }
            let beforeCount = messages.count
            await requestHistory(.older)
            if historyError != nil || messages.count != beforeCount { return }
        }
    }

    public func refreshConversation() async {
        conversation?.clearPageError()
        if hasMore { await loadEarlier() } else { await requestHistory(.reconcile) }
    }

    public func newSession() {
        let id = UUID().uuidString
        creationRequests[id] = selectionGeneration
        send(["type": "session-create", "requestId": id])
    }

    /// Asks the gateway to stop the running turn (`session-cancel`). The receipt only means the
    /// request was accepted; the turn is over when its `turn/end` arrives — the same rule the status
    /// line and the conversation's ending notice follow. Returns false when there is nothing to cancel.
    @discardableResult public func cancelTurn() -> Bool {
        guard isRunning, let sessionId = openSessionId, phase == .ready, validatedGatewayId != nil else {
            return false
        }
        return send(["type": "session-cancel", "sessionId": sessionId])
    }

    private func selectScope(gatewayId: String, sessionId: String) {
        let scope = DSHSessionScope(gatewayId: gatewayId, sessionId: sessionId, format: 4)
        selectedScope = scope
        if conversations[scope] == nil { conversations[scope] = DSHConversationState(scope: scope) }
    }

    private func publishConversation() {
        messages = conversation?.messages ?? []
        submissions = conversation?.submissions.filter { !$0.isRetired && $0.status != .accepted } ?? []
        queueHints = openSessionId.flatMap { gatewayQueues[$0] } ?? []
        queueIsKnown = hasQueueBaseline || openSessionId.map { gatewayQueues[$0] != nil } == true
        hasMore = conversation?.hasMore ?? false
        loadingEarlier = conversation?.loadingEarlier ?? false
        historyError = conversation?.pageError
        isStreaming = conversation?.attempt != nil
        if let sid = openSessionId, let first = messages.first(where: { $0.role == .user })?.text {
            rememberFirstMessage(first, for: sid)
        }
    }

    private func requestSubscription() {
        guard phase == .ready, validatedGatewayId != nil, inFlightSubscription == nil else { return }
        inFlightSubscription = (openSessionId, selectionGeneration)
        let frame: [String: Any] = openSessionId.map { ["type": "subscribe", "sessionId": $0, "assistantStream": true] }
            ?? ["type": "unsubscribe"]
        send(frame)
        scheduleTimeout("subscribe", seconds: 15) { [weak self] in
            self?.handleDrop(DSHError.transport("订阅确认超时"))
        }
    }

    private func resubscribe() {
        conversation?.retireStream()
        activity.endSession()
        if let sid = openSessionId { activity.beginSession(sid) }
        syncActivity(); publishConversation(); requestSubscription()
    }

    @discardableResult private func requestHistory(_ kind: DSHConversationState.RequestKind) async -> Bool {
        guard phase == .ready, conversation?.hasBaseline == true else { return false }
        guard let id = conversation?.register(kind, generation: selectionGeneration), let scope = selectedScope,
              let request = conversation?.requests[id] else {
            publishConversation()
            return false
        }
        var payload: [String: Any] = ["type": "history", "requestId": id, "sessionId": scope.sessionId,
                                      "historyFormatVersion": scope.format, "maxMessages": 30,
                                      "maxBytes": 262_144, "view": "conversation"]
        if let before = request.before { payload["beforeSeq"] = before }
        publishConversation()
        if !send(payload) { conversation?.failRequest(id, message: "历史请求未发出"); publishConversation(); return false }
        scheduleTimeout(id, seconds: 20) { [weak self] in
            self?.historyOutcomes[id] = false
            self?.conversation?.failRequest(id, message: "历史同步超时，请下拉重试")
            self?.publishConversation()
        }
        let generation = selectionGeneration
        let connection = connectionGeneration
        while generation == selectionGeneration, conversation?.requests[id] != nil {
            try? await Task.sleep(nanoseconds: 50_000_000)
            if Task.isCancelled { return false }
        }
        let accepted = historyOutcomes.removeValue(forKey: id) == true
        return accepted && generation == selectionGeneration && connection == connectionGeneration && phase == .ready
    }

    private func scheduleTimeout(_ id: String, seconds: UInt64, action: @escaping () -> Void) {
        operationTimeouts.removeValue(forKey: id)?.cancel()
        operationTimeouts[id] = Task { @MainActor [weak self] in
            try? await Task.sleep(nanoseconds: seconds * 1_000_000_000)
            guard !Task.isCancelled else { return }
            self?.operationTimeouts.removeValue(forKey: id)
            action()
        }
    }

    private func retireConnection() {
        let previous = connectionGeneration
        connectionGeneration &+= 1
        validatedGatewayId = nil; inFlightSubscription = nil; creationRequests = [:]
        gatewayQueues = [:]; hasQueueBaseline = false
        capabilities = []
        // A dropped connection ends the pictures that were in flight: their rows keep the placeholder
        // and may ask again once the connection is back. That is a read retry, never a resend.
        for (_, waiters) in imageWaiters { for waiter in waiters { waiter.resume(returning: nil) } }
        imageWaiters = [:]; imageInFlight = []; imageQueue = []
        commandAwaiter?.resume(returning: DSHFrame(kind: "error", json: ["code": "disconnected"]))
        commandAwaiter = nil
        commandGroups = []
        for timeout in operationTimeouts.values { timeout.cancel() }
        operationTimeouts = [:]
        for scope in Array(conversations.keys) {
            conversations[scope]?.interruptSending(connection: previous)
            conversations[scope]?.retireStream()
        }
        publishConversation()
    }

    private func updateDelivery(_ id: String, status: DSHSubmission.Status, detail: String) {
        operationTimeouts.removeValue(forKey: id)?.cancel()
        for scope in Array(conversations.keys) { conversations[scope]?.delivery(id, status: status, detail: detail) }
        publishConversation()
    }

    private func handleProtocolError(_ frame: DSHFrame) {
        let message = frame.string("message") ?? "未知错误"
        if frame.string("code") == "authentication-required" { requirePairingAgain(); return }
        if let id = frame.string("requestId") {
            let definite = ["bad-request", "permission-denied", "subagent/not-resumable"].contains(frame.string("code") ?? "")
            updateDelivery(id, status: definite ? .failed : .unknown,
                           detail: definite ? "没有发出去：" + message : "送达待核对：" + message)
            if conversation?.requests[id] != nil { historyOutcomes[id] = false }
            conversation?.failRequest(id, message: message)
            publishConversation()
        }
        if phase != .ready { phase = .failed(message) }
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
        let outline = raw as? [[String: Any]] ?? []
        if sessionId == openSessionId {
            turnOutline = outline.compactMap { item in
                guard let turn = (item["turn"] as? NSNumber)?.intValue,
                      let seq = (item["seq"] as? NSNumber)?.int64Value else { return nil }
                return DSHTurnOutline(turn: turn, seq: seq,
                                      prompt: item["prompt"] as? String ?? "",
                                      response: item["response"] as? String ?? "")
            }
        }
        guard let last = outline.last else { return }
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
        task?.cancel(with: .goingAway, reason: nil)
        task = nil
        retireConnection()
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
        task?.cancel(with: .policyViolation, reason: nil)
        task = nil
        retireConnection()
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

    /// The visible words of a chunk — and only those. A `reasoning-delta` carries the model's
    /// thinking, which belongs to the status line's title, never to a message bubble; reading its
    /// `text` here is what used to put the thinking in the reply and then lose it when the
    /// committed `assistant/message` replaced the bubble.
    static func text(ofChunk payload: [String: Any]) -> String? {
        if let chunk = payload["chunk"] as? [String: Any] {
            switch chunk["type"] as? String {
            case "text-delta":
                return chunk["text"] as? String ?? chunk["textDelta"] as? String
            case nil:
                // An older host's plain `{text}` chunk: no type, but it is the answer's words.
                return chunk["text"] as? String
            default:
                return nil
            }
        }
        return payload["text"] as? String
    }
}

/// The name an unnamed, unstarted session gets.
private enum L10nSessionFallback {
    static let title = "未命名会话"
}

/// One picture's cache address. Never keyed by file name or a bare attachment id: two gateways can
/// use the same attachment id for different pictures.
struct DSHAttachmentKey: Hashable, Sendable {
    let gatewayId: String
    let sessionId: String
    let attachmentId: String
}
