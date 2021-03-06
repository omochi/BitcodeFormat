import Foundation
import BigInt

public final class Reader {
    public struct Error : ErrorBase {
        public var message: String
        public var position: Position?
        public var blockName: String?
        
        public init(message: String,
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
        
        public init(offset: UInt64 = 0,
                    bitOffset: UInt8 = 0)
        {
            self.offset = offset
            self.bitOffset = bitOffset
        }
        
        public init(bitOffset: UInt64) {
            self.init(offset: bitOffset / 8,
                      bitOffset: UInt8(bitOffset % 8))
        }
        
        public var description: String {
            var str = "\(offset)"
            if bitOffset != 0 {
                str += "#\(bitOffset)"
            }
            return str
        }
    }
    
    public typealias AbbrevDefinitions = Document.AbbrevDefinitions
    public typealias RecordInfo = Document.RecordInfo
    public typealias BlockInfo = Document.BlockInfo
    
    public struct State {
        public var block: Block?
        public var abbrevDefinitions: AbbrevDefinitions
        public var enterPosition: UInt64
        
        public init(block: Block?,
                    abbrevDefinitions: AbbrevDefinitions = AbbrevDefinitions(),
                    enterPosition: UInt64)
        {
            self.block = block
            self.abbrevDefinitions = abbrevDefinitions
            self.enterPosition = enterPosition
        }
    }
    
    public var position: Position
    private var state: State {
        get {
            return stateStack.last!
        }
        set {
            stateStack[stateStack.count - 1] = newValue
        }
    }
    private var stateStack: [State]
    
    private var currentBlock: Block? {
        get {
            return state.block
        }
        set {
            state.block = newValue
        }
    }
    
    public var isTraceEnabled: Bool = false
    private let document: Document
    
    public convenience init(data: Data) {
        self.init(document: Document(data: data,
                                     magicNumber: 0),
                  position: Position())
    }
    
    public convenience init(file: URL) throws {
        let data = try Data(contentsOf: file)
        self.init(data: data)
    }
    
    public convenience init(block: Block) throws
    {
        guard let doc = block.document else {
            throw Error(message: "no document",
                        position: Position(),
                        blockName: nil)
        }
        self.init(document: doc,
                  position: Position())
        self.position = block.position
        try enter(block: block)
        try readBlock(onlyDefines: true)
    }
    
    private init(document: Document,
                 position: Position)
    {
        self.document = document
        self.position = position
        let state = State(block: nil, enterPosition: 0)
        self.stateStack = [state]
    }
    
    public func enter(block: Block) throws {
        guard position.bitOffset == 0 else {
            throw error("invalid enter block position")
        }

        trace("\(block.name) {")
        let blockInfo = document.blockInfos.items[block.id]
        let state = State(block: block,
                          abbrevDefinitions: blockInfo?.abbrevDefinitions ?? AbbrevDefinitions(),
                          enterPosition: self.position.offset)
        pushState(state)
    }
    
    private func pushState(_ state: State) {
        stateStack.append(state)
    }

    public func exitBlock() throws -> Block {
        precondition(stateStack.count >= 2)
        let state = self.state
        let block = state.block!
        stateStack.removeLast()
        trace("} \(block.name)")
        
        guard position.bitOffset == 0 else {
            throw error("invalid exit block position")
        }
        
        guard try state.enterPosition + castToUInt64(block.length) == self.position.offset else {
            throw error("invalid exit block position, enter=\(state.enterPosition), length=\(block.length)")
        }
        
        return block
    }

    public func read() throws -> Document {
        let magicNumber = try readMagicNumber()
        
        document.magicNumber = magicNumber
        
        while !isEnd {
            let abb = try readAbbreviation()
            switch abb {
            case .enterSubBlock(let block):
                if block.id == Block.BLOCKINFO.id {
                    try enter(block: block)
                    try readBlockInfo()
                    let block = try exitBlock()
                    document.blocks.append(block)
                } else {
                    try enter(block: block)
                    try readBlock(onlyDefines: false)
                    let block = try exitBlock()
                    document.blocks.append(block)
                }
            case .endBlock:
                emitWarning("END_BLOCK on top level is ignored")
            case .defineAbbrev:
                emitWarning("DEFINE_ABBREV on top level is ignored")
            case .unabbrevRecord:
                emitWarning("UNABBREV_RECORD on top level is ignored")
            case .definedRecord(let record):
                emitWarning("record(\(record.code)) on top level is ignored")
            }
        }
        
        return document
    }
    
