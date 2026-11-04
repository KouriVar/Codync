import CodyncKit
import SwiftUI

/// The "main bot" chooser: every bot on every computer, the current lead ticked.
/// Same data and the same `setLead` as the roster's long-press "set as main bot".
public struct LeadBotPickerView: View {
    @Environment(AccountStore.self) private var accounts
    @Environment(\.dismissModal) private var dismiss

    public init() {}

    public var body: some View {
        NavigationStack {
            picker(groups)
                .navigationTitle(L10n.tr("Main bot"))
                .navigationBarTitleDisplayMode(.inline)
                .toolbar {
                    ToolbarItem(placement: .topBarTrailing) {
                        Button(action: { dismiss() }) { RemixImage("close-line", size: 24) }
                            .accessibilityLabel(Text(L10n.tr("Close")))
                            .buttonBorderShape(.circle)
                    }
                }
        }
        .tint(.primary)
    }

    private func picker(_ groups: [LeadGroup]) -> some View {
        List {
            if groups.isEmpty {
                Text(L10n.tr("No bots yet"))
                    .foregroundStyle(Palette.secondary)
                    .frame(maxWidth: .infinity, alignment: .center)
                    .listRowSeparator(.hidden)
            }
            ForEach(groups) { group in
                // One computer needs no heading; several do, or two "Work" rows read alike.
                if groups.count > 1 {
                    Section {
                        rows(group)
                    } header: {
                        Text(group.title)
                    }
                } else {
                    Section {
                        rows(group)
                    }
                }
            }
        }
        .listStyle(.plain)
    }

    @ViewBuilder private func rows(_ group: LeadGroup) -> some View {
        ForEach(group.bots) { bot in
            Button {
                choose(bot, in: group.store)
            } label: {
                HStack(spacing: 12) {
                    CharacterAvatar(bot: bot, size: 28, animated: false)
                    Text(bot.name)
                        .foregroundStyle(Palette.text)
                        .lineLimit(1)
                    Spacer(minLength: 8)
                    if bot.lead {
                        RemixIcon("check-line", size: 20).foregroundStyle(Palette.accent)
                    }
                }
                .padding(.vertical, 6)
                .contentShape(Rectangle())
            }
            .buttonStyle(.plain)
            .accessibilityAddTraits(bot.lead ? .isSelected : [])
        }
    }

    private func choose(_ bot: Bot, in store: BotStore) {
        // The tap is confirmed before the sheet slides away, so it never feels dropped.
        Haptics.notification()
        store.setLead(bot)
        dismiss()
    }

    /// Each computer with bots to offer, the lead first and the rest in roster order.
    private var groups: [LeadGroup] {
        accounts.computers.compactMap { computer -> LeadGroup? in
            guard let store = accounts.store(for: computer.id) else { return nil }
            // A group chat can't be the one a call or shortcut with no bot named talks to.
            let bots = store.roster.filter { !$0.isGroup }
            guard !bots.isEmpty else { return nil }
            return LeadGroup(store: store, bots: bots.filter(\.lead) + bots.filter { !$0.lead },
                             id: computer.id, title: store.hostName)
        }
    }
}

/// One computer's bots, in the order the picker shows them.
private struct LeadGroup: Identifiable {
    let store: BotStore
    let bots: [Bot]
    let id: ComputerID
    /// The name the app shows for the computer, including a name the host gives itself.
    let title: String
}

/// The Settings row's detail line for the main bot.
@MainActor public struct LeadBotSummary {
    private init() {}

    /// "Bot · Computer" for the first bot that leads, nil until a computer names one.
    public static func describe(_ accounts: AccountStore) -> String? {
        for computer in accounts.computers {
            guard let store = accounts.store(for: computer.id),
                  let lead = store.bots.values.first(where: \.lead) else { continue }
            return "\(lead.name) · \(store.hostName)"
        }
        return nil
    }
}
