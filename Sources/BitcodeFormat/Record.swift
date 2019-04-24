import Foundation

public final class Record {
    public indirect enum Value {
        public enum Case : String {
            case value
            case array
            case blob
        }
        
        case value(UInt64)
        case array([Value])
        case blob(Data)
        
        public var `case`: Case {
            switch self {
            case .value: return .value
            case .array: return .array
            case .blob: return .blob
            }
        }
        
        public var value: UInt64? {
            guard case .value(let x) = self else {
                return nil
            }
            return x
        }
        
        public var array: [Value]? {
            guard case .array(let a) = self else {
                return nil
            }
            return a
        }
        
        public var blob: Data? {
            guard case .blob(let data) = self else {
                return nil
            }
            return data
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
    
    public var name: String {
        func _name() -> String? {
            guard let block = self.block,
                let document = block.document else
            {
                return nil
            }
            
            return document.blockInfos.items[block.id]?.recordInfos.items[code]?.name
        }
        
        return (_name() ?? "") + "#\(code)"
    }
    
    public var array: [Value]? {
        return values.last?.array
    }
    
    public var blob: Data? {
        return values.last?.blob
    }
}

extension Record : CustomDebugStringConvertible {
    public var debugDescription: String {
        return name
    }
}

extension Record : CustomReflectable {
    public var customMirror: Mirror {
        return Mirror(self, children: [
            "abbrevID": abbrevID,
            "values": values
            ])
    }
}

extension Record.Value : CustomDebugStringConvertible {
    public var debugDescription: String {
        switch self {
        case .value(let x): return "\(x)"
        case .array(let array): return array.debugDescription
        case .blob(let data): return "blob \(data.count) bytes"
        }
    }
}

extension Record.Value : CustomReflectable {
    public var customMirror: Mirror {
        switch self {
        case .value:
            return Mirror(self, children: [])
        case .array(let array):
            return Mirror(reflecting: array)
        case .blob:
            return Mirror(self, children: [])
        }
    }
}
