import Foundation

/// Structured interpretation of a tool execution result.
/// Provides semantic meaning extracted from raw tool results for natural response generation.
public struct ToolResultInterpretation: Sendable {
    
    /// Whether the tool execution succeeded.
    public let success: Bool
    
    /// Natural language summary of the result (Indonesian).
    /// This is the primary text that will be used for response generation.
    public let summary: String
    
    /// Detailed information about the result.
    /// Contains structured data that may be useful for follow-up context.
    public let details: [String: Sendable]?
    
    /// Entities extracted from the result for reference resolution.
    /// These are preserved for Phase 7.1 entity context.
    public let entities: [RuntimeEntity]?
    
    /// Error category if the tool failed.
    public let errorCategory: ToolErrorCategory?
    
    /// Whether this result should be displayed to the user.
    /// Some results (like internal system checks) may be hidden.
    public let displayToUser: Bool
    
    public init(
        success: Bool,
        summary: String,
        details: [String: Sendable]? = nil,
        entities: [RuntimeEntity]? = nil,
        errorCategory: ToolErrorCategory? = nil,
        displayToUser: Bool = true
    ) {
        self.success = success
        self.summary = summary
        self.details = details
        self.entities = entities
        self.errorCategory = errorCategory
        self.displayToUser = displayToUser
    }
    
    /// Creates a successful interpretation.
    public static func success(
        summary: String,
        details: [String: Sendable]? = nil,
        entities: [RuntimeEntity]? = nil
    ) -> ToolResultInterpretation {
        ToolResultInterpretation(
            success: true,
            summary: summary,
            details: details,
            entities: entities,
            errorCategory: nil,
            displayToUser: true
        )
    }
    
    /// Creates a failed interpretation.
    public static func failure(
        summary: String,
        errorCategory: ToolErrorCategory? = nil,
        details: [String: Sendable]? = nil
    ) -> ToolResultInterpretation {
        ToolResultInterpretation(
            success: false,
            summary: summary,
            details: details,
            entities: nil,
            errorCategory: errorCategory,
            displayToUser: true
        )
    }
    
    /// Creates a cancelled interpretation.
    public static func cancelled(summary: String = "Operasi dibatalkan.") -> ToolResultInterpretation {
        ToolResultInterpretation(
            success: false,
            summary: summary,
            details: nil,
            entities: nil,
            errorCategory: .cancelled,
            displayToUser: true
        )
    }
    
    /// Creates an internal result that should not be displayed to the user.
    public static func internalOnly(
        success: Bool,
        details: [String: Sendable]? = nil
    ) -> ToolResultInterpretation {
        ToolResultInterpretation(
            success: success,
            summary: "",
            details: details,
            entities: nil,
            errorCategory: nil,
            displayToUser: false
        )
    }
}

/// Categories of tool execution errors for structured failure handling.
public enum ToolErrorCategory: String, Sendable, Equatable {
    /// The requested resource (application, file, etc.) was not found.
    case notFound
    
    /// The resource or operation is unavailable.
    case unavailable
    
    /// Permission was denied for the operation.
    case permissionDenied
    
    /// The provided arguments were invalid.
    case invalidArguments
    
    /// The operation was cancelled by the user or system.
    case cancelled
    
    /// The operation failed for an execution-specific reason.
    case executionFailed
    
    /// The session was stale or expired.
    case staleSession
}
