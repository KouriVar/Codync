import CodyncKit
import CodyncUI
import SwiftUI
import WidgetKit

struct RootView: View {
    @Environment(AppStore.self) private var app
    @Environment(AccountStore.self) private var accounts
    @Environment(AccountSession.self) private var account
    @AppStorage("onboardingCompleted") private var onboardingCompleted = false
    @Environment(\.accessibilityReduceMotion) private var reduceMotion
    /// First launch only: past the welcome, on to setup.
    @State private var welcomed = false

    /// The open bot, as a NavigationStack path.
    private var path: Binding<[BotReference]> {
        Binding(get: { accounts.selection.map { [$0] } ?? [] }, set: { accounts.selection = $0.last })
    }

    var body: some View {
        Group {
            if mustSignIn {
                // Computers paired before sign-in was required wait in the signed-out context.
                WelcomeView(signedOutComputers: accounts.computers.count) {}
                    .transition(.opacity)
            } else if !onboardingCompleted && accounts.computers.isEmpty && accounts.cloudComputers.isEmpty {
                if !welcomed && !account.isSignedIn {
                    WelcomeView { withAnimation(Motion.reduced(Motion.layout, reduceMotion)) { welcomed = true } }
                        .transition(.move(edge: .leading).combined(with: .opacity))
                } else {
                    PairingView(onSkip: { completeOnboarding(via: .skipped) }) {
                        if account.isSignedIn {
                            AccountSwitcherButton()
                        } else {
                            BackButton { withAnimation(Motion.reduced(Motion.layout, reduceMotion)) { welcomed = false } }
                        }
                    }
                    .transition(.move(edge: .trailing).combined(with: .opacity))
                }
            } else {
                home
            }
        }
        .background(Palette.background)
        .onChange(of: accounts.computers.isEmpty && accounts.cloudComputers.isEmpty, initial: true) { _, empty in
            // Pairing, signing in to an account that has computers, or explicitly skipping completes
            // setup. Keep this device-level milestone across account changes and unpairing.
            if !empty { completeOnboarding(via: accounts.cloudComputers.isEmpty ? .paired : .account) }
        }
        .codyncDialog("Something went wrong", isPresented: errorShown, message: errorMessage, cancel: "OK", inPlace: true) { [] }
        .codyncOverlay(isPresented: Binding(get: { screenTarget.wrappedValue != nil }, set: { if !$0 { screenTarget.wrappedValue = nil } })) { close in
            if let target = screenTarget.wrappedValue, let store = accounts.store(for: target.computerId) {
                ScreenView(watching: target.request.watching, close: close)
                    .environment(store)
                    .id(target.id)
            }
        }
        .codyncSheet(isPresented: Bindable(app).showComputers) { ComputersView() }
        .codyncSheet(item: Binding(get: { app.marketplace.map(MarketplaceTarget.init) }, set: { app.marketplace = $0?.computerId })) { target in
            // Each computer has its own; it's opened from that computer's heading or row.
            if let store = accounts.store(for: target.computerId) {
                MarketplaceView()
                    .environment(store)
            }
        }
    }

    /// State and Settings live in the avatar sheet; the experimental tab remains hidden.
    private var home: some View {
        NavigationStack(path: path) {
            BotListView()
                .safeAreaInset(edge: .bottom, spacing: 0) { AccessBanners() }
                .navigationDestination(for: BotReference.self) { ref in
                    ChatScreen(ref: ref)
                }
        }
        .tint(Palette.text)
        .tracked(.screenViewed(.bots))
        // Opening a bot (notification, widget, link) always lands on the Bots tab.
        .onChange(of: accounts.selection) { old, ref in
            if ref != nil {
                app.tab = .bots
                ReviewInvitation.shared.cancel(.interaction)
            } else if let old {
                ReviewInvitation.shared.returned(from: "\(accounts.storage.id)/\(old.computerId)/\(old.botId)")
            }
        }
    }

    /// Every build with accounts requires sign-in. While Clerk restores, the last signed-in account's context
    /// stays on screen, so an offline launch still reaches its computers.
    private var mustSignIn: Bool {
        account.isConfigured && !account.isSignedIn && (account.isReady || accounts.accountId == nil)
    }

    /// Once per setup (Start over begins a new one): the first computer reached, or Skip.
    private func completeOnboarding(via: AnalyticsEvent.OnboardingVia) {
        guard !onboardingCompleted else { return }
        onboardingCompleted = true
        Analytics.shared.capture(.onboardingCompleted(via: via))
    }

    // MARK: one place for every computer's errors and screen requests

    private var errorMessage: String? {
        accounts.lastError ?? accounts.computers.lazy.compactMap { accounts.store(for: $0.id)?.lastError }.first
    }

    private var errorShown: Binding<Bool> {
        Binding(get: { errorMessage != nil }, set: { shown in
            guard !shown else { return }
            accounts.lastError = nil
            for computer in accounts.computers { accounts.store(for: computer.id)?.lastError = nil }
        })
    }

