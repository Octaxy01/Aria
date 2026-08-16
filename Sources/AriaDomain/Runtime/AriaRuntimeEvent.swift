import Foundation

/// Runtime events published by the backend for UI observation.
/// These events represent state changes in the Aria system that the UI may observe.
/// Events carry session identity for stale event protection.
public enum AriaRuntimeEvent: Sendable {
    /// A user request has started processing.
    /// - Parameters:
    ///   - sessionID: The unique identifier for this request session
    case requestStarted(sessionID: UUID)
    
    /// A user request has completed successfully.
    /// - Parameters:
    ///   - sessionID: The unique identifier for this request session
    case requestCompleted(sessionID: UUID)
    
    /// A user request was cancelled.
    /// - Parameters:
    ///   - sessionID: The unique identifier for this request session
    case requestCancelled(sessionID: UUID)
    
    /// A user request failed with an error.
    /// - Parameters:
    ///   - sessionID: The unique identifier for this request session
    ///   - error: The error that caused the failure
    case requestFailed(sessionID: UUID, error: String)
    
    /// The avatar state has changed.
    /// - Parameters:
    ///   - state: The new avatar state
    case avatarStateChanged(state: AvatarState)
    
    /// Audio playback state has changed.
    /// - Parameters:
    ///   - isPlaying: Whether audio is currently playing
    case audioStateChanged(isPlaying: Bool)
    
    /// Mute state has changed.
    /// - Parameters:
    ///   - isMuted: Whether audio is currently muted
    case muteStateChanged(isMuted: Bool)
    
    /// A clarification request is pending user input.
    /// - Parameters:
    ///   - sessionID: The unique identifier for this request session
    ///   - question: The clarification question to display
    ///   - candidates: The candidate entities for selection (if available)
    case clarificationRequested(sessionID: UUID, question: String, candidates: [ClarificationCandidate])
    
    /// A clarification request was resolved.
    /// - Parameters:
    ///   - sessionID: The unique identifier for this request session
    case clarificationResolved(sessionID: UUID)
    
    /// A confirmation request is pending user input.
    /// - Parameters:
    ///   - sessionID: The unique identifier for this request session
    ///   - action: The action description to confirm
    case confirmationRequested(sessionID: UUID, action: String)
    
    /// A confirmation request was resolved.
    /// - Parameters:
    ///   - sessionID: The unique identifier for this request session
    case confirmationResolved(sessionID: UUID)
    
    /// Tool activity has started.
    /// - Parameters:
    ///   - sessionID: The unique identifier for this request session
    ///   - activity: The activity description
    case toolStarted(sessionID: UUID, activity: String)
    
    /// Tool activity has finished.
    /// - Parameters:
    ///   - sessionID: The unique identifier for this request session
    case toolFinished(sessionID: UUID)
    
    /// Tool failure recovery is available.
    /// - Parameters:
    ///   - sessionID: The unique identifier for this request session
    ///   - canRetry: Whether retry is permitted by backend policy
    case recoveryAvailable(sessionID: UUID, canRetry: Bool)
}

/// A candidate entity for clarification selection.
public struct ClarificationCandidate: Sendable, Identifiable {
    public let id: UUID
    public let displayName: String
    public let type: String
    
    public init(id: UUID = UUID(), displayName: String, type: String) {
        self.id = id
        self.displayName = displayName
        self.type = type
    }
}
