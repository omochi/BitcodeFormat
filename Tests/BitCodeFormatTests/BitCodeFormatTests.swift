import XCTest
import BitCodeFormat

final class BitCodeFormatTests: XCTestCase {
    func testExample() throws {
        let file = try Resources.findResourceDirectory()
            .appendingPathComponent("Test/xcbox.swiftmodule")
        let reader = try Reader(file: file)
        try reader.read()
    }

    static var allTests = [
        ("testExample", testExample),
    ]
}
