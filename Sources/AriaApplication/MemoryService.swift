import Foundation
import AriaDomain

/// Application-layer service for memory operations.
/// Coordinates between Domain memory abstractions and Infrastructure storage.
/// Provides validation and business logic for memory operations.
public actor MemoryService {
    private let store: any MemoryStoring

    public init(store: any MemoryStoring) {
        self.store = store
    }

    /// Store a new memory with validation.
    public func store(content: String, category: MemoryCategory = .general, importance: MemoryImportance = .normal) async throws {
        let trimmedContent = content.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !trimmedContent.isEmpty else {
            throw AriaError.invalidState(reason: "Memory content cannot be empty")
        }

        let entry = MemoryEntry(
            content: trimmedContent,
            category: category,
            importance: importance
        )

        try await store.store(entry)
    }

    /// Retrieve a memory by ID.
    public func retrieve(id: UUID) async throws -> MemoryEntry? {
        return try await store.retrieve(id: id)
    }

    /// Retrieve all memories, optionally filtered by category.
    public func retrieveAll(category: MemoryCategory? = nil) async throws -> [MemoryEntry] {
        return try await store.retrieveAll(category: category)
    }

    /// Search memories by content.
    public func search(query: String) async throws -> [MemoryEntry] {
        let trimmedQuery = query.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !trimmedQuery.isEmpty else {
            return []
        }
        return try await store.search(query: trimmedQuery)
    }

    /// Update an existing memory's content.
    public func update(id: UUID, content: String) async throws {
        let trimmedContent = content.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !trimmedContent.isEmpty else {
            throw AriaError.invalidState(reason: "Memory content cannot be empty")
        }

        guard let existing = try await store.retrieve(id: id) else {
            throw AriaError.invalidState(reason: "Memory entry not found")
        }

        let updatedEntry = MemoryEntry(
            id: existing.id,
            content: trimmedContent,
            category: existing.category,
            importance: existing.importance,
            createdAt: existing.createdAt,
            lastAccessed: Date()
        )

        try await store.update(updatedEntry)
    }

    /// Delete a memory by ID.
    public func delete(id: UUID) async throws {
        try await store.delete(id: id)
    }

    /// Delete all memories, optionally filtered by category.
    public func deleteAll(category: MemoryCategory? = nil) async throws {
        try await store.deleteAll(category: category)
    }
    
    /// Update the lastAccessed timestamp for a memory.
    public func updateLastAccessed(id: UUID) async throws {
        guard let existing = try await store.retrieve(id: id) else {
            throw AriaError.invalidState(reason: "Memory entry not found")
        }
        
        let updatedEntry = MemoryEntry(
            id: existing.id,
            content: existing.content,
            category: existing.category,
            importance: existing.importance,
            createdAt: existing.createdAt,
            lastAccessed: Date()
        )
        
        try await store.update(updatedEntry)
    }
}
