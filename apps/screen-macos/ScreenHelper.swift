import AppKit
import ApplicationServices
import CoreGraphics
@preconcurrency import WebRTC

/// Serves the host's screen requests (see `host/src/screen/mod.rs` for the protocol).
@MainActor
final class ScreenHelper {
    private let link = HostLink()
    let input = InputInjector()
    private let driver = Driver()
    private var sessions: [String: Session] = [:]
    private let badge = ViewingBadge()
    private var lastStatus: [String: AnyHashable] = [:]

    init() {
        link.handler = { [unowned self] method, params in try await self.handle(method, params) }
        link.onConnect = { [unowned self] in
            // The host lost every session when we dropped.
            closeAll()
            lastStatus = [:]
            sendStatus()
        }
        link.onDisconnect = { [unowned self] in closeAll() }
        badge.onDisconnect = { [unowned self] in closeAll() }
    }

    func start() {
        link.start()
        NotificationCenter.default.addObserver(forName: NSApplication.didChangeScreenParametersNotification, object: nil, queue: .main) { [weak self] _ in
            MainActor.assumeIsolated { self?.sendStatus() }
        }
        // Permission grants don't notify: poll, cheaply, and report changes.
        Task { [weak self] in
            while !Task.isCancelled {
                try? await Task.sleep(for: .seconds(3))
                await self?.refreshPermissions()
            }
        }
    }

    private func handle(_ method: String, _ p: [String: Any]) async throws -> Any {
        switch method {
        case "requestPermission":
            guard let permission = p["permission"] as? String else { throw HelperError("permission is required") }
            try ScreenPermissions.request(permission)
            sendStatus()
            return [String: Any]()
        case "answer":
            guard let id = p["session"] as? String, let sdp = p["sdp"] as? String else { throw HelperError("session and sdp are required") }
            guard ScreenPermissions.captureGranted else {
                sendStatus()
                throw HelperError("Allow screen recording for \(ScreenPermissions.appName) in System Settings.")
            }
            if let s = sessions[id] { return ["sdp": try await s.answer(offer: sdp)] }
            let iceServers = (p["iceServers"] as? [[String: Any]] ?? []).compactMap { value -> RTCIceServer? in
                guard let urls = value["urls"] as? [String], !urls.isEmpty else { return nil }
                return RTCIceServer(urlStrings: urls, username: value["username"] as? String, credential: value["credential"] as? String)
            }
            let s = Session(id: id, display: display(p["display"]), helper: self, iceServers: iceServers,
                            maxBitrate: min(16_000_000, max(100_000, p["maxBitrateBps"] as? Int ?? 16_000_000)),
                            maxFramerate: min(60, max(1, p["maxFramerate"] as? Int ?? 60)), trickle: p["trickle"] as? Bool ?? false)
            sessions[id] = s
            do {
                let answer = try await s.answer(offer: sdp)
                badge.update(viewers: sessions.count)
                return ["sdp": answer]
            } catch {
                sessions[id] = nil
                s.close()
                throw error
            }
        case "candidate":
            guard let id = p["session"] as? String, let session = sessions[id],
                  let candidate = p["candidate"] as? [String: Any]
            else { throw HelperError("unknown screen session") }
            try await session.candidate(candidate)
            return [String: Any]()
        case "close":
            if let id = p["session"] as? String, let s = sessions.removeValue(forKey: id) {
                s.close()
                badge.update(viewers: sessions.count)
            }
            return [String: Any]()
        case "closeAll":
            closeAll()
            return [String: Any]()
        case "focusedField":
            return try AXTree.focusedField(pid: (p["pid"] as? NSNumber).map { pid_t($0.int32Value) })
        case "driver":
            guard ScreenPermissions.captureGranted, ScreenPermissions.inputGranted else {
                throw HelperError("Set up Computer access in Codync → Settings on this computer first.")
            }
            return ["socket": try await driver.socket()]
        default:
            throw HelperError("unknown method \(method)")
        }
    }

    func candidate(session: String, candidate: [String: Any]) {
        guard sessions[session] != nil else { return }
        link.notify("candidate", ["session": session, "candidate": candidate])
    }

    func sessionConnected(_ session: Session) {
        guard sessions[session.id] === session else { return }
        link.notify("session", ["session": session.id, "state": "connected"])
    }

    func sessionEnded(_ id: String) {
        guard let s = sessions.removeValue(forKey: id) else { return }
        s.close()
        badge.update(viewers: sessions.count)
        link.notify("session", ["session": id, "state": "closed"])
    }

    private func closeAll() {
        for (id, s) in sessions {
            s.close()
            link.notify("session", ["session": id, "state": "closed"])
        }
        sessions = [:]
        badge.update(viewers: 0)
    }

    private func refreshPermissions() async {
        sendStatus()
        // The running process can keep its pre-grant answer. The probe can trigger a restart,
        // but only the process that actually captures the screen can report it as ready.
        guard !ScreenPermissions.captureGranted, await ScreenPermissions.probeCaptureGrant(),
              !ScreenPermissions.captureGranted else { return }
        link.stop()
        exit(0) // KeepAlive starts the capture process again with the current grant.
    }

    private func display(_ v: Any?) -> CGDirectDisplayID {
        (v as? NSNumber)?.uint32Value ?? CGMainDisplayID()
    }

    // MARK: status

    private func sendStatus() {
        var ids = [CGDirectDisplayID](repeating: 0, count: 16)
        var count: UInt32 = 0
        CGGetActiveDisplayList(UInt32(ids.count), &ids, &count)
        let main = CGMainDisplayID()
        let displays: [[String: AnyHashable]] = ids.prefix(Int(count)).map { id in
            let b = CGDisplayBounds(id)
            let name = NSScreen.screens.first { ($0.deviceDescription[NSDeviceDescriptionKey("NSScreenNumber")] as? NSNumber)?.uint32Value == id }?.localizedName
            return ["id": Int(id), "name": name ?? "Display", "width": b.width, "height": b.height, "main": id == main]
        }
        let status: [String: AnyHashable] = [
            "platform": "macos",
            "permissionApp": ScreenPermissions.appName,
            "displays": displays,
            "capture": ScreenPermissions.captureGranted,
            "trickle": true,
            "input": ScreenPermissions.inputGranted,
        ]
        guard status != lastStatus, link.isConnected else { return }
        lastStatus = status
        link.notify("status", status)
    }
}

@main
enum ScreenHelperMain {
    @MainActor static var helper: ScreenHelper?

    @MainActor
    static func main() {
        if CommandLine.arguments.contains("--probe-capture") { exit(ScreenPermissions.captureGranted ? 0 : 1) }
        let app = NSApplication.shared
        app.setActivationPolicy(.accessory)
        let helper = ScreenHelper()
        Self.helper = helper
        helper.start()
        app.run()
    }
}
