import Foundation

public final class Document : CopyInitializable {
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
    
    public var data: Data
    public var magicNumber: UInt32
    public var blockInfos: BlockInfos
    public var blocks: [Block]
    
    public init(data: Data,
                magicNumber: UInt32,
                blockInfos: BlockInfos = BlockInfos(),
                blocks: [Block] = [])
    {
        self.data = data
        self.magicNumber = magicNumber
        self.blockInfos = blockInfos
        self.blocks = blocks
    }
    
    public convenience init(file: URL) throws {
        let reader = try Reader(file: file)
        let doc = try reader.read()
        self.init(copy: doc)
    }
}
