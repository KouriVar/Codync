import CodyncKit
import SwiftUI

extension Image {
    /// The codync-network mark (host/crates/network/assets/icon.png); SF Symbols has none.
    public static var codyncNetwork: Image { Image("codync-network", bundle: .module) }
}

/// A computer's networks of the user's other computers, read-only: who is in each, whether each one
/// answers and which bots it offers, who may message this computer's bots there, and whether cloud
/// assistants may reach them.
/// Changes are made at a computer. The computer is the `BotStore` in the environment.
public struct NetworkSheet: View {
    @Environment(BotStore.self) private var store
    @Environment(\.dismissModal) private var dismiss

    public init() {}

    public var body: some View {
        NavigationStack {
            Form {
                let networks = store.network?.networks ?? []
                ForEach(networks) { network in
                    Section(network.name) {
                        ForEach(network.computers ?? []) { NetworkComputerRow(computer: $0) }
                    }
                    if let rules = network.rules, !rules.isEmpty {
                        Section {
                            ForEach(Array(rules.enumerated()), id: \.offset) { _, rule in
                                Text(network.text(of: rule)).font(.subheadline).foregroundStyle(Palette.text)
                            }
                        } header: {
                            Text(L10n.tr("Who may message bots here"))
                        } footer: {
                            Text(L10n.tr("The first rule that matches decides. Without rules, every computer in the network may message every bot here. Answers to this computer's own messages always get in."))
                        }
                    }
                }
                if !networks.isEmpty {
                    Section { } footer: {
                        Text(L10n.tr("Changes are made on a computer: in Codync's settings there, or with codync-host network."))
                    }
                }
                if store.network?.assistantsAvailable == true {
                    Section {
                        LabeledContent(L10n.tr("Cloud assistants"), value: L10n.tr(store.network?.assistants == true ? "On" : "Off"))
                    } footer: {
                        Text(L10n.tr("ChatGPT or Claude in your Codync account can message this computer's bots when it's on. Codync's cloud can read these calls."))
                    }
                }
            }
            .navigationTitle(L10n.tr("Network"))
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .topBarTrailing) {
                    Button(L10n.tr("Close")) { dismiss() }
                }
            }
            .animation(Motion.layout, value: store.network)
        }
        .tint(.primary)
        .task { await store.refreshNetwork() }
        .tracked(.screenViewed(.network))
    }
}

private struct NetworkComputerRow: View {
    let computer: NetworkView.Computer

    var body: some View {
        VStack(alignment: .leading, spacing: 4) {
            HStack(spacing: 8) {
                Text(computer.name).font(.body.weight(.semibold)).foregroundStyle(Palette.text)
                Spacer(minLength: 8)
                Text(L10n.tr(computer.role.title)).font(.footnote).foregroundStyle(Palette.secondary)
            }
            HStack(alignment: .firstTextBaseline, spacing: 6) {
                Circle()
                    .fill(computer.online ? Palette.added : Palette.tertiary)
                    .frame(width: 7, height: 7)
                    .accessibilityHidden(true)
                Text(L10n.tr(presence))
                    .font(.footnote)
                    .foregroundStyle(Palette.secondary)
            }
            Text(bots)
                .font(.footnote)
                .foregroundStyle(Palette.tertiary)
                .fixedSize(horizontal: false, vertical: true)
        }
        .padding(.vertical, 2)
        .accessibilityElement(children: .combine)
    }

    private var presence: String {
        computer.me ? "This computer" : computer.online ? "Online" : "Away"
    }

    private var bots: String {
        let names = (computer.agents ?? []).map(\.name)
        return names.isEmpty ? L10n.tr("No bots") : names.joined(separator: ", ")
    }
}
