import XCTest
@testable import GodotTextFormat

final class ProjectFileTests: XCTestCase {
    func testProjectGodot() throws {
        let url = Bundle.module.url(forResource: "project.godot", withExtension: nil, subdirectory: "Fixtures")!
        let text = try String(contentsOf: url, encoding: .utf8)
        let proj = try ProjectFile.parse(text)
        XCTAssertEqual(proj.configVersion, 5)
        XCTAssertEqual(proj.section("application")?.prop("config/name"), .string("TestGame"))
        let input = proj.section("input")
        XCTAssertNotNil(input)
        XCTAssertEqual(input?.body.map(\.0), ["jump", "fire"])
    }

    func testPlatformVariantSections() throws {
        let url = Bundle.module.url(forResource: "project.godot", withExtension: nil, subdirectory: "Fixtures")!
        let text = try String(contentsOf: url, encoding: .utf8)
        let proj = try ProjectFile.parse(text)
        // base [input] + [input.macos] variant → 2 sections
        XCTAssertEqual(proj.sections(named: "input").count, 2)
        XCTAssertEqual(proj.sections(named: "input").map(\.kind), ["input", "input.macos"])
    }
}

extension ProjectFileTests {
    /// A `.import` sidecar has the INI shape `project.godot` has; the
    /// `[remap]` section's `type` is the class the asset loads as.
    func testImportSidecarRemapType() throws {
        let file = try ProjectFile.parse("""
        [remap]

        importer="texture"
        type="CompressedTexture2D"
        uid="uid://3ck5ev11udfv"
        path="res://.godot/imported/shop.png-c915d61f.ctex"
        metadata={
        "vram_texture": false
        }

        [deps]

        source_file="res://assets/sprites/shop.png"
        dest_files=["res://.godot/imported/shop.png-c915d61f.ctex"]

        [params]

        compress/mode=0
        process/channel_remap/red=0
        roughness/src_normal=""
        """)
        let remap = try XCTUnwrap(file.section("remap"))
        XCTAssertEqual(remap.body.first(where: { $0.0 == "type" })?.1, .string("CompressedTexture2D"))
        XCTAssertEqual(file.section("params")?.body.count, 3)
    }
}
