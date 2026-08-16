import Foundation
import AriaDomain
import AriaInfrastructure

/// Manages runtime entity context for reference resolution.
/// This is conversation-scoped, short-lived context that tracks entities from tool results.
/// Not to be confused with long-term memory - this is purely for resolving references like "itu", "yang tadi".
public actor RuntimeEntityContext {
    
    /// Maximum number of recent entities to keep
    private let maxRecentEntities: Int
    
    /// Maximum number of result sets to keep
    private let maxResultSets: Int
    
    /// Current session ID for this context
    private var currentSessionID: UUID?
    
    /// Recent entities in reverse chronological order (newest first)
    private var recentEntities: [RuntimeEntity] = []
    
    /// Ordered result sets from search operations (newest first)
    private var resultSets: [[RuntimeEntity]] = []
    
    /// Current result set being built (for search results)
    private var currentResultSet: [RuntimeEntity] = []
    
    private let logger: any Logging
    
    public init(
        maxRecentEntities: Int = 50,
        maxResultSets: Int = 10,
        logger: any Logging = ConsoleLogger(minimumLevel: .info)
    ) {
        self.maxRecentEntities = maxRecentEntities
        self.maxResultSets = maxResultSets
        self.logger = logger
    }
    
    /// Sets the current session ID for this context.
    /// - Parameter sessionID: The session ID to set
    public func setSessionID(_ sessionID: UUID) {
        currentSessionID = sessionID
        logger.debug("RuntimeEntityContext session ID set to: \(sessionID)")
    }
    
    /// Records a single entity from a tool result.
    /// - Parameter entity: The entity to record
    /// - Parameter sessionID: The session ID for validation
    public func record(_ entity: RuntimeEntity, sessionID: UUID) {
        // Validate session
        guard currentSessionID == sessionID else {
            logger.warning("Attempted to record entity with stale session ID")
            return
        }
        
        // Add to recent entities
        recentEntities.insert(entity, at: 0)
        
        // Trim if exceeding max
        if recentEntities.count > maxRecentEntities {
            recentEntities = Array(recentEntities.prefix(maxRecentEntities))
        }
        
        logger.debug("Recorded entity: \(entity.kind.rawValue) - \(entity.displayName)")
    }
    
    /// Starts recording a new ordered result set (for search results).
    /// - Parameter sessionID: The session ID for validation
    public func startResultSet(sessionID: UUID) {
        // Validate session
        guard currentSessionID == sessionID else {
            logger.warning("Attempted to start result set with stale session ID")
            return
        }
        
        currentResultSet = []
        logger.debug("Started new result set")
    }
    
    /// Records an entity as part of the current result set.
    /// - Parameter entity: The entity to record
    /// - Parameter sessionID: The session ID for validation
    public func recordInResultSet(_ entity: RuntimeEntity, sessionID: UUID) {
        // Validate session
        guard currentSessionID == sessionID else {
            logger.warning("Attempted to record in result set with stale session ID")
            return
        }
        
        currentResultSet.append(entity)
        logger.debug("Recorded in result set: \(entity.kind.rawValue) - \(entity.displayName)")
    }
    
    /// Finalizes the current result set and stores it.
    /// - Parameter sessionID: The session ID for validation
    public func finalizeResultSet(sessionID: UUID) {
        // Validate session
        guard currentSessionID == sessionID else {
            logger.warning("Attempted to finalize result set with stale session ID")
            return
        }
        
        guard !currentResultSet.isEmpty else {
            logger.debug("Result set empty, not storing")
            return
        }
        
        // Store result set
        resultSets.insert(currentResultSet, at: 0)
        
        // Trim if exceeding max
        if resultSets.count > maxResultSets {
            resultSets = Array(resultSets.prefix(maxResultSets))
        }
        
        // Also add all entities to recent entities
        for entity in currentResultSet.reversed() {
            record(entity, sessionID: sessionID)
        }
        
        currentResultSet = []
        logger.debug("Finalized result set with \(resultSets.first?.count ?? 0) entities")
    }
    
    /// Returns the most recent entity of any kind.
    /// - Returns: The most recent entity, or nil if none exist
    public func latest() -> RuntimeEntity? {
        return recentEntities.first
    }
    
    /// Returns the most recent entity of a specific kind.
    /// - Parameter kind: The entity kind to filter by
    /// - Returns: The most recent entity of the specified kind, or nil if none exist
    public func latest(kind: EntityKind) -> RuntimeEntity? {
        return recentEntities.first { $0.kind == kind }
    }
    
    /// Returns an entity at a specific position in the most recent result set.
    /// - Parameter position: The 1-based position (1 = first, 2 = second, etc.)
    /// - Returns: The entity at the specified position, or nil if not found
    public func entity(at position: Int) -> RuntimeEntity? {
        guard let latestSet = resultSets.first else {
            return nil
        }
        
        guard position >= 1 && position <= latestSet.count else {
            return nil
        }
        
        return latestSet[position - 1]
    }
    
    /// Returns all entities of a specific kind.
    /// - Parameter kind: The entity kind to filter by
    /// - Returns: Array of entities of the specified kind
    public func entities(kind: EntityKind) -> [RuntimeEntity] {
        return recentEntities.filter { $0.kind == kind }
    }
    
    /// Returns the most recent result set (for recency resolution).
    /// - Returns: The most recent result set, or nil if none exist
    public func latestResultSet() -> [RuntimeEntity]? {
        return resultSets.first
    }
    
    /// Clears all runtime entity context.
    /// This should be called when conversation is cleared.
    public func clear() {
        recentEntities.removeAll()
        resultSets.removeAll()
        currentResultSet.removeAll()
        logger.debug("Runtime entity context cleared")
    }
    
    /// Clears entities from a specific session (for session safety).
    /// - Parameter sessionID: The session ID to clear
    public func clearSession(_ sessionID: UUID) {
        if currentSessionID == sessionID {
            clear()
        }
    }
}
