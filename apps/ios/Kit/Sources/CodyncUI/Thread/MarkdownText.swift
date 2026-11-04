import CodyncKit
@preconcurrency import MarkdownUI
import SwiftUI

/// The iPhone's Markdown renderer for messages: MarkdownUI parses and lays it out, and
/// `Theme.codync` dresses it in the app's own tokens — tables scroll sideways under a solid header,
/// fenced code highlights and copies itself. Inline code, headings, lists, quotes and links keep the
/// type scale the hand-rolled renderer used.
///
/// Equatable so a reply that didn't change skips its body; a streaming reply simply re-parses what
/// has arrived so far.
public struct MarkdownText: View, Equatable {
    let source: String

    /// The body's own size, following Dynamic Type: every heading and the code block derive from it,
    /// so the whole message scales with the reader's setting.
    @ScaledMetric(relativeTo: .body) private var bodySize: CGFloat = 17
    @ScaledMetric(relativeTo: .footnote) private var codeSize: CGFloat = 13

    public init(_ source: String) {
        self.source = source
    }

    public var body: some View {
        Markdown(source)
            .markdownTheme(.codync(body: bodySize, code: codeSize))
            .textSelection(.enabled)
    }

    // Only the source decides whether a body is worth redrawing. `nonisolated` because the reader
    // compares these from outside the main actor, and `source` is an immutable string.
    public nonisolated static func == (left: Self, right: Self) -> Bool { left.source == right.source }
}
