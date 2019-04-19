import Foundation

public struct DefineAbbrev {
    public static let id: UInt32 = 2
    
    public enum Fixed {
        public static let code: UInt8 = 1
    }
    public enum VBR {
        public static let code: UInt8 = 2
    }
    public enum Array {
        public static let code: UInt8 = 3
    }
    public enum Char6 {
        public static let code: UInt8 = 4
    }
    public enum Blob {
        public static let code: UInt8 = 5
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
