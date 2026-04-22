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

    func testInheritanceTypedOverridePreservesParentFlags() throws {
        // Parent marks 'Marker' with unique_name_in_owner=true and groups=["overlay"].
        // Child overrides Marker to change its type. The unique-name flag and groups
        // must survive the override.
        let parent = """
        [gd_scene format=3]

        [node name="Base" type="Node2D"]

        [node name="Marker" type="Sprite2D" parent="." groups=["overlay"]]
        unique_name_in_owner = true
        """
        let child = """
        [gd_scene format=3]

        [ext_resource type="PackedScene" path="res://parent.tscn" id="1_parent"]

        [node name="Derived" instance=ExtResource("1_parent")]

        [node name="Marker" type="Sprite2D" parent="."]
        """
        let catalogue = makeCatalogue([
            "res://parent.tscn": parent,
            "res://child.tscn": child,
        ])
        let flat = try SceneResolver(catalogue: catalogue).flatten(resourcePath: "res://child.tscn")
        let marker = flat.nodes.first(where: { $0.name == "Marker" })
        XCTAssertNotNil(marker)
        XCTAssertEqual(marker?.type, "Sprite2D")
        XCTAssertTrue(marker?.uniqueInOwner ?? false, "unique_name_in_owner should survive typed override")
        XCTAssertEqual(marker?.groups, ["overlay"], "groups should survive typed override")
    }

    // MARK: - Nested instance boundary

    func testNestedInstanceIsBoundary() throws {
        let outer = try String(contentsOf:
            Bundle.module.url(forResource: "outer.tscn", withExtension: nil, subdirectory: "Fixtures/nested")!,
            encoding: .utf8)
        let inner = try String(contentsOf:
            Bundle.module.url(forResource: "inner.tscn", withExtension: nil, subdirectory: "Fixtures/nested")!,
            encoding: .utf8)
        let catalogue = makeCatalogue([
            "res://outer.tscn": outer,
            "res://inner.tscn": inner,
        ])
        let flat = try SceneResolver(catalogue: catalogue).flatten(resourcePath: "res://outer.tscn")
        // NestedInstance appears, but InnerLabel (child of the instanced scene) must NOT.
        XCTAssertEqual(flat.nodes.map(\.path), [["NestedInstance"], ["OuterLabel"]])
        XCTAssertEqual(flat.nodes.map(\.type), ["Control", "Label"])
        XCTAssertEqual(flat.nodes[0].instanceScenePath, "res://inner.tscn")
        XCTAssertNil(flat.nodes[1].instanceScenePath)
    }

    // MARK: - Unique name in owner

    func testUniqueNameInOwnerFlag() throws {
        let text = try String(contentsOf:
            Bundle.module.url(forResource: "unique-name.tscn", withExtension: nil, subdirectory: "Fixtures")!,
            encoding: .utf8)
        let catalogue = makeCatalogue(["res://unique.tscn": text])
        let flat = try SceneResolver(catalogue: catalogue).flatten(resourcePath: "res://unique.tscn")
        let useful = flat.nodes.first(where: { $0.name == "UsefulChild" })
        XCTAssertNotNil(useful)
        XCTAssertTrue(useful?.uniqueInOwner ?? false)
    }

    // MARK: - Cycle detection

    func testCyclicInheritanceIsDetected() throws {
        let a = """
        [gd_scene format=3]
        [ext_resource type="PackedScene" path="res://b.tscn" id="1"]
        [node name="A" instance=ExtResource("1")]
        """
        let b = """
        [gd_scene format=3]
        [ext_resource type="PackedScene" path="res://a.tscn" id="1"]
        [node name="B" instance=ExtResource("1")]
        """
        let catalogue = makeCatalogue(["res://a.tscn": a, "res://b.tscn": b])
        let resolver = SceneResolver(catalogue: catalogue)
        XCTAssertThrowsError(try resolver.flatten(resourcePath: "res://a.tscn")) { error in
            guard case ResolveError.cyclicInheritance = error else {
                return XCTFail("expected .cyclicInheritance, got \(error)")
            }
        }
    }

    // MARK: - Helpers

    fileprivate func makeCatalogue(_ store: [String: String]) -> SceneCatalogue {
        SceneCatalogue { path in
            guard let text = store[path] else { throw ResolveError.sceneNotFound(path) }
            return text
        }
    }
}
