import XCTest
@testable import GodotTextFormat

final class InputActionsTests: XCTestCase {
    func testInputActions() throws {
        let url = Bundle.module.url(forResource: "project.godot", withExtension: nil, subdirectory: "Fixtures")!
        let text = try String(contentsOf: url, encoding: .utf8)
        let proj = try ProjectFile.parse(text)
        let actions = InputActionsExtractor.extract(from: proj)
        XCTAssertEqual(actions.base.map(\.name), ["jump", "fire"])
        XCTAssertEqual(actions.platformVariants["macos"]?.map(\.name), ["cmd_quit"])
    }

    func testInputActionDeadzone() throws {
        let url = Bundle.module.url(forResource: "project.godot", withExtension: nil, subdirectory: "Fixtures")!
        let text = try String(contentsOf: url, encoding: .utf8)
        let proj = try ProjectFile.parse(text)
        let actions = InputActionsExtractor.extract(from: proj)
        let jump = actions.base.first(where: { $0.name == "jump" })
        XCTAssertEqual(jump?.deadzone, 0.5)
    }
}
