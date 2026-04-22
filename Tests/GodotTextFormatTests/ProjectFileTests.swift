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
}
