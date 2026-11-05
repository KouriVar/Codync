import CodyncKit
import SwiftUI

/// The conversation's one input frame, shared by both pages.
///
/// The bot page keeps it in the capsule shape. The chat page shows the same capsule until the field
/// is focused, then swaps it to the expanded two-row box. The frame is a single piece of glass that
/// holds `leading`, the field and `trailing`; the buttons carry no glass of their own, so glass is
/// never stacked on glass.
///
/// Geometry lives in `Layout` below and comes from `ControlMetrics`: the frame is the home bar's
/// height, the buttons are the compact circle.
public struct ConversationComposer: View {
    /// The frame's shape: one row (the capsule) or the focused two-row box.
    public enum Mode: Equatable {
        /// One row: + on the left, the field, send on the right.
        case capsule
        /// Two rows: the field on top, a button row below.
        case expanded
    }

    /// Whatever sits above the frame and moves with it — a quote, the attachments going out.
    var accessory: AnyView?
    var leading: AnyView
    var field: AnyView
    var trailing: AnyView
    var mode: Mode
    var topPadding: CGFloat
    var bottomPadding: CGFloat

    @Environment(\.accessibilityReduceMotion) private var reduceMotion

    public init(accessory: AnyView? = nil, leading: AnyView, field: AnyView, trailing: AnyView,
                mode: Mode = .capsule, topPadding: CGFloat = 6, bottomPadding: CGFloat = 12) {
        self.accessory = accessory
        self.leading = leading
        self.field = field
        self.trailing = trailing
        self.mode = mode
        self.topPadding = topPadding
        self.bottomPadding = bottomPadding
    }

    public var body: some View {
        VStack(spacing: 6) {
            if let accessory { accessory }
            frame
        }
        .padding(.horizontal, Layout.side)
        .padding(.top, topPadding)
        .padding(.bottom, bottomPadding)
        // Capsule → box is a size change: it takes the layout spring, never a hard cut.
        .animation(Motion.reduced(Motion.layout, reduceMotion), value: mode)
    }

    private var frame: some View {
        Group {
            switch mode {
            case .capsule: capsule
            case .expanded: expanded
            }
        }
        .glass(in: RoundedRectangle(cornerRadius: Layout.cornerRadius, style: .continuous),
               interactive: true)
    }

    /// One row: + left, field, send right. The buttons sit on the frame's bottom edge, so they stay
    /// put while a growing field pushes the frame upward.
    private var capsule: some View {
        HStack(alignment: .bottom, spacing: Layout.innerGap) {
            leading
            field.padding(.vertical, Layout.fieldVerticalPadding)
            trailing
        }
        .padding(.horizontal, Layout.buttonInset)
        .padding(.vertical, Layout.buttonInset)
        .frame(minHeight: Layout.minHeight)
    }

    /// The focused shape: the field on top (full width), a button row below with + on the left and the
    /// page's trailing controls (model, send) on the right.
    private var expanded: some View {
        VStack(spacing: 0) {
            field
                .padding(.horizontal, Layout.expandedFieldPadding)
                .padding(.top, Layout.expandedFieldPadding)
            HStack(spacing: Layout.innerGap) {
                leading
                Spacer(minLength: 0)
                trailing
            }
            .padding(.horizontal, Layout.buttonInset)
            .frame(height: Layout.buttonRowHeight)
        }
    }
}

/// The frame's numbers, in one place. Every size comes from the app's control metrics so the frame
/// stays the home bar's height and the buttons stay the compact circle.
private enum Layout {
    /// The screen's side margin, the same as the home bar.
    static let side: CGFloat = 16
    /// The frame's minimum height: the home bar's bar token.
    static let minHeight: CGFloat = ControlMetrics.Size.bar.hitTarget
    /// The expanded button row: the same height as the capsule.
    static let buttonRowHeight: CGFloat = ControlMetrics.Size.bar.hitTarget
    /// The frame's corner. One row reads as a capsule; several rows read as a 24pt rounded box.
    static let cornerRadius: CGFloat = 24
    /// How far the buttons sit from the frame's edge.
    static let buttonInset: CGFloat = 6
    /// The gap between the buttons and the field.
    static let innerGap: CGFloat = 6
    /// The typing area's padding inside the expanded box.
    static let expandedFieldPadding: CGFloat = 12
    /// Centres one line of text in the compact button row of the capsule.
    static let fieldVerticalPadding: CGFloat = (ControlMetrics.Size.compact.side - 22) / 2
}
