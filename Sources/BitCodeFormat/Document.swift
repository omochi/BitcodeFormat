import Foundation

public final class Document {
    public struct AbbrevDefinitions {
        public var items: [(UInt32, DefineAbbrev)]
        public init() {
            self.items = []
        }
        
        public var nextID: UInt32 {
            return items.map { $0.0 }.max().map { $0 + 1 } ?? 4
        }
        
        public func get(for id: UInt32) -> DefineAbbrev? {
            return items.first { $0.0 == id }.map { $0.1 }
        }
        
        public mutating func add(_ define: DefineAbbrev) {
            let id = nextID
            items.append((id, define))
        }
    }
    
    public struct RecordInfo : Modifiable {
        public var name: String?
        
        public init(name: String? = nil) {
            self.name = name
        }
    }
    
    public struct RecordInfos {
        public var items: [UInt32: RecordInfo]
        
        public init() {
            self.items = [:]
        }
    }
    
    public struct BlockInfo : Modifiable {
        public var name: String?
        public var recordInfos: RecordInfos
        public var abbrevDefinitions: AbbrevDefinitions
        
        public init(name: String? = nil,
                    recordInfos: RecordInfos = RecordInfos(),
                    abbrevDefinitions: AbbrevDefinitions = AbbrevDefinitions())
        {
            self.name = name
            self.recordInfos = recordInfos
            self.abbrevDefinitions = abbrevDefinitions
        }
    }
    
    public struct BlockInfos {
        public var items: [UInt32: BlockInfo] = [:]
        
        public init() {
            self.items = [:]
        }
    }
    
    public var magicNumber: UInt32
    public var blockInfos: BlockInfos
    public var blocks: [Block]
    
    public init(magicNumber: UInt32,
                blockInfos: BlockInfos = BlockInfos(),
                blocks: [Block] = [])
    {
        self.magicNumber = magicNumber
        self.blockInfos = blockInfos
        self.blocks = blocks
    }
    
    public func blockName(id: UInt32) -> String {
        if id == 0 {
            return "BLOCKINFO"
        }
        return blockInfos.items[id]?.name ?? ""
    }
    
    public func debugBlockName(id: UInt32) -> String {
        return blockName(id: id) + "#\(id)"
    }
    
    public func recordName(id: UInt32, blockID: UInt32) -> String {
        return blockInfos.items[id]?.recordInfos.items[id]?.name ?? ""
    }
    
    public func debugRecordName(id: UInt32, blockID: UInt32) -> String {
        return recordName(id: id, blockID: blockID) + "#\(id)"
    }
}
