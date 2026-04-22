import XCTest
@testable import GodotTextFormat

final class ValueParserTests: XCTestCase {
    // MARK: - Atoms

    func testString() throws {
        XCTAssertEqual(try parse("\"hello\""), .string("hello"))
    }

    func testIntegerPositiveAndNegative() throws {
        XCTAssertEqual(try parse("42"), .int(42))
        XCTAssertEqual(try parse("-17"), .int(-17))
    }

    func testDouble() throws {
        XCTAssertEqual(try parse("3.14"), .double(3.14))
        XCTAssertEqual(try parse("-1e9"), .double(-1e9))
    }

    func testBool() throws {
        XCTAssertEqual(try parse("true"), .bool(true))
        XCTAssertEqual(try parse("false"), .bool(false))
    }

    func testNullAndNil() throws {
        XCTAssertEqual(try parse("null"), .null)
        XCTAssertEqual(try parse("nil"), .null)
    }

    func testInfAndNan() throws {
        guard case .double(let v1) = try parse("inf") else { return XCTFail() }
        XCTAssertTrue(v1.isInfinite && v1 > 0)

        guard case .double(let v2) = try parse("-inf") else { return XCTFail() }
        XCTAssertTrue(v2.isInfinite && v2 < 0)

        guard case .double(let v3) = try parse("nan") else { return XCTFail() }
        XCTAssertTrue(v3.isNaN)
    }

    // MARK: - Helper

    private func parse(_ source: String) throws -> Value {
        var lexer = Lexer(source: source)
        let tokens = try lexer.tokenize()
        var parser = ValueParser(tokens: tokens)
        return try parser.parseValue()
    }
}
