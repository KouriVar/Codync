import CodyncKit
import CodyncUI
import SwiftUI

/// Which lead Siri, the Action button and Open Live Mode without a bot call (`ShortcutBotQuery.lead`), shown once
/// more than one computer has a lead. Automatic: the lead of the first computer in the list that has one.
struct ShortcutLeadSettings: View {
    @Environment(AppStore.self) private var app
    /// A computer id, or empty for Automatic.
    @State private var chosen = SharedStore.activeContext.shortcutLeadComputer ?? ""

    var body: some View {
        let leads = app.accounts.roster.filter(\.bot.lead)
        if leads.count > 1 {
            Section {
                Picker(L10n.tr("Lead to call"), selection: Binding(
                    get: { leads.contains { $0.ref.computerId == chosen } ? chosen : "" },
                    set: { chosen = $0 }
                )) {
                    Text(L10n.tr("Automatic")).tag("")
                    ForEach(leads, id: \.ref.computerId) { Text("\($0.bot.name) · \($0.computer.name)").tag($0.ref.computerId) }
                }
                .pickerStyle(.navigationLink)
            } header: { Text(L10n.tr("Shortcuts")) } footer: {
                Text(L10n.tr("Siri, the Action button and Open Live Mode without a bot call this lead. Automatic calls the lead of the first computer in your list."))
            }
            .onChange(of: chosen) { _, id in SharedStore.activeContext.shortcutLeadComputer = id.isEmpty ? nil : id }
        }
    }
}
