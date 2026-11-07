import XCTest
@testable import GodotTextFormat

final class ScriptHeaderTests: XCTestCase {
    /// `class_name` and `extends` in either order, on one line or two, past annotations and
    /// comments. llm-generated
    func testClassNameAndBase() {
        XCTAssertEqual(ScriptHeader.parse("class_name GameSettings\nextends Node\n\nconst PATH = \"user://settings.json\"\n"),
                       ScriptHeader(className: "GameSettings", base: .named("Node")))
        XCTAssertEqual(ScriptHeader.parse("@tool\n@icon(\"res://icon (big).svg\")\n# The music.\nextends AudioStreamPlayer # plays\nclass_name Music\n"),
                       ScriptHeader(className: "Music", base: .named("AudioStreamPlayer")))
        XCTAssertEqual(ScriptHeader.parse("class_name Hud extends CanvasLayer\n"),
                       ScriptHeader(className: "Hud", base: .named("CanvasLayer")))
    }

    /// A base by path, an inner class of one, and of a named class. llm-generated
    func testScriptBases() {
        XCTAssertEqual(ScriptHeader.parse("extends \"res://base.gd\"\n").base, .script(path: "res://base.gd", inner: nil))
        XCTAssertEqual(ScriptHeader.parse("extends 'res://base.gd'.Inner\n").base, .script(path: "res://base.gd", inner: "Inner"))
        XCTAssertEqual(ScriptHeader.parse("extends Player.Hitbox\n").base, .named("Player.Hitbox"))
    }

    /// Reading stops at the first other statement: an `extends` after it, an inner class's
    /// included, isn't the script's. A script without one has no base. llm-generated
    func testStopsAtTheFirstStatement() {
        XCTAssertEqual(ScriptHeader.parse("var speed = 3\nextends Node\n"), ScriptHeader(className: nil, base: nil))
        XCTAssertEqual(ScriptHeader.parse("@export var speed = 3\n"), ScriptHeader(className: nil, base: nil))
        XCTAssertEqual(ScriptHeader.parse("class_name Utils\n\nclass Inner extends Node2D:\n\tpass\n"), ScriptHeader(className: "Utils", base: nil))
    }
}
