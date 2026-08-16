import Foundation

/// A potential memory entry that has been identified but not yet stored.
/// Used by MemoryFormationService to validate and process candidate memories before storage.
public struct MemoryCandidate: Sendable, Equatable {
    public let content: String
    public let category: MemoryCategory
    public let importance: MemoryImportance
    public let confidence: Double // 0.0 to 1.0, how confident we are this should be stored
    
    public init(
        content: String,
        category: MemoryCategory,
        importance: MemoryImportance,
        confidence: Double
    ) {
        self.content = content
        self.category = category
        self.importance = importance
        self.confidence = confidence
    }
    
    /// Validates that the candidate is worth storing.
    public var isValid: Bool {
        !content.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty &&
        confidence >= 0.5 &&
        confidence <= 1.0
    }
    
    /// Creates a MemoryEntry from this candidate.
    public func toMemoryEntry() -> MemoryEntry {
        MemoryEntry(
            content: content,
            category: category,
            importance: importance
        )
    }
}