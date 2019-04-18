import Foundation
import BigInt

public enum Abbreviation {
    public enum ID: UInt32 {
        case endBlock = 0
        case enterSubBlock = 1
        case unabbrevRecord = 3
    }
    
    case endBlock
    case enterSubBlock(Block)
//    case endBlock
    case record(Record)
//    case defineAbbrev(DefineAbbrev)
//    case user(User)
    
//    public struct Un
}
