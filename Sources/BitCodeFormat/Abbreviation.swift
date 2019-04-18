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
    
    case endBlock
    case enterSubBlock(Block)
//    case endBlock
    case record(Record)
//    case defineAbbrev(DefineAbbrev)
//    case user(User)
    
//    public struct Un
}
