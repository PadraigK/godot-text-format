import XCTest
@testable import GodotTextFormat

final class SectionParserTests: XCTestCase {
    func testEmptyDocument() throws {
        XCTAssertEqual(try parseSections("").map(\.kind), [])
    }

    func testSingleHeaderNoBody() throws {
        let sections = try parseSections("[gd_scene format=3]")
        XCTAssertEqual(sections.count, 1)
        XCTAssertEqual(sections[0].kind, "gd_scene")
        XCTAssertEqual(sections[0].attrs.count, 1)
        XCTAssertEqual(sections[0].attrs[0].0, "format")
        XCTAssertEqual(sections[0].attrs[0].1, .int(3))
        XCTAssertEqual(sections[0].body.count, 0)
    }

    func testHeaderMultipleAttrs() throws {
        let sections = try parseSections(#"[gd_scene format=3 uid="uid://abc" load_steps=5]"#)
        XCTAssertEqual(sections[0].attrs.map(\.0), ["format", "uid", "load_steps"])
    }

    func testHeaderWithDottedKindName() throws {
        let sections = try parseSections("[gd_scene.Android]")
        XCTAssertEqual(sections[0].kind, "gd_scene.Android")
    }

    func testNodeSectionWithBody() throws {
        let src = """
        [node name="Main" type="Node2D"]
        position = Vector2(576, 324)
        visible = true
        """
        let sections = try parseSections(src)
        XCTAssertEqual(sections.count, 1)
        XCTAssertEqual(sections[0].kind, "node")
        XCTAssertEqual(sections[0].body.count, 2)
        XCTAssertEqual(sections[0].body[0].0, "position")
        XCTAssertEqual(sections[0].body[1].0, "visible")
        XCTAssertEqual(sections[0].body[1].1, .bool(true))
    }

    func testMultipleSections() throws {
        let src = """
        [gd_scene format=3]

        [ext_resource type="Texture2D" path="res://icon.svg" id="2_icon"]

        [node name="Main" type="Node2D"]
        """
        let sections = try parseSections(src)
        XCTAssertEqual(sections.map(\.kind), ["gd_scene", "ext_resource", "node"])
    }

    func testBodyWithMultilineDictionary() throws {
        let src = """
        [sub_resource type="AnimationLibrary" id="lib_1"]
        _data = {
        "explode": SubResource("anim_1"),
        "idle": SubResource("anim_2")
        }
        """
        let sections = try parseSections(src)
        guard case .dictionary(let pairs) = sections[0].body[0].1 else {
            return XCTFail("expected dictionary")
        }
        XCTAssertEqual(pairs.map { $0.0 }, [.string("explode"), .string("idle")])
    }

    func testSectionWithAttrsAndMultilineBody() throws {
        let src = """
        [sub_resource type="AnimationLibrary" id="lib_1" load_steps=2]
        _data = {
        "explode": SubResource("anim_1"),
        "idle": SubResource("anim_2")
        }
        resource_name = "combat"
        """
        let sections = try parseSections(src)
        XCTAssertEqual(sections.count, 1)
        XCTAssertEqual(sections[0].attrs.map(\.0), ["type", "id", "load_steps"])
        XCTAssertEqual(sections[0].body.map(\.0), ["_data", "resource_name"])
        XCTAssertEqual(sections[0].body[1].1, .string("combat"))
    }

    func testBodyStopsAtNextHeader() throws {
        let src = """
        [a]
        x = 1
        y = 2
        [b]
        z = 3
        """
        let sections = try parseSections(src)
        XCTAssertEqual(sections.count, 2)
        XCTAssertEqual(sections[0].body.map(\.0), ["x", "y"])
        XCTAssertEqual(sections[1].body.map(\.0), ["z"])
    }

    private func parseSections(_ source: String) throws -> [Section] {
        var lexer = Lexer(source: source)
        let tokens = try lexer.tokenize()
        var parser = SectionParser(tokens: tokens)
        return try parser.parseDocument()
    }
}
