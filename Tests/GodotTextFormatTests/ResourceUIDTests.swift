import XCTest
@testable import GodotTextFormat

final class ResourceUIDTests: XCTestCase {
    /// A `.uid` file declares the uid of the file beside it; a scene and a resource declare their
    /// own in their header; a file of another kind, or a header without one, declares none.
    /// llm-generated
    func testDeclaredUIDs() {
        let script = ResourceUIDs.declared(at: "res://player.gd.uid", text: "uid://bq3x7c1\n")
        XCTAssertEqual(script?.uid, "uid://bq3x7c1")
        XCTAssertEqual(script?.resourcePath, "res://player.gd")
        let scene = ResourceUIDs.declared(at: "res://sounds.tscn", text: "[gd_scene load_steps=2 format=3 uid=\"uid://d10tlxc6yk6o6\"]\n\n[node name=\"Sounds\" type=\"Node\"]\n")
        XCTAssertEqual(scene?.uid, "uid://d10tlxc6yk6o6")
        XCTAssertEqual(scene?.resourcePath, "res://sounds.tscn")
        let resource = ResourceUIDs.declared(at: "res://theme.tres", text: "[gd_resource type=\"Theme\" format=3 uid=\"uid://c8k2\"]\n")
        XCTAssertEqual(resource?.uid, "uid://c8k2")
        XCTAssertNil(ResourceUIDs.declared(at: "res://old.tscn", text: "[gd_scene format=2]\n"))
        XCTAssertNil(ResourceUIDs.declared(at: "res://player.gd", text: "extends Node\n"))
        XCTAssertTrue(ResourceUIDs.mayDeclare("res://player.gd.uid"))
        XCTAssertFalse(ResourceUIDs.mayDeclare("res://player.gd"))
    }
}
