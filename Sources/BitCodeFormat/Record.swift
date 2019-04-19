import Foundation

public final class Record {
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

    public weak var block: Block?
    public var abbrevID: UInt32
    public var code: UInt32
    public var values: [Value]
    
    public init(block: Block?,
                abbrevID: UInt32,
                code: UInt32,
                values: [Value])
    {
        self.block = block
        self.abbrevID = abbrevID
        self.code = code
        self.values = values
    }
}

extension Record : CustomReflectable {
    public var customMirror: Mirror {
        return Mirror(
    }
}
