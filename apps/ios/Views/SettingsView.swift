import CodyncKit
import CodyncUI
import DSHKit
import SwiftUI
import UIKit

/// This iPhone's settings, grouped: account rows come first from `AccountProfileView`, then the
/// computers/sources, then notifications & appearance, and finally the destructive rows (revealed
/// by ten taps on the version).
struct SettingsView: View {
    @Binding var path: [AccountRoute]
    @Binding var showComputersSheet: Bool
    @Binding var showDSHConnect: Bool
    @Binding var showHaptics: Bool
    @Environment(AppStore.self) private var app
    @Environment(AccountSession.self) private var account
    @Environment(\.openURL) private var openURL
    @Environment(\.scenePhase) private var scenePhase

    @ObservedObject private var dsh = DSHGateway.shared
    @AppStorage(HomeSourcePrefs.sourcesKey) private var sourcesRaw = HomeSourcePrefs.defaultRaw
    @AppStorage(Haptics.storageKey) private var hapticsRaw = HapticsLevel.medium.rawValue

    @State private var notificationsAllowed: Bool?
    @State private var confirmSignOut = false
    @State private var confirmDelete = false
    @State private var confirmStartOver = false
    /// Easter egg: ten quick taps on the version reveal the destructive rows.
    @State private var versionTaps = 0
    @State private var lastVersionTap = Date.distantPast
    @State private var showAdvanced = false

    var body: some View {
        Group {
            // 电脑 + DSH 连接 + 三个首页来源开关：一组，不要组标题。
            Section {
                Button { showComputersSheet = true } label: {
                    SettingsRow("computer-line", title: "电脑",
                                value: app.accounts.computers.isEmpty ? nil : "\(app.accounts.computers.count) 台已连接")
                }
                .buttonStyle(.plain)

                Button { showDSHConnect = true } label: {
                    SettingsRow("link", title: "DSH 连接", value: dshStatus)
                }
                .buttonStyle(.plain)

                ForEach(HomeSource.allCases) { source in
                    Toggle(isOn: Binding(get: { enabledSources.contains(source) },
                                        set: { setSource(source, on: $0) })) {
                        Label { Text(source.title) } icon: { HomeSourceIcon(source: source) }
                    }
                }
            }
            .listRowSeparator(.hidden)

            // 未提及项：快捷指令默认主 Bot 的电脑，放在「电脑」这一组之后。
            ShortcutLeadSettings()

            // 通知、主题、应用语言、触感、思考细节。
            Section {
                notificationsRow
                AppearanceRow { path.append(.appearance) }
                LanguageRow { path.append(.language) }
                hapticsRow
                ThinkingDetailsSettings()
            }
            .listRowSeparator(.hidden)

            // The app mark, name and version: the ten-tap trigger for the destructive rows.
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

            if showAdvanced {
                Section {
                    if account.isSignedIn {
                        Button(L10n.tr("Sign out"), role: .destructive) { confirmSignOut = true }
                            .disabled(account.isBusy)
                        Button(L10n.tr("Delete account"), role: .destructive) { confirmDelete = true }
                            .disabled(account.isBusy)
                    }
                    Button(role: .destructive) { confirmStartOver = true } label: {
                        SettingsRow("restart-line", title: L10n.tr("Start over"), destructive: true, chevron: false)
                    }
                }
                .listRowSeparator(.hidden)
            }
        }
        .tint(.primary)
        .confirmationDialog(L10n.tr("Sign out of \(account.email ?? "this account")?"),
                            isPresented: $confirmSignOut, titleVisibility: .visible) {
            Button(L10n.tr("Sign out"), role: .destructive) { Task { await app.signOut() } }
            Button(L10n.tr("Cancel"), role: .cancel) {}
        } message: {
            Text(L10n.tr("This iPhone stops getting the account's notifications and keeps its computers, so signing back in needs no scan. To take it off them, use Start over in Settings instead."))
        }
        .alert(L10n.tr("Delete your Codync account?"), isPresented: $confirmDelete) {
            Button(L10n.tr("Delete account"), role: .destructive) { Task { await app.deleteAccount() } }
            Button(L10n.tr("Cancel"), role: .cancel) {}
        } message: {
            Text(L10n.tr("Your account, its list of computers and every device's access through it are deleted. Your computers keep their bots and chats. This can't be undone."))
        }
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

    /// Ten quick taps on the version row reveal sign out / delete / start over; slow taps restart.
    private func tappedVersion() {
        let now = Date()
        versionTaps = now.timeIntervalSince(lastVersionTap) > 2 ? 1 : versionTaps + 1
        lastVersionTap = now
        if versionTaps >= 10 && !showAdvanced {
            withAnimation { showAdvanced = true }
            versionTaps = 0
        }
    }

    private var notificationsRow: some View {
        Toggle(isOn: Binding(get: { notificationsAllowed == true }, set: { on in
            if on {
                Task { notificationsAllowed = await PushRegistrar.shared.requestAuthorization(from: .settings) }
            } else if let url = URL(string: UIApplication.openNotificationSettingsURLString) {
                // iOS has no API to revoke; send the user to the system switch.
                UIApplication.shared.open(url)
            }
        })) {
            Label { Text(L10n.tr("Notifications")) } icon: { RemixIcon("notification-3-line") }
        }
    }

    private var hapticsRow: some View {
        Button { showHaptics = true } label: {
            SettingsRow("smartphone-line", title: "触感",
                        value: HapticsLevel(rawValue: hapticsRaw)?.title ?? HapticsLevel.medium.title)
        }
        .buttonStyle(.plain)
    }

    private var dshStatus: String {
        switch dsh.phase {
        case .idle: return "未连接"
        case .connecting: return "连接中…"
        case .ready: return "已连接"
        case .failed: return "连接失败"
        }
    }

    private var enabledSources: Set<HomeSource> { HomeSourcePrefs.enabled(from: sourcesRaw) }

    private func setSource(_ source: HomeSource, on: Bool) {
        var set = enabledSources
        if on {
            set.insert(source)
        } else {
            guard set.count > 1 else { return }
            set.remove(source)
        }
        sourcesRaw = HomeSourcePrefs.raw(set)
    }
}

/// 触感：五档单选，选中时立刻震一下；「关」让全 App 不再震。
struct HapticsSettingsView: View {
    @Environment(\.dismiss) private var dismiss
    @AppStorage(Haptics.storageKey) private var raw = HapticsLevel.medium.rawValue

    var body: some View {
        NavigationStack {
            List {
                ForEach(HapticsLevel.allCases) { level in
                    Button {
                        raw = level.rawValue
                        Haptics.preview(level)
                    } label: {
                        HStack {
                            Text(level.title)
                            Spacer()
                            if raw == level.rawValue {
                                Image(systemName: "checkmark").font(.body.weight(.semibold))
                            }
                        }
                        .contentShape(Rectangle())
                    }
                    .buttonStyle(.plain)
                }
            }
            .navigationTitle("触感")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .cancellationAction) { Button("关闭") { dismiss() } }
            }
        }
    }
}

/// The home source's icon: the COE agent glyph from the design files, Remix's DeepSeek and chat-ai.
private struct HomeSourceIcon: View {
    let source: HomeSource

    var body: some View {
        Group {
            switch source {
            case .coe:
                RemixIcon("ghost-4-line", size: 18).foregroundStyle(.primary)
            case .dsBot:
                RemixIcon("deepseek-line", size: 18).foregroundStyle(.primary)
            case .dsh:
                RemixIcon("chat-ai-line", size: 18).foregroundStyle(.primary)
            }
        }
        .frame(width: 22, height: 22)
    }
}
