import CodyncKit
import CodyncUI
import DSHKit
import SwiftUI
import UIKit
import PhotosUI

struct AccountSwitcherButton: View {
    @Environment(AccountSession.self) private var account
    @Environment(AppStore.self) private var app
    /// The inner image size; the button/circle around it stays 44pt.
    var avatarSize: CGFloat = 40
    private let buttonSize: CGFloat = 44

    var body: some View {
        Button { app.accountPane = .account; account.showSwitcher = true } label: {
            Group {
                if account.isBusy || !account.isReady {
                    Spinner(size: 18).frame(width: avatarSize, height: avatarSize)
                } else {
                    AccountAvatar(url: account.avatarURL, email: account.email, size: avatarSize)
                }
            }
            .frame(width: buttonSize, height: buttonSize)
            .contentShape(Circle())
        }
        .buttonBorderShape(.circle)
        .accessibilityLabel(L10n.tr("Account"))
        .accessibilityValue(account.email ?? L10n.tr("Local account"))
    }
}

enum AccountPane: String, CaseIterable, Identifiable {
    case account, state, settings
    var id: Self { self }
    var title: String {
        switch self {
        case .account: "Account"
        case .state: "State"
        case .settings: "Settings"
        }
    }
    var screen: AnalyticsEvent.Screen {
        switch self {
        case .account: .account
        case .state: .state
        case .settings: .settings
        }
    }
}

/// The avatar sheet: the account profile and this iPhone's settings on one page,
/// with "状态" (widgets / Live Activity / Dynamic Island previews) on a pushed secondary page.
struct AccountSwitcherView: View {
    @Environment(AppStore.self) private var app
    @Environment(AccountSession.self) private var account
    @Environment(\.dismissModal) private var dismiss
    @State private var path: [AccountRoute] = []
    @State private var showPairing = false
    @State private var showVault = false
    @State private var showExtensions = false
    @State private var showComputersSheet = false
    @State private var showDSHConnect = false
    @State private var showHaptics = false
    @State private var showMainBot = false

    var body: some View {
        NavigationStack(path: $path) {
            Form {
                AccountProfileView(path: $path, showPairing: $showPairing, showVault: $showVault, showExtensions: $showExtensions)
                SettingsView(path: $path, showComputersSheet: $showComputersSheet,
                             showDSHConnect: $showDSHConnect, showHaptics: $showHaptics,
                             showMainBot: $showMainBot)
            }
            // No separators between rows: each row hides its own.
            .listRowSeparator(.hidden)
            .codyncSheet(isPresented: $showPairing) { PairingView(inModal: true) }
            .codyncSheet(isPresented: $showVault) {
                if let store = app.currentStore {
                    CredentialsView().environment(store)
                }
            }
            .codyncSheet(isPresented: $showExtensions) {
                if let store = app.currentStore {
                    MarketplaceView().environment(store)
                }
            }
            .codyncSheet(isPresented: $showComputersSheet) { ComputersView() }
            // Presented at the sheet root, not from a Form row: a row-level anchor is rebuilt and
            // would take the Settings sheet down with it (C0035).
            .sheet(isPresented: $showDSHConnect) {
                DSHConnectSheet(gateway: DSHGateway.shared, scan: { onCode in
                    AnyView(QRScanner(onCode: onCode, onError: { _ in }, acceptedPrefixes: nil))
                })
            }
            .sheet(isPresented: $showHaptics) { HapticsSettingsView() }
            // Also at the sheet root: the main bot is picked from a Settings row (C0035).
            .codyncSheet(isPresented: $showMainBot) { LeadBotPickerView() }
            .navigationTitle(L10n.tr("Settings"))
            .navigationBarTitleDisplayMode(.inline)
            .navigationDestination(for: AccountRoute.self) { route in
                switch route {
                case .state:
                    StateTab(active: true)
                        .navigationTitle(L10n.tr("State"))
                        .navigationBarTitleDisplayMode(.inline)
                case .profile:
                    ProfileEditView()
                        .navigationTitle("个人资料")
                        .navigationBarTitleDisplayMode(.inline)
                case .ordering:
                    OrderingView()
                        .navigationTitle("列表排序")
                        .navigationBarTitleDisplayMode(.inline)
                case .appearance:
                    AppearancePage()
                        .navigationTitle(L10n.tr("Theme"))
                        .navigationBarTitleDisplayMode(.inline)
                case .language:
                    LanguagePage()
                        .navigationTitle("语言")
                        .navigationBarTitleDisplayMode(.inline)
                }
            }
            .toolbar {
                if account.isBusy {
                    ToolbarItem(placement: .topBarLeading) {
                        ProgressView().accessibilityLabel(L10n.tr("Signing in"))
                    }
                }
                ToolbarItem(placement: .topBarTrailing) {
                    Button(action: {  dismiss()  }) { RemixImage("close-line", size: 24) }.accessibilityLabel(Text(L10n.tr("Close")))
                        .buttonBorderShape(.circle)
                        .keyboardShortcut(.cancelAction)
                }
            }
        }
        .tint(.primary)
        .softScrollEdges()
        .tracked(.screenViewed(app.accountPane.screen))
        .onChange(of: app.accountPane, initial: true) { _, pane in
            // Debug/deep-link opens (CODYNC_ACCOUNT_PANE=state, codync://usage): push the state page once.
            guard pane == .state else { return }
            if path.isEmpty { path = [.state] }
            app.accountPane = .settings
        }
    }
}

