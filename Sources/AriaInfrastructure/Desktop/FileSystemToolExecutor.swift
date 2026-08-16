import Foundation
import AppKit
import AriaDomain

/// Executor for filesystem tools.
/// Implements safe macOS filesystem operations using native APIs.
public actor FileSystemToolExecutor: ToolExecuting {
    
    private let fileSystemResolver: any FileSystemResolving
    private let fileSearchService: any FileSearching
    
    public init(
        fileSystemResolver: any FileSystemResolving = NativeFileSystemResolver(),
        fileSearchService: any FileSearching = NativeFileSearchService()
    ) {
        self.fileSystemResolver = fileSystemResolver
        self.fileSearchService = fileSearchService
    }
    
    public func execute(_ call: ToolCall) async throws -> ToolResult {
        // Check for cancellation
        try Task.checkCancellation()
        
        // Route to specific tool implementation
        switch call.toolIdentifier {
        case .openFile:
            return try await openFile(from: call)
        case .openFolder:
            return try await openFolder(from: call)
        case .findFile:
            return try await findFile(from: call)
        default:
            throw ToolExecutionError.toolNotFound(call.toolIdentifier)
        }
    }
    
    // MARK: - Open File
    
    private func openFile(from call: ToolCall) async throws -> ToolResult {
        // Check for cancellation
        try Task.checkCancellation()
        
        // Validate arguments
        guard let path = call.arguments["path"] as? String else {
            throw ToolExecutionError.invalidArguments("Missing required parameter: path")
        }
        
        // Validate path is not empty or whitespace-only
        let trimmedPath = path.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !trimmedPath.isEmpty else {
            throw ToolExecutionError.invalidArguments("Path cannot be empty")
        }
        
        // Check for cancellation after validation
        try Task.checkCancellation()
        
        // Resolve and validate path
        guard let target = try await fileSystemResolver.resolvePath(trimmedPath) else {
            return ToolResult.failure("File not found at path: \(trimmedPath)", errorCode: "file_not_found")
        }
        
        // Verify it's a file, not a directory
        if target.isDirectory {
            return ToolResult.failure("Path is a directory, not a file: \(trimmedPath)", errorCode: "wrong_target_type")
        }
        
        // Check for cancellation after resolution
        try Task.checkCancellation()
        
        // Open file using NSWorkspace
        let success = await Task.detached(priority: .userInitiated) {
            NSWorkspace.shared.open(target.url)
        }.value
        
        if success {
            return ToolResult.success([
                "path": target.path,
                "fileName": target.fileName,
                "fileExtension": target.fileExtension ?? "",
                "status": "opened"
            ])
        } else {
            return ToolResult.failure("Failed to open file: \(trimmedPath)", errorCode: "execution_failed")
        }
    }
    
    // MARK: - Open Folder
    
    private func openFolder(from call: ToolCall) async throws -> ToolResult {
        // Check for cancellation
        try Task.checkCancellation()
        
        // Validate arguments
        guard let path = call.arguments["path"] as? String else {
            throw ToolExecutionError.invalidArguments("Missing required parameter: path")
        }
        
        // Validate path is not empty or whitespace-only
        let trimmedPath = path.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !trimmedPath.isEmpty else {
            throw ToolExecutionError.invalidArguments("Path cannot be empty")
        }
        
        // Check for cancellation after validation
        try Task.checkCancellation()
        
        // Resolve and validate path
        guard let target = try await fileSystemResolver.resolvePath(trimmedPath) else {
            return ToolResult.failure("Folder not found at path: \(trimmedPath)", errorCode: "file_not_found")
        }
        
        // Verify it's a directory, not a file
        if !target.isDirectory {
            return ToolResult.failure("Path is a file, not a directory: \(trimmedPath)", errorCode: "wrong_target_type")
        }
        
        // Check for cancellation after resolution
        try Task.checkCancellation()
        
        // Open folder in Finder using NSWorkspace
        let success = await Task.detached(priority: .userInitiated) {
            NSWorkspace.shared.open(target.url)
        }.value
        
        if success {
            return ToolResult.success([
                "path": target.path,
                "fileName": target.fileName,
                "status": "opened"
            ])
        } else {
            return ToolResult.failure("Failed to open folder: \(trimmedPath)", errorCode: "execution_failed")
        }
    }
    
    // MARK: - Find File
    
    private func findFile(from call: ToolCall) async throws -> ToolResult {
        // Check for cancellation
        try Task.checkCancellation()
        
        // Validate arguments
        guard let query = call.arguments["query"] as? String else {
            throw ToolExecutionError.invalidArguments("Missing required parameter: query")
        }
        
        // Validate query is not empty or whitespace-only
        let trimmedQuery = query.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !trimmedQuery.isEmpty else {
            throw ToolExecutionError.invalidArguments("Query cannot be empty")
        }
        
        // Get optional search scope
        let searchScope = call.arguments["searchScope"] as? String
        
        // Validate search scope if provided
        let trimmedScope: String?
        if let scope = searchScope {
            let trimmed = scope.trimmingCharacters(in: .whitespacesAndNewlines)
            guard !trimmed.isEmpty else {
                throw ToolExecutionError.invalidArguments("Search scope cannot be empty")
            }
            trimmedScope = trimmed
        } else {
            trimmedScope = nil
        }
        
        // Check for cancellation after validation
        try Task.checkCancellation()
        
        // Perform search
        let response = try await fileSearchService.searchFiles(
            query: trimmedQuery,
            searchScope: trimmedScope,
            maxResults: 20
        )
        
        // Check for cancellation after search
        try Task.checkCancellation()
        
        // Format results
        let resultsData = response.results.map { result in
            [
                "path": result.path,
                "fileName": result.fileName,
                "isDirectory": result.isDirectory
            ] as [String: Sendable]
        }
        
        return ToolResult.success([
            "query": trimmedQuery,
            "results": resultsData,
            "count": response.results.count,
            "truncated": response.truncated,
            "totalCount": response.totalCount
        ])
    }
}