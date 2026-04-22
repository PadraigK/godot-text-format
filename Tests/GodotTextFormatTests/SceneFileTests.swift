import XCTest
@testable import GodotTextFormat

final class SceneFileTests: XCTestCase {
    func testLoadMinimalScene() throws {
        let scene = try loadScene(named: "minimal.tscn")
        XCTAssertEqual(scene.format, 3)
        XCTAssertEqual(scene.uid, "uid://abc")
        XCTAssertEqual(scene.extResources.count, 2)
        XCTAssertEqual(scene.subResources.count, 1)
        XCTAssertEqual(scene.nodes.count, 3)
    }

    func testExtResourceLookup() throws {
        let scene = try loadScene(named: "minimal.tscn")
        let icon = scene.extResource(id: "2_icon")
        XCTAssertEqual(icon?.type, "Texture2D")
        XCTAssertEqual(icon?.path, "res://icon.svg")
        XCTAssertEqual(icon?.uid, "uid://xyz")
    }

    func testSubResourceLookup() throws {
        let scene = try loadScene(named: "minimal.tscn")
        let shape = scene.subResource(id: "shape_1")
        XCTAssertEqual(shape?.type, "CircleShape2D")
        XCTAssertEqual(shape?.prop("radius"), .double(16.0))
    }

    func testRootNodeIsFirstNode() throws {
        let scene = try loadScene(named: "minimal.tscn")
        XCTAssertEqual(scene.rootNode?.name, "Main")
        XCTAssertEqual(scene.rootNode?.type, "Node2D")
        XCTAssertNil(scene.rootNode?.parentPath)
    }

    func testChildNodeParents() throws {
        let scene = try loadScene(named: "minimal.tscn")
        let spinner = scene.nodes.first(where: { $0.name == "Spinner" })
        XCTAssertEqual(spinner?.type, "Sprite2D")
        XCTAssertEqual(spinner?.parentPath, ".")

        let body = scene.nodes.first(where: { $0.name == "Body" })
        XCTAssertEqual(body?.parentPath, "Spinner")
    }

    func testEditableInstanceParsed() throws {
        // Godot writes `[editable path="Spinner"]` with a plain string.
        let text = """
        [gd_scene format=3]
        [node name="Main" type="Node2D"]
        [node name="Spinner" type="Node" parent="."]
        [editable path="Spinner"]
        """
        let scene = try SceneFile.parse(text)
        XCTAssertEqual(scene.editableInstances, ["Spinner"])
    }

    func testConnectionParsed() throws {
        let text = """
        [gd_scene format=3]
        [node name="Main" type="Node"]
        [node name="Button" type="Button" parent="."]
        [connection signal="pressed" from="Button" to="." method="_on_pressed"]
        """
        let scene = try SceneFile.parse(text)
        XCTAssertEqual(scene.connections.count, 1)
        XCTAssertEqual(scene.connections[0].signal, "pressed")
        XCTAssertEqual(scene.connections[0].from, "Button")
        XCTAssertEqual(scene.connections[0].to, ".")
        XCTAssertEqual(scene.connections[0].method, "_on_pressed")
    }

    func testNodeGroupsParsed() throws {
        let text = """
        [gd_scene format=3]
        [node name="Main" type="Node"]
        [node name="Enemy" type="Node2D" parent="." groups=["enemies", "dangerous"]]
        """
        let scene = try SceneFile.parse(text)
        let enemy = scene.nodes.first(where: { $0.name == "Enemy" })
        XCTAssertEqual(enemy?.groups, ["enemies", "dangerous"])
    }

    // MARK: - Known-broken: TileSet body keys

    // Real user fixture — TileSet sub-resources in Godot 4 use property keys
    // like `0:0/animation_columns`, `sources/0`, `0:0/0`. These start with a
    // digit and/or contain `:`, which our current Lexer body-key identifier
    // rule doesn't accept. Godot's own variant_parser.cpp treats body-key
    // property names as essentially any-non-whitespace-non-`=` chars.
    //
    // This test pins the current (broken) behavior: it expects a parse error.
    // When the lexer is fixed to accept permissive body-key names, flip this
    // test to assert successful parse + expected node tree.
    func testTileSetBodyKeysCurrentlyFailToLex() throws {
        let url = Bundle.module.url(forResource: "tileset-keys-background.tscn",
            withExtension: nil, subdirectory: "Fixtures")!
        let text = try String(contentsOf: url, encoding: .utf8)
        XCTAssertThrowsError(try SceneFile.parse(text)) { error in
            guard let parseError = error as? ParseError else {
                return XCTFail("expected ParseError, got \(error)")
            }
            XCTAssertTrue(parseError.message.contains("unexpected character '/'"),
                "expected '/' character error, got: \(parseError.message)")
        }
    }

    private func loadScene(named name: String) throws -> SceneFile {
        let url = Bundle.module.url(forResource: name, withExtension: nil, subdirectory: "Fixtures")!
        let text = try String(contentsOf: url, encoding: .utf8)
        return try SceneFile.parse(text)
    }
}
