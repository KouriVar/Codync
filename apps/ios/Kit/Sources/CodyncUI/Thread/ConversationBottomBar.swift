import CodyncKit
import SwiftUI
import UIKit

/// The numbers every conversation's bottom area lines up from.
///
/// The bot page and the chat page both read these, so their bars are one height, one side margin and
/// one jump gap; changing a value here moves both pages together. The jump arrow and the running
/// status line live in the transcript (above the composer), so they read the same numbers to keep
/// their distance to the input's top edge.
public enum ConversationBottomMetrics {
    /// The screen's side margin, the same as the home bar.
    public static let sideMargin: CGFloat = 16
    /// The input frame's height: the capsule, and the expanded button row.
    public static let inputHeight: CGFloat = 48
    /// The composer's own top padding — the gap between the frame's glass and what sits above it.
    public static let composerTopPadding: CGFloat = 6
    /// Below the glass while the keyboard is down. Read by the home bar too, so the conversation's
    /// input bottom and the home's search bar sit at the same place above the screen's bottom edge.
    public static let restingBottomPadding: CGFloat = 28
    /// Below the glass while the keyboard is up.
    public static let keyboardBottomPadding: CGFloat = 8
    /// The jump-to-latest arrow's bottom edge sits this far above the input's top edge.
    public static let jumpGap: CGFloat = 32
    /// What the arrow pads above the content's bottom, so that gap holds once the composer's top is
    /// added: `jumpGap - composerTopPadding`.
    public static var jumpPadding: CGFloat { jumpGap - composerTopPadding }
    /// Above the running status line.
    public static let statusTopPadding: CGFloat = 12
    /// The status line's bottom edge sits this far above the input's top edge.
    public static let statusInputGap: CGFloat = 24
    /// What the status row pads below itself, so that gap holds once the composer's top is added:
    /// `statusInputGap - composerTopPadding`.
    public static var statusBottomPadding: CGFloat { statusInputGap - composerTopPadding }
}

/// The conversation's bottom bar, built once and used by both pages.
///
/// It owns the frame's spacing policy — the resting and keyboard gaps, and the keyboard observation
/// that keeps them — so the bot page and the chat page cannot drift apart. A page supplies only the
/// frame's contents: its `mode`, the `leading`, `field` and `trailing` controls, and an optional
/// `accessory` above the frame. The chat page's own controls (model, and later plans/goals/… ) are
/// just what it passes in `trailing`; the bot page passes none of them.
public struct ConversationBottomBar: View {
    let mode: ConversationComposer.Mode
    let accessory: AnyView?
    let leading: AnyView
    let field: AnyView
    let trailing: AnyView

    @State private var keyboardUp = false

    public init(mode: ConversationComposer.Mode = .capsule, accessory: AnyView? = nil,
                leading: AnyView, field: AnyView, trailing: AnyView) {
        self.mode = mode
        self.accessory = accessory
        self.leading = leading
        self.field = field
        self.trailing = trailing
    }

    public var body: some View {
        ConversationComposer(
            accessory: accessory,
            leading: leading,
            field: field,
            trailing: trailing,
            mode: mode,
            topPadding: ConversationBottomMetrics.composerTopPadding,
            bottomPadding: keyboardUp ? ConversationBottomMetrics.keyboardBottomPadding
                                      : ConversationBottomMetrics.restingBottomPadding
        )
        .onReceive(NotificationCenter.default.publisher(for: UIResponder.keyboardWillShowNotification)) { _ in
            keyboardUp = true
        }
        .onReceive(NotificationCenter.default.publisher(for: UIResponder.keyboardWillHideNotification)) { _ in
            keyboardUp = false
        }
        // Exactly the home bar's bottom policy, applied on the bar itself (not on the transcript): with
        // the keyboard down the bar escapes the bottom safe area so the input's bottom sits at the same
        // place as the home's search bar; with the keyboard up it stays above it. Putting this on the
        // transcript instead (C0222) made the scroll content and the safe area inset re-layout each
        // other every frame while typing → a layout loop that froze the app; the escape belongs here.
        .ignoresSafeArea(.container, edges: keyboardUp ? [] : .bottom)
    }
}
