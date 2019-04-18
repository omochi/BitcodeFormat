import Foundation
import BigInt

public final class Reader {
    public enum Message : CustomStringConvertible {
        case reachedEndOfFile
        case invalidFilePosition(UInt64)
        case unknownAbbrevID(UInt32)
        case noExpectedEndBlock
        case primitiveOutOfRange(BigUInt)
        case invalidRecordOperand
        
        case endBlockOnTopLevelIgnored
        case recordOnTopLevelIgnored
        case subBlockInBlockInfoIgnored
        case utf8DecodeFailed
        case unknownRecordCode(code: UInt32)
        
        public var description: String {
            switch self {
            case .reachedEndOfFile:
                return "reached end of file"
            case .invalidFilePosition(let x):
                return "invalid file position: \(x)"
            case .unknownAbbrevID(let id):
                return "unknown abbrev ID: \(id)"
            case .noExpectedEndBlock:
                return "no expected END_BLOCK"
            case .primitiveOutOfRange(let x):
                return "primitive is out of range: \(x)"
            case .invalidRecordOperand:
                return "invalid record operand"
            case .endBlockOnTopLevelIgnored:
                return "END_BLOCK on top lebel ignored"
            case .recordOnTopLevelIgnored:
                return "record on top level ignored"
            case .subBlockInBlockInfoIgnored:
                return "subblock in BLOCKINFO ignored"
            case .utf8DecodeFailed:
                return "utf-8 decode failed"
            case .unknownRecordCode(code: let code):
                return "unknown record code: \(code)"
            }
        }
    }
    
    public struct Error : ErrorBase {
        public var message: Message
        public var position: Position?
        public var blockID: UInt32?
        
        public init(message: Message,
                    position: Position?,
                    blockID: UInt32?)
        {
            self.message = message
            self.position = position
            self.blockID = blockID
        }
        
        public var description: String {
            var s = "\(message)"
            if let pos = position {
                s += " at \(pos)"
            }
            if let bid = blockID {
                s += " in block \(bid)"
            }
            return s
        }
    }
    
    public struct Position : CustomStringConvertible {
        public var offset: UInt64
        public var bitOffset: UInt8
        
        public var description: String {
            var str = String(format: "0x%08x", offset)
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

    private func popState() {
        precondition(stateStack.count >= 2)
        stateStack.removeLast()
    }
    
    public func read() throws {
        let magic = try readMagicNumber()
        
        while !isEnd {
            let abb = try readAbbreviation()
            switch abb {
            case .enterSubBlock(let block):
                if block.id == Block.BlockInfo.id {
                    let state = State(block: block)
                    pushState(state)
                    try readBlockInfo()
                    popState()
                } else {
                    advancePosition(length: castToUInt64(block.length) * 8)
                }
            case .endBlock:
                emitWarning(.endBlockOnTopLevelIgnored)
            case .record:
                emitWarning(.recordOnTopLevelIgnored)
            }
        }
    }
    
    private func emitWarning(_ message: Message) {
        emitWarning(error(message))
    }
    
    private func emitWarning(_ warning: Error) {
        print("[WARN] \(warning)")
    }
    
    private func error(_ message: Message,
                       position: Position? = nil) -> Error {
        return Error(message: message,
                     position: position ?? self.position,
                     blockID: state.block?.id)
    }
    
    public func readMagicNumber() throws -> UInt32 {
        let bs = try readBits(length: 32)
        return try castToUInt32(bs.asBigUInt)
    }
    
    public func readAbbreviation() throws -> Abbreviation {
        let abbPos = self.position
        let abbLen = castToInt(state.block?.abbrevIDWidth ?? 2)
        let abbrevID = try castToUInt32(readBits(length: abbLen).asBigUInt)
        switch abbrevID {
        case Abbreviation.EndBlock.id:
            skipToAlignment(32)
            return .endBlock
        case Abbreviation.EnterSubBlock.id:
            let blockID = try castToUInt32(readVBR(width: 8))
            let abbrevLen = try castToUInt8(readVBR(width: 4))
            skipToAlignment(32)
            let length = try castToUInt32(readFixed(width: 32)) * 4
            let block = Block(id: blockID,
                              abbrevIDWidth: abbrevLen,
                              length: length)
            return .enterSubBlock(block)
        case Abbreviation.UnabbrevRecord.id:
            let code = try castToUInt32(readVBR(width: 6))
            let opsNum = try castToUInt32(readVBR(width: 6))
            var operands: [UInt64] = []
            for _ in 0..<opsNum {
                let op = try castToUInt64(readVBR(width: 6))
                operands.append(op)
            }
            let record = Record(code: code, operands: operands)
            return .record(record)
        default:
            throw error(.unknownAbbrevID(abbrevID), position: abbPos)
        }
    }
    
    public func readBlockInfo() throws {
        var blockID: UInt32?
        while true {
            let abb = try readAbbreviation()
            
            switch abb {
            case .enterSubBlock(let block):
                emitWarning(.subBlockInBlockInfoIgnored)
                advancePosition(length: castToUInt64(block.length))
            case .endBlock:
                return
            case .record(let record):
                switch record.code {
                case Block.BlockInfo.SetBID.id:
                    if record.operands.count <= 0 {
                        throw error(.invalidRecordOperand, position: position)
                    }
                    blockID = try castToUInt32(record.operands[0])
                case Block.BlockInfo.BlockName.id:
                    var data = Data()
                    for o in record.operands {
                        data.append(try castToUInt8(o))
                    }
                    guard let string = String(data: data, encoding: .utf8) else {
                        throw error(.utf8DecodeFailed, position: position)
                    }
                    print(string)
                case Block.BlockInfo.SetRecordName.id:
                    break
                default:
                    break
                }
            }
            
        }
        
    }
    
    public func readFixed(width: Int) throws -> BigUInt {
        let bits = try readBits(length: width)
        return bits.asBigUInt
    }
    
    public func readVBR(width: Int) throws -> BigUInt {
        var result = BigUInt()
        var bitLen = 0
        while true {
            let bits = try readBits(length: width)
            let valueWidth = width - 1
            
            let value = bits.asBigUInt
            let contMask = BigUInt(1) << valueWidth
            let valueMask = ~contMask
            
            result |= (value & valueMask) << bitLen
            bitLen += valueWidth
            
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
            throw error(.invalidFilePosition(_pos))
        }
        
        if position + size > data.count {
            throw error(.reachedEndOfFile)
        }
        
        return data.subdata(in: position..<(position + size))
    }
    
    private func operand(at index: Int, for record: Record) throws -> UInt64 {
        guard 0 <= index, index < record.operands.count else {
            throw error(.invalidRecordOperand, position: position)
        }
        return record.operands[index]
    }
    
    private func castToUInt8(_ a: UInt64) throws -> UInt8 { return try intCast(a) }
    private func castToUInt8(_ a: BigUInt) throws -> UInt8 { return try intCast(a) }
    private func castToUInt32(_ a: UInt64) throws -> UInt32 { return try intCast(a) }
    private func castToUInt32(_ a: BigUInt) throws -> UInt32 { return try intCast(a) }
    private func castToUInt64(_ a: UInt32) -> UInt64 { return UInt64(a) }
    private func castToUInt64(_ a: BigUInt) throws -> UInt64 { return try intCast(a) }
    private func castToInt(_ a: UInt8) -> Int { return Int(a) }
    
    private func intCast<A, R>(_ a: A) throws -> R where A : BinaryInteger, R : BinaryInteger {
        guard let x = R(exactly: a) else {
            throw error(.primitiveOutOfRange(BigUInt(a)), position: position)
        }
        return x
    }
    
}
