import CodyncKit
import CodyncUI
import DSHKit
import SwiftUI
import UIKit

/// The Settings tab: what belongs to this iPhone alone (appearance, language, the lead shortcuts call,
/// notification permission, analytics, Start over). Each computer's own settings (voice chat, push, connection, hidden bots) are in
/// Computer management (`ComputersView`).
struct SettingsView: View {
    @Binding var path: [AccountRoute]
    @Environment(AppStore.self) private var app
    @Environment(\.openURL) private var openURL
    @Environment(\.scenePhase) private var scenePhase
    @State private var notificationsAllowed: Bool?
    @State private var confirmStartOver = false
    /// Easter egg: ten quick taps on the version reveal Start over, so it can't be hit by mistake.
    @State private var versionTaps = 0
    @State private var lastVersionTap = Date.distantPast
    @State private var showStartOver = false
    /// 首页布局：混排 / 分页（先放在调试区）。
    @AppStorage(HomeSourcePrefs.layoutKey) private var layoutRaw = HomeLayout.mixed.rawValue

    var body: some View {
        Group {
            // Notifications, appearance and language share one grouped card.
            Section {
                notificationsRow
                AppearanceRow { path.append(.appearance) }
                LanguageRow { path.append(.language) }
                ThinkingDetailsSettings()
            }
            .listRowSeparator(.hidden)

            ShortcutLeadSettings()

            // 调试：首页布局先放在这里，方便对比混排和分页。
            Section {
                Picker(L10n.tr("首页布局"), selection: $layoutRaw) {
                    Text("混排").tag(HomeLayout.mixed.rawValue)
                    Text("分页").tag(HomeLayout.paged.rawValue)
                }
                .pickerStyle(.segmented)
            } header: {
                Text("调试")
            }
            .listRowSeparator(.hidden)

            // DSH 配对状态搬到这里：首页不再显示状态区。
            DSHSettingsSection()

            // The app mark, name and version: the hidden trigger for Start over.
            Section {
                VStack(spacing: 10) {
                    if let mark = UIImage(named: "AppMark") {
                        Image(uiImage: mark)
                            .resizable()
                            .scaledToFit()
                            .frame(width: 68, height: 68)
                            .clipShape(RoundedRectangle(cornerRadius: 16, style: .continuous))
                    }
                    Text(appName).font(.headline)
                    Text(appVersion).font(.footnote).foregroundStyle(.secondary)
                }
                .frame(maxWidth: .infinity)
                .padding(.vertical, 16)
                .contentShape(Rectangle())
                .onTapGesture(perform: tappedVersion)
                .listRowBackground(Color.clear)
                .listRowSeparator(.hidden)
            }
            .listRowSeparator(.hidden)

            if showStartOver {
                Section {
                    Button(role: .destructive) { confirmStartOver = true } label: {
                        SettingsRow("restart-line", title: L10n.tr("Start over"), destructive: true, chevron: false)
                    }
                }
            .listRowSeparator(.hidden)
            }
        }
        .tint(.primary)
        .alert(L10n.tr("Start over?"), isPresented: $confirmStartOver) {
            Button(L10n.tr("Start over"), role: .destructive) { Task { await app.startOver() } }
            Button(L10n.tr("Cancel"), role: .cancel) {}
        } message: {
            Text(L10n.tr("Signs out of every account and forgets every computer on this iPhone, then shows the welcome again. Your computers keep their bots and chats; pair again to use them."))
        }
        .task { notificationsAllowed = await PushRegistrar.shared.isAllowed() }
        // The tab stays alive: coming back from iOS Settings reads the permission again.
        .onChange(of: scenePhase) { _, phase in
            if phase == .active { Task { notificationsAllowed = await PushRegistrar.shared.isAllowed() } }
        }
    }

    private var appName: String {
        Bundle.main.object(forInfoDictionaryKey: "CFBundleDisplayName") as? String ?? "Sully Coe"
    }

    private var appVersion: String {
        Bundle.main.infoDictionary?["CFBundleShortVersionString"] as? String ?? ""
    }

    /// Ten quick taps on the version row reveal Start over; slow taps restart the count.
    private func tappedVersion() {
        let now = Date()
        versionTaps = now.timeIntervalSince(lastVersionTap) > 2 ? 1 : versionTaps + 1
        lastVersionTap = now
        if versionTaps >= 10 && !showStartOver {
            withAnimation { showStartOver = true }
            versionTaps = 0
        }
    }

    private var notificationsRow: some View {
        Button {
            if notificationsAllowed != nil {
                UIApplication.shared.open(URL(string: UIApplication.openNotificationSettingsURLString)!)
            } else {
                Task { notificationsAllowed = await PushRegistrar.shared.requestAuthorization(from: .settings) }
            }
        } label: {
            SettingsRow("notification-3-line", title: L10n.tr("Notifications"),
                        value: L10n.tr(notificationsAllowed == true ? "On" : notificationsAllowed == false ? "Off in Settings" : "Turn on"))
        }
        .buttonStyle(.plain)
    }
}

/// DSH 配对状态与入口。首页移除状态区后，配对状态在这里显示，需要时打开配对页。
@MainActor
private struct DSHSettingsSection: View {
    @ObservedObject private var gateway = DSHGateway.shared
    @State private var showConnect = false

    var body: some View {
        Section {
            Button {
                showConnect = true
            } label: {
                SettingsRow("link", title: "DSH 连接", value: statusText)
            }
            .buttonStyle(.plain)
            .sheet(isPresented: $showConnect) {
                DSHConnectSheet(gateway: gateway, scan: { onCode in
                    AnyView(QRScanner(onCode: onCode, onError: { _ in }, acceptedPrefixes: nil))
                })
            }
        } header: {
            Text("DSH")
        }
        .listRowSeparator(.hidden)
    }

    private var statusText: String {
        switch gateway.phase {
        case .idle: return "未连接"
        case .connecting: return "连接中…"
        case .ready: return "已连接（\(gateway.gatewayName)）"
        case .failed: return "连接失败"
        }
    }
}
