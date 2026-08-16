import Foundation
import AriaDomain

/// Definitions for filesystem tools.
/// These tools allow Aria to safely access filesystem operations using native macOS APIs.
public enum FileSystemToolDefinitions {
    
    /// Tool definition for opening an existing file with its associated macOS application.
    public static var openFile: ToolDefinition {
        ToolDefinition(
            identifier: .openFile,
            description: "Open an existing file with its associated macOS application",
            riskLevel: .safe,
            parameters: [
                ToolParameter(
                    name: "path",
                    description: "The absolute path to the file to open (e.g., '/Users/username/Documents/file.pdf' or '~/Documents/file.pdf')",
                    isRequired: true,
                    type: .string
                )
            ],
            requiresConfirmation: false,
            category: .file
        )
    }
    
    /// Tool definition for opening an existing folder in Finder.
    public static var openFolder: ToolDefinition {
        ToolDefinition(
            identifier: .openFolder,
            description: "Open an existing folder in Finder",
            riskLevel: .safe,
            parameters: [
                ToolParameter(
                    name: "path",
                    description: "The absolute path to the folder to open (e.g., '/Users/username/Documents' or '~/Documents')",
                    isRequired: true,
                    type: .string
                )
            ],
            requiresConfirmation: false,
            category: .file
        )
    }
    
    /// Tool definition for finding files matching a search query within an allowed search scope.
    public static var findFile: ToolDefinition {
        ToolDefinition(
            identifier: .findFile,
            description: "Find files matching a search query within the user's home directory",
            riskLevel: .sensitive,
            parameters: [
                ToolParameter(
                    name: "query",
                    description: "The search query to match against file names (case-insensitive)",
                    isRequired: true,
                    type: .string
                ),
                ToolParameter(
                    name: "searchScope",
                    description: "The directory scope to search within (defaults to home directory if not specified)",
                    isRequired: false,
                    type: .string
                )
            ],
            requiresConfirmation: false,
            category: .file
        )
    }
    
    /// Returns all filesystem tool definitions.
    public static var all: [ToolDefinition] {
        [
            openFile,
            openFolder,
            findFile
        ]
    }
}