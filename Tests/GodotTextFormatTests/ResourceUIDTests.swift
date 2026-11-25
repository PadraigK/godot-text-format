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

    /// A uid's text and its number, both ways, as Godot 4.7.2's `ResourceUID.text_to_id` and
    /// `id_to_text` gave them in a headless run: the largest number, `z` and `9` (which Godot
    /// never writes) read as 25 and 34, text too long for 63 bits kept to its low 63 bits, and
    /// text Godot doesn't read as a uid. llm-generated
    func testUIDNumbers() {
        let pairs: [(String, Int64)] = [
            ("uid://eny3t2qg3pl5", 309_100_535_800_113_872),
            ("uid://c4startchk2n", 201_371_505_225_696_067),
            ("uid://d4n4ub6itg400", 9_223_372_036_854_775_807),
            ("uid://a", 0),
        ]
        for (text, id) in pairs {
            XCTAssertEqual(ResourceUIDs.id(of: text), id, text)
            XCTAssertEqual(ResourceUIDs.text(of: id), text, text)
        }
        XCTAssertEqual(ResourceUIDs.id(of: "uid://"), 0)
        XCTAssertEqual(ResourceUIDs.id(of: "uid://z"), 25)
        XCTAssertEqual(ResourceUIDs.id(of: "uid://9"), 34)
        XCTAssertEqual(ResourceUIDs.text(of: 34), "uid://ba")
        XCTAssertEqual(ResourceUIDs.id(of: "uid://0ibyyurl65b4k"), 4_885_361_142_208_378_344)
        XCTAssertEqual(ResourceUIDs.text(of: 4_885_361_142_208_378_344), "uid://cburgi83sw2ky")
        XCTAssertEqual(ResourceUIDs.id(of: "uid://zzzzzzzzzzzzzz"), 5_443_912_359_627_349_767)
        XCTAssertNil(ResourceUIDs.id(of: "uid://ABC"))
        XCTAssertNil(ResourceUIDs.id(of: "res://x"))
        XCTAssertNil(ResourceUIDs.id(of: "uid://<invalid>"))
        XCTAssertNil(ResourceUIDs.text(of: -1))
    }
}
