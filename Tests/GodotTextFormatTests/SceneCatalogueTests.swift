import XCTest
@testable import GodotTextFormat

final class SceneCatalogueTests: XCTestCase {
    func testLoadsAndCaches() throws {
        var loads = 0
        let store: [String: String] = [
            "res://a.tscn": "[gd_scene format=3]\n\n[node name=\"A\" type=\"Node\"]\n"
        ]
        let catalogue = SceneCatalogue { path in
            loads += 1
            guard let text = store[path] else { throw ResolveError.sceneNotFound(path) }
            return text
        }
        _ = try catalogue.sceneFile(at: "res://a.tscn")
        _ = try catalogue.sceneFile(at: "res://a.tscn")
        XCTAssertEqual(loads, 1, "second lookup should hit cache")
    }

    func testReportsMissingScene() {
        let catalogue = SceneCatalogue { _ in throw ResolveError.sceneNotFound("res://x.tscn") }
        XCTAssertThrowsError(try catalogue.sceneFile(at: "res://x.tscn")) { error in
            guard case ResolveError.sceneNotFound = error else {
                return XCTFail("expected sceneNotFound")
            }
        }
    }

    func testCycleDetection() throws {
        let store: [String: String] = [
            "res://a.tscn": """
            [gd_scene format=3]
            [ext_resource path="res://b.tscn" type="PackedScene" id="1"]
            [node name="A" instance=ExtResource("1")]
            """,
            "res://b.tscn": """
            [gd_scene format=3]
            [ext_resource path="res://a.tscn" type="PackedScene" id="1"]
            [node name="B" instance=ExtResource("1")]
            """,
        ]
        let catalogue = SceneCatalogue { path in
            guard let t = store[path] else { throw ResolveError.sceneNotFound(path) }
            return t
        }
        XCTAssertThrowsError(try catalogue.detectCycle(startingFrom: "res://a.tscn")) { error in
            guard case ResolveError.cyclicInheritance = error else {
                return XCTFail("expected cyclicInheritance")
            }
        }
    }

    func testNoFalseCycleForLinearInheritance() throws {
        // a inherits b inherits c — not a cycle.
        let store: [String: String] = [
            "res://a.tscn": """
            [gd_scene format=3]
            [ext_resource path="res://b.tscn" type="PackedScene" id="1"]
            [node name="A" instance=ExtResource("1")]
            """,
            "res://b.tscn": """
            [gd_scene format=3]
            [ext_resource path="res://c.tscn" type="PackedScene" id="1"]
            [node name="B" instance=ExtResource("1")]
            """,
            "res://c.tscn": """
            [gd_scene format=3]
            [node name="C" type="Node"]
            """,
        ]
        let catalogue = SceneCatalogue { path in
            guard let t = store[path] else { throw ResolveError.sceneNotFound(path) }
            return t
        }
        XCTAssertNoThrow(try catalogue.detectCycle(startingFrom: "res://a.tscn"))
    }
}
