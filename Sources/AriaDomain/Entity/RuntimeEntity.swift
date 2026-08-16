import Foundation

/// Represents a runtime entity that can be referenced in conversation.
/// These are short-lived, conversation-scoped entities captured from tool results.
/// Not to be confused with long-term memory - this is purely for reference resolution.
public struct RuntimeEntity: Sendable, Equatable {
    /// Unique identifier for this entity instance
    public let id: UUID
    
    /// Kind of entity (application, file, folder, etc.)
    public let kind: EntityKind
    
    /// Display name for the entity (user-facing)
    public let displayName: String
    
    /// File system path if applicable (for files/folders)
    public let path: String?
    
    /// Application bundle identifier if applicable
    public let applicationIdentifier: String?
    
    /// Position in a result set (for search results)
    public let position: Int?
    
    /// Session ID when this entity was recorded
    public let sessionID: UUID
    
    /// Timestamp when this entity was recorded
    public let timestamp: Date
    
    public init(
        id: UUID = UUID(),
        kind: EntityKind,
        displayName: String,
        path: String? = nil,
        applicationIdentifier: String? = nil,
        position: Int? = nil,
        sessionID: UUID,
        timestamp: Date = Date()
    ) {
        self.id = id
        self.kind = kind
        self.displayName = displayName
        self.path = path
        self.applicationIdentifier = applicationIdentifier
        self.position = position
        self.sessionID = sessionID
        self.timestamp = timestamp
    }
}

/// Kinds of entities that can be tracked for reference resolution.
public enum EntityKind: String, Sendable, Equatable {
    case application
    case file
    case folder
    case searchResult
    case systemInfo
}

/// Result of a reference resolution attempt.
public enum ResolutionResult: Sendable, Equatable {
    /// Successfully resolved to a concrete entity
    case resolved(RuntimeEntity)
    
    /// Reference could not be resolved (no matching entity)
    case unresolved
    
    /// Reference is ambiguous (multiple matching entities)
    case ambiguous([RuntimeEntity])
    
    /// Invalid reference (e.g., "yang ke-5" when only 3 results exist)
    case invalidPosition
}

/// Types of references that can be resolved.
public enum ReferenceType: Sendable, Equatable {
    /// Demonstrative pronouns: "itu", "ini", "tersebut", "tadi"
    case demonstrative
    
    /// Positional references: "yang pertama", "yang kedua", "yang ketiga"
    case positional(Int)
    
    /// Context references: "di situ", "di sana", "foldernya", "filenya", "aplikasinya"
    case context(EntityKind)
    
    /// Unrecognized reference pattern
    case unknown
}
