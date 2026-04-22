import XCTest
@testable import GodotTextFormat

final class SmokeTests: XCTestCase {
    func testModuleVersionIsDefined() {
        XCTAssertEqual(GodotTextFormat.moduleVersion, "0.1.0")
    }
}
