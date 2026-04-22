public struct ValueParser {
    private let tokens: [Token]
    private var index: Int = 0

    public init(tokens: [Token]) {
        self.tokens = tokens
    }

    /// Position in the token stream. Used by SectionParser to resume after a value.
    public var consumedCount: Int { index }

    public mutating func parseValue() throws -> Value {
        let token = peek()
        switch token.kind {
        case .string:
            advance()
            return .string(token.text)
        case .integer:
            advance()
            guard let n = Int64(token.text) else {
                throw ParseError("invalid integer literal '\(token.text)'", at: token.range.start)
            }
            return .int(n)
        case .double:
            advance()
            guard let d = Double(token.text) else {
                throw ParseError("invalid double literal '\(token.text)'", at: token.range.start)
            }
            return .double(d)
        case .identifier:
            return try parseIdentifierValue()
        case .leftBracket:
            return try parseArray()
        case .leftBrace:
            return try parseDictionary()
        default:
            throw ParseError(
                "unexpected token '\(token.text)' when expecting a value",
                at: token.range.start
            )
        }
    }

    private mutating func parseIdentifierValue() throws -> Value {
        let token = peek()
        switch token.text {
        case "true":  advance(); return .bool(true)
        case "false": advance(); return .bool(false)
        case "null", "nil": advance(); return .null
        case "inf":   advance(); return .double(.infinity)
        case "-inf":  advance(); return .double(-.infinity)
        case "nan":   advance(); return .double(.nan)
        case "-nan":  advance(); return .double(-.nan)
        default:
            throw ParseError("unknown identifier '\(token.text)'", at: token.range.start)
        }
    }

    private mutating func parseArray() throws -> Value {
        _ = try expect(.leftBracket)
        var items: [Value] = []
        if peek().kind == .rightBracket {
            advance()
            return .array(items)
        }
        while true {
            items.append(try parseValue())
            let next = peek()
            if next.kind == .comma {
                advance()
                if peek().kind == .rightBracket {
                    throw ParseError("trailing comma in array", at: peek().range.start)
                }
            } else if next.kind == .rightBracket {
                advance()
                return .array(items)
            } else {
                throw ParseError(
                    "expected ',' or ']' in array, got '\(next.text)'",
                    at: next.range.start
                )
            }
        }
    }

    private mutating func parseDictionary() throws -> Value {
        _ = try expect(.leftBrace)
        var pairs: [(Value, Value)] = []
        if peek().kind == .rightBrace {
            advance()
            return .dictionary(pairs)
        }
        while true {
            let key = try parseValue()
            _ = try expect(.colon)
            let value = try parseValue()
            pairs.append((key, value))
            let next = peek()
            if next.kind == .comma {
                advance()
                if peek().kind == .rightBrace {
                    throw ParseError("trailing comma in dictionary", at: peek().range.start)
                }
            } else if next.kind == .rightBrace {
                advance()
                return .dictionary(pairs)
            } else {
                throw ParseError(
                    "expected ',' or '}' in dictionary, got '\(next.text)'",
                    at: next.range.start
                )
            }
        }
    }

    // MARK: - Cursor

    internal func peek(_ offset: Int = 0) -> Token {
        let i = index + offset
        if i < tokens.count { return tokens[i] }
        // Lexer always appends a real `.eof` token, so tokens.last carries
        // the correct end-of-source location. Fall back to a synthetic only
        // if somehow the token stream is empty.
        if let last = tokens.last { return last }
        let eof = SourceLocation(line: 0, column: 0)
        return Token(kind: .eof, text: "", range: SourceRange(start: eof, end: eof))
    }

    internal mutating func advance() {
        if index < tokens.count { index += 1 }
    }

    internal mutating func expect(_ kind: TokenKind) throws -> Token {
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
