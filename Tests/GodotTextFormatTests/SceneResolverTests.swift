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
        XCTAssertEqual(flat.root.type, "Node2D")
        XCTAssertEqual(flat.root.name, "Main")
        XCTAssertEqual(flat.nodes.map(\.path), [["Spinner"], ["Spinner", "Body"]])
        XCTAssertEqual(flat.nodes.map(\.type), ["Sprite2D", "StaticBody2D"])
    }

    func testRootGroupsAreExposed() throws {
        let catalogue = makeCatalogue([
            "res://window.tscn": """
            [gd_scene format=3]

            [node name="Window" type="PanelContainer" groups=["window"]]

            [node name="Title" type="Label" parent="." groups=["titles"]]
            """
        ])
        let resolver = SceneResolver(catalogue: catalogue)
        let flat = try resolver.flatten(resourcePath: "res://window.tscn")
        XCTAssertEqual(flat.root.groups, ["window"])
        XCTAssertEqual(flat.nodes.map(\.groups), [["titles"]])
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
        XCTAssertEqual(flat.root.scriptPath, "res://spin.gd")
    }

    // MARK: - Instanced scene typed-root resolution

    func testInstancedScenesRootScriptPathIsResolved() throws {
        // Parent instances a child whose root has a script attached.
        // The flattener must surface the inner root's script path on
        // the FlatNode for the instanced sub-scene, so SceneGen can
        // type the NodeRef using the script's user class.
        let catalogue = makeCatalogue([
            "res://parent.tscn": """
            [gd_scene format=3]

            [ext_resource type="PackedScene" path="res://scripted-child.tscn" id="1_child"]

            [node name="Parent" type="Node2D"]

            [node name="Child" parent="." instance=ExtResource("1_child")]
            """,
            "res://scripted-child.tscn": """
            [gd_scene format=3]

            [ext_resource type="Script" path="res://boil_meter.gd" id="1_script"]

            [node name="ScriptedRoot" type="MarginContainer"]
            script = ExtResource("1_script")
            """,
        ])

        let resolver = SceneResolver(catalogue: catalogue)
        let flat = try resolver.flatten(resourcePath: "res://parent.tscn")

        let child = flat.nodes.first(where: { $0.name == "Child" })
        XCTAssertNotNil(child, "expected Child node in flattened parent")
        // Existing behaviour preserved: type is the inner scene's engine class.
        XCTAssertEqual(child?.type, "MarginContainer",
                       "FlatNode.type should still report the inner scene's engine type")
        // Existing behaviour preserved: instanceScenePath points at the child.
        XCTAssertEqual(child?.instanceScenePath, "res://scripted-child.tscn")
        // New behaviour: instancedRootScriptPath is the inner root's script.
        XCTAssertEqual(child?.instancedRootScriptPath, "res://boil_meter.gd",
                       "expected the inner scene's root script ExtResource path to be resolved")
    }

    func testInstancedSceneWithoutRootScriptHasNilScriptPath() throws {
        // Negative: instanced child has no script on its root → field is nil.
        // Confirms we don't fabricate a script path or accidentally
        // surface some other ext_resource.
        let catalogue = makeCatalogue([
            "res://parent.tscn": """
            [gd_scene format=3]

            [ext_resource type="PackedScene" path="res://scriptless-child.tscn" id="1_child"]

            [node name="Parent" type="Node2D"]

            [node name="Child" parent="." instance=ExtResource("1_child")]
            """,
            "res://scriptless-child.tscn": """
            [gd_scene format=3]

            [node name="ScriptedRoot" type="MarginContainer"]
            """,
        ])

        let resolver = SceneResolver(catalogue: catalogue)
        let flat = try resolver.flatten(resourcePath: "res://parent.tscn")

        let child = flat.nodes.first(where: { $0.name == "Child" })
        XCTAssertNotNil(child)
        XCTAssertNil(child?.instancedRootScriptPath,
                     "expected nil when inner root has no script attached")
    }

    func testNonInstancedNodesHaveNilInstancedRootScriptPath() throws {
        // Negative: a regular (non-instanced) node — even one with a
        // direct `script =` attachment — must NOT have
        // instancedRootScriptPath set. That field is exclusively for
        // the instance=ExtResource(...) path. Direct scripts go in
        // FlatNode.scriptPath.
        let catalogue = makeCatalogue([
            "res://main.tscn": """
            [gd_scene format=3]

            [ext_resource type="Script" path="res://spin.gd" id="1_spin"]

            [node name="Main" type="Node2D"]

            [node name="Spinner" type="Sprite2D" parent="."]
            script = ExtResource("1_spin")
            """
        ])

        let resolver = SceneResolver(catalogue: catalogue)
        let flat = try resolver.flatten(resourcePath: "res://main.tscn")
        let spinner = flat.nodes.first(where: { $0.name == "Spinner" })
        XCTAssertNotNil(spinner)
        XCTAssertEqual(spinner?.scriptPath, "res://spin.gd",
                       "direct scripts populate scriptPath, not instancedRootScriptPath")
        XCTAssertNil(spinner?.instancedRootScriptPath,
                     "non-instanced nodes must not have instancedRootScriptPath set")
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

        XCTAssertEqual(flat.root.type, "Node2D", "root type comes from inherited parent")
        XCTAssertEqual(flat.root.name, "Derived", "root name comes from child")
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

    /// Godot composes groups as an ordered union. Packing a derived scene
    /// writes only the entries no scene in the pack stack already declares
    /// (`packed_scene.cpp:1086-1109`), and instantiating adds every recorded
    /// entry to whatever the base instantiation already put on the node
    /// (`:586-589`). So the derived file is a delta and the base's entries
    /// survive.
    func testInheritedRootGroupsUnionWithTheChildsOwn() throws {
        let parent = """
        [gd_scene format=3]

        [node name="Base" type="Node2D" groups=["saveable", "window"]]
        """
        let child = """
        [gd_scene format=3]

        [ext_resource type="PackedScene" path="res://parent.tscn" id="1_parent"]

        [node name="Derived" instance=ExtResource("1_parent") groups=["paused"]]
        """
        let catalogue = makeCatalogue([
            "res://parent.tscn": parent,
            "res://child.tscn": child,
        ])
        let flat = try SceneResolver(catalogue: catalogue).flatten(resourcePath: "res://child.tscn")
        XCTAssertEqual(flat.root.groups, ["saveable", "window", "paused"])
    }

    /// The same union one level down: an overriding node keeps the groups
    /// the inherited node declared and adds its own.
    func testOverridingNodeGroupsUnionWithTheInheritedNodes() throws {
        let parent = """
        [gd_scene format=3]

        [node name="Base" type="Node2D"]

        [node name="Marker" type="Sprite2D" parent="." groups=["overlay"]]
        """
        let child = """
        [gd_scene format=3]

        [ext_resource type="PackedScene" path="res://parent.tscn" id="1_parent"]

        [node name="Derived" instance=ExtResource("1_parent")]

        [node name="Marker" parent="." index="0" groups=["hidden"]]
        """
        let catalogue = makeCatalogue([
            "res://parent.tscn": parent,
            "res://child.tscn": child,
        ])
        let flat = try SceneResolver(catalogue: catalogue).flatten(resourcePath: "res://child.tscn")
        let marker = flat.nodes.first(where: { $0.name == "Marker" })
        XCTAssertEqual(marker?.groups, ["overlay", "hidden"])
    }

    /// An instanced scene's root keeps the groups its own scene declares:
    /// instantiating the inner scene adds them before the outer scene's
    /// entries reach the same node.
    func testInstancedNodeKeepsTheInnerScenesRootGroups() throws {
        let inner = """
        [gd_scene format=3]

        [node name="Inner" type="Control" groups=["window"]]

        [node name="InnerLabel" type="Label" parent="."]
        """
        let outer = """
        [gd_scene format=3]

        [ext_resource type="PackedScene" path="res://inner.tscn" id="1_inner"]

        [node name="Outer" type="Node2D"]

        [node name="NestedInstance" parent="." instance=ExtResource("1_inner") groups=["paused"]]
        """
        let catalogue = makeCatalogue([
            "res://inner.tscn": inner,
            "res://outer.tscn": outer,
        ])
        let flat = try SceneResolver(catalogue: catalogue).flatten(resourcePath: "res://outer.tscn")
        let instance = flat.nodes.first(where: { $0.name == "NestedInstance" })
        XCTAssertEqual(instance?.groups, ["window", "paused"])
    }

    // MARK: - Nested instance with a script-less root

    func testNestedInstanceWithScriptlessRootIsTransparent() throws {
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
        // The inner scene's root has no script, so its layout is the outer
        // scene's to reach: InnerLabel appears under NestedInstance.
        XCTAssertEqual(flat.nodes.map(\.path), [["NestedInstance"], ["NestedInstance", "InnerLabel"], ["OuterLabel"]])
        XCTAssertEqual(flat.nodes.map(\.type), ["Control", "Label", "Label"])
        XCTAssertEqual(flat.nodes[0].instanceScenePath, "res://inner.tscn")
        XCTAssertNil(flat.nodes[2].instanceScenePath)
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

    // MARK: - Instances

    func testInstanceWithScriptedRootIsOpaqueAndTypedThroughInheritance() throws {
        let catalogue = makeCatalogue([
            "res://main.tscn": """
            [gd_scene format=3]

            [ext_resource type="PackedScene" path="res://pat.tscn" id="1_pat"]

            [node name="Main" type="Node2D"]

            [node name="Pat" parent="." instance=ExtResource("1_pat")]
            """,
            "res://pat.tscn": """
            [gd_scene format=3]

            [ext_resource type="PackedScene" path="res://customer.tscn" id="1_c"]

            [node name="Pat" instance=ExtResource("1_c")]
            """,
            "res://customer.tscn": """
            [gd_scene format=3]

            [ext_resource type="Script" path="res://customer.gd" id="1_s"]

            [node name="Customer" type="CharacterBody2D"]
            script = ExtResource("1_s")

            [node name="Body" type="Sprite2D" parent="."]
            """,
        ])
        let flat = try SceneResolver(catalogue: catalogue).flatten(resourcePath: "res://main.tscn")
        XCTAssertEqual(flat.nodes.map(\.path), [["Pat"]])
        XCTAssertEqual(flat.nodes[0].type, "CharacterBody2D")
        XCTAssertEqual(flat.nodes[0].instancedRootScriptPath, "res://customer.gd")
    }

    func testInstanceWithScriptlessRootIsTransparent() throws {
        let catalogue = makeCatalogue([
            "res://main.tscn": """
            [gd_scene format=3]

            [ext_resource type="PackedScene" path="res://hud.tscn" id="1_hud"]

            [node name="Main" type="Node2D"]

            [node name="Hud" parent="." instance=ExtResource("1_hud")]

            [node name="Score" parent="Hud"]
            text = "0"
            """,
            "res://hud.tscn": """
            [gd_scene format=3]

            [ext_resource type="Script" path="res://panel.gd" id="1_p"]

            [node name="Hud" type="Control"]

            [node name="Score" type="Label" parent="."]
            unique_name_in_owner = true

            [node name="Panel" type="Control" parent="."]
            script = ExtResource("1_p")
            """,
        ])
        let flat = try SceneResolver(catalogue: catalogue).flatten(resourcePath: "res://main.tscn")
        XCTAssertEqual(flat.nodes.map { $0.path.joined(separator: "/") }, ["Hud", "Hud/Score", "Hud/Panel"])
        XCTAssertEqual(flat.nodes[0].type, "Control")
        XCTAssertNil(flat.nodes[0].instancedRootScriptPath)
        XCTAssertEqual(flat.nodes[1].type, "Label")
        XCTAssertFalse(flat.nodes[1].uniqueInOwner, "uniqueness belongs to the instanced scene's owner, not this one")
        XCTAssertEqual(flat.nodes[2].scriptPath, "res://panel.gd")
    }

    // MARK: - Owner

    func testOwnerPathFollowsGodotsOwner() throws {
        let catalogue = makeCatalogue([
            "res://badge.tscn": """
            [gd_scene format=3]

            [node name="Badge" type="Control"]

            [node name="Icon" type="TextureRect" parent="."]
            """,
            "res://tower_info.tscn": """
            [gd_scene format=3]

            [ext_resource type="PackedScene" path="res://badge.tscn" id="1_b"]

            [node name="TowerInfo" type="PanelContainer"]

            [node name="VBox" type="VBoxContainer" parent="."]

            [node name="Phase" type="GridContainer" parent="VBox"]
            unique_name_in_owner = true

            [node name="Badge" parent="." instance=ExtResource("1_b")]
            """,
            "res://board.tscn": """
            [gd_scene format=3]

            [ext_resource type="PackedScene" path="res://tower_info.tscn" id="1_t"]

            [node name="Board" type="Node2D"]

            [node name="TowerInfo" parent="." instance=ExtResource("1_t")]

            [node name="Phase" parent="TowerInfo/VBox"]
            columns = 3

            [node name="Extra" type="Label" parent="TowerInfo/VBox"]
            unique_name_in_owner = true

            [node name="Note" type="Label" parent="TowerInfo/Badge"]

            [editable path="TowerInfo"]
            [editable path="TowerInfo/Badge"]
            """,
            "res://level.tscn": """
            [gd_scene format=3]

            [ext_resource type="PackedScene" path="res://board.tscn" id="1_board"]

            [node name="Level" instance=ExtResource("1_board")]

            [node name="Goal" type="Label" parent="TowerInfo/VBox"]
            """,
            "res://main.tscn": """
            [gd_scene format=3]

            [ext_resource type="PackedScene" path="res://board.tscn" id="1_board"]

            [node name="Main" type="Node"]

            [node name="Board" parent="." instance=ExtResource("1_board")]
            """,
        ])
        let resolver = SceneResolver(catalogue: catalogue)
        func owners(_ path: String) throws -> [String: String] {
            let flat = try resolver.flatten(resourcePath: path)
            XCTAssertEqual(flat.root.ownerPath, [])
            return Dictionary(uniqueKeysWithValues: flat.nodes.map {
                ($0.path.joined(separator: "/"), $0.ownerPath.joined(separator: "/"))
            })
        }
        let board: [String: String] = [
            "TowerInfo": "",
            "TowerInfo/VBox": "TowerInfo",
            "TowerInfo/VBox/Phase": "TowerInfo",
            "TowerInfo/Badge": "TowerInfo",
            "TowerInfo/Badge/Icon": "TowerInfo/Badge",
            "TowerInfo/VBox/Extra": "",
            "TowerInfo/Badge/Note": "",
        ]
        XCTAssertEqual(try owners("res://board.tscn"), board)
        XCTAssertEqual(try owners("res://level.tscn"), board.merging(["TowerInfo/VBox/Goal": ""]) { $1 })
        XCTAssertEqual(try owners("res://main.tscn"), [
            "Board": "",
            "Board/TowerInfo": "Board",
            "Board/TowerInfo/VBox": "Board/TowerInfo",
            "Board/TowerInfo/VBox/Phase": "Board/TowerInfo",
            "Board/TowerInfo/Badge": "Board/TowerInfo",
            "Board/TowerInfo/Badge/Icon": "Board/TowerInfo/Badge",
            "Board/TowerInfo/VBox/Extra": "Board",
            "Board/TowerInfo/Badge/Note": "Board",
        ])
    }

    fileprivate func makeCatalogue(_ store: [String: String]) -> SceneCatalogue {
        SceneCatalogue { path in
            guard let text = store[path] else { throw ResolveError.sceneNotFound(path) }
            return text
        }
    }
}
