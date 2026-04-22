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
