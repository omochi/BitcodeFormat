import XCTest
import BitcodeFormat
import BigInt

final class BitBufferTests: XCTestCase {
    func testJustByte1() throws {
        let data = Data([0xAA]) // 10101010
        let bits = BitBuffer(data: data, bitOffset: 0, bitLength: 8)
        XCTAssertEqual(bits.length, 8)
        XCTAssertEqual(bits.asBigUInt, BigUInt(0xAA))
    }
    
    func testOffsetRightByte1() throws {
        let data = Data([0xAA]) // 10101010
        let bits = BitBuffer(data: data, bitOffset: 1, bitLength: 7)
        XCTAssertEqual(bits.length, 7)
        XCTAssertEqual(bits.asBigUInt, BigUInt(0x55))
    }
    
    func testOffsetLeftByte1() throws {
        let data = Data([0xAA]) // 10101010
        let bits = BitBuffer(data: data, bitOffset: 0, bitLength: 7)
        XCTAssertEqual(bits.length, 7)
        XCTAssertEqual(bits.asBigUInt, BigUInt(0x2A))
    }
    
    func testOffsetBothByte1() throws {
        let data = Data([0xAA]) // 10101010
        let bits = BitBuffer(data: data, bitOffset: 1, bitLength: 6)
        XCTAssertEqual(bits.length, 6)
        XCTAssertEqual(bits.asBigUInt, BigUInt(0x15))
    }
    
    func testJustByte2() throws {
        // 10111011 10101010
        let data = Data([0xAA, 0xBB])
        let bits = BitBuffer(data: data, bitOffset: 0, bitLength: 16)
        XCTAssertEqual(bits.length, 16)
        XCTAssertEqual(bits.asBigUInt, BigUInt(0xBBAA))
    }
    
    func testOffsetLeftByte2() throws {
        // 10111011 10101010
        //  1011101 11010101
        let data = Data([0xAA, 0xBB])
        let bits = BitBuffer(data: data, bitOffset: 1, bitLength: 15)
        XCTAssertEqual(bits.length, 15)
        XCTAssertEqual(bits.asBigUInt, BigUInt(0x5DD5))
    }
    
    func testOffsetRightByte2() throws {
        // 10111011 10101010
        //  0111011 10101010
        let data = Data([0xAA, 0xBB])
        let bits = BitBuffer(data: data, bitOffset: 0, bitLength: 15)
        XCTAssertEqual(bits.length, 15)
        XCTAssertEqual(bits.asBigUInt, BigUInt(0x3BAA))
    }
    
    func testOffsetBothByte2() throws {
        // 10111011 10101010
        //       11 01110101
        let data = Data([0xAA, 0xBB])
        let bits = BitBuffer(data: data, bitOffset: 3, bitLength: 10)
        XCTAssertEqual(bits.length, 10)
        XCTAssertEqual(bits.asBigUInt, BigUInt(0x375))
    }
    
    func testOffsetBothByte6() throws {
        // 11001100 10111011 10101010 11001100 10111011 10101010
        //       01 10010111 01110101 01011001 10010111 01110101
        let data = Data([0xAA, 0xBB, 0xCC, 0xAA, 0xBB, 0xCC])
        let bits = BitBuffer(data: data, bitOffset: 3, bitLength: 42)
        XCTAssertEqual(bits.length, 42)
        XCTAssertEqual(bits.asBigUInt, BigUInt(0x197_75599775))
    }
}
