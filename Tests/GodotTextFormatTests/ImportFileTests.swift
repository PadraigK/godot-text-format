import XCTest
@testable import GodotTextFormat

final class ImportFileTests: XCTestCase {
    /// A model's import file as Godot's editor writes it gives the importer, the class the
    /// import loads as, and each import setting by name. llm-generated
    func testReadsRemapAndParams() throws {
        let file = try ImportFile.parse("""
        [remap]

        importer="scene"
        importer_version=1
        type="PackedScene"
        uid="uid://cjhd5a1txvbs8"
        path="res://.godot/imported/ladder.glb-0135d13dc5f4626864cdabcafd1e3806.scn"

        [deps]

        source_file="res://models/ladder.glb"
        dest_files=["res://.godot/imported/ladder.glb-0135d13dc5f4626864cdabcafd1e3806.scn"]

        [params]

        nodes/root_type=""
        nodes/root_name=""
        nodes/root_script=null
        nodes/apply_root_scale=true
        nodes/root_scale=1.0
        meshes/lightmap_texel_size=0.2
        import_script/path=""
        _subresources={}
        gltf/naming_version=2
        """)
        XCTAssertEqual(file.importer, "scene")
        XCTAssertEqual(file.type, "PackedScene")
        XCTAssertEqual(file.param("nodes/root_scale"), .double(1.0))
        XCTAssertNil(file.param("nodes/missing"))
    }

    /// The imported scene's root is the import dock's Root Type when that names a class and a
    /// `Node3D` when it's empty; where a script decides the class it is only known to be a
    /// `Node`. llm-generated
    func testSceneRootType() throws {
        func rootType(_ params: String) throws -> String {
            try ImportFile.parse("[remap]\n\nimporter=\"scene\"\ntype=\"PackedScene\"\n\n[params]\n\n\(params)\n").sceneRootType
        }
        XCTAssertEqual(try rootType("nodes/root_type=\"\"\nnodes/root_script=null"), "Node3D")
        XCTAssertEqual(try rootType("nodes/root_name=\"Board\""), "Node3D")
        XCTAssertEqual(try rootType("nodes/root_type=\"Area3D\"\nnodes/root_script=null"), "Area3D")
        XCTAssertEqual(try rootType("nodes/root_type=\"Enemy (enemy.gd)\"\nnodes/root_script=null"), "Node")
        XCTAssertEqual(try rootType("nodes/root_type=\"\"\nnodes/root_script=Resource(\"res://enemy.gd\")"), "Node")
        XCTAssertEqual(try rootType("nodes/root_type=\"Area3D\"\nnodes/root_script=Resource(\"res://enemy.gd\")"), "Area3D")
    }
}
