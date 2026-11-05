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
    /// Whether the field has the keyboard. Unfocused it rests narrower; focused it takes the full
    /// side margin. Both pages follow this, so they look the same.
    var focused: Bool

    @Environment(\.accessibilityReduceMotion) private var reduceMotion

    public init(accessory: AnyView? = nil, leading: AnyView, field: AnyView, trailing: AnyView,
                mode: Mode = .capsule, topPadding: CGFloat = 6, bottomPadding: CGFloat = 12,
                focused: Bool = false) {
        self.accessory = accessory
        self.leading = leading
        self.field = field
        self.trailing = trailing
        self.mode = mode
        self.topPadding = topPadding
        self.bottomPadding = bottomPadding
        self.focused = focused
    }

    public var body: some View {
        VStack(spacing: 6) {
            if let accessory { accessory.padding(.horizontal, Layout.side) }
            frame.padding(.horizontal, frameSideInset)
        }
        .padding(.top, topPadding)
        .padding(.bottom, bottomPadding)
        // Capsule → box is a size change: it takes the layout spring, never a hard cut.
        .animation(Motion.reduced(Motion.layout, reduceMotion), value: mode)
        // The resting capsule is narrower; gaining the keyboard widens it back to the full margin.
        .animation(Motion.reduced(Motion.layout, reduceMotion), value: focused)
    }

    /// The glass frame's side inset: the full margin while focused, the wider resting inset when not.
    private var frameSideInset: CGFloat {
        focused ? Layout.side : Layout.side + Layout.collapsedExtra
    }

    /// The frame, built once with a single structure so the field never leaves its place.
    ///
    /// The field is always the middle child of the same `HStack`; switching shapes only changes the
    /// HStack's own geometry and, when expanded, adds a button row *after* it. Putting the field in a
    /// `switch` over `mode` instead would give the two shapes two different branches, so SwiftUI would
    /// tear the `TextField` down and rebuild it on every flip — it would lose focus, flip back, and the
    /// focus/rebuild pair would loop (C0220). One field, one identity, no loop.
    private var frame: some View {
        VStack(spacing: 0) {
            HStack(alignment: .bottom, spacing: Layout.innerGap) {
                // Beside the field in the capsule. In the box the buttons move to the row below, so
                // these collapse to nothing — but they stay in the tree, which keeps the field's
                // position (and identity) fixed.
                leading
                    .frame(width: isExpanded ? 0 : nil)
                    .opacity(isExpanded ? 0 : 1)
                    .clipped()
                field
                    .padding(.vertical, isExpanded ? 0 : Layout.fieldVerticalPadding)
                    .padding(.horizontal, isExpanded ? Layout.expandedFieldPadding : 0)
                    .padding(.top, isExpanded ? Layout.expandedFieldPadding : 0)
                trailing
                    .frame(width: isExpanded ? 0 : nil)
                    .opacity(isExpanded ? 0 : 1)
                    .clipped()
            }
            .padding(.horizontal, isExpanded ? 0 : Layout.buttonInset)
            .frame(minHeight: isExpanded ? 0 : Layout.minHeight)

            if isExpanded {
                HStack(spacing: Layout.innerGap) {
                    leading
                    Spacer(minLength: 0)
                    trailing
                }
                .padding(.horizontal, Layout.buttonInset)
                .frame(height: Layout.buttonRowHeight)
            }
        }
        .glass(in: RoundedRectangle(cornerRadius: Layout.cornerRadius, style: .continuous),
               interactive: true)
    }

    private var isExpanded: Bool { mode == .expanded }
}

/// The frame's numbers, in one place. The side margin and the height come from
/// `ConversationBottomMetrics`, which the transcript's jump arrow and status line also read, so the
/// whole bottom area lines up from one set of values.
private enum Layout {
    /// The screen's side margin, the same as the home bar.
    static let side: CGFloat = ConversationBottomMetrics.sideMargin
    /// Extra side inset while the field is unfocused: the resting capsule sits narrower.
    static let collapsedExtra: CGFloat = ConversationBottomMetrics.collapsedExtraSideInset
    /// The frame's minimum height.
    static let minHeight: CGFloat = ConversationBottomMetrics.inputHeight
    /// The expanded button row: the same height as the capsule.
    static let buttonRowHeight: CGFloat = ConversationBottomMetrics.inputHeight
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
