public struct SectionParser {
    private let tokens: [Token]
    private var index: Int = 0

    public init(tokens: [Token]) {
        self.tokens = tokens
    }

    public mutating func parseDocument() throws -> [Section] {
        var sections: [Section] = []
        while peek().kind != .eof {
            sections.append(try parseSection())
        }
        return sections
    }

    private mutating func parseSection() throws -> Section {
        let startTok = peek()
        guard startTok.kind == .leftBracket else {
            throw ParseError(
                "expected '[' at start of section, got '\(startTok.text)'",
                at: startTok.range.start
            )
        }
        advance()

        let kind = try parseDottedIdentifier()

        var attrs: [(String, Value)] = []
        while peek().kind != .rightBracket {
            let keyTok = peek()
            guard keyTok.kind == .identifier else {
                throw ParseError(
                    "expected attribute name, got '\(keyTok.text)'",
                    at: keyTok.range.start
                )
            }
            advance()
            _ = try expect(.equals)
            var valueParser = ValueParser(tokens: tokens, startingAt: index)
            let value = try valueParser.parseValue()
            index += valueParser.consumedCount
            attrs.append((keyTok.text, value))
        }
        let rightBracketTok = try expect(.rightBracket)

        // Body: zero or more `identifier = value` lines until EOF or next '['.
        var body: [(String, Value)] = []
        while peek().kind == .identifier {
            let keyTok = peek()
            advance()
            _ = try expect(.equals)
            var valueParser = ValueParser(tokens: tokens, startingAt: index)
            let value = try valueParser.parseValue()
            index += valueParser.consumedCount
            body.append((keyTok.text, value))
        }

        return Section(
            kind: kind,
            attrs: attrs,
            body: body,
            headerRange: SourceRange(start: startTok.range.start, end: rightBracketTok.range.end)
        )
    }

    private mutating func parseDottedIdentifier() throws -> String {
        let first = try expect(.identifier)
        var name = first.text
        while peek().kind == .period {
            advance()
            let part = try expect(.identifier)
            name += "." + part.text
        }
        return name
    }

    // MARK: - Cursor

    private func peek(_ offset: Int = 0) -> Token {
        let i = index + offset
        if i < tokens.count { return tokens[i] }
        if let last = tokens.last { return last }
        let eof = SourceLocation(line: 0, column: 0)
        return Token(kind: .eof, text: "", range: SourceRange(start: eof, end: eof))
    }

    private mutating func advance() {
        if index < tokens.count { index += 1 }
    }

    private mutating func expect(_ kind: TokenKind) throws -> Token {
        let token = peek()
        guard token.kind == kind else {
            throw ParseError(
                "expected \(kind), got \(token.kind) ('\(token.text)')",
                at: token.range.start
            )
        }
        advance()
        return token
    }


}
