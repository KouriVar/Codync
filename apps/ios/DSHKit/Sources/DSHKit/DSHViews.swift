import SwiftUI

/// One entry on the host app's home page: the DSH group. It shows the paired gateway and its
/// sessions, and offers the pairing sheet when nothing is paired yet.
public struct DSHHomeSection: View {
    @StateObject private var gateway = DSHGateway()
    @State private var showSessions = false
    @State private var showConnect = false
    @State private var showChat = false
    /// `scan` lets the host supply its own QR scanner: it is handed a callback to call with the
    /// scanned string, and returns the view to show (or nil when the host cannot scan).
    private let scan: (@escaping (String) -> Void) -> AnyView?

    public init(scan: @escaping (@escaping (String) -> Void) -> AnyView? = { _ in nil }) {
        self.scan = scan
    }

    public var body: some View {
        VStack(alignment: .leading, spacing: 8) {
            header
            switch gateway.phase {
            case .idle, .connecting:
                statusRow("正在连接 \(gateway.gatewayName)…", systemImage: "circle.dotted")
            case .failed(let message):
                statusRow(message, systemImage: "exclamationmark.triangle")
                Button("重新配对…") { showConnect = true }
                    .buttonStyle(.borderless)
                    .font(.subheadline)
            case .ready:
                if gateway.sessions.isEmpty {
                    statusRow("还没有会话", systemImage: "tray")
                } else {
                    ForEach(gateway.sessions.prefix(3)) { session in
                        Button { showChat = true; gateway.open(sessionId: session.id) } label: {
                            sessionRow(session)
                        }
                        .buttonStyle(.plain)
                    }
                    if gateway.sessions.count > 3 {
                        Button("查看全部 \(gateway.sessions.count) 个会话") { showSessions = true }
                            .font(.subheadline)
                    }
                }
            }
        }
        .padding(.horizontal, 16)
        .padding(.vertical, 10)
        .task { gateway.connectLastPaired() }
        .sheet(isPresented: $showSessions) {
            DSHSessionListSheet(gateway: gateway)
        }
        .sheet(isPresented: $showChat) {
            DSHChatScreen(gateway: gateway)
        }
        .sheet(isPresented: $showConnect) {
            DSHConnectSheet(gateway: gateway, scan: scan)
        }
    }

    private var header: some View {
        HStack(spacing: 6) {
            Image(systemName: "sparkles").font(.caption)
            Text("DSH 对话").font(.caption).bold()
            Spacer()
            Button {
                showConnect = true
            } label: {
                Image(systemName: "plus.circle").font(.caption)
            }
            .buttonStyle(.plain)
            .accessibilityLabel("连接 DSH")
        }
        .foregroundStyle(.secondary)
    }

    private func statusRow(_ text: String, systemImage: String) -> some View {
        HStack(spacing: 8) {
            Image(systemName: systemImage).font(.caption)
            Text(text).font(.footnote).lineLimit(2)
        }
        .foregroundStyle(.secondary)
    }

    private func sessionRow(_ session: DSHSession) -> some View {
        HStack(spacing: 10) {
            Circle()
                .fill(session.running ? Color.green : Color.secondary.opacity(0.35))
                .frame(width: 8, height: 8)
            VStack(alignment: .leading, spacing: 1) {
                Text(session.title).font(.subheadline).lineLimit(1)
                Text(session.running ? "运行中" : "空闲").font(.caption2).foregroundStyle(.secondary)
            }
            Spacer()
            Image(systemName: "chevron.right").font(.caption2).foregroundStyle(.tertiary)
        }
        .contentShape(Rectangle())
    }
}

// MARK: - Session list

struct DSHSessionListSheet: View {
    @ObservedObject var gateway: DSHGateway
    @Environment(\.dismiss) private var dismiss
    @State private var selected: DSHSession?

    var body: some View {
        NavigationStack {
            List(gateway.sessions) { session in
                Button { selected = session } label: {
                    HStack(spacing: 10) {
                        Circle()
                            .fill(session.running ? Color.green : Color.secondary.opacity(0.35))
                            .frame(width: 8, height: 8)
                        Text(session.title).lineLimit(1)
                        Spacer()
                        Text(session.running ? "运行中" : "").font(.caption).foregroundStyle(.secondary)
                    }
                }
                .buttonStyle(.plain)
            }
            .navigationTitle(gateway.gatewayName)
            .toolbar { ToolbarItem(placement: .cancellationAction) { Button("关闭") { dismiss() } } }
            .navigationDestination(item: $selected) { session in
                DSHChatScreen(gateway: gateway)
                    .onAppear { gateway.open(sessionId: session.id) }
            }
        }
    }
}

// MARK: - Chat

public struct DSHChatScreen: View {
    @ObservedObject var gateway: DSHGateway
    @Environment(\.dismiss) private var dismiss
    @State private var draft = ""

    public init(gateway: DSHGateway) {
        self.gateway = gateway
    }

