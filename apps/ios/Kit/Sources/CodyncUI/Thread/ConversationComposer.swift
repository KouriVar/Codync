import CodyncKit
import SwiftUI
import UIKit

/// A conversation's input bar: one glass field that takes the width left over, and round buttons at
/// the ends. The field and every button are the bar size (48pt) with 24pt glyphs — the same numbers
/// as the home's search bar, so the two bottom bars are one height.
///
/// It is deliberately just the text and the send: attachments, voice, commands and quoting belong to
/// whichever page offers them and are passed in as `leading`.
public struct ConversationComposer: View {
    @Binding var text: String
    let placeholder: String
    /// The leading button's glyph and action, when the page has one (Coe's attachments).
    var leading: (glyph: String, action: () -> Void)?
    let canSend: Bool
    let onSend: () -> Void
    /// The row under the field: the page's numbers, so the bar sits where that page puts it.
    var bottomPadding: CGFloat

    @FocusState private var focused: Bool
    @Environment(\.accessibilityReduceMotion) private var reduceMotion

    public init(text: Binding<String>, placeholder: String, leading: (glyph: String, action: () -> Void)? = nil,
                canSend: Bool, bottomPadding: CGFloat = 12, onSend: @escaping () -> Void) {
        _text = text
        self.placeholder = placeholder
        self.leading = leading
        self.canSend = canSend
        self.bottomPadding = bottomPadding
        self.onSend = onSend
    }

    public var body: some View {
        HStack(alignment: .bottom, spacing: 12) {
            if let leading {
                GlassButton(placeholder, glyph: .remix(leading.glyph), size: .bar) {
                    leading.action()
                }
            }
            field
            GlassButton("Send", glyph: .remix("arrow-up-line"), size: .bar,
                        style: .filled(canSend ? Palette.accentFill : Palette.accentDim,
                                       ink: canSend ? Palette.onAccent : Palette.secondary)) {
                guard canSend else { return }
                onSend()
            }
        }
        .padding(.horizontal, 16)
        .padding(.top, 6)
        .padding(.bottom, bottomPadding)
        .animation(Motion.reduced(Motion.layout, reduceMotion), value: canSend)
    }

    private var field: some View {
        TextField(placeholder, text: $text, axis: .vertical)
            .font(.body)
            .lineLimit(1...6)
            .textFieldStyle(.plain)
            .focused($focused)
            .padding(.horizontal, 14)
            .frame(minHeight: ControlMetrics.Size.bar.hitTarget)
            .glass(in: RoundedRectangle(cornerRadius: 24, style: .continuous), interactive: true)
            .contentShape(RoundedRectangle(cornerRadius: 24, style: .continuous))
    }
}
