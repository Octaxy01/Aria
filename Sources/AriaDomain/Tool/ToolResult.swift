import Foundation

/// Represents the result of a tool execution.
/// Distinguishes between successful execution and failures with structured error information.
public struct ToolResult: Sendable, Equatable {
    /// Whether the tool execution succeeded.
    public let success: Bool
    
    /// Structured output data from successful execution.
    /// The format depends on the specific tool - this is generic to allow flexibility.
    public let data: [String: Sendable]?
    
    /// Human-readable error message if execution failed.
    public let error: String?
    
    /// Optional machine-readable error code for programmatic handling.
    public let errorCode: String?
    
    private init(success: Bool, data: [String: Sendable]?, error: String?, errorCode: String?) {
        self.success = success
        self.data = data
        self.error = error
        self.errorCode = errorCode
    }
    
    /// Creates a successful tool result with output data.
    public static func success(_ data: [String: Sendable] = [:]) -> ToolResult {
        ToolResult(success: true, data: data, error: nil, errorCode: nil)
    }
    
    /// Creates a failed tool result with error information.
    public static func failure(_ error: String, errorCode: String? = nil) -> ToolResult {
        ToolResult(success: false, data: nil, error: error, errorCode: errorCode)
    }
    
    /// Creates a result indicating the tool was cancelled.
    public static func cancelled() -> ToolResult {
        ToolResult(success: false, data: nil, error: "Tool execution was cancelled", errorCode: "cancelled")
    }
    
    /// Creates a result indicating the session was stale.
    public static func staleSession() -> ToolResult {
        ToolResult(success: false, data: nil, error: "Tool execution cancelled due to stale session", errorCode: "stale_session")
    }
    
    /// Custom equality implementation.
    /// Data dictionary is compared by count only due to Sendable type limitations.
    public static func == (lhs: ToolResult, rhs: ToolResult) -> Bool {
        lhs.success == rhs.success &&
        lhs.error == rhs.error &&
        lhs.errorCode == rhs.errorCode &&
        lhs.data?.count == rhs.data?.count
    }
}