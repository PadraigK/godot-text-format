import XCTest
@testable import GodotTextFormat

final class AnimationExtractorTests: XCTestCase {
    func testExtractsAnimationsPerPlayer() throws {
        let url = Bundle.module.url(forResource: "anim.tscn", withExtension: nil, subdirectory: "Fixtures")!
        let scene = try SceneFile.parse(String(contentsOf: url, encoding: .utf8))
        let players = AnimationExtractor.extract(from: scene)
        XCTAssertEqual(players.map(\.nodeName), ["AnimationPlayer", "Secondary"])

        let main = players[0]
        XCTAssertEqual(main.libraries.count, 1)
        XCTAssertEqual(main.libraries[0].libraryName, "")
        XCTAssertEqual(main.libraries[0].animationNames, ["explode", "idle"])

        let secondary = players[1]
        XCTAssertEqual(secondary.libraries[0].libraryName, "shared")
        XCTAssertEqual(secondary.libraries[0].animationNames, ["explode", "idle"])
    }
}
