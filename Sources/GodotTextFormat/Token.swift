public struct SourceLocation: Hashable, Sendable {
    public let line: Int
    public let column: Int
    public init(line: Int, column: Int) {
        self.line = line
        self.column = column
    }
}

struct SourceRange: Hashable, Sendable {
    let start: SourceLocation
    /// One-past-the-last-character end position (exclusive upper bound).
    let end: SourceLocation
    init(start: SourceLocation, end: SourceLocation) {
        self.start = start
        self.end = end
    }
}

enum TokenKind: Hashable, Sendable {
    case leftBracket      // [
    case rightBracket     // ]
    case leftBrace        // {
    case rightBrace       // }
    case leftParen        // (
    case rightParen       // )
    case equals           // =
    case colon            // :
    case comma            // ,
    case period           // .
    case ampersand        // &    (StringName prefix per variant_parser.cpp)
    case identifier       // foo, true, null, inf, ExtResource, etc.
    case string           // "..."
    case integer          // 42, -17
    case double           // 3.14, -1e9, .5
    case hexColor         // #RRGGBB / #RRGGBBAA
    case eof
}

struct Token: Hashable, Sendable {
    let kind: TokenKind
    /// Textual content. For `.string` this is the *decoded* string (escapes resolved).
    /// For `.identifier`, `.integer`, `.double`, `.hexColor`, this is the raw source text.
    /// For punctuation tokens this is a single-character string.
    let text: String
    let range: SourceRange

    init(kind: TokenKind, text: String, range: SourceRange) {
        self.kind = kind
        self.text = text
        self.range = range
    }
}
