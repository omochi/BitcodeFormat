import Foundation
import BigInt

public final class Reader {
    public enum Message : CustomStringConvertible {
        case reachedEndOfFile
        case invalidFilePosition(UInt64)
        case primitiveOutOfRange(BigUInt)
        
        case unknownAbbrevID(UInt32)
        case unknownDefineAbbrevOperandCode(UInt8)
        case blobMustBeLast
        case endBlockOnTopLevelIgnored
        case defineAbbrevOnTopLevelIgnored
        case unabbrevRecordOnTopLevelIgnored
        case subBlockInBlockInfoIgnored
        case utf8DecodeFailed
        case unknownRecordCode(code: UInt32)
        case invalidRecordOperand
        case blockIDNotSpecified
        case invalidLengthValue(UInt32)
        
        public var description: String {
            switch self {
            case .reachedEndOfFile:
                return "reached end of file"
            case .invalidFilePosition(let x):
                return "invalid file position: \(x)"
            case .primitiveOutOfRange(let x):
                return "primitive is out of range: \(x)"
            case .unknownAbbrevID(let id):
                return "unknown abbrev ID: \(id)"
            case .unknownDefineAbbrevOperandCode(let code):
                return "unknown DEFINE_ABBREV operand code: \(code)"
            case .blobMustBeLast:
                return "Blob must be last operand"
            case .endBlockOnTopLevelIgnored:
                return "END_BLOCK on top lebel ignored"
            case .defineAbbrevOnTopLevelIgnored:
                return "DEFINE_ABBREV on top level ignored"
            case .unabbrevRecordOnTopLevelIgnored:
                return "UNABBREV_RECORD on top level ignored"
            case .subBlockInBlockInfoIgnored:
                return "subblock in BLOCKINFO ignored"
            case .utf8DecodeFailed:
                return "utf-8 decode failed"
            case .unknownRecordCode(code: let code):
                return "unknown record code: \(code)"
            case .invalidRecordOperand:
                return "invalid record operand"
            case .blockIDNotSpecified:
                return "block id is not specified"
            case .invalidLengthValue(let x):
                return "invalid length value: \(x)"
            }
        }
    }
    
    public struct Error : ErrorBase {
        public var message: Message
        public var position: Position?
        public var blockName: String?
        
        public init(message: Message,
                    position: Position?,
                    blockName: String?)
        {
            self.message = message
            self.position = position
            self.blockName = blockName
        }
        
