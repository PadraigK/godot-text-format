import XCTest
@testable import GodotTextFormat

final class AutoloadTests: XCTestCase {
    /// Autoloads come in the order Godot adds them: `[autoload]`'s in order, each
    /// `[autoload_prepend]` entry put first (so the second prepended is first of all) and replacing
    /// an entry of its name; the `*` is dropped and reported, and an entry without it is still an
    /// autoload. llm-generated
    func testAutoloadsInGodotsOrder() throws {
        let project = try ProjectFile.parse("""
        config_version=5

        [autoload]

        Sounds="*uid://d10tlxc6yk6o6"
        Debug="res://debug.gd"
        Dialog="*res://dialog.tscn"

        [autoload_prepend]

        Dialog="*res://addons/dialog/dialog.gd"
        Hooks="*res://addons/hooks/hooks.gd"

        """)
        XCTAssertEqual(project.autoloads, [
            Autoload(name: "Hooks", path: "res://addons/hooks/hooks.gd", isGlobal: true),
            Autoload(name: "Dialog", path: "res://addons/dialog/dialog.gd", isGlobal: true),
            Autoload(name: "Sounds", path: "uid://d10tlxc6yk6o6", isGlobal: true),
            Autoload(name: "Debug", path: "res://debug.gd", isGlobal: false),
        ])
    }

    /// A project without autoloads has none. llm-generated
    func testNoAutoloads() throws {
        XCTAssertEqual(try ProjectFile.parse("config_version=5\n\n[application]\n\nconfig/name=\"Game\"\n").autoloads, [])
    }
}
