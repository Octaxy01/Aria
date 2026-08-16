import Foundation

/// A single memory entry about the user or conversation context.
/// Distinct from conversation history - this is for long-term facts
/// and preferences that should persist across sessions.
public struct MemoryEntry: Sendable, Codable, Equatable, Identifiable {
    public let id: UUID
    public let content: String
    public let category: MemoryCategory
    public let importance: MemoryImportance
    public let createdAt: Date
    public let lastAccessed: Date

    public init(
        id: UUID = UUID(),
        content: String,
        category: MemoryCategory = .general,
        importance: MemoryImportance = .normal,
        createdAt: Date = Date(),
        lastAccessed: Date = Date()
    ) {
        self.id = id
        self.content = content
        self.category = category
        self.importance = importance
        self.createdAt = createdAt
        self.lastAccessed = lastAccessed
    }
}

/// High-level categorization for memory entries.
public enum MemoryCategory: String, Sendable, Codable, Equatable, CaseIterable {
    case general
    case preference
    case fact
    case relationship
    case context
}

/// How important a memory is for retrieval and retention decisions.
public enum MemoryImportance: String, Sendable, Codable, Equatable, CaseIterable {
    case low
    case normal
    case high
    case critical
}
