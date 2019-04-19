import Foundation

public struct Record {
    public indirect enum Value {
        public enum Kind : String {
            case value
            case array
            case blob
        }
        
        case value(UInt64)
        case array([Value])
        case blob(Data)
        
        public var kind: Kind {
            switch self {
            case .value: return .value
            case .array: return .array
            case .blob: return .blob
            }
        }
    }
    
    public var code: UInt32
    public var values: [Value]
}