/// A pushed secondary page from the avatar sheet.
enum AccountRoute: Hashable { case state, profile, ordering, appearance, language }

private struct AccountProfileView: View {
    @Environment(AppStore.self) private var app
    @Environment(AccountSession.self) private var account
    @Environment(AccountStore.self) private var accounts
    @AppStorage(LocalProfile.nameKey) private var profileName = ""
    @AppStorage(LocalProfile.bioKey) private var profileBio = ""
    @Binding var path: [AccountRoute]
    @Binding var showPairing: Bool
    @Binding var showVault: Bool
    @Binding var showExtensions: Bool
    @State private var addingAccount = false
    @State private var avatarImage: UIImage?

    var body: some View {
        Group {
            // One grouped card (Grok style): editable profile on top, then connections and the vault.
            Section {
                Button { path.append(.profile) } label: {
                    HStack(spacing: 12) {
                        profileAvatar
                            .frame(width: 28, height: 28)
                        VStack(alignment: .leading, spacing: 2) {
                            Text(displayName).font(.body.weight(.medium)).lineLimit(1).truncationMode(.middle)
                            Text(displayBio).font(.subheadline).foregroundStyle(.secondary).lineLimit(1)
                        }
                        Spacer(minLength: 8)
                        RemixIcon("arrow-right-s-line", size: 20).foregroundStyle(.tertiary)
                    }
                }
                .listRowSeparator(.hidden)

                Button { path.append(.state) } label: {
                    SettingsRow("pulse-line", title: "状态")
                }

                Button { path.append(.ordering) } label: {
                    SettingsRow("arrow-up-down-line", title: "排序")
                }

                Button { showVault = true } label: {
                    SettingsRow("shield-keyhole-line", title: "凭证")
                }
                .disabled(app.currentStore == nil)

                Button { showExtensions = true } label: {
                    SettingsRow("plug-line", title: "连接")
                }
                .disabled(app.currentStore == nil)
            }
            .listRowSeparator(.hidden)

            if !account.isSignedIn && account.isConfigured {
                Section { SignInButtons() }
            .listRowSeparator(.hidden)
            }

            if account.isSignedIn, account.supportsMultipleAccounts || account.accounts.count > 1 {
                Section {
                    ForEach(account.accounts) { item in
                        Button { Task { await account.switchAccount(item) } } label: {
                            HStack(spacing: 12) {
                                AccountAvatar(url: item.avatarURL, email: item.email, size: 36)
                                Text(item.email).lineLimit(1).truncationMode(.middle)
                                Spacer()
                                if item.id == account.userID { RemixIcon("check-line") }
                            }
                        }
                        .disabled(account.isBusy || item.id == account.userID)
                        .accessibilityAddTraits(item.id == account.userID ? .isSelected : [])
                    }
                    if account.supportsMultipleAccounts {
                        Button { withAnimation(Motion.layout) { addingAccount.toggle() } } label: {
                            Label { Text(L10n.tr("Add account")) } icon: { RemixIcon("add-line") }
                        }
                        .disabled(account.isBusy)
                    }
                    if addingAccount { SignInButtons() }
                }
            .listRowSeparator(.hidden)
            }
            if let message = account.errorMessage {
                Section {
                    Label { Text(L10n.tr(message)) } icon: { RemixIcon("alert-fill") }
                        .font(.footnote).foregroundStyle(.red)
                }
            .listRowSeparator(.hidden)
            }
        }
        .onAppear { avatarImage = LocalProfile.loadAvatar() }
        .onChange(of: account.userID) { _, _ in addingAccount = false }
    }

    private var displayName: String {
        let n = profileName.trimmingCharacters(in: .whitespacesAndNewlines)
        if !n.isEmpty { return n }
        return account.email ?? "本地账户"
    }

