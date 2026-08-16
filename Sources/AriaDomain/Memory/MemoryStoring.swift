import Foundation

/// Protocol for memory storage operations. Infrastructure layer provides
/// concrete implementations (in-memory, file-based, database, etc.).
/// Application layer uses this protocol without knowing storage details.
public protocol MemoryStoring: Sendable {
    /// Store a new memory entry.
    func store(_ entry: MemoryEntry) async throws

    /// Retrieve a memory entry by ID.
    func retrieve(id: UUID) async throws -> MemoryEntry?

    /// Retrieve all memory entries, optionally filtered by category.
    func retrieveAll(category: MemoryCategory?) async throws -> [MemoryEntry]

    /// Search for memory entries containing the given text.
    func search(query: String) async throws -> [MemoryEntry]

    /// Update an existing memory entry.
    func update(_ entry: MemoryEntry) async throws

    /// Delete a memory entry by ID.
    func delete(id: UUID) async throws

    /// Delete all memory entries, optionally filtered by category.
    func deleteAll(category: MemoryCategory?) async throws
}
