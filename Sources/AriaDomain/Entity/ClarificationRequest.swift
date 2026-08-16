import Foundation

/// Represents a pending clarification request when a reference is ambiguous.
/// This stores the state needed to resolve user clarification and continue the original intent.
public struct ClarificationRequest: Sendable, Equatable {
    /// Unique identifier for this clarification request
    public let id: UUID
    
    /// The original user message that triggered the ambiguity
    public let originalUserMessage: String
    
    /// The candidate entities that are ambiguous
    public let candidates: [RuntimeEntity]
    
    /// The session ID for this clarification
    public let sessionID: UUID
    
    /// The tool call that was being resolved (if applicable)
    public let pendingToolCall: ToolCall?
    
    /// Timestamp when this clarification was requested
    public let timestamp: Date
    
    public init(
        id: UUID = UUID(),
        originalUserMessage: String,
        candidates: [RuntimeEntity],
        sessionID: UUID,
        pendingToolCall: ToolCall? = nil,
        timestamp: Date = Date()
    ) {
        self.id = id
        self.originalUserMessage = originalUserMessage
        self.candidates = candidates
        self.sessionID = sessionID
        self.pendingToolCall = pendingToolCall
        self.timestamp = timestamp
    }
}

/// Result of parsing a user's clarification answer.
public enum ClarificationAnswer: Sendable, Equatable {
    /// User selected a specific entity by name
    case selectedEntity(RuntimeEntity)
    
    /// User selected by position (1-based index)
    case selectedPosition(Int)
    
    /// User provided an invalid or unclear answer
    case invalid
    
    /// User cancelled the clarification
    case cancelled
}
