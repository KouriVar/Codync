import CodyncKit
import SwiftUI

/// A small syntax highlighter for fenced code blocks: comments, strings, numbers and keywords, in the
/// colours the app already uses elsewhere. No dependency, and nothing to fail on a half-written
/// stream — an unclosed string or comment simply colours the rest of what has arrived.
///
/// It is deliberately coarse: the message body wants code to be readable at a glance, not
/// compiler-grade colouring, and a table of every keyword in every language is a maintenance bill
/// nobody asked for.
enum CodeHighlighter {
    /// The colour each token kind is drawn in, all from the palette.
    enum Kind {
        case keyword
        case string
        case number
        case comment
    }

    static func color(_ kind: Kind) -> Color {
        switch kind {
        case .keyword: Palette.text
        case .string: Palette.added
        case .number: Palette.warning
        case .comment: Palette.tertiary
        }
    }

    /// The code with its tokens coloured. Unknown languages come back plain.
    static func highlighted(_ code: String, language: String?, size: CGFloat) -> AttributedString {
        guard let syntax = Syntax(language), !code.isEmpty else { return AttributedString(code) }
        var result = AttributedString()
        var index = code.startIndex
        var plainStart = index

        func flushPlain(upTo end: String.Index) {
            guard plainStart < end else { return }
            var part = AttributedString(code[plainStart..<end])
            part.font = .system(size: size, design: .monospaced)
            part.foregroundColor = Palette.text
            result += part
        }

        func append(_ text: Substring, as kind: Kind) {
            var part = AttributedString(text)
            part.font = .system(size: size, weight: kind == .keyword ? .semibold : .regular,
                                design: .monospaced)
            part.foregroundColor = color(kind)
            result += part
        }

        while index < code.endIndex {
            let rest = code[index...]

            // Comments first: nothing inside one is highlighted again.
            if let comment = syntax.comments.first(where: { rest.hasPrefix($0.open) }) {
                flushPlain(upTo: index)
                let end: String.Index
                if let close = comment.close {
                    let after = code.index(index, offsetBy: comment.open.count, limitedBy: code.endIndex)
                        ?? code.endIndex
                    end = code[after...].range(of: close)?.upperBound ?? code.endIndex
                } else {
                    end = rest.firstIndex(of: "\n") ?? code.endIndex
                }
                append(code[index..<end], as: .comment)
                index = end
                plainStart = index
                continue
            }

            let character = rest.first!

            if syntax.strings.contains(character) {
                flushPlain(upTo: index)
                var cursor = code.index(after: index)
                while cursor < code.endIndex {
                    let current = code[cursor]
                    if current == "\\" {
                        cursor = code.index(after: cursor)
                        if cursor < code.endIndex { cursor = code.index(after: cursor) }
                        continue
                    }
                    cursor = code.index(after: cursor)
                    if current == character { break }
                }
                append(code[index..<cursor], as: .string)
                index = cursor
                plainStart = index
                continue
            }

            if character.isNumber {
                flushPlain(upTo: index)
                var cursor = index
                while cursor < code.endIndex, code[cursor].isNumber || code[cursor] == "." {
                    cursor = code.index(after: cursor)
                }
                append(code[index..<cursor], as: .number)
                index = cursor
                plainStart = index
                continue
            }

            if character.isLetter || character == "_" {
                var cursor = index
                while cursor < code.endIndex, code[cursor].isLetter || code[cursor].isNumber || code[cursor] == "_" {
                    cursor = code.index(after: cursor)
                }
                let word = code[index..<cursor]
                if syntax.keywords.contains(String(word)) {
                    flushPlain(upTo: index)
                    append(word, as: .keyword)
                    plainStart = cursor
                }
                index = cursor
                continue
            }

            index = code.index(after: index)
        }
        flushPlain(upTo: code.endIndex)
        return result
    }

    /// What one language's colouring needs to know.
    private struct Syntax {
        let keywords: Set<String>
        /// Comment openers with their terminator; `nil` means it runs to the end of the line.
        let comments: [(open: String, close: String?)]
        let strings: Set<Character>

