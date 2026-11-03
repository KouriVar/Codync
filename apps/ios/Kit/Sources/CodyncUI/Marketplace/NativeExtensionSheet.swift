import CodyncKit
import SwiftUI

/// System sheet navigation shared by extension details and editors; content owns its native Form.
struct NativeExtensionSheet<Content: View>: View {
    let title: String
    var busy = false
    var actionTitle: String?
    var actionEnabled = true
    var action: (() -> Void)?
    @ViewBuilder var content: Content
    @Environment(\.dismissModal) private var dismiss

    init(_ title: String, busy: Bool = false, actionTitle: String? = nil,
         actionEnabled: Bool = true, action: (() -> Void)? = nil,
         @ViewBuilder content: () -> Content) {
        self.title = title
        self.busy = busy
        self.actionTitle = actionTitle
        self.actionEnabled = actionEnabled
        self.action = action
        self.content = content()
    }

    var body: some View {
        NavigationStack {
            content
                .navigationTitle(L10n.tr(title))
                .navigationBarTitleDisplayMode(.inline)
                .toolbar {
                    ToolbarItem(placement: .cancellationAction) {
                        Button(L10n.tr("Close"), systemImage: "xmark") { dismiss() }
                            .labelStyle(.iconOnly).buttonBorderShape(.circle)
                            .disabled(busy)
                    }
                    if let actionTitle, let action {
                        ToolbarItem(placement: .confirmationAction) {
                            Button(action: action) {
                                if busy { ProgressView() } else { Text(L10n.tr(actionTitle)) }
                            }
                            .buttonStyle(.glassProminent).buttonBorderShape(.capsule)
                            .tint(.primary).foregroundStyle(Color(uiColor: .systemBackground))
                            .disabled(busy || !actionEnabled)
                        }
                    }
                }
        }
        .tint(.primary)
        .interactiveDismissDisabled(busy)
    }
}

/// Localizes existing extension copy while delegating all row grouping/insets to Form.
struct NativeFormSection<Content: View>: View {
    var title: String?
    var footer: String?
    @ViewBuilder var content: Content

    init(_ title: String? = nil, footer: String? = nil, @ViewBuilder content: () -> Content) {
        self.title = title
        self.footer = footer
        self.content = content()
    }

    var body: some View {
        Section {
            content
        } header: {
            if let title { Text(L10n.tr(title)) }
        } footer: {
            if let footer { Text(L10n.tr(footer)) }
        }
    }
}
