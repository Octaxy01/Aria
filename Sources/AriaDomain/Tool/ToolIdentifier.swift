import Foundation

/// Stable, type-safe identifier for tools.
/// Ensures deterministic tool identity without stringly-typed dispatch.
public struct ToolIdentifier: Sendable, Hashable, Equatable {
    public let rawValue: String
    
    /// Creates a tool identifier from a stable string name.
    /// Tool identifiers should be lowercase with underscores, e.g., "open_application".
    public init(_ rawValue: String) {
        self.rawValue = rawValue
    }
    
    /// Validates that the identifier follows tool naming conventions.
    /// Conventions: lowercase, underscores only, no spaces or special characters.
    public var isValid: Bool {
        let pattern = "^[a-z][a-z0-9_]*$"
        return rawValue.range(of: pattern, options: .regularExpression) != nil
    }
}

// MARK: - Common Tool Identifiers

extension ToolIdentifier {
    /// Example identifiers for future tool implementations.
    /// These are not implemented yet - they demonstrate the naming convention.
    
    public static let openApplication = ToolIdentifier("open_application")
    public static let quitApplication = ToolIdentifier("quit_application")
    public static let focusApplication = ToolIdentifier("focus_application")
    public static let openFile = ToolIdentifier("open_file")
    public static let openFolder = ToolIdentifier("open_folder")
    public static let findFile = ToolIdentifier("find_file")
    public static let getSystemInfo = ToolIdentifier("get_system_info")
    public static let getBatteryStatus = ToolIdentifier("get_battery_status")
    public static let getStorageInfo = ToolIdentifier("get_storage_info")
}