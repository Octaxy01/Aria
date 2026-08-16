import Foundation

/// Risk classification for tools to guide permission policies and user confirmation requirements.
/// Higher risk tools require additional safeguards and user consent.
public enum ToolRiskLevel: String, Sendable, Equatable {
    /// Safe operations that cannot cause data loss or system instability.
    /// Examples: opening applications, reading system information, opening folders.
    /// No user confirmation required for these operations.
    case safe
    
    /// Potentially sensitive operations that access user data or system information.
    /// Examples: searching user files, reading arbitrary files, listing directories.
    /// May require user confirmation or scope limiting.
    case sensitive
    
    /// Destructive or high-risk operations that can cause data loss or system changes.
    /// Examples: deleting files, modifying files, terminating processes, arbitrary command execution.
    /// Always requires explicit user confirmation and additional entitlements.
    case destructive
}