    private func emitWarning(_ message: String) {
        emitWarning(error(message))
    }
    
    private func emitWarning(_ warning: Error) {
        print("[WARN] \(warning)")
    }
    
    private func error(_ message: String,
                       position: Position? = nil) -> Error {
        let blockName = currentBlock.map { $0.name }
        return Error(message: message,
                     position: position ?? self.position,
                     blockName: blockName)
    }
    
    private func readMagicNumber() throws -> UInt32 {
        let bs = try readBits(length: 32)
        return try castToUInt32(bs.asBigUInt)
    }
    
    public func readAbbreviation() throws -> Abbreviation {
        let abbPos = self.position
        let abbLen = castToInt(currentBlock?.abbrevIDWidth ?? 2)
        let abbrevIDValue = try castToUInt32(readBits(length: abbLen).asBigUInt)
        if let abbrevID = Abbreviation.ID(rawValue: abbrevIDValue) {
            switch abbrevID {
            case .endBlock:
                skipToAlignment(32)
                return .endBlock
            case .enterSubBlock:
                let blockID = try castToUInt32(readVBR(width: 8))
                let abbrevLen = try castToUInt8(readVBR(width: 4))
                guard abbrevLen > 0 else {
                    throw error("zero abbrevLen")
                }
                skipToAlignment(32)
                let lengthInWord = try castToInt(try readFixed(width: 32))
                let (length, ovf) = lengthInWord.multipliedReportingOverflow(by: 4)
                if ovf {
                    throw error("invalid length value: \(lengthInWord)")
                }
                let block = Block(document: document,
                                  parent: currentBlock,
                                  id: blockID,
                                  abbrevIDWidth: abbrevLen,
                                  position: self.position,
                                  length: length)
                return .enterSubBlock(block)
            case .defineAbbrev:
                let num = try castToUInt32(readVBR(width: 5))
                guard num >= 1 else {
                    throw error("no operand for DEFINE_ABBREV")
                }
                let numInt = try castToInt(num)
                
                var operands: [DefineAbbrev.Operand] = []
                var count: Int = 0
                while true {
                    let op = try readDefineOperand(count: &count)
                    operands.append(op)
                    if count > numInt {
                        throw error("DEFINE_ABBREV operand count overflow")
                    }
                    if count == numInt {
                        break
                    }
                }
                let defAbb = DefineAbbrev(operands: operands)
                return .defineAbbrev(defAbb)
            case .unabbrevRecord:
                let code = try castToUInt32(readVBR(width: 6))
                let opsNum = try castToUInt32(readVBR(width: 6))
                var values: [Record.Value] = []
                for _ in 0..<opsNum {
                    let op = try castToUInt64(readVBR(width: 6))
                    values.append(.value(op))
                }
                let record = Record(block: currentBlock,
                                    abbrevID: abbrevIDValue,
                                    code: code,
                                    values: values)
                return .unabbrevRecord(record)
                
            }
        }
        
        guard let define = state.abbrevDefinitions.get(for: abbrevIDValue) else {
            throw error("unknown abbrev id: \(abbrevIDValue)",
                position: abbPos)
        }
        var operands = define.operands
        guard operands.count >= 1 else {
            throw error("no operand")
        }
        let value0 = try readValue(for: operands[0])
        guard case .value(let codeValue) = value0 else {
            throw error("code is not primitive: \(value0.case)")
        }
        let code: UInt32 = try castToUInt32(codeValue)
        operands.removeFirst()
        var values: [Record.Value] = []
        for op in operands {
            let v = try readValue(for: op)
            values.append(v)
        }
        let record = Record(block: currentBlock,
                            abbrevID: abbrevIDValue,
                            code: code,
                            values: values)
        return .definedRecord(record)
    }
    
