import XCTest
@testable import GodotTextFormat

final class AnimationExtractorTests: XCTestCase {
    func testExtractsAnimationsPerPlayer() throws {
        let scene = try fixtureScene("anim.tscn")
        let players = AnimationExtractor.extract(from: scene)
        XCTAssertEqual(players.map(\.nodeName), ["AnimationPlayer", "Secondary"])

        let main = players[0]
        XCTAssertEqual(main.libraries.count, 1)
        XCTAssertEqual(main.libraries[0].libraryName, "")
        XCTAssertEqual(main.libraries[0].animations, .names(["explode", "idle"]))

        let secondary = players[1]
        XCTAssertEqual(secondary.libraries[0].libraryName, "shared")
        XCTAssertEqual(secondary.libraries[0].animations, .names(["explode", "idle"]))
    }

    /// Real Godot 4 scenes don't write `libraries = {...}` — they emit
    /// one `libraries/<name> = SubResource(...)` line per entry, and
    /// the library `_data` keys are StringNames (`&"title"`), not plain
    /// strings. Both shapes were silently dropped before the extractor
    /// learned the dotted form.
    func testExtractsAnimationsFromDottedLibraries() throws {
        let scene = try fixtureScene("anim-dotted.tscn")
        let players = AnimationExtractor.extract(from: scene)
        XCTAssertEqual(players.count, 1)
        let libs = players[0].libraries.sorted(by: { $0.libraryName < $1.libraryName })
        XCTAssertEqual(libs.map(\.libraryName), ["", "enemy"])
        XCTAssertEqual(libs[0].animations, .names(["RESET", "title"]))
        XCTAssertEqual(libs[1].animations, .names(["attack"]))
    }

    /// A mixer is any node that sets `libraries`, whatever class the scene gives it: a game's own
    /// subclass of AnimationPlayer and an AnimationTree count, an AnimationPlayer with no libraries
    /// gives nothing. A library in its own file is reported by its path. llm-generated
    func testFindsMixersByTheirLibraries() throws {
        let mixers = AnimationExtractor.extract(from: try fixtureScene("anim-mixers.tscn"))
        XCTAssertEqual(mixers, [
            .init(nodeName: "PlayerAnimations", nodePath: "PlayerAnimations", libraries: [
                .init(libraryName: "", animations: .names(["idle"])),
            ]),
            .init(nodeName: "Tree", nodePath: "Body/Tree", libraries: [
                .init(libraryName: "combat", animations: .file("res://combat-library.tres")),
            ]),
        ])
    }

    /// A library file's animation names, in its order; a file of another type has none. llm-generated
    func testReadsALibraryFile() throws {
        XCTAssertEqual(AnimationExtractor.animationNames(inLibrary: try fixtureResource("combat-library.tres")), ["slash", "kick"])
        XCTAssertNil(AnimationExtractor.animationNames(inLibrary: try fixtureResource("mob-frames.tres")))
    }

    /// SpriteFrames' animation names, from each sub-resource of a scene and from a file of its
    /// own; a file of another type has none. llm-generated
    func testReadsSpriteFrames() throws {
        XCTAssertEqual(AnimationExtractor.spriteFrames(in: try fixtureScene("anim-mixers.tscn")), [["default", "walk"], ["fly"]])
        XCTAssertEqual(AnimationExtractor.animationNames(inSpriteFrames: try fixtureResource("mob-frames.tres")), ["swim", "fly"])
        XCTAssertNil(AnimationExtractor.animationNames(inSpriteFrames: try fixtureResource("combat-library.tres")))
    }

    private func fixtureText(_ name: String) throws -> String {
        let url = Bundle.module.url(forResource: name, withExtension: nil, subdirectory: "Fixtures")!
        return try String(contentsOf: url, encoding: .utf8)
    }

    private func fixtureScene(_ name: String) throws -> SceneFile {
        try SceneFile.parse(fixtureText(name))
    }

    private func fixtureResource(_ name: String) throws -> ResourceFile {
        try ResourceFile.parse(fixtureText(name))
    }
}
