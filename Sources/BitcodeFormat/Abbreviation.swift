import Foundation
import BigInt

public enum Abbreviation {
    public enum ID: UInt32 {
        case endBlock = 0
        case enterSubBlock = 1
        case defineAbbrev = 2
        case unabbrevRecord = 3
    }
    
    case endBlock
    case enterSubBlock(Block)
    case defineAbbrev(DefineAbbrev)
    case unabbrevRecord(Record)
    case definedRecord(Record)
    
    public var record: Record? {
        switch self {
        case .unabbrevRecord(let r),
             .definedRecord(let r): return r
        case .endBlock,
             .enterSubBlock,
             .defineAbbrev:
            return nil
        }
    }
}
