import XCTest
@testable import GodotTextFormat

final class LexerTests: XCTestCase {
    // MARK: - Structural + whitespace

    func testEmptySource() throws {
        let tokens = try tokenize("")
        XCTAssertEqual(tokens.map(\.kind), [.eof])
    }

    func testWhitespaceIsSkipped() throws {
        let tokens = try tokenize("   \t  \n\n  ")
        XCTAssertEqual(tokens.map(\.kind), [.eof])
    }

    func testPunctuation() throws {
        let tokens = try tokenize("[]{}()=:,.&")
        XCTAssertEqual(tokens.map(\.kind), [
            .leftBracket, .rightBracket,
            .leftBrace, .rightBrace,
            .leftParen, .rightParen,
            .equals, .colon, .comma, .period,
            .ampersand,
            .eof
        ])
    }

    func testPunctuationTokenRange() throws {
        let tokens = try tokenize("[")
        XCTAssertEqual(tokens[0].range.start, SourceLocation(line: 1, column: 1))
        XCTAssertEqual(tokens[0].range.end, SourceLocation(line: 1, column: 2))
    }

    func testIdentifierSimple() throws {
        let tokens = try tokenize("foo bar_baz Quux123")
        XCTAssertEqual(tokens.map(\.kind), [.identifier, .identifier, .identifier, .eof])
        XCTAssertEqual(tokens.map(\.text), ["foo", "bar_baz", "Quux123", ""])
    }

    func testIdentifiersIncludeKeywordsAsJustIdentifiers() throws {
        // The lexer does not distinguish keywords; the parser decides.
        let tokens = try tokenize("true false null nil inf nan")
        XCTAssertEqual(tokens.map(\.kind), Array(repeating: .identifier, count: 6) + [.eof])
        XCTAssertEqual(tokens.map(\.text), ["true", "false", "null", "nil", "inf", "nan", ""])
    }

    // MARK: - Comments

    func testSemicolonCommentEndsAtNewline() throws {
        let tokens = try tokenize("foo ; this is a comment\nbar")
        XCTAssertEqual(tokens.map(\.kind), [.identifier, .identifier, .eof])
        XCTAssertEqual(tokens.map(\.text), ["foo", "bar", ""])
    }

    func testSemicolonCommentAtEOF() throws {
        let tokens = try tokenize("foo ; trailing comment")
        XCTAssertEqual(tokens.map(\.kind), [.identifier, .eof])
    }

    func testHashIsNotAComment() throws {
        // '#' starts a hex color, not a comment (only ';' is a comment in Godot's format).
        let tokens = try tokenize("#FFAA00")
        XCTAssertEqual(tokens.map(\.kind), [.hexColor, .eof])
        XCTAssertEqual(tokens.first?.text, "#FFAA00")
    }

    func testHexColorWithAlpha() throws {
        let tokens = try tokenize("#FFAA0080")
        XCTAssertEqual(tokens.map(\.kind), [.hexColor, .eof])
        XCTAssertEqual(tokens.first?.text, "#FFAA0080")
    }

    func testHexColorWrongLengthThrows() {
        XCTAssertThrowsError(try tokenize("#FFAA")) { err in
            guard let parseError = err as? ParseError else {
                return XCTFail("expected ParseError, got \(err)")
            }
            XCTAssertEqual(parseError.location, SourceLocation(line: 1, column: 1))
        }
    }

    // MARK: - Source locations

    func testSourceLocationsTrackLinesAndColumns() throws {
        let tokens = try tokenize("foo\n  bar")
        XCTAssertEqual(tokens[0].range.start, SourceLocation(line: 1, column: 1))
        XCTAssertEqual(tokens[0].range.end, SourceLocation(line: 1, column: 4))
        XCTAssertEqual(tokens[1].range.start, SourceLocation(line: 2, column: 3))
    }

    // MARK: - Numbers

    func testIntegerPositive() throws {
        let tokens = try tokenize("42")
        XCTAssertEqual(tokens.map(\.kind), [.integer, .eof])
        XCTAssertEqual(tokens[0].text, "42")
    }

    func testIntegerNegative() throws {
        let tokens = try tokenize("-17")
        XCTAssertEqual(tokens.map(\.kind), [.integer, .eof])
        XCTAssertEqual(tokens[0].text, "-17")
    }

    func testDoubleWithDecimalPoint() throws {
        let tokens = try tokenize("3.14")
        XCTAssertEqual(tokens.map(\.kind), [.double, .eof])
        XCTAssertEqual(tokens[0].text, "3.14")
    }

    func testDoubleStartingWithDecimalPoint() throws {
        let tokens = try tokenize(".5")
        XCTAssertEqual(tokens.map(\.kind), [.double, .eof])
        XCTAssertEqual(tokens[0].text, ".5")
    }

    func testDoubleEndingWithDecimalPoint() throws {
        let tokens = try tokenize("5.")
        XCTAssertEqual(tokens.map(\.kind), [.double, .eof])
        XCTAssertEqual(tokens[0].text, "5.")
    }

