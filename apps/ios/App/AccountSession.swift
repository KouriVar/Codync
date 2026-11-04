import CodyncKit
import Foundation
@preconcurrency import GoogleSignIn
import Observation
import UIKit

/// Google is the account: the phone signs in with Google and proves it to the computer at pairing
/// with a Google ID token. There is no Codync cloud account here; each computer still approves
/// this device's key (spec §4.2), and after pairing the E2E channel is the existing one.
@MainActor
@Observable
final class AccountSession {
    private(set) var isBusy = false
    var errorMessage: String?

    var showSwitcher = false

    struct Account: Identifiable {
        let id: String
        let sessionID: String
        let email: String
        let avatarURL: URL?
    }

    // Only Sendable facts about the signed-in Google user are kept; the SDK's objects stay in the SDK.
    private var googleUserID: String?
    private var googleEmail: String?
    private var googleAvatar: URL?
    private var didRestore = false

    var userID: String? { googleUserID }
    var accounts: [Account] {
        guard let id = googleUserID else { return [] }
        return [Account(id: id, sessionID: id, email: googleEmail ?? "Google account", avatarURL: googleAvatar)]
    }
    var supportsMultipleAccounts: Bool { false }

    /// Google sign-in is always available in this build.
    var isConfigured: Bool { true }
    /// The previous sign-in (if any) has been restored from the Keychain.
    var isReady: Bool { didRestore }
    var restoreFailed: Bool { false }
    func retryRestore() async { restore(); didRestore = true }
    func waitUntilReady(timeout: Duration) async -> Bool {
        let deadline = ContinuousClock.now + timeout
        while !isReady, !Task.isCancelled, ContinuousClock.now < deadline {
            try? await Task.sleep(for: .milliseconds(100))
        }
        return isReady
    }

    /// The Codync cloud (accounts and the encrypted relay): off in this build, so nil.
    let cloudURL: URL? = nil
    var isSignedIn: Bool { googleUserID != nil }
    var email: String? { googleEmail }
    var avatarURL: URL? { googleAvatar }

    init() {
        restore()
        didRestore = true
    }

    /// Loads the previous Google sign-in, when there is one.
    private func restore() {
        guard GIDSignIn.sharedInstance.hasPreviousSignIn() else { return }
        GIDSignIn.sharedInstance.restorePreviousSignIn { [weak self] _, _ in
            Task { @MainActor in self?.readCurrentUser() }
        }
    }

    /// Copies the SDK's current user into the Sendable facts above.
    private func readCurrentUser() {
        let user = GIDSignIn.sharedInstance.currentUser
        googleUserID = user?.userID
        googleEmail = user?.profile?.email
        googleAvatar = avatarURL(of: user)
    }

    private func avatarURL(of user: GIDGoogleUser?) -> URL? {
        guard let user, user.profile?.hasImage == true else { return nil }
        return user.profile?.imageURL(withDimension: 96)
    }

    /// A Google ID token for pairing. Refreshes first when it has expired.
    func googleIDToken() async throws -> String {
        guard let user = GIDSignIn.sharedInstance.currentUser else { throw SessionError.signedOut }
        let refreshed = try await user.refreshTokensIfNeeded()
        guard let token = refreshed.idToken?.tokenString else { throw SessionError.signedOut }
        return token
    }

    /// No Codync cloud in this build.
    func cloudClient(for userID: String?, identity: DeviceIdentity?) -> CloudClient? { nil }

    func signIn(provider: AnalyticsEvent.SignInProvider) async {
        guard !isBusy else { return }
        Analytics.shared.capture(.signInStarted(.google))
        isBusy = true
        errorMessage = nil
        defer { isBusy = false }
        do {
            _ = try await GIDSignIn.sharedInstance.signIn(withPresenting: presentingViewController())
            readCurrentUser()
            didRestore = true
            Analytics.shared.capture(.signedIn(.google))
        } catch {
            let ns = error as NSError
            if ns.domain == "com.google.GIDSignIn", ns.code == -5 {
                Analytics.shared.capture(.signInFailed(.google, reason: .cancelled))
                return
            }
            errorMessage = "Couldn't sign in with Google. Check your connection and try again."
            Analytics.shared.capture(.signInFailed(.google, reason: .error))
        }
    }

    func signOut() async {
        GIDSignIn.sharedInstance.signOut()
        googleUserID = nil
        googleEmail = nil
        googleAvatar = nil
    }

    func signOutAll() async {
        await signOut()
    }

    /// Deleting the account is not offered: signing out is all this build does.
    func deleteUser() async throws {
        await signOut()
    }

    func switchAccount(_ account: Account) async {}

    /// Google Sign-In's redirect (`com.googleusercontent.apps.…`). True when it was ours.
    @discardableResult
    func handle(_ url: URL) -> Bool {
        GIDSignIn.sharedInstance.handle(url)
    }

    enum SessionError: LocalizedError {
        case signedOut
        var errorDescription: String? { "Sign in with Google again to reach your computer." }
    }

    private func presentingViewController() -> UIViewController {
        let scenes = UIApplication.shared.connectedScenes.compactMap { $0 as? UIWindowScene }
        let scene = scenes.first { $0.activationState == .foregroundActive } ?? scenes.first
        let root = scene?.keyWindow?.rootViewController ?? scene?.windows.first?.rootViewController
        var top = root
        while let presented = top?.presentedViewController { top = presented }
        return top ?? UIViewController()
    }
}
