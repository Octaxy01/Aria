import Foundation

/// Protocol for executing tool calls.
/// Concrete implementations live in the Infrastructure layer and handle actual macOS operations.
/// The Application layer coordinates execution through this protocol.
public protocol ToolExecuting: Sendable {
    /// Executes a tool call with the given session context.
    /// - Parameter call: The tool call to execute
    /// - Returns: Result of the tool execution
    /// - Throws: ToolExecutionError if execution fails
    func execute(_ call: ToolCall) async throws -> ToolResult
}

/// Errors that can occur during tool execution.
public enum ToolExecutionError: Error, Equatable {
    /// The requested tool was not found in the registry.
    case toolNotFound(ToolIdentifier)
    
    /// The tool call failed due to invalid arguments.
    case invalidArguments(String)
    
    /// The tool execution was cancelled.
    case cancelled
    
    /// The tool execution failed due to a stale session.
    case staleSession
    
    /// The tool execution failed for an implementation-specific reason.
    case executionFailed(String)
    
    /// The tool requires permission that was not granted.
    case permissionDenied
}