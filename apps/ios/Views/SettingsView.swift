import CodyncKit
import CodyncUI
import SwiftUI

/// The Settings tab: what belongs to this iPhone alone (appearance, language, the lead shortcuts call,
/// notification permission, analytics, Start over). Each computer's own settings (voice chat, push, connection, hidden bots) are in
/// Computer management (`ComputersView`).
struct SettingsView: View {
    @Environment(AppStore.self) private var app
    @Environment(\.openURL) private var openURL
    @Environment(\.scenePhase) private var scenePhase
    @State private var notificationsAllowed: Bool?
    @AppStorage(Analytics.enabledKey) private var analyticsEnabled = true
    @State private var confirmStartOver = false
    @State private var aboutAnalytics = false
    /// Easter egg: ten quick taps on the version reveal Start over, so it can't be hit by mistake.
    @State private var versionTaps = 0
    @State private var lastVersionTap = Date.distantPast
    @State private var showStartOver = false

    var body: some View {
        Group {
            // Notifications, appearance and language share one grouped card.
            Section {
                notificationsRow
                AppearanceSettings()
                LanguageSettings()
            }

            // Chat (thinking details) and usage analytics share one grouped card.
            Section {
                ThinkingDetailsSettings()
                analyticsRow
            }

            ShortcutLeadSettings()

            // The version row is the hidden trigger for Start over.
            Section {
                LabeledContent(L10n.tr("App version"), value: appVersion)
                    .contentShape(Rectangle())
                    .onTapGesture(perform: tappedVersion)
            }

            if showStartOver {
                Section {
                    Button(role: .destructive) { confirmStartOver = true } label: {
                        Label { Text(L10n.tr("Start over")) } icon: { RemixIcon("restart-line") }
                            .foregroundStyle(.red)
                    }
                }
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
        .codyncSheet(isPresented: $aboutAnalytics) { AnalyticsSheet() }
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

    private var analyticsRow: some View {
        Toggle(isOn: Binding(get: { analyticsEnabled }, set: { Analytics.shared.setEnabled($0) })) {
            HStack(spacing: 4) {
                Text(L10n.tr("Share usage analytics"))
                Button {  aboutAnalytics = true  } label: { Label { Text(L10n.tr("About usage analytics")) } icon: { RemixIcon("information-line") } }
                    .labelStyle(.iconOnly).buttonStyle(.borderless)
            }
        }
        .toggleStyle(.switch)
        .accessibilityLabel(L10n.tr("Share usage analytics"))
    }

    private var notificationsRow: some View {
        Button {
            if notificationsAllowed != nil {
                UIApplication.shared.open(URL(string: UIApplication.openNotificationSettingsURLString)!)
            } else {
                Task { notificationsAllowed = await PushRegistrar.shared.requestAuthorization(from: .settings) }
            }
        } label: {
            HStack {
                Text(L10n.tr("Notifications"))
                Spacer()
                Text(L10n.tr(notificationsAllowed == true ? "On" : notificationsAllowed == false ? "Off in Settings" : "Turn on"))
                    .foregroundStyle(.secondary)
                RemixIcon("arrow-right-s-line").font(.footnote.weight(.semibold)).foregroundStyle(.tertiary)
            }
        }
        .buttonStyle(.plain)
    }
}
