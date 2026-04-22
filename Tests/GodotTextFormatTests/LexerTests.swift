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

    // MARK: - Helper

    private func tokenize(_ source: String) throws -> [Token] {
        var lexer = Lexer(source: source)
        return try lexer.tokenize()
    }
}
