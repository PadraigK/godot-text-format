import XCTest
@testable import GodotTextFormat

/// `appendingAutoload` is the one edit gdswift makes to a file the editor
/// owns, so every test compares the untouched bytes exactly.
final class ProjectFileWriterTests: XCTestCase {

    func testAppendsToAnExistingSection() {
        let source = """
        config_version=5

        [application]

        config/name="Game"

        [autoload]

        Dialogic="*res://addons/dialogic/dialogic.gd"

        """
        XCTAssertEqual(
            ProjectFile.appendingAutoload(name: "Sounds", path: "res://generated/sounds.gd", to: source),
            """
            config_version=5

            [application]

            config/name="Game"

            [autoload]

            Dialogic="*res://addons/dialogic/dialogic.gd"
            Sounds="*res://generated/sounds.gd"

            """
        )
    }

    func testCreatesTheSectionAfterApplicationWhenAbsent() {
        let source = """
        config_version=5

        [application]

        config/name="Game"
        run/main_scene="res://main.tscn"

        [rendering]

        renderer/rendering_method="mobile"

        """
        XCTAssertEqual(
            ProjectFile.appendingAutoload(name: "Sounds", path: "res://generated/sounds.gd", to: source),
            """
            config_version=5

            [application]

            config/name="Game"
            run/main_scene="res://main.tscn"

            [autoload]

            Sounds="*res://generated/sounds.gd"

            [rendering]

            renderer/rendering_method="mobile"

            """
        )
    }

    func testKeepsUnrelatedSectionsAfterTheOneItEdits() {
        let source = """
        [autoload]

        Dialogic="*res://addons/dialogic/dialogic.gd"

        [input]

        jump={
        "deadzone": 0.5
        }

        [input.macos]

        jump=null

        """
        XCTAssertEqual(
            ProjectFile.appendingAutoload(name: "Sounds", path: "res://generated/sounds.gd", to: source),
            """
            [autoload]

            Dialogic="*res://addons/dialogic/dialogic.gd"
            Sounds="*res://generated/sounds.gd"

            [input]

            jump={
            "deadzone": 0.5
            }

            [input.macos]

            jump=null

            """
        )
    }

    func testOpensAnEmptySectionWithABlankLine() {
        let source = """
        [autoload]

        [rendering]

        renderer/rendering_method="mobile"

        """
        XCTAssertEqual(
            ProjectFile.appendingAutoload(name: "Sounds", path: "res://generated/sounds.gd", to: source),
            """
            [autoload]

            Sounds="*res://generated/sounds.gd"

            [rendering]

            renderer/rendering_method="mobile"

            """
        )
    }

    func testAppendsAtTheEndWhenTheFileHasNeitherSection() {
        let source = """
        config_version=5

        [rendering]

        renderer/rendering_method="mobile"

        """
        XCTAssertEqual(
            ProjectFile.appendingAutoload(name: "Sounds", path: "res://generated/sounds.gd", to: source),
            """
            config_version=5

            [rendering]

            renderer/rendering_method="mobile"

            [autoload]

            Sounds="*res://generated/sounds.gd"

            """
        )
    }

    func testTheWrittenEntryParsesBackAsAnAutoload() throws {
        let source = """
        config_version=5

        [application]

        config/name="Game"

        """
        let updated = ProjectFile.appendingAutoload(name: "Sounds", path: "res://generated/sounds.gd", to: source)
        let parsed = try ProjectFile.parse(updated)
        XCTAssertEqual(parsed.section("autoload")?.body.map { $0.0 }, ["Sounds"])
        XCTAssertEqual(
            parsed.section("autoload")?.prop("Sounds"),
            .string("*res://generated/sounds.gd")
        )
    }
}
