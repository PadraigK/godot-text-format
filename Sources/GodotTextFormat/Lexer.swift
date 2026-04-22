public struct Lexer {
    private let source: [Character]
    private var index: Int = 0
    private var line: Int = 1
    private var column: Int = 1

    public init(source: String) {
        self.source = Array(source)
    }

    public mutating func tokenize() throws -> [Token] {
        var tokens: [Token] = []
        while true {
            let token = try nextToken()
            tokens.append(token)
            if token.kind == .eof { break }
        }
        return tokens
    }

    private mutating func nextToken() throws -> Token {
        skipWhitespaceAndComments()
        let start = currentLocation()
        guard let ch = peek() else {
            return Token(kind: .eof, text: "", range: SourceRange(start: start, end: start))
        }

        switch ch {
        case "[": advance(); return make(.leftBracket, "[", from: start)
        case "]": advance(); return make(.rightBracket, "]", from: start)
        case "{": advance(); return make(.leftBrace, "{", from: start)
        case "}": advance(); return make(.rightBrace, "}", from: start)
        case "(": advance(); return make(.leftParen, "(", from: start)
        case ")": advance(); return make(.rightParen, ")", from: start)
        case "=": advance(); return make(.equals, "=", from: start)
        case ":": advance(); return make(.colon, ":", from: start)
        case ",": advance(); return make(.comma, ",", from: start)
        case ".":
            // `.5`-style floats start with a period; dispatch to readNumber
            // when followed by a digit. Otherwise emit a bare `.period` token
            // (used for dotted section kind names like `gd_scene.Android`).
            if let next = peek(1), next.isNumber {
                return try readNumber(from: start)
            }
            advance()
            return make(.period, ".", from: start)
        case "&": advance(); return make(.ampersand, "&", from: start)
        case "#": return try readHexColor(from: start)
        case "-":
            if let next = peek(1) {
                if next.isNumber || next == "." {
                    return try readNumber(from: start)
                }
                if next.isLetter {
                    // `-inf`, `-nan` etc. — produce a single identifier token
                    // whose text includes the leading `-`. The ValueParser
                    // interprets these at the value level.
                    advance() // consume '-'
                    var text = "-"
                    while let ch = peek(), ch.isLetter || ch.isNumber || ch == "_" {
                        text.append(ch)
                        advance()
                    }
                    return make(.identifier, text, from: start)
                }
            }
            throw ParseError("stray '-' is not allowed", at: start)
        default:
            if ch.isNumber {
                return try readNumber(from: start)
            }
            if ch.isLetter || ch == "_" {
                return readIdentifier(from: start)
            }
            throw ParseError("unexpected character '\(ch)'", at: start)
        }
    }

    // MARK: - Scanner primitives

    private func peek(_ offset: Int = 0) -> Character? {
        let i = index + offset
        return i < source.count ? source[i] : nil
    }

    private mutating func advance() {
        guard index < source.count else { return }
        let ch = source[index]
        index += 1
        if ch == "\n" {
            line += 1
            column = 1
        } else {
            column += 1
        }
    }

    private func currentLocation() -> SourceLocation {
        SourceLocation(line: line, column: column)
    }

    private func make(_ kind: TokenKind, _ text: String, from start: SourceLocation) -> Token {
        Token(kind: kind, text: text, range: SourceRange(start: start, end: currentLocation()))
    }

    // MARK: - Whitespace and comments

    private mutating func skipWhitespaceAndComments() {
        while let ch = peek() {
            if ch.isWhitespace {
                advance()
            } else if ch == ";" {
                while let c = peek(), c != "\n" { advance() }
            } else {
                break
            }
        }
    }

    // MARK: - Identifiers

    private mutating func readIdentifier(from start: SourceLocation) -> Token {
        var text = ""
        while let ch = peek(), ch.isLetter || ch.isNumber || ch == "_" {
            text.append(ch)
            advance()
        }
        return make(.identifier, text, from: start)
    }

    // MARK: - Numbers

    private mutating func readNumber(from start: SourceLocation) throws -> Token {
        var text = ""
        var isDouble = false

        // Optional leading '-'
        if peek() == "-" {
            text.append("-")
            advance()
        }

        // Integer part (may be empty if starting with '.')
        while let ch = peek(), ch.isNumber {
            text.append(ch)
            advance()
        }

        // Fractional part
        if peek() == "." {
            isDouble = true
            text.append(".")
            advance()
            while let ch = peek(), ch.isNumber {
                text.append(ch)
                advance()
            }
        }

        // Exponent
        if let e = peek(), e == "e" || e == "E" {
            isDouble = true
            text.append(e)
            advance()
            if let sign = peek(), sign == "+" || sign == "-" {
                text.append(sign)
                advance()
            }
            var exponentDigits = 0
            while let ch = peek(), ch.isNumber {
                text.append(ch)
                advance()
                exponentDigits += 1
            }
            guard exponentDigits > 0 else {
                throw ParseError("missing digits after exponent marker", at: start)
            }
        }

        // `readNumber` is only entered when the caller has already seen a
        // digit, `.<digit>`, or `-<digit|.|letter>`. The bare-period path
        // guarantees a digit follows, so `text == "."` is unreachable here.
        // The remaining rejection cases are `-` alone and `-.`, both of
        // which slip through when the caller dispatches on `-` and the
        // character after the period isn't a digit (e.g. "-.<space>").
        if text == "-" || text == "-." {
            throw ParseError("malformed number literal '\(text)'", at: start)
        }

        return make(isDouble ? .double : .integer, text, from: start)
    }

    // MARK: - Hex color

    private mutating func readHexColor(from start: SourceLocation) throws -> Token {
        advance() // consume '#'
        var text = "#"
        while let ch = peek(), ch.hexDigitValue != nil {
            text.append(ch)
            advance()
        }
        let digits = text.count - 1
        guard digits == 6 || digits == 8 else {
            throw ParseError("hex color must have 6 or 8 hex digits, got \(digits)", at: start)
        }
        return make(.hexColor, text, from: start)
    }
}
