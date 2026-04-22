import XCTest
@testable import GodotTextFormat

final class SceneResolverTests: XCTestCase {
    // MARK: - Flat scene

    func testFlatScene() throws {
        let catalogue = makeCatalogue([
            "res://main.tscn": """
            [gd_scene format=3]

            [node name="Main" type="Node2D"]

            [node name="Spinner" type="Sprite2D" parent="."]
            [node name="Body" type="StaticBody2D" parent="Spinner"]
            """
        ])
        let resolver = SceneResolver(catalogue: catalogue)
        let flat = try resolver.flatten(resourcePath: "res://main.tscn")
        XCTAssertEqual(flat.rootType, "Node2D")
        XCTAssertEqual(flat.rootNodeName, "Main")
        XCTAssertEqual(flat.nodes.map(\.path), [["Spinner"], ["Spinner", "Body"]])
        XCTAssertEqual(flat.nodes.map(\.type), ["Sprite2D", "StaticBody2D"])
    }

    func testNodeScriptIsExposed() throws {
        let catalogue = makeCatalogue([
            "res://main.tscn": """
            [gd_scene format=3]

            [ext_resource type="Script" path="res://spin.gd" id="1_spin"]

            [node name="Main" type="Node2D"]
            script = ExtResource("1_spin")

            [node name="Spinner" type="Sprite2D" parent="."]
            """
        ])
        let resolver = SceneResolver(catalogue: catalogue)
        let flat = try resolver.flatten(resourcePath: "res://main.tscn")
        XCTAssertEqual(flat.rootScriptPath, "res://spin.gd")
    }

    // MARK: - Inheritance

    func testInheritanceFlattensParent() throws {
        let parentURL = Bundle.module.url(
            forResource: "parent.tscn", withExtension: nil,
            subdirectory: "Fixtures/inherited"
        )!
        let childURL = Bundle.module.url(
            forResource: "child.tscn", withExtension: nil,
            subdirectory: "Fixtures/inherited"
        )!
        let parent = try String(contentsOf: parentURL, encoding: .utf8)
        let child = try String(contentsOf: childURL, encoding: .utf8)

        let catalogue = makeCatalogue([
            "res://parent.tscn": parent,
            "res://child.tscn": child,
        ])
        let resolver = SceneResolver(catalogue: catalogue)
        let flat = try resolver.flatten(resourcePath: "res://child.tscn")

        XCTAssertEqual(flat.rootType, "Node2D", "root type comes from inherited parent")
        XCTAssertEqual(flat.rootNodeName, "Derived", "root name comes from child")
        XCTAssertEqual(flat.nodes.map(\.path), [["Title"], ["Body"], ["Extra"]])
        XCTAssertEqual(flat.nodes.map(\.type), ["Label", "StaticBody2D", "Sprite2D"])
    }

    // MARK: - Helpers

    fileprivate func makeCatalogue(_ store: [String: String]) -> SceneCatalogue {
        SceneCatalogue { path in
            guard let text = store[path] else { throw ResolveError.sceneNotFound(path) }
            return text
        }
    }
}
