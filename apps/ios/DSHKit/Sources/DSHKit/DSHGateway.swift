import Foundation

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
    @Published public private(set) var messages: [DSHMessage] = []
    @Published public private(set) var openSessionId: String?
    @Published public private(set) var isStreaming = false

    public private(set) var profile: DSHGatewayProfile?

    private var task: URLSessionWebSocketTask?
    private let session: URLSession
    private var reconnectAttempt = 0
    private var reconnectTask: Task<Void, Never>?
    private var shouldReconnect = false
    /// assistant-stream attempts being written, so a stale chunk from an earlier attempt is ignored.
    private var streamingAttempts = Set<String>()
    private var pendingPairing: CheckedContinuation<DSHGatewayProfile, Error>?
    private var pairingTimeoutTask: Task<Void, Never>?

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
        guard profile == nil else { return start() }
        guard let saved = DSHCredentialStore.load().first else { return }
        profile = saved
        gatewayName = saved.name
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
        task?.cancel(with: .goingAway, reason: nil)
        task = nil
        phase = .idle
        isStreaming = false
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
        if pairing == nil { send(["type": "sessions"]) }
    }

    private func receiveLoop(on socket: URLSessionWebSocketTask) {
        socket.receive { [weak self] result in
            guard let self else { return }
            Task { @MainActor in
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
            if phase != .ready { phase = .ready }
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
        switch type {
        case "assistant/message":
            let text = Self.text(of: event)
            guard !text.isEmpty else { return }
            isStreaming = false
            streamingAttempts.removeAll()
            upsertFinishedAssistant(text)
            refreshSession(sid)
        case "user/message":
            let text = Self.text(of: event)
            if !text.isEmpty, messages.last?.text != text {
                messages.append(DSHMessage(role: .user, text: text))
            }
        case "turn/end":
            isStreaming = false
        default:
            break
        }
    }

    /// The opening baseline after `subscribe`: a window of recent events. P1 shows the last user and
    /// assistant messages so a conversation is not empty on open.
    private func handleSnapshot(_ frame: DSHFrame) {
        guard let sid = frame.string("sessionId"), sid == openSessionId else { return }
        let events = frame.array("events") ?? []
        var seeded: [DSHMessage] = []
        for event in events {
            guard let type = event["type"] as? String else { continue }
            if type == "user/message" {
                let text = Self.text(of: event)
                if !text.isEmpty { seeded.append(DSHMessage(role: .user, text: text)) }
            } else if type == "assistant/message" {
                let text = Self.text(of: event)
                if !text.isEmpty { seeded.append(DSHMessage(role: .assistant, text: text)) }
            }
        }
        if !seeded.isEmpty || messages.isEmpty { messages = seeded }
    }

    private func handleStream(_ frame: DSHFrame) {
        guard frame.string("sessionId") == openSessionId, let payload = frame.dict("frame") else { return }
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

    // MARK: - Conversation

    public func open(sessionId: String) {
        openSessionId = sessionId
        messages = []
        isStreaming = false
        streamingAttempts.removeAll()
        send(["type": "subscribe", "sessionId": sessionId, "assistantStream": true])
    }

    public func closeConversation() {
        if let openSessionId { send(["type": "unsubscribe"]) }
        openSessionId = nil
        messages = []
        isStreaming = false
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
    private func upsertFinishedAssistant(_ text: String) {
        if let index = messages.lastIndex(where: { $0.role == .assistant }) {
            messages[index].text = text
            messages[index].streaming = false
        } else {
            messages.append(DSHMessage(role: .assistant, text: text))
        }
    }

    private func refreshSession(_ sessionId: String) {
        send(["type": "sessions"])
    }

    private func handleDrop(_ error: Error) {
        let message = error.localizedDescription
        if pendingPairing != nil {
            pendingPairing?.resume(throwing: DSHError.transport(message))
            pendingPairing = nil
            pairingTimeoutTask?.cancel()
            pairingTimeoutTask = nil
        }
        phase = .failed(message)
        scheduleReconnect()
    }

    private func scheduleReconnect() {
        guard shouldReconnect, profile != nil else { return }
        reconnectAttempt = min(reconnectAttempt + 1, 6)
        let delay = min(pow(2.0, Double(reconnectAttempt)), 30)
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
        phase = .failed(DSHError.authenticationRequired.localizedDescription)
        if let id = profile?.id { DSHCredentialStore.delete(id: id) }
        profile = nil
    }

    private func fail(_ error: Error) {
        phase = .failed(error.localizedDescription)
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