        public var description: String {
            var s = "\(message)"
            if let pos = position {
                s += " at \(pos)"
            }
            if let name = blockName {
                s += " in \(name)"
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
    
    public struct BlockInfo {
        public struct RecordInfo {
            public var name: String?
            public var define: DefineAbbrev?
            
            public init(name: String? = nil,
                        define: DefineAbbrev? = nil)
            {
                self.name = name
                self.define = define
            }
        }
        
        public var name: String?
        public var recordInfos: [(UInt32, RecordInfo)]
        
        public init(name: String? = nil,
                    recordInfos: [(UInt32, RecordInfo)] = [])
        {
            self.name = name
            self.recordInfos = recordInfos
        }
        
        public func recordInfo(id: UInt32) -> RecordInfo {
            return recordInfos
                .first { $0.0 == id }
                .map { $0.1 } ?? RecordInfo()
        }
        
        public mutating func setRecordInfo(_ info: RecordInfo, id: UInt32) {
            guard let index = (recordInfos.firstIndex { $0.0 == id }) else {
                recordInfos.append((id, info))
                return
            }
            recordInfos[index] = (id, info)
        }
        
        public mutating func modifyRecordInfo(id: UInt32, _ f: (inout RecordInfo) -> Void) {
            var info = recordInfo(id: id)
            f(&info)
            setRecordInfo(info, id: id)
        }
        
        public var nextDefineRecordID: UInt32 {
            return recordInfos.map { $0.0 }.max().map { $0 + 1 } ?? 4
        }
        
        public mutating func defineAbbrev(_ define: DefineAbbrev) {
            let id = nextDefineRecordID
            modifyRecordInfo(id: id) { (info) in
                info.define = define
            }
        }
    }
    
    public struct State {
        public var block: Block?
        public var blockInfo: BlockInfo
        
        public init(block: Block?,
                    blockInfo: BlockInfo = BlockInfo())
        {
            self.block = block
            self.blockInfo = blockInfo
        }
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
    
    private var blockInfos: [UInt32: BlockInfo]
    
    private func rootBlockInfo(id: UInt32) -> BlockInfo {
        return blockInfos[id] ?? BlockInfo()
    }
    private func setRootBlockInfo(_ info: BlockInfo, id: UInt32) {
        blockInfos[id] = info
    }
    private func modifyRootBlockInfo(id: UInt32, _ f: (inout BlockInfo) -> Void) {
        var info = rootBlockInfo(id: id)
        f(&info)
        setRootBlockInfo(info, id: id)
    }
    
    public init(data: Data) {
        self.data = data
        self.position = Position(offset: 0, bitOffset: 0)
        let state = State(block: nil)
        self.stateStack = [state]
        self.blockInfos = [:]
    }
    
    public convenience init(file: URL) throws {
        let data = try Data(contentsOf: file)
        self.init(data: data)
    }
    
    private func enter(block: Block) {
        let name = traceName(ofBlockWithID: block.id)
        trace("enter \(name) {")
        let blockInfo = rootBlockInfo(id: block.id)
        let state = State(block: block,
                          blockInfo: blockInfo)
        pushState(state)
    }
    
    private func pushState(_ state: State) {
        stateStack.append(state)
    }

    private func exitBlock() {
        precondition(stateStack.count >= 2)
        let state = self.state
        let name = traceName(ofBlockWithID: state.block!.id)
        stateStack.removeLast()
        trace("} exit \(name)")
    }
    
    private var blockID: UInt32? {
        return state.block?.id
    }
    
    public func read() throws {
        let magic = try readMagicNumber()
        
        while !isEnd {
            let abb = try readAbbreviation()
            switch abb {
            case .enterSubBlock(let block):
                if block.id == Block.BlockInfo.id {
                    enter(block: block)
                    try readBlockInfo()
                    exitBlock()
                } else {
                    let name = traceName(ofBlockWithID: block.id)
                    enter(block: block)
                    try readBlock()
                    exitBlock()
                }
            case .endBlock:
                emitWarning(.endBlockOnTopLevelIgnored)
            case .defineAbbrev:
                emitWarning(.defineAbbrevOnTopLevelIgnored)
            case .unabbrevRecord:
                emitWarning(.unabbrevRecordOnTopLevelIgnored)
            }
        }
    }

    private func name(ofBlockWithID id: UInt32) -> String {
        if id == 0 {
            return "BLOCKINFO"
        }
        let info = rootBlockInfo(id: id)
        return info.name ?? ""
    }
    
    private func traceName(ofBlockWithID id: UInt32) -> String {
        return name(ofBlockWithID: id) + "#\(id)"
    }
    
    private func emitWarning(_ message: Message) {
        emitWarning(error(message))
    }
    
    private func emitWarning(_ warning: Error) {
        print("[WARN] \(warning)")
    }
    
    private func error(_ message: Message,
                       position: Position? = nil) -> Error {
        let blockID = self.blockID
        let blockName = blockID.map { traceName(ofBlockWithID: $0) }
        return Error(message: message,
                     position: position ?? self.position,
                     blockName: blockName)
    }
    
    private func readMagicNumber() throws -> UInt32 {
        let bs = try readBits(length: 32)
        return try castToUInt32(bs.asBigUInt)
    }
    
    private func readAbbreviation() throws -> Abbreviation {
        while true {
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
                let lengthInWord = try castToUInt32(try readFixed(width: 32))
                let (length, ovf) = lengthInWord.multipliedReportingOverflow(by: 4)
                if ovf {
                    throw error(.invalidLengthValue(lengthInWord))
                }
                let block = Block(id: blockID,
                                  abbrevIDWidth: abbrevLen,
                                  length: length)
                return .enterSubBlock(block)
            case DefineAbbrev.id:
                let opsNum = try castToUInt32(readVBR(width: 5))
                var operands: [DefineAbbrev.Operand] = []
                
                func decodeOperand() throws -> DefineAbbrev.Operand {
                    let isLiteral = try castToUInt8(readFixed(width: 1)) != 0
                    if isLiteral {
                        let value = try castToUInt64(readVBR(width: 8))
                        return DefineAbbrev.Operand.literal(value: value)
                    }
                    
                    let encoding = try castToUInt8(readFixed(width: 3))
                    switch encoding {
                    case DefineAbbrev.Fixed.code:
                        let width = try castToUInt8(readVBR(width: 5))
                        return .fixed(width: width)
                    case DefineAbbrev.VBR.code:
                        let width = try castToUInt8(readVBR(width: 5))
                        return .vbr(width: width)
                    case DefineAbbrev.Array.code:
                        let type = try decodeOperand()
                        return .array(type: type)
                    case DefineAbbrev.Char6.code:
                        return .char6
                    case DefineAbbrev.Blob.code:
                        guard operands.count + 1 == opsNum else {
                            throw error(.blobMustBeLast)
                        }
                        return .blob
                    default:
                        throw error(.unknownDefineAbbrevOperandCode(encoding))
                    }
                }
                
                while operands.count < opsNum {
                    let op = try decodeOperand()
                    operands.append(op)
                }
                
                let defAbb = DefineAbbrev(operands: operands)
                return .defineAbbrev(defAbb)
            case Abbreviation.UnabbrevRecord.id:
                let code = try castToUInt32(readVBR(width: 6))
                let opsNum = try castToUInt32(readVBR(width: 6))
                var operands: [UInt64] = []
                for _ in 0..<opsNum {
                    let op = try castToUInt64(readVBR(width: 6))
                    operands.append(op)
                }
                let record = Record(code: code, operands: operands)
                return .unabbrevRecord(record)
            default:
                throw error(.unknownAbbrevID(abbrevID),
                            position: abbPos)
            }
        }
    }
    
    private func readBlock() throws {
        while true {
            let abb = try readAbbreviation()
            
            switch abb {
            case .enterSubBlock(let subBlock):
                enter(block: subBlock)
                try readBlock()
                exitBlock()
            case .endBlock:
                return
            case .defineAbbrev(let defAbb):
                state.blockInfo.defineAbbrev(defAbb)
            case .unabbrevRecord(let record):
                dump(record)
            }
        }
    }
    
    private func readBlockInfo() throws {
        var targetBlockID: UInt32?
        
        func modifyBlockInfo(_ f: (inout BlockInfo) -> Void) throws {
            guard let id = targetBlockID else {
                throw error(.blockIDNotSpecified)
            }
            self.modifyRootBlockInfo(id: id, f)
        }
        
        while true {
            let abb = try readAbbreviation()
            
            switch abb {
            case .enterSubBlock(let block):
                emitWarning(.subBlockInBlockInfoIgnored)
                advancePosition(length: castToUInt64(block.length))
            case .endBlock:
                return
            case .defineAbbrev(let defAbb):
                try modifyBlockInfo { (info) in
                    info.defineAbbrev(defAbb)
                }
            case .unabbrevRecord(let record):
                do {
                    switch record.code {
                    case Block.BlockInfo.SetBID.id:
                        if record.operands.count <= 0 {
                            throw error(.invalidRecordOperand)
                        }
                        targetBlockID = try castToUInt32(record.operands[0])
                    case Block.BlockInfo.BlockName.id:
                        let name = try decodeOperandsString(record.operands)
                        try modifyBlockInfo { (info) in
                            info.name = name
                        }
                    case Block.BlockInfo.SetRecordName.id:
                        var operands = record.operands
                        if operands.count <= 0 {
                            throw error(.invalidRecordOperand)
                        }
                        let recordID = try castToUInt32(operands[0])
                        operands.removeFirst()
                        let name = try decodeOperandsString(operands)
                        try modifyBlockInfo { (info) in
                            info.modifyRecordInfo(id: recordID) { (info) in
                                info.name = name
                            }
                        }
                    default:
                        throw error(.unknownRecordCode(code: record.code))
                    }
                } catch {
                    switch error {
                    case let error as Error:
                        emitWarning(error)
                    default:
                        throw error
                    }
                }
            }
        }
    }
    
    private func decodeOperandsString(_ operands: [UInt64]) throws -> String {
        var data = Data()
        for o in operands {
            data.append(try castToUInt8(o))
        }
        guard let string = String(data: data, encoding: .utf8) else {
            throw error(.utf8DecodeFailed)
        }
        return string
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
    
    private func trace(_ message: String) {
        let indent = String(repeating: "  ", count: stateStack.count - 1)
        let str = indent + message
        print(str)
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
