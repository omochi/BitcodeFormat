import Foundation
import BigInt

public struct BitBuffer {
    public typealias Word = BigUInt.Word
    
    public var length: Int
    public var words: [Word] = []
    
    public init(length: Int, words: [Word]) {
        self.length = length
        self.words = words
    }
    
    public var asBigUInt: BigUInt {
        return BigUInt(words: words)
    }
    
    public init(data: Data, bitOffset: Int, bitLength: Int) {
        precondition(0 <= bitOffset)
        precondition(bitOffset < 8)
        precondition(0 <= bitLength)
        precondition(bitOffset + bitLength <= data.count * 8)
        
        if bitLength == 0 {
            self.init(length: 0, words: [])
            return
        }
        
        let startIndex = bitOffset / 8
        let endIndex = (bitOffset + bitLength - 1) / 8 + 1
        
        var total = BigUInt(0)
        var totalBitLength = 0
        for index in startIndex..<endIndex {
            var byte = BigUInt(data[data.startIndex + index])
            var byteBitLength = 8
            if index + 1 == endIndex {
                let lastBitOffset = (bitOffset + bitLength) % 8
                if lastBitOffset != 0 {
                    let mask = (BigUInt(1) << lastBitOffset) - BigUInt(1)
                    byte &= mask
                    byteBitLength -= (8 - lastBitOffset)
                }
            }
            if index == startIndex {
                byte >>= bitOffset
                byteBitLength -= bitOffset
            }
            total |= byte << totalBitLength
            totalBitLength += byteBitLength
        }

        self.init(length: bitLength, words: Array(total.words))
    }
}
