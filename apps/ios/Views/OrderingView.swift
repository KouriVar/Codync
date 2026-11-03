import CodyncKit
import CodyncUI
import SwiftUI

/// Reorder each computer's chat list. Drag the handle to move a bot; the order syncs to the computer.
struct OrderingView: View {
    @Environment(AccountStore.self) private var accounts

    var body: some View {
        List {
            ForEach(accounts.computers, id: \.id) { computer in
                if let store = accounts.store(for: computer.id) {
                    let bots = store.roster
                    Section(computer.name) {
                        ForEach(bots) { bot in
                            Text(bot.name)
                        }
                        .onMove { source, destination in
                            var ids = store.roster.map(\.id)
                            ids.move(fromOffsets: source, toOffset: destination)
                            store.reorder(ids)
                        }
                    }
                }
            }
        }
        .environment(\.editMode, .constant(EditMode.active))
    }
}