    private var displayBio: String {
        let b = profileBio.trimmingCharacters(in: .whitespacesAndNewlines)
        if !b.isEmpty { return b }
        if let e = account.email, !e.isEmpty { return e }
        return "编辑名称与说明"
    }

    @ViewBuilder private var profileAvatar: some View {
        if let image = avatarImage {
            Image(uiImage: image).resizable().scaledToFill()
                .frame(width: 28, height: 28).clipShape(Circle())
        } else {
            AccountAvatar(url: account.avatarURL, email: account.email, size: 28)
        }
    }
}

/// The account's photo or initial; local mode uses the bundled default photo.
struct AccountAvatar: View {
    let url: URL?
    var email: String?
    let size: CGFloat

    var body: some View {
        AsyncImage(url: url) { phase in
            if let image = phase.image {
                image.resizable().scaledToFill()
            } else {
                ZStack {
                    Circle().fill(Palette.bubbleUser)
                    if let letter = email?.first {
                        Text(String(letter).uppercased())
                            .font(.system(size: size * 0.42, weight: .semibold))
                            .foregroundStyle(Palette.text)
                    } else {
                        Image("LocalDefaultAvatar")
                            .resizable()
                            .scaledToFill()
                    }
                }
            }
        }
        .frame(width: size, height: size)
        .clipShape(Circle())
        .accessibilityHidden(true)
    }
}

/// Device-only personal profile shown on the avatar sheet: display name, description and avatar.
/// Nothing is uploaded; it lives in this iPhone's UserDefaults and Application Support.
enum LocalProfile {
    static let nameKey = "profileDisplayName"
    static let bioKey = "profileBio"

    static var avatarFileURL: URL {
        let dir = FileManager.default.urls(for: .applicationSupportDirectory, in: .userDomainMask)[0]
        return dir.appendingPathComponent("local-profile-avatar.jpg")
    }

    static func loadAvatar() -> UIImage? {
        guard let data = try? Data(contentsOf: avatarFileURL) else { return nil }
        return UIImage(data: data)
    }

    static func saveAvatar(_ data: Data?) {
        guard let data, let image = UIImage(data: data), let jpeg = image.jpegData(compressionQuality: 0.85) else {
            try? FileManager.default.removeItem(at: avatarFileURL)
            return
        }
        try? FileManager.default.createDirectory(at: avatarFileURL.deletingLastPathComponent(), withIntermediateDirectories: true)
        try? jpeg.write(to: avatarFileURL)
    }
}

/// Native edit page for the local profile: photo (PhotosPicker), name and description.
struct ProfileEditView: View {
    @Environment(\.dismiss) private var dismiss
    @AppStorage(LocalProfile.nameKey) private var name = ""
    @AppStorage(LocalProfile.bioKey) private var bio = ""
    @State private var avatar: UIImage?
    @State private var pickerItem: PhotosPickerItem?

    var body: some View {
        Form {
            Section {
                VStack(spacing: 12) {
                    avatarPreview
                    PhotosPicker(selection: $pickerItem, matching: .images) {
                        Text("选择照片")
                    }
                    .buttonStyle(.bordered)
                    if avatar != nil {
                        Button("移除照片", role: .destructive) {
                            LocalProfile.saveAvatar(nil)
                            avatar = nil
                        }
                        .font(.footnote)
                    }
                }
                .frame(maxWidth: .infinity)
                .padding(.vertical, 8)
            }
            .listRowSeparator(.hidden)
            Section("显示") {
                TextField("名称", text: $name)
                TextField("说明", text: $bio, axis: .vertical)
                    .lineLimit(1...3)
            }
        }
        .navigationTitle("个人资料")
        .navigationBarTitleDisplayMode(.inline)
        .toolbar {
            ToolbarItem(placement: .confirmationAction) {
                Button("完成") { dismiss() }
            }
        }
        .onAppear { avatar = LocalProfile.loadAvatar() }
        .onChange(of: pickerItem) { _, item in
            guard let item else { return }
            Task {
                if let data = try? await item.loadTransferable(type: Data.self) {
                    LocalProfile.saveAvatar(data)
                    avatar = LocalProfile.loadAvatar()
                }
            }
        }
    }

    @ViewBuilder private var avatarPreview: some View {
        if let avatar {
            Image(uiImage: avatar).resizable().scaledToFill()
                .frame(width: 88, height: 88).clipShape(Circle())
        } else {
            AccountAvatar(url: nil, email: nil, size: 88)
        }
    }
}