    func testDoubleWithExponent() throws {
        let tokens = try tokenize("1e9 2.5e-3 -1E+2")
        XCTAssertEqual(tokens.map(\.kind), [.double, .double, .double, .eof])
        XCTAssertEqual(tokens.map(\.text), ["1e9", "2.5e-3", "-1E+2", ""])
    }

    func testNegativeDouble() throws {
        let tokens = try tokenize("-3.14")
        XCTAssertEqual(tokens.map(\.kind), [.double, .eof])
        XCTAssertEqual(tokens[0].text, "-3.14")
    }

    func testPeriodBetweenIdentifiersIsAPeriod() throws {
        // e.g. "gd_scene.Android" (platform-variant section name)
        let tokens = try tokenize("gd_scene.Android")
        XCTAssertEqual(tokens.map(\.kind), [.identifier, .period, .identifier, .eof])
    }

    func testNegativeInfAsIdentifier() throws {
        // "-inf" becomes a single identifier token so the ValueParser can map it to .double(-.infinity).
        let tokens = try tokenize("-inf")
        XCTAssertEqual(tokens.map(\.kind), [.identifier, .eof])
        XCTAssertEqual(tokens[0].text, "-inf")
    }

    func testStrayMinusThrows() {
        XCTAssertThrowsError(try tokenize("-"))
        XCTAssertThrowsError(try tokenize("- "))
        XCTAssertThrowsError(try tokenize("-+"))
    }

    // MARK: - Strings

    func testSimpleString() throws {
        let tokens = try tokenize("\"hello world\"")
        XCTAssertEqual(tokens.map(\.kind), [.string, .eof])
        XCTAssertEqual(tokens[0].text, "hello world")
    }

    func testEmptyString() throws {
        let tokens = try tokenize("\"\"")
        XCTAssertEqual(tokens.map(\.kind), [.string, .eof])
        XCTAssertEqual(tokens[0].text, "")
    }

    func testStringWithSimpleEscapes() throws {
        let tokens = try tokenize(#""line1\nline2\ttab\"quote\\back""#)
        XCTAssertEqual(tokens.map(\.kind), [.string, .eof])
        XCTAssertEqual(tokens[0].text, "line1\nline2\ttab\"quote\\back")
    }

    func testStringWithBFR() throws {
        let tokens = try tokenize(#""a\bb\fc\rd""#)
        XCTAssertEqual(tokens[0].text, "a\u{08}b\u{0C}c\rd")
    }

    func testStringWithUnicodeBMP() throws {
        let tokens = try tokenize(#""é""#)  // é
        XCTAssertEqual(tokens[0].text, "\u{00E9}")
    }

    func testStringWithUnicodeSurrogatePair() throws {
        // U+1F600 😀 encoded as surrogate pair 😀
        let tokens = try tokenize(#""😀""#)
        XCTAssertEqual(tokens[0].text, "\u{1F600}")
    }

    func testStringWithUnicodeBMPEscape() throws {
        // é → é (U+00E9) via the 4-digit BMP escape path.
        let tokens = try tokenize("\"hello\\u00E9world\"")
        XCTAssertEqual(tokens.map(\.kind), [.string, .eof])
        XCTAssertEqual(tokens[0].text, "hello\u{00E9}world")
    }

    func testStringWithUnicodeSurrogatePairEscape() throws {
        // 😀 → 😀 (U+1F600) via UTF-16 surrogate pair combination 😀.
        let tokens = try tokenize("\"smile\\uD83D\\uDE00\"")
        XCTAssertEqual(tokens.map(\.kind), [.string, .eof])
        XCTAssertEqual(tokens[0].text, "smile\u{1F600}")
    }

    func testStringLoneLowSurrogateThrows() {
        // \uDC00 alone is an unpaired low surrogate — Godot's variant_parser rejects it.
        XCTAssertThrowsError(try tokenize(#""\uDC00""#)) { error in
            guard let parseError = error as? ParseError else {
                return XCTFail("expected ParseError, got \(error)")
            }
            XCTAssertTrue(parseError.message.contains("low surrogate"),
                "error message should mention low surrogate, got: \(parseError.message)")
        }
    }

    func testStringWithUnicodeExtended() throws {
        // \U takes 6 hex digits; \U01F600 is also 😀 (U+1F600)
        let tokens = try tokenize(#""\U01F600""#)
        XCTAssertEqual(tokens[0].text, "\u{1F600}")
    }

    func testStringUnterminated() {
        XCTAssertThrowsError(try tokenize("\"never ends")) { error in
            guard error is ParseError else {
                return XCTFail("expected ParseError, got \(error)")
            }
        }
    }

    func testStringUnknownEscapePassesThrough() throws {
        // Unknown escapes (variant_parser behavior) pass through as the literal char.
        let tokens = try tokenize(#""foo\qbar""#)
        XCTAssertEqual(tokens[0].text, "fooqbar")
    }

    // MARK: - Helper

    private func tokenize(_ source: String) throws -> [Token] {
        var lexer = Lexer(source: source)
        return try lexer.tokenize()
    }
}
