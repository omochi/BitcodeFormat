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
    public weak var parent: Block?
    public var id: UInt32
    public var abbrevIDWidth: UInt8
    public var position: Reader.Position
    public var length: Int
    public var records: [Record]
    public var blocks: [Block]
   
    
    public init(document: Document?,
                parent: Block?,
                id: UInt32,
                abbrevIDWidth: UInt8,
                position: Reader.Position,
                length: Int)
    {
        self.document = document
        self.parent = parent
        self.id = id
        self.abbrevIDWidth = abbrevIDWidth
        self.position = position
        self.length = length
        self.records = []
        self.blocks = []
    }

    public var name: String {
        func _name() -> String? {
            if id == 0 {
                return "BLOCKINFO"
            }
            
            guard let document = self.document else {
                return nil
            }
            return document.blockInfos.items[id]?.name
        }
        
        return (_name() ?? "") + "#\(id)"
    }
}

extension Block : CustomDebugStringConvertible {
    public var debugDescription: String {
        return name
    }
}

extension Block : CustomReflectable {
    public var customMirror: Mirror {
        return Mirror(self, children: [
            "abbrevIDWidth": abbrevIDWidth,
            "length": length,
            "records": records,
            "blocks": blocks
            ])
    }
}