    public func readBlock(onlyDefines: Bool) throws {
        while true {
            let abb = try readAbbreviation()
            
            switch abb {
            case .enterSubBlock(let subBlock):
                if onlyDefines { break }
                try enter(block: subBlock)
                try readBlock(onlyDefines: false)
                let subBlock = try exitBlock()
                currentBlock!.blocks.append(subBlock)
            case .endBlock:
                return
            case .defineAbbrev(let defAbb):
                state.abbrevDefinitions.add(defAbb)
            case .unabbrevRecord(let record):
                if onlyDefines { break }
                trace("\(record.name)")
                currentBlock!.records.append(record)
                break
            case .definedRecord(let record):
                if onlyDefines { break }
                trace("\(record.name)")
                currentBlock!.records.append(record)
                break
            }
        }
    }
    
    private func readBlockInfo() throws {
        var targetBlockID: UInt32?
        
        func modifyBlockInfo(_ f: (inout BlockInfo) -> Void) throws {
            guard let id = targetBlockID else {
                throw error("block id is not specified")
            }
            f(&document.blockInfos.items[id, default: BlockInfo()])
        }
        
        while true {
            let abb = try readAbbreviation()
            
            switch abb {
            case .enterSubBlock(let block):
                emitWarning("ENTER_SUBBLOCK in BLOCKINFO is ignored")
                advancePosition(lengthInBits: try castToUInt64(block.length))
            case .endBlock:
                return
            case .defineAbbrev(let defAbb):
                try modifyBlockInfo { (info) in
                    info.abbrevDefinitions.add(defAbb)
                }
            case .definedRecord(let record):
                emitWarning("Record(\(record.code)) in BLOCKINFO is ignored")
            case .unabbrevRecord(let record):
                do {
                    let values = try record.values.map { try castToPrimitive($0) }
                    guard let code = Block.BLOCKINFO.Code(rawValue: record.code) else {
                         throw error("unknown record code: \(record.code)")
                    }
                    switch code {
                    case .SET_BID:
                        if values.count <= 0 {
                            throw error("invalid operand for SET_BID")
                        }
                        targetBlockID = try castToUInt32(values[0])
                    case .BLOCK_NAME:
                        let name = try decodePrimitivesString(values)
                        try modifyBlockInfo { (info) in
                            info.name = name
                        }
                    case .SET_RECORD_NAME:
                        var values = values
                        if values.count <= 0 {
                            throw error("invalid operand for SET_RECORD_NAME")
                        }
                        let recordID = try castToUInt32(values[0])
                        values.removeFirst()
                        let name = try decodePrimitivesString(values)
                        try modifyBlockInfo { (info) in
                            info.recordInfos.items[recordID, default: RecordInfo()].modify { (info) in
                                info.name = name
                            }
                        }
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
    
    private func readValue(for operand: DefineAbbrev.Operand) throws -> Record.Value {
        switch operand {
        case .literal(value: let value):
            return .value(value)
        case .fixed(width: let width):
            let value = try castToUInt64(readFixed(width: castToInt(width)))
            return .value(value)
        case .vbr(width: let width):
            let value = try castToUInt64(readVBR(width: castToInt(width)))
            return .value(value)
        case .char6:
            let value = try readChar6()
            return .value(castToUInt64(value))
        case .array(type: let type):
            let count = try castToInt(readVBR(width: 6))
            var array: [Record.Value] = []
            for _ in 0..<count {
                let item = try readValue(for: type)
                array.append(item)
            }
            return .array(array)
        case .blob:
            let size = try castToInt(readVBR(width: 6))
            skipToAlignment(32)
            let data = try readBlobData(size: size)
            skipToAlignment(32)
            return .blob(data)
        }
    }
    
    private func readDefineOperand(count: inout Int) throws -> DefineAbbrev.Operand {
        count += 1
        
        let isLiteral = try castToUInt8(readFixed(width: 1)) != 0
        if isLiteral {
            let value = try castToUInt64(readVBR(width: 8))
            return DefineAbbrev.Operand.literal(value: value)
        }
        
        let encodingValue = try castToUInt8(readFixed(width: 3))
        guard let encoding = DefineAbbrev.Code(rawValue: encodingValue) else {
            throw error("unknown operand code: \(encodingValue)")
        }
        switch encoding {
        case .fixed:
            let width = try castToUInt8(readVBR(width: 5))
            return .fixed(width: width)
        case .vbr:
            let width = try castToUInt8(readVBR(width: 5))
            return .vbr(width: width)
        case .array:
            let type = try readDefineOperand(count: &count)
            return .array(type: type)
        case .char6:
            return .char6
        case .blob:
            return .blob
        }
    }
    
    private func decodePrimitivesString(_ operands: [UInt64]) throws -> String {
        var data = Data()
        for o in operands {
            data.append(try castToUInt8(o))
        }
        guard let string = String(data: data, encoding: .utf8) else {
            throw error("UTF-8 decode failed")
        }
        return string
    }
    
    private static let char6Table: [UInt8] = {
        let str: String = [
            "abcdefghijklmnopqrstuvwxyz",
            "ABCDEFGHIJKLMNOPQRSTUVWXYZ",
            "._"
            ].joined()
        let chars: [Character] = str.map { $0 }
        return chars.map { $0.asciiValue! }
    }()
    
    private func readChar6() throws -> UInt8 {
        let value = try castToUInt8(readFixed(width: 6))
        guard value < 64 else {
            throw error("invalid char6: \(value)")
        }
        return Reader.char6Table[castToInt(value)]
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
    
    private func readBlobData(size: Int) throws -> Data {
        precondition(position.bitOffset == 0)
        let data = try _readData(position: position.offset, size: size)
        advancePosition(lengthInBits: try castToUInt64(size) * 8)
        return data
    }
    
    private func skipToAlignment(_ alignment: Int) {
        let bitPosition = position.offset * 8 + UInt64(position.bitOffset)
        let rem = Int(bitPosition % UInt64(alignment))
        if rem == 0 {
            return
        }
        advancePosition(lengthInBits: UInt64(alignment - rem))
    }

    private func readBits(length: Int) throws -> BitBuffer {
        precondition(length > 0)
        let bitOffset = castToInt(position.bitOffset)
        let readSize = (bitOffset + length - 1) / 8 + 1
        let data = try _readData(position: position.offset, size: readSize)
        let bits = BitBuffer(data: data, bitOffset: bitOffset, bitLength: length)
        advancePosition(lengthInBits: try castToUInt64(length))
        return bits
    }
    
    private func advancePosition(lengthInBits: UInt64) {
        position.offset += UInt64(lengthInBits / 8)
        position.bitOffset += UInt8(lengthInBits % 8)
        while position.bitOffset >= 8 {
            position.offset += 1
            position.bitOffset -= 8
        }
    }
    
    private var isEnd: Bool {
        return position.offset >= UInt64(document.data.count)
    }
    
    private func trace(_ message: String) {
        guard isTraceEnabled else {
            return
        }
        let indent = String(repeating: "  ", count: stateStack.count - 1)
        let str = indent + message
        print(str)
    }
    
    private func _readData(position _pos: UInt64, size: Int) throws -> Data {
        let data = document.data
        
        guard let position = Int(exactly: _pos) else {
            throw error("invalid file position: \(_pos)")
        }
        
        let low = data.startIndex + position
        let high = low + size
        
        if high > data.endIndex {
            throw error("reached at end of file")
        }
    
        return data[low..<high]
    }
    
    private func castToUInt8(_ a: UInt64) throws -> UInt8 { return try intCast(a) }
    private func castToUInt8(_ a: BigUInt) throws -> UInt8 { return try intCast(a) }
    private func castToUInt32(_ a: UInt64) throws -> UInt32 { return try intCast(a) }
    private func castToUInt32(_ a: BigUInt) throws -> UInt32 { return try intCast(a) }
    private func castToUInt64(_ a: UInt8) -> UInt64 { return UInt64(a) }
    private func castToUInt64(_ a: UInt32) -> UInt64 { return UInt64(a) }
    private func castToUInt64(_ a: Int) throws -> UInt64 { return try intCast(a) }
    private func castToUInt64(_ a: BigUInt) throws -> UInt64 { return try intCast(a) }
    private func castToInt(_ a: UInt8) -> Int { return Int(a) }
    private func castToInt(_ a: UInt32) throws -> Int { return try intCast(a) }
    private func castToInt(_ a: BigUInt) throws -> Int { return try intCast(a) }
    
    private func intCast<A, R>(_ a: A) throws -> R where A : BinaryInteger, R : BinaryInteger {
        guard let x = R(exactly: a) else {
            throw error("primitive is out of range: \(a)")
        }
        return x
    }
    
    private func castToPrimitive(_ a: Record.Value) throws -> UInt64 {
        guard case .value(let x) = a else {
            throw error("value is not primitive: \(a.case)")
        }
        return x
    }
    
}
