import Foundation
import AriaDomain

/// Sendable wrapper for file search results.
public struct FileSearchResult: Sendable {
    public let path: String
    public let fileName: String
    public let isDirectory: Bool
    
    public init(path: String, fileName: String, isDirectory: Bool) {
        self.path = path
        self.fileName = fileName
        self.isDirectory = isDirectory
    }
}

/// Sendable wrapper for file search response.
public struct FileSearchResponse: Sendable {
    public let results: [FileSearchResult]
    public let truncated: Bool
    public let totalCount: Int
    
    public init(results: [FileSearchResult], truncated: Bool, totalCount: Int) {
        self.results = results
        self.truncated = truncated
        self.totalCount = totalCount
    }
}

/// Protocol for searching files in the filesystem.
/// This abstraction allows for testing with mock implementations.
public protocol FileSearching: Sendable {
    /// Searches for files matching a query within a scope.
    /// - Parameters:
    ///   - query: The search query (case-insensitive filename matching)
    ///   - searchScope: The directory to search within (defaults to home directory)
    ///   - maxResults: Maximum number of results to return
    /// - Returns: File search response with results and truncation info
    func searchFiles(query: String, searchScope: String?, maxResults: Int) async throws -> FileSearchResponse
}

/// Mock implementation for testing.
public actor MockFileSearchService: FileSearching {
    private var searchResults: [String: [FileSearchResult]] = [:]
    
    public init() {}
    
    public func setSearchResults(_ query: String, results: [FileSearchResult]) {
        searchResults[query] = results
    }
    
    public func searchFiles(query: String, searchScope: String?, maxResults: Int) async throws -> FileSearchResponse {
        let results = searchResults[query] ?? []
        let truncated = results.count > maxResults
        let limitedResults = Array(results.prefix(maxResults))
        return FileSearchResponse(results: limitedResults, truncated: truncated, totalCount: results.count)
    }
}

/// Native macOS implementation of file search using FileManager.
public actor NativeFileSearchService: FileSearching {
    
    private let fileManager: FileManager
    private let defaultMaxResults = 20
    
    public init(fileManager: FileManager = .default) {
        self.fileManager = fileManager
    }
    
    public func searchFiles(query: String, searchScope: String?, maxResults: Int) async throws -> FileSearchResponse {
        // Check for cancellation
        try Task.checkCancellation()
        
        // Validate query
        guard !query.isEmpty else {
            throw FileSearchError.invalidQuery("Query cannot be empty")
        }
        
        // Validate maxResults is reasonable
        guard maxResults > 0 && maxResults <= 1000 else {
            throw FileSearchError.invalidQuery("Max results must be between 1 and 1000")
        }
        
        // Determine search scope
        let scope = searchScope ?? fileManager.homeDirectoryForCurrentUser.path
        
        // Expand tilde if present in scope
        let expandedScope = (scope as NSString).expandingTildeInPath
        
        // Validate scope exists and is a directory
        guard fileManager.fileExists(atPath: expandedScope) else {
            throw FileSearchError.searchScopeNotFound(expandedScope)
        }
        
        var isDirectory: ObjCBool = false
        fileManager.fileExists(atPath: expandedScope, isDirectory: &isDirectory)
        guard isDirectory.boolValue else {
            throw FileSearchError.invalidSearchScope("Search scope must be a directory")
        }
        
        // Set max results limit (enforce hard limit)
        let limit = min(maxResults, 100)
        
        // Perform search
        var allResults: [FileSearchResult] = []
        let scopeURL = URL(fileURLWithPath: expandedScope)
        
        // Use FileManager directory enumeration
        // Note: FileManager enumerator follows symlinks by default but does not recursively follow symlink loops
        // This is safe for bounded search as the limit and cancellation prevent infinite loops
        if let enumerator = fileManager.enumerator(at: scopeURL, includingPropertiesForKeys: [.isDirectoryKey], options: [.skipsHiddenFiles]) {
            
            while let url = enumerator.nextObject() as? URL {
                // Check for cancellation during enumeration
                try Task.checkCancellation()
                
                // Get resource values
                let resourceValues = try url.resourceValues(forKeys: [URLResourceKey.isDirectoryKey])
                let isDir = resourceValues.isDirectory ?? false
                
                // Check filename match (case-insensitive)
                let fileName = url.lastPathComponent
                if fileName.localizedCaseInsensitiveContains(query) {
                    let result = FileSearchResult(
                        path: url.path,
                        fileName: fileName,
                        isDirectory: isDir
                    )
                    allResults.append(result)
                    
                    // Early exit if we have enough results
                    if allResults.count >= limit * 2 {
                        // Collect a bit more to determine truncation accurately
                        break
                    }
                }
            }
        }
        
        // Sort results by filename for deterministic output
        allResults.sort { $0.fileName.localizedCaseInsensitiveCompare($1.fileName) == .orderedAscending }
        
        // Apply limit
        let truncated = allResults.count > limit
        let limitedResults = Array(allResults.prefix(limit))
        
        return FileSearchResponse(
            results: limitedResults,
            truncated: truncated,
            totalCount: allResults.count
        )
    }
}

/// Error types for file search.
public enum FileSearchError: Error, Equatable {
    case invalidQuery(String)
    case searchScopeNotFound(String)
    case invalidSearchScope(String)
    case permissionDenied(String)
    case cancelled
}