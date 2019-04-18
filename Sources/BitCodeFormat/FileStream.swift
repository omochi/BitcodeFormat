import Foundation

public class FileStream {
    public typealias Handle = UnsafeMutablePointer<FILE>
    public let handle: Handle
    
    public init(handle: Handle) {
        self.handle = handle
    }
    
    public convenience init(file: URL, mode: String) throws {
        let path = file.path
        let handleOrNone: UnsafeMutablePointer<FILE>? =
            path.withCString { (path) in
                mode.withCString { (mode) in
                    Darwin.fopen(path, mode)
                }
        }
        guard let handle = handleOrNone else {
            throw PosixError.current
        }
        self.init(handle: handle)
    }
    
    deinit {
        _ = try? close()
    }
    
    public var isEnd: Bool {
        return Darwin.feof(handle) != 0
    }
    
    public var streamError: PosixError? {
        let code = Darwin.ferror(handle)
        if code == 0 {
            return nil
        }
        return PosixError(code: code)
    }
    
    public func read(size: Int) throws -> Data {
        var buffer = Data(count: size)
        let readSize: Int = buffer.withUnsafeMutableBytes {
            (buffer: UnsafeMutableRawBufferPointer) in
            Darwin.fread(buffer.baseAddress, 1, size, handle)
        }
        if readSize < size, !isEnd, let error = streamError {
            throw error
        }
        buffer.count = readSize
        return buffer
    }
    
    public func seek(position: Int64) throws {
        guard fseeko(handle, position, Darwin.SEEK_SET) == 0 else {
            throw PosixError.current
        }
    }
    
    private func close() throws {
        guard Darwin.fclose(handle) == 0 else {
            throw PosixError.current
        }
    }
}