        init?(_ language: String?) {
            switch Syntax.family(language) {
            case .swift:
                self.init(Syntax.swiftKeywords, comments: [("//", nil), ("/*", "*/")], strings: ["\""])
            case .json:
                self.init(["true", "false", "null"], comments: [], strings: ["\""])
            case .javascript:
                self.init(Syntax.javascriptKeywords, comments: [("//", nil), ("/*", "*/")],
                          strings: ["\"", "'", "`"])
            case .python:
                self.init(Syntax.pythonKeywords, comments: [("#", nil)], strings: ["\"", "'"])
            case .shell:
                self.init(Syntax.shellKeywords, comments: [("#", nil)], strings: ["\"", "'"])
            case .sql:
                self.init(Syntax.sqlKeywords, comments: [("--", nil)], strings: ["\"", "'"])
            case .go:
                self.init(Syntax.goKeywords, comments: [("//", nil), ("/*", "*/")], strings: ["\"", "`"])
            case .rust:
                self.init(Syntax.rustKeywords, comments: [("//", nil), ("/*", "*/")], strings: ["\"", "'"])
            case .yaml:
                self.init(Syntax.yamlKeywords, comments: [("#", nil)], strings: ["\"", "'"])
            case .plain:
                return nil
            }
        }

        private init(_ keywords: Set<String>, comments: [(open: String, close: String?)],
                     strings: Set<Character>) {
            self.keywords = keywords
            self.comments = comments
            self.strings = strings
        }

        private enum Family { case swift, json, javascript, python, shell, sql, go, rust, yaml, plain }

        private static func family(_ language: String?) -> Family {
            switch language?.lowercased() {
            case "swift": .swift
            case "json", "jsonc": .json
            case "js", "javascript", "ts", "typescript", "jsx", "tsx", "mjs": .javascript
            case "py", "python": .python
            case "sh", "bash", "zsh", "shell", "console": .shell
            case "sql": .sql
            case "go", "golang": .go
            case "rs", "rust": .rust
            case "yaml", "yml": .yaml
            default: .plain
            }
        }

        private static let swiftKeywords: Set<String> = [
            "actor", "any", "as", "associatedtype", "async", "await", "break", "case", "catch", "class",
            "continue", "defer", "default", "deinit", "do", "else", "enum", "extension", "fallthrough",
            "false", "fileprivate", "final", "for", "func", "guard", "if", "import", "in", "indirect",
            "init", "inout", "internal", "is", "lazy", "let", "mutating", "nil", "nonisolated", "open",
            "operator", "override", "private", "protocol", "public", "repeat", "required", "return",
            "self", "Self", "some", "static", "struct", "subscript", "super", "switch", "throw", "throws",
            "true", "try", "typealias", "var", "weak", "where", "while",
        ]

        private static let javascriptKeywords: Set<String> = [
            "async", "await", "break", "case", "catch", "class", "const", "continue", "default", "delete",
            "do", "else", "export", "extends", "false", "finally", "for", "from", "function", "if",
            "import", "in", "instanceof", "let", "new", "null", "of", "return", "static", "super",
            "switch", "this", "throw", "true", "try", "type", "typeof", "undefined", "var", "void",
            "while", "yield",
        ]

        private static let pythonKeywords: Set<String> = [
            "and", "as", "assert", "async", "await", "break", "class", "continue", "def", "del", "elif",
            "else", "except", "False", "finally", "for", "from", "global", "if", "import", "in", "is",
            "lambda", "None", "nonlocal", "not", "or", "pass", "raise", "return", "True", "try", "while",
            "with", "yield",
        ]

        private static let shellKeywords: Set<String> = [
            "case", "do", "done", "elif", "else", "esac", "export", "fi", "for", "function", "if", "in",
            "local", "return", "then", "until", "while",
        ]

        private static let sqlKeywords: Set<String> = [
            "AND", "AS", "ASC", "BY", "CREATE", "DELETE", "DESC", "DISTINCT", "DROP", "FROM", "GROUP",
            "HAVING", "INDEX", "INSERT", "INTO", "JOIN", "LEFT", "LIMIT", "NOT", "NULL", "ON", "OR",
            "ORDER", "OUTER", "RIGHT", "SELECT", "SET", "TABLE", "UPDATE", "VALUES", "WHERE",
        ]

        private static let goKeywords: Set<String> = [
            "break", "case", "chan", "const", "continue", "default", "defer", "else", "fallthrough",
            "for", "func", "go", "goto", "if", "interface", "map", "package", "range", "return",
            "select", "struct", "switch", "type", "var",
        ]

        private static let rustKeywords: Set<String> = [
            "as", "async", "await", "break", "const", "continue", "crate", "dyn", "else", "enum",
            "extern", "false", "fn", "for", "if", "impl", "in", "let", "loop", "match", "mod", "move",
            "mut", "pub", "ref", "return", "self", "Self", "static", "struct", "super", "trait", "true",
            "type", "unsafe", "use", "where", "while",
        ]

        private static let yamlKeywords: Set<String> = ["true", "false", "null", "~"]
    }
}
