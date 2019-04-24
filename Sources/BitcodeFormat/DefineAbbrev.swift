import Foundation

public struct DefineAbbrev {
    public enum Code : UInt8 {
        case fixed = 1
        case vbr = 2
        case array = 3
        case char6 = 4
        case blob = 5
    }
    
    public indirect enum Operand {
        case literal(value: UInt64)
        case fixed(width: UInt8)
        case vbr(width: UInt8)
        case array(type: Operand)
        case char6
        case blob
    }
    
    public var operands: [Operand]
}
