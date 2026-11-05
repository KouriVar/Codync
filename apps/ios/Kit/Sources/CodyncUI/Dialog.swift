import CodyncKit
import SwiftUI
import UIKit

// MARK: - Dialogs

/// A button in a Codync dialog.
public struct DialogAction: Identifiable {
    public let id = UUID()
    public var title: String
    public var destructive: Bool
    public var action: () -> Void

    public init(_ title: String, destructive: Bool = false, action: @escaping () -> Void) {
        self.title = title
        self.destructive = destructive
        self.action = action
    }
}

/// A text box above a dialog's actions (a name to type), focused as the dialog opens.
public struct DialogField {
    public var placeholder: String
    public var text: Binding<String>

    public init(_ placeholder: String, text: Binding<String>) {
        self.placeholder = placeholder
        self.text = text
    }
}

public extension View {
    /// A centered card over a dimmed screen with the actions and Cancel:
    /// the replacement for `confirmationDialog` and `alert`. A `field` sits above the actions;
    /// Return in it runs the first action.
    /// Set `inPlace` only at the navigation root to keep underlying glass unchanged.
    func codyncDialog(_ title: String, isPresented: Binding<Bool>, message: String? = nil, field: DialogField? = nil,
                      cancel: String? = "Cancel", inPlace: Bool = false,
                      actions: @escaping () -> [DialogAction]) -> some View {
        modifier(CodyncDialog(title: title, message: message, field: field, cancel: cancel, inPlace: inPlace,
                              isPresented: isPresented, actions: actions))
    }
}

private struct CodyncDialog: ViewModifier {
    let title: String
    let message: String?
    let field: DialogField?
    let cancel: String?
    /// Use only above the navigation container so the scrim also covers its toolbar.
    let inPlace: Bool
    @Binding var isPresented: Bool
    let actions: () -> [DialogAction]
    /// Counts the dismissals: each opening of the in-place card is a fresh card, so one that closed
    /// and reopened before a redraw can't keep its `closed` flag.
    @State private var opening = 0
    @Environment(\.accessibilityReduceMotion) private var reduceMotion

    func body(content: Content) -> some View {
        // Native iOS alert (was a hand-drawn card). Supports a text field and dynamic buttons.
        content.alert(L10n.tr(title), isPresented: $isPresented) {
            if let field {
                TextField(L10n.tr(field.placeholder), text: field.text)
            }
            ForEach(actions()) { action in
                Button(L10n.tr(action.title), role: action.destructive ? .destructive : nil) {
                    action.action()
                }
            }
            if let cancel {
                Button(L10n.tr(cancel), role: .cancel) {}
            }
        } message: {
            if let message, !message.isEmpty {
                Text(L10n.tr(message))
            }
        }
    }
}