    public var body: some View {
        NavigationStack {
            VStack(spacing: 0) {
                ScrollViewReader { proxy in
                    ScrollView {
                        LazyVStack(alignment: .leading, spacing: 12) {
                            ForEach(gateway.messages) { message in
                                bubble(message).id(message.id)
                            }
                            if gateway.isStreaming { typing().id("typing") }
                        }
                        .padding(.horizontal, 16)
                        .padding(.vertical, 12)
                    }
                    .onChange(of: gateway.messages.count) { _, _ in
                        if let last = gateway.messages.last { withAnimation { proxy.scrollTo(last.id, anchor: .bottom) } }
                    }
                    .onChange(of: gateway.messages.last?.text) { _, _ in
                        withAnimation { proxy.scrollTo("typing", anchor: .bottom) }
                    }
                }
                Divider()
                composer
            }
            .navigationTitle(title)
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .cancellationAction) { Button("关闭") { dismiss() } }
                ToolbarItem(placement: .primaryAction) {
                    Button { gateway.newSession() } label: { Image(systemName: "square.and.pencil") }
                        .accessibilityLabel("新建会话")
                }
            }
        }
        .onDisappear { gateway.closeConversation() }
    }

    private var title: String {
        gateway.sessions.first { $0.id == gateway.openSessionId }?.title ?? gateway.gatewayName
    }

    @ViewBuilder private func bubble(_ message: DSHMessage) -> some View {
        HStack {
            if message.role == .user { Spacer(minLength: 40) }
            Text(message.text.isEmpty ? " " : message.text)
                .font(.body)
                .textSelection(.enabled)
                .padding(.horizontal, 12)
                .padding(.vertical, 8)
                .background(message.role == .user ? Color.accentColor.opacity(0.15) : Color.secondary.opacity(0.12))
                .clipShape(RoundedRectangle(cornerRadius: 12))
            if message.role == .assistant { Spacer(minLength: 40) }
        }
    }

    private func typing() -> some View {
        HStack(spacing: 4) {
            ForEach(0..<3) { _ in Circle().fill(Color.secondary).frame(width: 5, height: 5) }
        }
        .padding(.vertical, 6)
    }

    private var composer: some View {
        HStack(spacing: 8) {
            TextField("给 DSH 发一条消息", text: $draft, axis: .vertical)
                .lineLimit(1...5)
                .textFieldStyle(.roundedBorder)
            Button {
                let text = draft
                draft = ""
                gateway.send(text: text)
            } label: {
                Image(systemName: "arrow.up.circle.fill").font(.title2)
            }
            .disabled(draft.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty || gateway.openSessionId == nil)
        }
        .padding(.horizontal, 12)
        .padding(.vertical, 8)
    }
}

// MARK: - Connect

public struct DSHConnectSheet: View {
    @ObservedObject var gateway: DSHGateway
    @Environment(\.dismiss) private var dismiss
    let scan: (@escaping (String) -> Void) -> AnyView?
    @State private var message: String?
    @State private var pasted = ""

    /// Public so the host's Settings can offer pairing (the home no longer shows the status area).
    public init(gateway: DSHGateway, scan: @escaping (@escaping (String) -> Void) -> AnyView?) {
        self.gateway = gateway
        self.scan = scan
    }

    public var body: some View {
        NavigationStack {
            Form {
                Section {
                    Text("在 Mac 上打开 DSH 的侧栏「移动设备」，生成配对二维码，然后扫描它。")
                        .font(.footnote)
                }
                Section {
                    if let scanner = scan({ code in
                        Task { await pair(qrPayload: code) }
                    }) {
                        scanner.frame(height: 260)
                    } else {
                        Text("这个 App 暂时拿不到相机。")
                    }
                }
                Section("或粘贴配对内容") {
                    TextField("qrPayload", text: $pasted, axis: .vertical)
                        .lineLimit(2...4)
                        .font(.caption.monospaced())
                    Button("用这段内容配对") { Task { await pair(qrPayload: pasted) } }
                        .disabled(pasted.trimmingCharacters(in: .whitespaces).isEmpty)
                }
                if let message {
                    Section { Text(message).font(.footnote).foregroundStyle(.red) }
                } else {
                    Section { Text("配对中…").font(.footnote).foregroundStyle(.secondary) }
                }
            }
            .navigationTitle("连接 DSH")
            .toolbar { ToolbarItem(placement: .cancellationAction) { Button("关闭") { dismiss() } } }
        }
    }

    private func pair(qrPayload: String) async {
        // Copy/paste often brings leading/trailing whitespace or newlines along.
        let cleaned = qrPayload.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !cleaned.isEmpty else { message = "内容为空"; return }
        message = nil
        do {
            let code = try DSHPairingCode.decode(qrPayload: cleaned)
            _ = try await gateway.pair(code: code)
            dismiss()
        } catch {
            message = error.localizedDescription
        }
    }
}

