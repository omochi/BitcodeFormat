import Foundation

public enum Resources {
    public enum Error : ErrorBase {
        case noExecutableURL
        
        public var description: String {
            switch self {
            case .noExecutableURL: return "Bundle.main.executableURL is nil"
            }
        }
    }
    
    public static func findResourceDirectory() throws -> URL {
        guard var execFile = Bundle.main.executableURL else {
            throw Error.noExecutableURL
        }
        execFile = try FileSystems.followLink(file: execFile)
        
        func isSwiftPM() -> Bool {
            let pathComponents = execFile.pathComponents
            guard let _ = pathComponents.lastIndex(of: ".build") else {
                return false
            }
            return true
        }
        
        func isXcode() -> Bool {
            // test: DerivedData/.../Build/Products
            var pathComponents = execFile.pathComponents
            guard let index1 = pathComponents.lastIndex(of: "Products") else {
                return false
            }
            pathComponents.removeSubrange(index1...)
            
            guard let index2 = pathComponents.lastIndex(of: "Build"),
                index2 + 1 == index1 else
            {
                return false
            }
            pathComponents.removeSubrange(index2...)
            
            guard let _ = pathComponents.lastIndex(of: "DerivedData") else {
                return false
            }
            
            return true
        }
        
        func isXCTest() -> Bool {
            return execFile.lastPathComponent == "xctest"
        }
        
        
        if isSwiftPM() || isXcode() || isXCTest()
        {
            let repoDir = URL(fileURLWithPath: String(#file))
                .deletingLastPathComponent()
                .deletingLastPathComponent()
                .deletingLastPathComponent()
            return repoDir.appendingPathComponent("Resources")
        }
        
        fatalError("unsupported runtime environment")
    }
}
