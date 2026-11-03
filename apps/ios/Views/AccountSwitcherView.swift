import CodyncKit
import CodyncUI
import SwiftUI
import UIKit
import PhotosUI

struct AccountSwitcherButton: View {
    @Environment(AccountSession.self) private var account
    @Environment(AppStore.self) private var app
    private let avatarSize: CGFloat = 40
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

    var body: some View {
        NavigationStack(path: $path) {
            Form {
                AccountProfileView(showPairing: $showPairing, showVault: $showVault, showExtensions: $showExtensions, showComputersSheet: $showComputersSheet)
                SettingsView()
            }
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
                }
            }
            .toolbar {
                if account.isBusy {
                    ToolbarItem(placement: .topBarLeading) {
                        ProgressView().accessibilityLabel(L10n.tr("Signing in"))
                    }
                }
                ToolbarItem(placement: .topBarTrailing) {
                    Button(L10n.tr("Close"), systemImage: "xmark") { dismiss() }
                        .labelStyle(.iconOnly)
                        .buttonBorderShape(.circle)
                        .keyboardShortcut(.cancelAction)
                }
            }
        }
        .tint(.primary)
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
enum AccountRoute: Hashable { case state, profile, ordering }

private struct AccountProfileView: View {
    @Environment(AppStore.self) private var app
    @Environment(AccountSession.self) private var account
    @Environment(AccountStore.self) private var accounts
    @AppStorage(LocalProfile.nameKey) private var profileName = ""
    @AppStorage(LocalProfile.bioKey) private var profileBio = ""
    @State private var confirmSignOut = false
    @State private var confirmDelete = false
    @Binding var showPairing: Bool
    @Binding var showVault: Bool
    @Binding var showExtensions: Bool
    @Binding var showComputersSheet: Bool
    @State private var addingAccount = false
    @State private var avatarImage: UIImage?

    var body: some View {
        Group {
            // One grouped card (Grok style): editable profile on top, then connections and the vault.
            Section {
                NavigationLink(value: AccountRoute.profile) {
                    HStack(spacing: 12) {
                        profileAvatar
                        VStack(alignment: .leading, spacing: 2) {
                            Text(displayName).font(.headline).lineLimit(1).truncationMode(.middle)
                            Text(displayBio).font(.subheadline).foregroundStyle(.secondary).lineLimit(1)
                        }
                        Spacer(minLength: 8)
                    }
                }

                Button { showPairing = true } label: {
                    HStack {
                        Text("配对")
                        Spacer(minLength: 8)
                        Image(systemName: "chevron.right").font(.footnote.weight(.semibold)).foregroundStyle(.tertiary)
                    }
                }

                Button { showComputersSheet = true } label: {
                    HStack {
                        Text("电脑")
                        Spacer(minLength: 8)
                        if !accounts.computers.isEmpty {
                            Text("\(accounts.computers.count) 台已连接").foregroundStyle(.secondary)
                        }
                        Image(systemName: "chevron.right").font(.footnote.weight(.semibold)).foregroundStyle(.tertiary)
                    }
                }

                NavigationLink(value: AccountRoute.state) {
                    Text("状态")
                }

                Button { showVault = true } label: {
                    HStack {
                        VStack(alignment: .leading, spacing: 2) {
                            Text("凭证")
                            Text("可以使用的登录信息、卡片和联系信息")
                                .font(.subheadline).foregroundStyle(.secondary).lineLimit(1)
                        }
                        Spacer(minLength: 8)
                        Image(systemName: "chevron.right").font(.footnote.weight(.semibold)).foregroundStyle(.tertiary)
                    }
                }
                .disabled(app.currentStore == nil)
            }

            // A separate list that opens the Extensions (marketplace) page.
            Section {
                Button { showExtensions = true } label: {
                    HStack {
                        VStack(alignment: .leading, spacing: 2) {
                            Text("连接应用")
                            Text("搜索插件")
                                .font(.subheadline).foregroundStyle(.secondary)
                        }
                        Spacer(minLength: 8)
                        Image(systemName: "chevron.right").font(.footnote.weight(.semibold)).foregroundStyle(.tertiary)
                    }
                }
                .disabled(app.currentStore == nil)
            }

            Section {
                NavigationLink(value: AccountRoute.ordering) {
                    HStack {
                        Text("列表排序")
                        Spacer(minLength: 8)
                        Image(systemName: "chevron.right").font(.footnote.weight(.semibold)).foregroundStyle(.tertiary)
                    }
                }
            }

            if !account.isSignedIn && account.isConfigured {
                Section { SignInButtons() }
            }

            if account.isSignedIn, account.supportsMultipleAccounts || account.accounts.count > 1 {
                Section {
                    ForEach(account.accounts) { item in
                        Button { Task { await account.switchAccount(item) } } label: {
                            HStack(spacing: 12) {
                                AccountAvatar(url: item.avatarURL, email: item.email, size: 36)
                                Text(item.email).lineLimit(1).truncationMode(.middle)
                                Spacer()
                                if item.id == account.userID { Image(systemName: "checkmark") }
                            }
                        }
                        .disabled(account.isBusy || item.id == account.userID)
                        .accessibilityAddTraits(item.id == account.userID ? .isSelected : [])
                    }
                    if account.supportsMultipleAccounts {
                        Button { withAnimation(Motion.layout) { addingAccount.toggle() } } label: {
                            Label(L10n.tr("Add account"), systemImage: "plus")
                        }
                        .disabled(account.isBusy)
                    }
                    if addingAccount { SignInButtons() }
                }
            }
            if account.isSignedIn {
                Section {
                    Button(L10n.tr("Sign out"), role: .destructive) { confirmSignOut = true }
                        .disabled(account.isBusy)
                    Button(L10n.tr("Delete account"), role: .destructive) { confirmDelete = true }
                        .disabled(account.isBusy)
                }
            }
            if let message = account.errorMessage {
                Section {
                    Label(L10n.tr(message), systemImage: "exclamationmark.triangle.fill")
                        .font(.footnote).foregroundStyle(.red)
                }
            }
        }
        .onAppear { avatarImage = LocalProfile.loadAvatar() }
        .onChange(of: account.userID) { _, _ in addingAccount = false }
        .confirmationDialog(L10n.tr("Sign out of \(account.email ?? "this account")?"), isPresented: $confirmSignOut, titleVisibility: .visible) {
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
                .frame(width: 44, height: 44).clipShape(Circle())
        } else {
            AccountAvatar(url: account.avatarURL, email: account.email, size: 44)
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
