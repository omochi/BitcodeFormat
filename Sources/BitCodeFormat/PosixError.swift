import Foundation

public struct PosixError : ErrorBase {
    public var code: Int32
    public init(code: Int32) {
        self.code = code
    }
    public var description: String {
        let str = PosixError.string(fromCode: code)
        return String(format: "%@(%d)", str, code)
    }
    public static var current: PosixError {
        return PosixError(code: Darwin.errno)
    }    
    public static func string(fromCode code: Int32) -> String {
        let cstr: UnsafeMutablePointer<CChar> = strerror(code)
        return String(cString: cstr)
    }
}
