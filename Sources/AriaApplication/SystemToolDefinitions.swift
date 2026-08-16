import Foundation
import AriaDomain

/// Definitions for system information tools.
/// These tools allow Aria to safely access read-only macOS system information using native APIs.
public enum SystemToolDefinitions {
    
    /// Tool definition for getting basic system information.
    public static var getSystemInfo: ToolDefinition {
        ToolDefinition(
            identifier: .getSystemInfo,
            description: "Get basic information about the Mac and macOS system",
            riskLevel: .safe,
            parameters: [],
            requiresConfirmation: false,
            category: .system
        )
    }
    
    /// Tool definition for getting battery status.
    public static var getBatteryStatus: ToolDefinition {
        ToolDefinition(
            identifier: .getBatteryStatus,
            description: "Get the current Mac battery status",
            riskLevel: .safe,
            parameters: [],
            requiresConfirmation: false,
            category: .system
        )
    }
    
    /// Tool definition for getting storage information.
    public static var getStorageInfo: ToolDefinition {
        ToolDefinition(
            identifier: .getStorageInfo,
            description: "Get storage information for the Mac",
            riskLevel: .safe,
            parameters: [],
            requiresConfirmation: false,
            category: .system
        )
    }
    
    /// Returns all system tool definitions.
    public static var all: [ToolDefinition] {
        [
            getSystemInfo,
            getBatteryStatus,
            getStorageInfo
        ]
    }
}
