import CodyncKit
import SwiftUI

/// A device preference: the working pill unfolds the turn's thinking and steps. Off (the default) keeps the chat to its
/// messages.
enum ThinkingDetails {
    static let storageKey = "showThinkingDetails"
}

/// Settings › Chat: whether the working pill unfolds the turn's thinking and steps on this device.
public struct ThinkingDetailsSettings: View {
    @AppStorage(ThinkingDetails.storageKey) private var details = false

    public init() {}

    public var body: some View {
        SettingsToggleRow("brain-line", title: "思考细节", isOn: $details)
    }
}
