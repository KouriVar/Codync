import CodyncKit
@preconcurrency import MarkdownUI
import SwiftUI

extension Theme {
    /// The message body's Markdown, dressed in the app's own tokens: the colours and type scale the
    /// hand-rolled renderer used, plus tables that scroll sideways under a solid header and fenced
    /// code that highlights itself and offers a copy button. Everything here is a palette colour, a
    /// `ControlMetrics` size or a `@ScaledMetric` value — no theme of its own.
    static func codync(body: CGFloat, code: CGFloat) -> Theme {
        var theme = Theme()

        theme.text = combined { FontSize(body); ForegroundColor(Palette.text) }
        theme.code = combined {
            FontFamilyVariant(.monospaced)
            FontSize(.em(0.9))
            ForegroundColor(Palette.text)
            BackgroundColor(Palette.text.opacity(0.08))
        }
        // Links stay monochrome and underlined, as they read before: the app has no link colour.
        theme.link = combined { ForegroundColor(Palette.text); UnderlineStyle(.single) }

        theme.heading1 = heading(body * 1.18, weight: .bold)
        theme.heading2 = heading(body, weight: .semibold)
        theme.heading3 = heading(body * 0.88, weight: .bold)
        theme.heading4 = heading(body * 0.88, weight: .semibold)
        theme.heading5 = heading(body * 0.82, weight: .semibold)
        theme.heading6 = heading(body * 0.82, weight: .semibold)

        theme.blockquote = BlockStyle { configuration in
            rendered {
                configuration.label
                    .padding(.leading, 10)
                    .overlay(alignment: .leading) {
                        Rectangle().fill(Palette.border).frame(width: 3)
                    }
                    .markdownTextStyle { ForegroundColor(Palette.secondary) }
            }
        }
        theme.thematicBreak = BlockStyle {
            rendered {
                Rectangle().fill(Palette.border).frame(height: 1).padding(.vertical, 4)
            }
        }
        // One glyph for every depth, the way the old renderer drew "•".
        theme.bulletedListMarker = .disc

        theme.codeBlock = BlockStyle { configuration in
            rendered {
                MarkdownCodeBlock(code: configuration.content,
                                  language: configuration.language,
                                  size: code)
            }
        }

        theme.table = BlockStyle { configuration in
            rendered {
                ScrollView(.horizontal, showsIndicators: false) {
                    configuration.label
                        .fixedSize(horizontal: true, vertical: false)
                }
                // The header row is the one that differs: a solid surface behind it, hairlines
                // between the rows below.
                .markdownTableBackgroundStyle(.alternatingRows(.clear, .clear, header: Palette.surface))
                .markdownTableBorderStyle(
                    TableBorderStyle(.insideHorizontalBorders, color: Palette.border, width: 1)
                )
            }
        }
        theme.tableCell = BlockStyle { configuration in
            rendered {
                configuration.label
                    .padding(.horizontal, 12)
                    .padding(.vertical, 7)
                    .markdownTextStyle {
                        if configuration.row == 0 { FontWeight(.semibold) }
                    }
            }
        }

        return theme
    }

    private static func heading(_ size: CGFloat, weight: Font.Weight) -> BlockStyle<BlockConfiguration> {
        BlockStyle { configuration in
            rendered {
                configuration.label
                    .markdownTextStyle { FontSize(size); FontWeight(weight) }
                    .padding(.top, 2)
            }
        }
    }
}

/// A view a block style built. `BlockStyle` stores its body as a plain (non-main-actor) closure, but
/// SwiftUI only calls it while rendering on the main actor: `rendered` states that to the type system,
/// and the box carries the view — which is not `Sendable` — back out of the closure.
private struct RenderedView: @unchecked Sendable {
    let view: AnyView
}

private func rendered<V: View>(_ build: @MainActor @escaping () -> V) -> AnyView {
    MainActor.assumeIsolated { RenderedView(view: AnyView(build())) }.view
}

/// One text style built from several, for the `Theme` slots that take a single `TextStyle`.
private struct CombinedTextStyle<Content: TextStyle>: TextStyle {
    let content: Content

    func _collectAttributes(in attributes: inout AttributeContainer) {
        content._collectAttributes(in: &attributes)
    }
}

private func combined<Content: TextStyle>(
    @TextStyleBuilder _ build: () -> Content
) -> CombinedTextStyle<Content> {
    CombinedTextStyle(content: build())
}

/// A fenced code block: syntax-highlighted, scrolling sideways instead of wrapping, with the copy
/// button pinned to its corner. Half-written code from a streaming reply renders as it arrives.
struct MarkdownCodeBlock: View {
    let code: String
    let language: String?
    let size: CGFloat

    @State private var copied = false

    var body: some View {
        ScrollView(.horizontal, showsIndicators: false) {
            Text(CodeHighlighter.highlighted(code, language: language, size: size))
                .textSelection(.enabled)
                .fixedSize(horizontal: true, vertical: false)
                .padding(10)
        }
        .background(Palette.codeBackground, in: RoundedRectangle(cornerRadius: 8))
        .overlay(alignment: .topTrailing) { copyButton }
    }

    private var copyButton: some View {
        Button {
            Pasteboard.copy(code)
            copied = true
            Task { @MainActor in
                try? await Task.sleep(for: .milliseconds(1200))
                copied = false
            }
        } label: {
            RemixIcon(copied ? "check-line" : "file-copy-line", size: ControlMetrics.Size.micro.glyph)
                .foregroundStyle(copied ? Palette.added : Palette.secondary)
                .frame(width: ControlMetrics.Size.micro.side, height: ControlMetrics.Size.micro.side)
                .contentShape(Circle())
        }
        .buttonStyle(PressScale())
        .padding(.top, 4)
        .padding(.trailing, 4)
        .accessibilityLabel(Text(L10n.tr(copied ? "Copied" : "Copy code")))
    }
}
