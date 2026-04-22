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
