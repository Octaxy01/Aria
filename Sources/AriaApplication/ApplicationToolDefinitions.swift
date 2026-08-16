import Foundation
import AriaDomain

/// Definitions for application control tools.
/// These tools allow Aria to safely control macOS applications using native APIs.
public enum ApplicationToolDefinitions {
    
    /// Tool definition for opening an installed macOS application.
    public static var openApplication: ToolDefinition {
        ToolDefinition(
            identifier: .openApplication,
            description: "Open an installed macOS application by name",
            riskLevel: .safe,
            parameters: [
                ToolParameter(
                    name: "applicationName",
                    description: "The name of the application to open (e.g., 'Google Chrome', 'Spotify', 'VS Code')",
                    isRequired: true,
                    type: .string
                )
            ],
            requiresConfirmation: false,
            category: .application
        )
    }
    
    /// Tool definition for quitting a running macOS application.
    public static var quitApplication: ToolDefinition {
        ToolDefinition(
            identifier: .quitApplication,
            description: "Quit a running macOS application by name",
            riskLevel: .safe,
            parameters: [
                ToolParameter(
                    name: "applicationName",
                    description: "The name of the application to quit (e.g., 'Google Chrome', 'Spotify', 'VS Code')",
                    isRequired: true,
                    type: .string
                )
            ],
            requiresConfirmation: false,
            category: .application
        )
    }
    
    /// Tool definition for focusing/activating a running macOS application.
    public static var focusApplication: ToolDefinition {
        ToolDefinition(
            identifier: .focusApplication,
            description: "Bring a running macOS application to the foreground by name",
            riskLevel: .safe,
            parameters: [
                ToolParameter(
                    name: "applicationName",
                    description: "The name of the application to focus (e.g., 'Google Chrome', 'Spotify', 'VS Code')",
                    isRequired: true,
                    type: .string
                )
            ],
            requiresConfirmation: false,
            category: .application
        )
    }
    
    /// Returns all application tool definitions.
    public static var all: [ToolDefinition] {
        [
            openApplication,
            quitApplication,
            focusApplication
        ]
    }
}