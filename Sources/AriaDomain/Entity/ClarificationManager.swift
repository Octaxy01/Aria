import Foundation

/// Manages pending clarification requests for ambiguous references.
/// This actor ensures thread-safe access to clarification state with session isolation.
public actor ClarificationManager {
    
    /// Current pending clarification request (if any)
    private var pendingClarification: ClarificationRequest?
    
    /// Current session ID for validation
    private var currentSessionID: UUID?
    
    public init() {}
    
    /// Sets the current session ID for clarification state.
    /// - Parameter sessionID: The session ID to set
    public func setSessionID(_ sessionID: UUID) {
        currentSessionID = sessionID
    }
    
    /// Stores a pending clarification request.
    /// - Parameter clarification: The clarification request to store
    /// - Parameter sessionID: The session ID for validation
    public func storeClarification(_ clarification: ClarificationRequest, sessionID: UUID) {
        // Validate session
        guard currentSessionID == sessionID else {
            return
        }
        
        pendingClarification = clarification
    }
    
    /// Retrieves the current pending clarification request.
    /// - Parameter sessionID: The session ID for validation
    /// - Returns: The pending clarification request, or nil if none exists or session mismatch
    public func getPendingClarification(sessionID: UUID) -> ClarificationRequest? {
        guard currentSessionID == sessionID else {
            return nil
        }
        
        return pendingClarification
    }
    
    /// Clears the current pending clarification request.
    /// - Parameter sessionID: The session ID for validation
    public func clearClarification(sessionID: UUID) {
        guard currentSessionID == sessionID else {
            return
        }
        
        pendingClarification = nil
    }
    
    /// Clears all clarification state (for stop/clear commands).
    public func clearAll() {
        pendingClarification = nil
    }
    
    /// Checks if there is a pending clarification for the given session.
    /// - Parameter sessionID: The session ID to check
    /// - Returns: True if there is a pending clarification
    public func hasPendingClarification(sessionID: UUID) -> Bool {
        guard currentSessionID == sessionID else {
            return false
        }
        
        return pendingClarification != nil
    }
}
