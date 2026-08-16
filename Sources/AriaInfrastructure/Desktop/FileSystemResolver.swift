import Foundation
import AppKit
import AriaDomain

/// Sendable wrapper for file system target information.
public struct FileSystemTarget: Sendable {
    public let url: URL
    public let path: String
    public let fileName: String
    public let fileExtension: String?
    public let isDirectory: Bool
    public let exists: Bool
    
    public init(url: URL, path: String, fileName: String, fileExtension: String?, isDirectory: Bool, exists: Bool) {
        self.url = url
        self.path = path
        self.fileName = fileName
        self.fileExtension = fileExtension
        self.isDirectory = isDirectory
        self.exists = exists
    }
}

/// Protocol for resolving and validating filesystem paths.
/// This abstraction allows for testing with mock implementations.
public protocol FileSystemResolving: Sendable {
    /// Resolves and validates a filesystem path.
    /// - Parameter path: The path to resolve and validate
    /// - Returns: The filesystem target information if valid, nil otherwise
    func resolvePath(_ path: String) async throws -> FileSystemTarget?
    
    /// Checks if a path exists.
    /// - Parameter path: The path to check
    /// - Returns: True if the path exists, false otherwise
    func pathExists(_ path: String) async -> Bool
    
    /// Checks if a path is a directory.
    /// - Parameter path: The path to check
    /// - Returns: True if the path is a directory, false otherwise
    func isDirectory(_ path: String) async -> Bool
    
    /// Checks if a path is a file.
    /// - Parameter path: The path to check
    /// - Returns: True if the path is a file, false otherwise
    func isFile(_ path: String) async -> Bool
}

/// Mock implementation for testing.
public actor MockFileSystemResolver: FileSystemResolving {
    private var paths: [String: FileSystemTarget] = [:]
    
    public init() {}
    
    public func setPath(_ path: String, target: FileSystemTarget) {
        paths[path] = target
    }
    
    public func resolvePath(_ path: String) async throws -> FileSystemTarget? {
        return paths[path]
    }
    
    public func pathExists(_ path: String) async -> Bool {
        return paths[path]?.exists ?? false
    }
    
    public func isDirectory(_ path: String) async -> Bool {
        return paths[path]?.isDirectory ?? false
    }
    
    public func isFile(_ path: String) async -> Bool {
        if let target = paths[path] {
            return !target.isDirectory && target.exists
        }
        return false
    }
}

/// Native macOS implementation of filesystem resolution using FileManager.
public actor NativeFileSystemResolver: FileSystemResolving {
    
    private let fileManager: FileManager
    
    public init(fileManager: FileManager = .default) {
        self.fileManager = fileManager
    }
    
    public func resolvePath(_ path: String) async throws -> FileSystemTarget? {
        // Expand tilde if present
        let expandedPath = (path as NSString).expandingTildeInPath
        
        // Validate path is not empty
        guard !expandedPath.isEmpty else {
            return nil
        }
        
        // Create URL from path
        let url = URL(fileURLWithPath: expandedPath)
        
        // Check if path exists
        let exists = fileManager.fileExists(atPath: expandedPath)
        
        guard exists else {
            return nil
        }
        
        // Determine if it's a directory
        var isDirectory: ObjCBool = false
        fileManager.fileExists(atPath: expandedPath, isDirectory: &isDirectory)
        
        // Extract file information
        let fileName = url.lastPathComponent
        let fileExtension = url.pathExtension.isEmpty ? nil : url.pathExtension
        
        return FileSystemTarget(
            url: url,
            path: expandedPath,
            fileName: fileName,
            fileExtension: fileExtension,
            isDirectory: isDirectory.boolValue,
            exists: exists
        )
    }
    
    public func pathExists(_ path: String) async -> Bool {
        let expandedPath = (path as NSString).expandingTildeInPath
        return fileManager.fileExists(atPath: expandedPath)
    }
    
    public func isDirectory(_ path: String) async -> Bool {
        let expandedPath = (path as NSString).expandingTildeInPath
        var isDirectory: ObjCBool = false
        let exists = fileManager.fileExists(atPath: expandedPath, isDirectory: &isDirectory)
        return exists && isDirectory.boolValue
    }
    
    public func isFile(_ path: String) async -> Bool {
        let expandedPath = (path as NSString).expandingTildeInPath
        var isDirectory: ObjCBool = false
        let exists = fileManager.fileExists(atPath: expandedPath, isDirectory: &isDirectory)
        return exists && !isDirectory.boolValue
    }
}

/// Error types for filesystem resolution.
public enum FileSystemResolutionError: Error, Equatable {
    case invalidPath(String)
    case pathNotFound(String)
    case permissionDenied(String)
    case wrongTargetType(String, expected: String)
}