import Foundation
import BigInt

public final class Reader {
    public enum Error : ErrorBase {
        case reachedEndOfFile
        case invalidFilePosition(UInt64)
        case unknownAbbrevID(UInt32, position: Position)
        case noExpectedEndBlock(position: Position)

        public var description: String {
            switch self {
            case .reachedEndOfFile:
                return "reached end of file"
            case .invalidFilePosition(let x):
                return "invalid file position: \(x)"
            case .unknownAbbrevID(let id, position: let pos):
                return "unknown abbrev ID: \(id) at \(pos)"
            case .noExpectedEndBlock(position: let pos):
                return "no expected END_BLOCK at \(pos)"
            }
        }
    }
    
    public enum Warning : CustomStringConvertible {
        case endBlockOnTopLevelIgnored
        case recordOnTopLevelIgnored
        case subBlockInBlockInfoIgnored
        
        public var description: String {
            switch self {
            case .endBlockOnTopLevelIgnored: return "END_BLOCK on top lebel ignored"
            case .recordOnTopLevelIgnored: return "record on top level ignored"
            case .subBlockInBlockInfoIgnored: return "subblock in BLOCKINFO ignored"
            }
        }
    }
    
    public struct Position : CustomStringConvertible {
        public var offset: UInt64
        public var bitOffset: UInt8
        
        public var description: String {
            var str = String(format: "0x%8x", offset)
            if bitOffset != 0 {
                str += "#\(bitOffset)"
            }
            return str
        }
    }
    
    public struct State {
        public var block: Block?
    }
    
    private let data: Data
    private var position: Position
    private var state: State {
        get {
            return stateStack.last!
        }
        set {
            stateStack[stateStack.count - 1] = newValue
        }
    }
    private var stateStack: [State]
    
    public init(data: Data) {
        self.data = data
        self.position = Position(offset: 0, bitOffset: 0)
        let state = State(block: nil)
        self.stateStack = [state]
    }
    
    public convenience init(file: URL) throws {
        let data = try Data(contentsOf: file)
        self.init(data: data)
    }
    
    private func pushState(_ state: State) {
        stateStack.append(state)
    }
    
    public func read() throws {
        let magic = try readMagicNumber()
        
        while !isEnd {
            let abb = try readAbbreviation()
            switch abb {
            case .enterSubBlock(let block):
                
                advancePosition(length: UInt64(block.length) * 8)
                
                let endAbbPos = self.position
                let endAbb = try readAbbreviation()
                guard case .endBlock = endAbb else {
                    throw Error.noExpectedEndBlock(position: endAbbPos)
                }
                
                //            if block.id == 0 {
                //                let state = State(block: block)
                //                pushState(state)
                //
                //                try readBlockInfo()
            //            }
            case .endBlock:
                emitWarning(.endBlockOnTopLevelIgnored)
            case .record:
                emitWarning(.recordOnTopLevelIgnored)
            }
        }
    }
    
    private func emitWarning(_ warning: Warning) {
        print("[WARN] \(warning)")
    }
    
    public func readMagicNumber() throws -> UInt32 {
        let bs = try readBits(length: 32)
        return UInt32(bs.asBigUInt)
    }
    
    public func readAbbreviation() throws -> Abbreviation {
        let abbPos = self.position
        let abbLen = Int(state.block?.abbrevIDWidth ?? 2)
        let abbrevID = UInt32(try readBits(length: abbLen).asBigUInt)
        switch abbrevID {
        case Abbreviation.ID.endBlock.rawValue:
            skipToAlignment(32)
            return .endBlock
        case Abbreviation.ID.enterSubBlock.rawValue:
            let blockID = UInt32(try readVBR(width: 8))
            let abbrevLen = UInt8(try readVBR(width: 4))
            skipToAlignment(32)
            let length = UInt32(try readFixed(width: 32))
            let block = Block(id: blockID,
                              abbrevIDWidth: abbrevLen,
                              length: length)
            return .enterSubBlock(block)
        case Abbreviation.ID.unabbrevRecord.rawValue:
            let code = UInt32(try readVBR(width: 6))
            let opsNum = UInt32(try readVBR(width: 6))
            var operands: [UInt32] = []
            for _ in 0..<opsNum {
                let op = UInt32(try readVBR(width: 6))
                operands.append(op)
            }
            let record = Record(code: code, operands: operands)
            return .record(record)
        default:
            throw Error.unknownAbbrevID(abbrevID, position: abbPos)
        }
    }
    
    public func readBlockInfo() throws {
        let abb = try readAbbreviation()
        var blockID: UInt32?
        
//        switch abb {
//        case .enterSubBlock(let block):
//            emitWarning(.subBlockInBlockInfoIgnored)
//        }
        
    }
    
    public func readFixed(width: Int) throws -> BigUInt {
        let bits = try readBits(length: width)
        return bits.asBigUInt
    }
    
    public func readVBR(width: Int) throws -> BigUInt {
        var result = BigUInt()
        while true {
            let bits = try readBits(length: width)
            let valueWidth = width - 1
            
            let value = bits.asBigUInt
            let contMask = BigUInt(1) << valueWidth
            let valueMask = ~contMask
            
            result = (result << valueWidth) | (value & valueMask)
            
            if value & contMask == BigUInt(0) {
                break
            }
        }
        return result
    }
    
    public func skipToAlignment(_ alignment: Int) {
        let bitPosition = position.offset * 8 + UInt64(position.bitOffset)
        let rem = Int(bitPosition % UInt64(alignment))
        if rem == 0 {
            return
        }
        advancePosition(length: UInt64(alignment - rem))
    }

    private func readBits(length: Int) throws -> BitBuffer {
        precondition(length > 0)
        let bitOffset = Int(position.bitOffset)
        let readSize = (bitOffset + length - 1) / 8 + 1
        let data = try _readData(position: position.offset, size: readSize)
        let bits = BitBuffer(data: data, bitOffset: bitOffset, bitLength: length)
        advancePosition(length: UInt64(length))
        return bits
    }
    
    private func advancePosition(length: UInt64) {
        position.offset += UInt64(length / 8)
        position.bitOffset += UInt8(length % 8)
        while position.bitOffset >= 8 {
            position.offset += 1
            position.bitOffset -= 8
        }
    }
    
    private var isEnd: Bool {
        return position.offset >= UInt64(data.count)
    }
    
    private func _readData(position _pos: UInt64, size: Int) throws -> Data {
        guard let position = Int(exactly: _pos) else {
            throw Error.invalidFilePosition(_pos)
        }
        
        if position + size > data.count {
            throw Error.reachedEndOfFile
        }
        
        return data.subdata(in: position..<(position + size))
    }
    
}
