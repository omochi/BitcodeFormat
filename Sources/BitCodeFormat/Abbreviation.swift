import Foundation
import BigInt

public enum Abbreviation {
    public enum EndBlock {
        public static let id: UInt32 = 0
    }
    public enum EnterSubBlock {
        public static let id: UInt32 = 1
    }
    public enum UnabbrevRecord {
        public static let id: UInt32 = 3
    }

    // TODO: define abbriv
    
    case endBlock
    case enterSubBlock(Block)
    case record(Record)
}
