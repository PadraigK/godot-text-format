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

    /// Real Godot 4 scenes don't write `libraries = {...}` — they emit
    /// one `libraries/<name> = SubResource(...)` line per entry, and
    /// the library `_data` keys are StringNames (`&"title"`), not plain
    /// strings. Both shapes were silently dropped before the extractor
    /// learned the dotted form.
    func testExtractsAnimationsFromDottedLibraries() throws {
        let url = Bundle.module.url(forResource: "anim-dotted.tscn", withExtension: nil, subdirectory: "Fixtures")!
        let scene = try SceneFile.parse(String(contentsOf: url, encoding: .utf8))
        let players = AnimationExtractor.extract(from: scene)
        XCTAssertEqual(players.count, 1)
        let libs = players[0].libraries.sorted(by: { $0.libraryName < $1.libraryName })
        XCTAssertEqual(libs.map(\.libraryName), ["", "enemy"])
        XCTAssertEqual(Set(libs[0].animationNames), Set(["RESET", "title"]))
        XCTAssertEqual(libs[1].animationNames, ["attack"])
    }
}