    private struct ScreenTarget: Identifiable {
        let computerId: ComputerID
        let request: ScreenRequest
        var id: String { "\(computerId)/\(request.id)" }
    }

    /// Any computer's "open the screen" request (thread toolbar, computers list, `codync://screen`).
    private var screenTarget: Binding<ScreenTarget?> {
        Binding(get: {
            accounts.computers.lazy.compactMap { c in
                accounts.store(for: c.id)?.screenRequest.map { ScreenTarget(computerId: c.id, request: $0) }
            }.first
        }, set: { target in
            guard target == nil else { return }
            for computer in accounts.computers { accounts.store(for: computer.id)?.screenRequest = nil }
        })
    }
}

/// A conversation, talking to the computer the bot lives on.
private struct ChatScreen: View {
    let ref: BotReference
    @Environment(AccountStore.self) private var accounts

    var body: some View {
        if let store = accounts.store(for: ref.computerId) {
            ThreadView(botId: ref.botId)
                .environment(store)
        } else {
            VStack(spacing: 0) {
                ScreenHeader { BackButton { accounts.selection = nil } } title: { EmptyView() } trailing: { EmptyView() }
                EmptyState(title: "This computer was removed", systemImage: "desktopcomputer.trianglebadge.exclamationmark")
            }
            .background(Palette.background)
            .hidesSystemNavigationBar()
        }
    }
}

/// Where your bots show up outside the app: Widget, Live Activity and Dynamic Island,
/// each designed and switched on here. Usage limits open from the header.
struct StateTab: View {
    var active = true
    enum Surface: Hashable { case widget, liveActivity, island }

    @Environment(AppStore.self) private var app
    @Environment(\.accessibilityReduceMotion) private var reduceMotion
    // Screenshots: CODYNC_STATE_SURFACE=widget|liveActivity|island opens the tab on that gallery.
    @State private var surface: Surface = {
        #if DEBUG
            switch ProcessInfo.processInfo.environment["CODYNC_STATE_SURFACE"] {
            case "liveActivity": return .liveActivity
            case "island": return .island
            default: return .widget
            }
        #else
            return .widget
        #endif
    }()

    var body: some View {
        VStack(spacing: 0) {
            Picker(L10n.tr("State"), selection: $surface) {
                Text(L10n.tr("Widget")).tag(Surface.widget)
                Text(L10n.tr("Live Activity")).tag(Surface.liveActivity)
                Text(L10n.tr("Dynamic Island")).tag(Surface.island)
            }
            .pickerStyle(.segmented)
            .padding(.horizontal, 20)
            .padding(.bottom, 12)
            ZStack {
                WidgetGalleryView()
                    .environment(\.stateSurfaceActive, active && surface == .widget)
                    .tabLayer(surface == .widget)
                ActivityGalleryView(forms: [.lockScreen])
                    .tabLayer(surface == .liveActivity)
                ActivityGalleryView(forms: [.compact, .minimal, .expanded])
                    .tabLayer(surface == .island)
            }
            .animation(Motion.reduced(Motion.fade, reduceMotion), value: surface)
        }
        .background(Palette.background)
        .toolbar {
            if active {
                ToolbarItem(placement: .topBarTrailing) {
                    Button(action: {  app.showUsage = true  }) { RemixIcon("bar-chart-line") }.accessibilityLabel(Text(L10n.tr("Usage limits")))
                        .buttonBorderShape(.circle)
                }
            }
        }
        .codyncSheet(isPresented: Binding(get: { active && app.showUsage }, set: { app.showUsage = $0 })) { UsageSheet() }
    }
}

/// Usage for one computer at a time: the last active one, which the Usage widget shows too.
private struct UsageSheet: View {
    @Environment(AppStore.self) private var app
    @Environment(AccountStore.self) private var accounts
    @Environment(\.dismissModal) private var dismiss
    /// Picked here; also becomes the computer the Usage widget shows.
    @State private var picked: ComputerID?

    var body: some View {
        let store = picked.flatMap(accounts.store(for:)) ?? app.currentStore
        NavigationStack {
            Group {
                if let store { UsageView().environment(store).id(store.computer.id) }
                else {
                    ContentUnavailableView(L10n.tr("No computer yet"), systemImage: "chart.bar",
                                           description: Text(L10n.tr("Usage shows up once a computer is connected.")))
                }
            }
            .navigationTitle(L10n.tr("Usage"))
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .topBarTrailing) {
                    Button(action: {  dismiss()  }) { RemixImage("close-line", size: 24) }.accessibilityLabel(Text(L10n.tr("Close"))).buttonBorderShape(.circle)
                }
                if store != nil, accounts.computers.count > 1 {
                    ToolbarItem(placement: .topBarLeading) {
                        Menu { 
                            ForEach(accounts.computers) { computer in
                                Button(computer.name) {
                                    picked = computer.id
                                    accounts.storage.lastComputerId = computer.id
                                    WidgetCenter.shared.reloadTimelines(ofKind: "CodyncUsage")
                                }
                            }
                         } label: { Label { Text(L10n.tr("Computers")) } icon: { RemixIcon("computer-line") } }
                    }
                }
            }
        }
        .tint(.primary)
        .tracked(.screenViewed(.usage))
    }
}

