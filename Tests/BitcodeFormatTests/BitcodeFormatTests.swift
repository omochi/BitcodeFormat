import XCTest
import BitCodeFormat

final class BitcodeFormatTests: XCTestCase {
    func test1() throws {
        let file = try Resources.findResourceDirectory()
            .appendingPathComponent("Test/xcbox.swiftmodule")
        let reader = try Reader(file: file)
        let document = try reader.read()
        _ = document
    }
}
