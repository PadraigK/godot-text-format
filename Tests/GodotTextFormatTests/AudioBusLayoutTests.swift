import XCTest
@testable import GodotTextFormat

final class AudioBusLayoutTests: XCTestCase {
    /// A layout as Godot's editor saves it, with bus 0's name left out, gives Master then the
    /// named buses by index; an effect sub-resource and a bus's other lines are skipped.
    /// llm-generated
    func testBusNamesByIndex() throws {
        let layout = try ResourceFile.parse("""
        [gd_resource type="AudioBusLayout" load_steps=2 format=3 uid="uid://dlshmww65ljnq"]

        [sub_resource type="AudioEffectReverb" id="AudioEffectReverb_1"]
        resource_name = "Reverb"

        [resource]
        bus/0/volume_db = 0.0672607
        bus/1/name = &"Music"
        bus/1/solo = false
        bus/1/send = &"Master"
        bus/2/name = &"SFX"
        bus/2/effect/0/effect = SubResource("AudioEffectReverb_1")
        bus/2/effect/0/enabled = true

        """)
        XCTAssertEqual(AudioBusLayoutReader.busNames(in: layout), ["Master", "Music", "SFX"])
    }

    /// Bus 0 is Master whatever the file names it, as `AudioServer.set_bus_layout` makes it; a
    /// bus the file gives only other lines has an empty name. llm-generated
    func testBusZeroIsMasterAndUnnamedBusesAreEmpty() throws {
        let layout = try ResourceFile.parse("""
        [gd_resource type="AudioBusLayout" format=3]

        [resource]
        bus/0/name = &"Main"
        bus/1/mute = true
        bus/2/name = "Voice"

        """)
        XCTAssertEqual(AudioBusLayoutReader.busNames(in: layout), ["Master", "", "Voice"])
    }

    /// A file of another type has no buses to read. llm-generated
    func testOtherResourceIsNotALayout() throws {
        let file = try ResourceFile.parse("[gd_resource type=\"Theme\" format=3]\n\n[resource]\n")
        XCTAssertNil(AudioBusLayoutReader.busNames(in: file))
    }

    /// The project's layout is `[audio]`'s `buses/default_bus_layout` as written, a uid included;
    /// a project that doesn't set it has none of its own. llm-generated
    func testDefaultBusLayoutSetting() throws {
        let set = try ProjectFile.parse("config_version=5\n\n[audio]\n\nbuses/default_bus_layout=\"uid://dlshmww65ljnq\"\n")
        XCTAssertEqual(set.defaultBusLayout, "uid://dlshmww65ljnq")
        let unset = try ProjectFile.parse("config_version=5\n\n[application]\n\nconfig/name=\"Game\"\n")
        XCTAssertNil(unset.defaultBusLayout)
    }
}
