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

        guard case .double(let v4) = try parse("-nan") else { return XCTFail() }
        XCTAssertTrue(v4.isNaN)
    }

    func testUnknownIdentifierThrows() {
        XCTAssertThrowsError(try parse("foo")) { error in
            guard let parseError = error as? ParseError else {
                return XCTFail("expected ParseError, got \(error)")
            }
            XCTAssertTrue(parseError.message.contains("unknown identifier"),
                "expected 'unknown identifier' in message, got: \(parseError.message)")
        }
    }

    // MARK: - Containers

    func testEmptyArray() throws {
        XCTAssertEqual(try parse("[]"), .array([]))
    }

    func testFlatArray() throws {
        XCTAssertEqual(try parse("[1, 2, 3]"), .array([.int(1), .int(2), .int(3)]))
    }

    func testMixedArray() throws {
        XCTAssertEqual(try parse("[1, \"two\", true, null]"),
            .array([.int(1), .string("two"), .bool(true), .null]))
    }

    func testNestedArray() throws {
        XCTAssertEqual(try parse("[[1, 2], [3]]"),
            .array([.array([.int(1), .int(2)]), .array([.int(3)])]))
    }

    func testArrayMultiline() throws {
        XCTAssertEqual(try parse("[\n  1,\n  2,\n  3\n]"),
            .array([.int(1), .int(2), .int(3)]))
    }

    func testArrayTrailingCommaRejected() {
        XCTAssertThrowsError(try parse("[1, 2,]")) { error in
            guard let parseError = error as? ParseError else {
                return XCTFail("expected ParseError, got \(error)")
            }
            XCTAssertTrue(parseError.message.contains("trailing comma"),
                "expected 'trailing comma' in message, got: \(parseError.message)")
        }
    }

    func testEmptyDictionary() throws {
        XCTAssertEqual(try parse("{}"), .dictionary([]))
    }

    func testFlatDictionary() throws {
        XCTAssertEqual(try parse("{\"a\": 1, \"b\": 2}"),
            .dictionary([(.string("a"), .int(1)), (.string("b"), .int(2))]))
    }

    func testDictionaryPreservesOrder() throws {
        let v = try parse("{\"z\": 1, \"a\": 2, \"m\": 3}")
        guard case .dictionary(let pairs) = v else { return XCTFail() }
        XCTAssertEqual(pairs.map { $0.0 }, [.string("z"), .string("a"), .string("m")])
    }

    func testDictionaryNestedValue() throws {
        XCTAssertEqual(try parse("{\"outer\": {\"inner\": 42}}"),
            .dictionary([(.string("outer"), .dictionary([(.string("inner"), .int(42))]))]))
    }

    func testDictionaryNonStringKey() throws {
        // Numeric keys are legal Variant dicts.
        XCTAssertEqual(try parse("{1: \"one\", 2: \"two\"}"),
            .dictionary([(.int(1), .string("one")), (.int(2), .string("two"))]))
    }

    func testDictionaryTrailingCommaRejected() {
        XCTAssertThrowsError(try parse("{\"a\": 1,}")) { error in
            guard let parseError = error as? ParseError else {
                return XCTFail("expected ParseError, got \(error)")
            }
            XCTAssertTrue(parseError.message.contains("trailing comma"),
                "expected 'trailing comma' in message, got: \(parseError.message)")
        }
    }

    // MARK: - References

    func testExtResource() throws {
        XCTAssertEqual(try parse("ExtResource(\"1_icon\")"), .extResource(id: "1_icon"))
    }

    func testSubResource() throws {
        XCTAssertEqual(try parse("SubResource(\"anim_1\")"), .subResource(id: "anim_1"))
    }

    func testNodePath() throws {
        XCTAssertEqual(try parse("NodePath(\"Kettle/BoilMeter\")"), .nodePath("Kettle/BoilMeter"))
    }

    func testStringNameConstructor() throws {
        XCTAssertEqual(try parse("StringName(\"foo\")"), .stringName("foo"))
    }

    func testStringNameAmpersand() throws {
        XCTAssertEqual(try parse("&\"foo\""), .stringName("foo"))
    }

    func testResource() throws {
        XCTAssertEqual(try parse("Resource(\"res://foo.tres\")"), .resource(path: "res://foo.tres"))
    }

    // MARK: - Hex color

    func testHexColorNoAlpha() throws {
        XCTAssertEqual(try parse("#FFAA00"), .hexColor(0xFFAA00, hasAlpha: false))
    }

    func testHexColorWithAlpha() throws {
        XCTAssertEqual(try parse("#FFAA0080"), .hexColor(0xFFAA0080, hasAlpha: true))
    }

    // MARK: - Generic constructors

    func testVector2AsConstruct() throws {
        XCTAssertEqual(try parse("Vector2(1, 2)"),
            .construct(name: "Vector2", args: [.int(1), .int(2)]))
    }

    func testRIDConstruct() throws {
        XCTAssertEqual(try parse("RID()"), .construct(name: "RID", args: []))
        XCTAssertEqual(try parse("RID(42)"), .construct(name: "RID", args: [.int(42)]))
    }

    // MARK: - Typed containers

    func testTypedArray() throws {
        XCTAssertEqual(try parse("Array[int]([1, 2, 3])"),
            .typedArray(elementType: .named("int"), elements: [.int(1), .int(2), .int(3)]))
    }

    func testTypedDictionary() throws {
        XCTAssertEqual(try parse("Dictionary[String, int]({\"a\": 1})"),
            .typedDictionary(keyType: .named("String"), valueType: .named("int"), pairs: [(.string("a"), .int(1))]))
    }

    func testTypedArrayWithExtResourceType() throws {
        XCTAssertEqual(
            try parse(#"Array[ExtResource("2_u5sy4")]([1, 2])"#),
            .typedArray(elementType: .extResource(id: "2_u5sy4"), elements: [.int(1), .int(2)])
        )
    }

    func testTypedDictionaryWithExtResourceKey() throws {
        XCTAssertEqual(
            try parse(#"Dictionary[ExtResource("k"), int]({"a": 1})"#),
            .typedDictionary(
                keyType: .extResource(id: "k"),
                valueType: .named("int"),
                pairs: [(.string("a"), .int(1))]
            )
        )
    }

    // MARK: - Object

    func testObject() throws {
        let v = try parse("Object(MyClass, \"a\": 1, \"b\": \"two\")")
        XCTAssertEqual(v, .object(className: "MyClass",
            properties: [("a", .int(1)), ("b", .string("two"))]))
    }

    func testObjectNoProperties() throws {
        // Godot's writer always emits "Object(ClassName," even for zero-property objects.
        let v = try parse("Object(MyClass,)")
        XCTAssertEqual(v, .object(className: "MyClass", properties: []))
    }

    func testExtResourceWrongArgTypeThrows() {
        XCTAssertThrowsError(try parse("ExtResource(42)")) { error in
            guard let parseError = error as? ParseError else {
                return XCTFail("expected ParseError, got \(error)")
            }
            XCTAssertTrue(parseError.message.contains("string"),
                "expected 'string' in message, got: \(parseError.message)")
        }
    }

    func testTypedArrayWithTwoTypeParamsThrows() {
        XCTAssertThrowsError(try parse("Array[int, float]([1, 2])"))
    }

    func testTypedDictionaryWithOneTypeParamThrows() {
        XCTAssertThrowsError(try parse("Dictionary[String]({\"a\": 1})"))
    }

    // MARK: - Helper

    private func parse(_ source: String) throws -> Value {
        var lexer = Lexer(source: source)
        let tokens = try lexer.tokenize()
        var parser = ValueParser(tokens: tokens)
        return try parser.parseValue()
    }
}
