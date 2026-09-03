import XCTest
@testable import GodotTextFormat

final class ResourceFileTests: XCTestCase {
    func testPackedArrays() throws {
        let url = Bundle.module.url(forResource: "packed-arrays.tres", withExtension: nil, subdirectory: "Fixtures")!
        let text = try String(contentsOf: url, encoding: .utf8)
        let file = try ResourceFile.parse(text)
        XCTAssertEqual(file.type, "MyResource")
        XCTAssertEqual(file.resource?.prop("names"),
            .construct(name: "PackedStringArray",
                args: [.string("alpha"), .string("beta"), .string("gamma")]))
    }
}

extension ResourceFileTests {
    func testScriptClassOnTheHeader() throws {
        let file = try ResourceFile.parse("""
        [gd_resource type="Resource" script_class="GroceryItem" format=3 uid="uid://wev5pwbmjyl6"]

        [ext_resource type="Script" path="res://generated/grocery_item.gd" id="1"]

        [resource]
        script = ExtResource("1")
        """)
        XCTAssertEqual(file.type, "Resource")
        XCTAssertEqual(file.scriptClass, "GroceryItem")
    }

    func testScriptClassAbsent() throws {
        let file = try ResourceFile.parse("[gd_resource type=\"Theme\" format=3]\n[resource]\n")
        XCTAssertEqual(file.type, "Theme")
        XCTAssertNil(file.scriptClass)
    }
}
