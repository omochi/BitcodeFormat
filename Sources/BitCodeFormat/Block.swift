import Foundation
import BigInt

public struct Block {
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
    
    public var id: UInt32
    public var abbrevIDWidth: UInt8
    public var length: UInt32
}
