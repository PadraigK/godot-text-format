struct ValueParser {
    private let tokens: [Token]
    private let startIndex: Int
    private var index: Int

    init(tokens: [Token], startingAt start: Int = 0) {
        self.tokens = tokens
        self.startIndex = start
        self.index = start
    }

    /// Number of tokens consumed relative to the starting index.
    /// SectionParser uses this to advance its own cursor after a call to parseValue().
    var consumedCount: Int { index - startIndex }

    mutating func parseValue() throws -> Value {
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
        case .hexColor:
            return try parseHexColor()
        case .ampersand:
            return try parseStringNameShorthand()
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
            // Constructor-like: `Name(...)` or `Name[...](... )`, or bare identifier (unknown).
            let next = peek(1)
            if next.kind == .leftParen {
                return try parseConstructor(name: token.text)
            }
            if next.kind == .leftBracket {
                return try parseTypedContainer(name: token.text)
            }
            throw ParseError("unknown identifier '\(token.text)'", at: token.range.start)
        }
    }

    private mutating func parseConstructor(name: String) throws -> Value {
        advance() // consume name
        _ = try expect(.leftParen)

        switch name {
        case "ExtResource":
            let argStart = peek().range.start
            let v = try parseValue()
            _ = try expect(.rightParen)
            guard case .string(let s) = v else {
                throw ParseError("ExtResource expects a string id", at: argStart)
            }
            return .extResource(id: s)
        case "SubResource":
            let argStart = peek().range.start
            let v = try parseValue()
            _ = try expect(.rightParen)
            guard case .string(let s) = v else {
                throw ParseError("SubResource expects a string id", at: argStart)
            }
            return .subResource(id: s)
        case "NodePath":
            let argStart = peek().range.start
            let v = try parseValue()
            _ = try expect(.rightParen)
            guard case .string(let s) = v else {
                throw ParseError("NodePath expects a string", at: argStart)
            }
            return .nodePath(s)
        case "StringName":
            let argStart = peek().range.start
            let v = try parseValue()
            _ = try expect(.rightParen)
            guard case .string(let s) = v else {
                throw ParseError("StringName expects a string", at: argStart)
            }
            return .stringName(s)
        case "Resource":
            let argStart = peek().range.start
            let v = try parseValue()
            _ = try expect(.rightParen)
            guard case .string(let s) = v else {
                throw ParseError("Resource expects a path string", at: argStart)
            }
            return .resource(path: s)
        case "Object":
            return try parseObjectTail()
        default:
            // Generic construct: parse a comma-separated list of values.
            var args: [Value] = []
            if peek().kind == .rightParen {
                advance()
                return .construct(name: name, args: args)
            }
            while true {
                args.append(try parseValue())
                let next = peek()
                if next.kind == .comma {
                    advance()
                } else if next.kind == .rightParen {
                    advance()
                    return .construct(name: name, args: args)
                } else {
                    throw ParseError(
                        "expected ',' or ')' in \(name)(...), got '\(next.text)'",
                        at: next.range.start
                    )
                }
            }
        }
    }

    /// After `Object(`, first arg is a class-name identifier, then `, "prop": value, ...`, closed by `)`.
    private mutating func parseObjectTail() throws -> Value {
        let nameTok = try expect(.identifier)
        let className = nameTok.text
        var properties: [(String, Value)] = []
        while peek().kind == .comma {
            advance()
            // Godot's writer always emits "Object(ClassName," even for zero-property
            // objects (variant_parser.cpp:2215), so a ',' followed by ')' is legal.
            if peek().kind == .rightParen { break }
            let keyTok = try expect(.string)
            _ = try expect(.colon)
            let value = try parseValue()
            properties.append((keyTok.text, value))
        }
        _ = try expect(.rightParen)
        return .object(className: className, properties: properties)
    }

    /// Parses a single type-parameter slot inside `[...]`.
    ///
    /// Accepts either a bare identifier (`.named`) or an `ExtResource("id")`
    /// call (`.extResource`). Real Godot scenes use the latter when the element
    /// type is a script-declared custom class.
    private mutating func parseTypeSlot() throws -> TypedContainerType {
        let token = peek()
        // Bare identifier not followed by `(` → a plain type name (.named).
        // An identifier followed by `(` must be a constructor call — the only
        // legal form here is ExtResource("id"), so fall through to parseValue().
        if token.kind == .identifier && peek(1).kind != .leftParen {
            advance()
            return .named(token.text)
        }
        // Try parsing a full value — the only other legal form is ExtResource("id").
        let v = try parseValue()
        if case .extResource(let id) = v {
            return .extResource(id: id)
        }
        throw ParseError(
            "expected type name or ExtResource in typed-container type slot, got \(v)",
            at: token.range.start
        )
    }

    /// `Array[T](...)` and `Dictionary[K, V](...)`.
    private mutating func parseTypedContainer(name: String) throws -> Value {
        advance() // consume name
        _ = try expect(.leftBracket)
        let firstType = try parseTypeSlot()
        var secondType: TypedContainerType? = nil
        if peek().kind == .comma {
            advance()
            secondType = try parseTypeSlot()
        }
        _ = try expect(.rightBracket)
        _ = try expect(.leftParen)
        switch name {
        case "Array":
            guard secondType == nil else {
                throw ParseError(
                    "Array[T] takes exactly one type parameter",
                    at: peek().range.start
                )
            }
            let inner = try parseValue() // the inner [...]
            guard case .array(let elems) = inner else {
                throw ParseError("Array[T] expected an array body", at: peek().range.start)
            }
            _ = try expect(.rightParen)
            return .typedArray(elementType: firstType, elements: elems)
        case "Dictionary":
            guard let v = secondType else {
                throw ParseError(
                    "Dictionary[K, V] requires two type parameters",
                    at: peek().range.start
                )
            }
            let inner = try parseValue() // the inner {...}
            guard case .dictionary(let pairs) = inner else {
                throw ParseError("Dictionary[K, V] expected a dictionary body", at: peek().range.start)
            }
            _ = try expect(.rightParen)
            return .typedDictionary(keyType: firstType, valueType: v, pairs: pairs)
        default:
            throw ParseError("unknown typed-container name '\(name)'", at: peek().range.start)
        }
    }

    private mutating func parseHexColor() throws -> Value {
        let tok = try expect(.hexColor)
        let hex = String(tok.text.dropFirst()) // drop '#'
        guard let value = UInt32(hex, radix: 16) else {
            throw ParseError("invalid hex color '\(tok.text)'", at: tok.range.start)
        }
        return .hexColor(value, hasAlpha: hex.count == 8)
    }

    private mutating func parseStringNameShorthand() throws -> Value {
        _ = try expect(.ampersand)
        let tok = try expect(.string)
        return .stringName(tok.text)
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
