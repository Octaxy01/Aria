import Foundation
import AriaDomain

/// Represents a pending tool confirmation awaiting user response.
/// Session-bound and cleared after decision or expiration.
public struct PendingToolConfirmation: Sendable, Equatable {
    /// The session ID for which this confirmation is pending.
    public let sessionID: UUID
    
    /// The tool call awaiting confirmation.
    public let toolCall: ToolCall
    
    /// The tool definition for the pending call.
    public let toolDefinition: ToolDefinition
    
    /// When this confirmation was created.
    public let createdAt: Date
    
    /// User-friendly summary of the action (display-safe).
    public let summary: String
    
    public init(
        sessionID: UUID,
        toolCall: ToolCall,
        toolDefinition: ToolDefinition,
        createdAt: Date = Date(),
        summary: String
    ) {
        self.sessionID = sessionID
        self.toolCall = toolCall
        self.toolDefinition = toolDefinition
        self.createdAt = createdAt
        self.summary = summary
    }
    
    /// Checks if this confirmation is stale for a given session.
    /// - Parameter sessionID: The current session ID
    /// - Returns: True if the confirmation is stale (different session)
    public func isStale(for sessionID: UUID) -> Bool {
        return self.sessionID != sessionID
    }
    
    /// Checks if this confirmation has expired.
    /// - Parameter timeoutSeconds: Timeout in seconds (default: 300 = 5 minutes)
    /// - Returns: True if the confirmation has expired
    public func isExpired(timeoutSeconds: TimeInterval = 300) -> Bool {
        return Date().timeIntervalSince(createdAt) > timeoutSeconds
    }
}
