import Foundation

/// Represents the current desktop task context for multi-turn conversations.
/// This is conversation-scoped, short-lived context that answers "What is the user currently doing?"
/// Separate from RuntimeEntityContext (which answers "What entities were recently mentioned?")
/// and MemoryService (which is long-term memory).
public struct DesktopTaskContext: Sendable {
    
    /// Unique identifier for this task context instance
    public let id: UUID
    
    /// Session ID when this task was created
    public let sessionID: UUID
    
    /// Kind of desktop task
    public let taskKind: TaskKind
    
    /// Kind of entity this task targets (if applicable)
    public let targetEntityKind: EntityKind?
    
    /// Scope of the task (e.g., "Downloads" for file search)
    public let scope: String?
    
    /// Ordered results from this task (e.g., search results)
    public let recentResults: [TaskResult]
    
    /// Timestamp when this task was created
    public let createdAt: Date
    
    /// Timestamp when this task was last updated
    public let updatedAt: Date
    
    public init(
        id: UUID = UUID(),
        sessionID: UUID,
        taskKind: TaskKind,
        targetEntityKind: EntityKind? = nil,
        scope: String? = nil,
        recentResults: [TaskResult] = [],
        createdAt: Date = Date(),
        updatedAt: Date = Date()
    ) {
        self.id = id
        self.sessionID = sessionID
        self.taskKind = taskKind
        self.targetEntityKind = targetEntityKind
        self.scope = scope
        self.recentResults = recentResults
        self.createdAt = createdAt
        self.updatedAt = updatedAt
    }
    
    /// Creates an updated copy with new results and updated timestamp
    public func withUpdatedResults(_ results: [TaskResult]) -> DesktopTaskContext {
        DesktopTaskContext(
            id: id,
            sessionID: sessionID,
            taskKind: taskKind,
            targetEntityKind: targetEntityKind,
            scope: scope,
            recentResults: results,
            createdAt: createdAt,
            updatedAt: Date()
        )
    }
}

/// Kinds of desktop tasks that can be tracked.
public enum TaskKind: String, Sendable {
    case applicationInteraction
    case fileSearch
    case fileInteraction
    case folderInteraction
    case systemQuery
}

/// A result within a task context (e.g., a search result).
public struct TaskResult: Sendable {
    /// Display name for this result
    public let displayName: String
    
    /// Path if applicable (for files/folders)
    public let path: String?
    
    /// Application identifier if applicable
    public let applicationIdentifier: String?
    
    /// Modification date for recency ordering (if available)
    public let modificationDate: Date?
    
    /// Position in the result set
    public let position: Int?
    
    public init(
        displayName: String,
        path: String? = nil,
        applicationIdentifier: String? = nil,
        modificationDate: Date? = nil,
        position: Int? = nil
    ) {
        self.displayName = displayName
        self.path = path
        self.applicationIdentifier = applicationIdentifier
        self.modificationDate = modificationDate
        self.position = position
    }
}
