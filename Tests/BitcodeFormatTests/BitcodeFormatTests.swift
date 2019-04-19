import XCTest
import BitcodeFormat

final class BitcodeFormatTests: XCTestCase {
    func test1() throws {
        let file = try Resources.findResourceDirectory()
            .appendingPathComponent("Test/xcbox.swiftmodule")
        let document = try Document(file: file)
        _ = document
    }
}
