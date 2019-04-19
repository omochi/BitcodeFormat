import Foundation
import BigInt

public final class Block {
    public enum BlockInfo {
        public static let id: UInt32 = 0
        
        public enum SetBID {
            public static let id: UInt32 = 1
        }
        public enum BlockName {
            public static let id: UInt32 = 2
        }
        public enum SetRecordName {
            public static let id: UInt32 = 3
        }
    }
    
    public weak var document: Document?
    public var id: UInt32
    public var abbrevIDWidth: UInt8
    public var length: UInt32
    public var records: [Record]
    public var blocks: [Block]
    
    public init(document: Document?,
                id: UInt32,
                abbrevIDWidth: UInt8,
                length: UInt32)
    {
        self.document = document
        self.id = id
        self.abbrevIDWidth = abbrevIDWidth
        self.length = length
        self.records = []
        self.blocks = []
    }
    
    public var name: String {
        func _name() -> String? {
            guard let document = self.document else {
                return nil
            }
            return document.blockInfos.items[id]?.name
        }
        
        return (_name() ?? "") + "#\(id)"
    }
}
