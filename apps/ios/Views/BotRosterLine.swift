import CodyncKit
import CodyncUI
import SwiftUI

struct NewTarget: Identifiable {
    enum Kind { case bot, group }
    let id = UUID()
    let kind: Kind
    let computerId: ComputerID
}

struct GroupTarget: Identifiable {
    let id = UUID()
    let computerId: ComputerID
    let group: Bot
}

struct EditTarget: Identifiable {
    let id = UUID()
    let computerId: ComputerID
    let draft: BotDraft
}

