import Foundation
import AriaDomain

/// Represents a single desktop intent entry in the history.
public struct IntentHistoryEntry: Sendable, Equatable {
    /// The intent that was executed
    public let intent: String
    
    /// The tool identifier if applicable
    public let toolIdentifier: ToolIdentifier?
    
    /// Whether the intent succeeded or failed
    public let success: Bool
    
    /// When the intent was recorded
    public let timestamp: Date
    
    /// The session ID for this intent
    public let sessionID: UUID
    
    public init(
        intent: String,
        toolIdentifier: ToolIdentifier? = nil,
        success: Bool,
        timestamp: Date = Date(),
        sessionID: UUID
    ) {
        self.intent = intent
        self.toolIdentifier = toolIdentifier
        self.success = success
        self.timestamp = timestamp
        self.sessionID = sessionID
    }
}

/// Bounded runtime-only intent history.
/// Session-scoped, limited to 10 entries, not persisted.
/// Used for short-term conversational continuity and debugging.
public actor IntentHistory {
    private var entries: [IntentHistoryEntry] = []
    private let maxEntries: Int = 10
    private var currentSessionID: UUID?
    
    public init() {}
    
    /// Sets the current session ID.
    /// - Parameter sessionID: The current session ID
    public func setSessionID(_ sessionID: UUID) {
        self.currentSessionID = sessionID
    }
    
    /// Records an intent in the history.
    /// - Parameters:
    ///   - intent: The intent to record
    ///   - toolIdentifier: The tool identifier if applicable
    ///   - success: Whether the intent succeeded
    public func record(
        intent: String,
        toolIdentifier: ToolIdentifier? = nil,
        success: Bool
    ) {
        guard let sessionID = currentSessionID else {
            return
        }
        
        let entry = IntentHistoryEntry(
            intent: intent,
            toolIdentifier: toolIdentifier,
            success: success,
            timestamp: Date(),
            sessionID: sessionID
        )
        
        entries.append(entry)
        
        // Enforce maximum size
        if entries.count > maxEntries {
            entries.removeFirst()
        }
    }
    
    /// Returns all entries for the current session.
    /// - Returns: Array of intent history entries
    public func getEntries() -> [IntentHistoryEntry] {
        guard let sessionID = currentSessionID else {
            return []
        }
        
        return entries.filter { $0.sessionID == sessionID }
    }
    
    /// Returns the most recent entry for the current session.
    /// - Returns: The most recent entry, or nil if none exists
    public func getLatest() -> IntentHistoryEntry? {
        let sessionEntries = getEntries()
        return sessionEntries.last
    }
    
    /// Clears all history entries.
    public func clear() {
        entries.removeAll()
    }
    
    /// Clears entries for a specific session.
    /// - Parameter sessionID: The session ID to clear
    public func clear(sessionID: UUID) {
        entries.removeAll { $0.sessionID == sessionID }
    }
    
    /// Returns the count of entries for the current session.
    /// - Returns: The number of entries
    public func count() -> Int {
        guard let sessionID = currentSessionID else {
            return 0
        }
        
        return entries.filter { $0.sessionID == sessionID }.count
    }
}