/// A centered icon, title and optional line: what a screen shows when it has nothing yet.
struct EmptyState: View {
    let title: String
    let systemImage: String
    var message: String?

    var body: some View {
        VStack(spacing: 8) {
            Image(systemName: systemImage).font(.system(size: 40)).foregroundStyle(Palette.tertiary)
            Text(L10n.tr(title)).font(.title3.weight(.semibold)).foregroundStyle(Palette.text)
            if let message {
                Text(L10n.tr(message)).font(.subheadline).foregroundStyle(Palette.secondary)
            }
        }
        .multilineTextAlignment(.center)
        .padding(24)
        .frame(maxWidth: .infinity, maxHeight: .infinity)
    }
}

/// A page's title row inside a modal: the close button on the modal's first page,
/// a back button once pushed inside it.
struct PageHeader<Trailing: View>: View {
    let title: String
    var pushed = false
    var icon: String?
    let trailing: Trailing
    @Environment(\.dismiss) private var pop

    init(_ title: String, pushed: Bool = false, icon: String? = nil, @ViewBuilder trailing: () -> Trailing) {
        self.title = title
        self.pushed = pushed
        self.icon = icon
        self.trailing = trailing()
    }

    var body: some View {
        if pushed {
            ScreenHeader {
                BackButton { pop() }
            } title: {
                headerTitle
            } trailing: {
                trailing
            }
        } else {
            ModalHeader { headerTitle } trailing: { trailing }
        }
    }
}

private extension PageHeader {
    var headerTitle: some View {
        HStack(spacing: 8) {
            if let icon {
                Image(systemName: icon).font(.title2).accessibilityHidden(true)
            }
            Text(L10n.tr(title)).font(.body.weight(.semibold)).lineLimit(1)
        }
        .foregroundStyle(Palette.text)
    }
}

extension PageHeader where Trailing == EmptyView {
    init(_ title: String, pushed: Bool = false, icon: String? = nil) { self.init(title, pushed: pushed, icon: icon) { EmptyView() } }
}

extension View {
    /// Tops a screen with its `PageHeader` in place of the system navigation bar.
    func page(_ title: String, pushed: Bool = false, icon: String? = nil) -> some View {
        VStack(spacing: 0) {
            PageHeader(title, pushed: pushed, icon: icon)
            self
        }
        .background(Palette.background)
        .hidesSystemNavigationBar()
    }
}

private extension View {
    /// One tab's stack in the root ZStack: visible and interactive only while selected.
    func tabLayer(_ selected: Bool) -> some View {
        opacity(selected ? 1 : 0)
            .allowsHitTesting(selected)
            .accessibilityHidden(!selected)
    }
}

/// Access requests still waiting after their sheet closed: the code to check, until the computer answers.
private struct AccessBanners: View {
    @Environment(AccountStore.self) private var accounts

    var body: some View {
        VStack(spacing: 8) {
            ForEach(Array(accounts.pendingAccess.values).sorted { $0.requestId < $1.requestId }) { ticket in
                let name = accounts.cloudComputers.first { $0.computerId == ticket.computerId }?.name ?? "Your computer"
                HStack(spacing: 12) {
                    Spinner(size: 16)
                    VStack(alignment: .leading, spacing: 1) {
                        Text(L10n.tr("Approve on \(name)")).font(.subheadline.weight(.medium)).foregroundStyle(Palette.text)
                        Text(L10n.tr("Code \(ticket.code.prefix(3)) \(ticket.code.suffix(3))"))
                            .font(.footnote.monospacedDigit()).foregroundStyle(Palette.secondary)
                    }
                    Spacer(minLength: 8)
                    IconButton("Cancel request", systemImage: "xmark") {
                        Task { await accounts.cancelAccess(ticket.computerId) }
                    }
                }
                .padding(.leading, 14)
                .padding(.trailing, 6)
                .padding(.vertical, 8)
                .background(Palette.bubbleAgent, in: RoundedRectangle(cornerRadius: 16, style: .continuous))
                .transition(.move(edge: .bottom).combined(with: .opacity))
            }
        }
        .padding(.horizontal, 16)
        .padding(.bottom, accounts.pendingAccess.isEmpty ? 0 : 8)
        .animation(Motion.layout, value: accounts.pendingAccess.keys.sorted())
        .accessibilityElement(children: .contain)
    }
}

/// The marketplace sheet's item, so it keeps its computer while sliding away.
private struct MarketplaceTarget: Identifiable {
    let computerId: ComputerID
    var id: String { "marketplace" }
}
