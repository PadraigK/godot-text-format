import XCTest
@testable import GodotTextFormat

final class TokenTests: XCTestCase {
    func testSourceLocationIsEquatable() {
        XCTAssertEqual(SourceLocation(line: 1, column: 2), SourceLocation(line: 1, column: 2))
        XCTAssertNotEqual(SourceLocation(line: 1, column: 2), SourceLocation(line: 2, column: 2))
    }

    func testSourceRangeSpansTwoLocations() {
        let range = SourceRange(
            start: SourceLocation(line: 1, column: 1),
            end: SourceLocation(line: 1, column: 5)
        )
        XCTAssertEqual(range.start.line, 1)
        XCTAssertEqual(range.end.column, 5)
    }

    func testTokenKindCasesExist() {
        // Sanity-check the kind enum compiles and covers the tokens we rely on.
        let kinds: [TokenKind] = [
            .leftBracket, .rightBracket,
            .leftBrace, .rightBrace,
            .leftParen, .rightParen,
            .equals, .colon, .comma, .period,
            .ampersand,
            .identifier, .string, .integer, .double,
            .hexColor, .eof
        ]
        XCTAssertEqual(kinds.count, 17)
    }
}
