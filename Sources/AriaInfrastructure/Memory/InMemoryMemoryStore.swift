import Foundation
import AriaDomain

/// In-memory implementation of MemoryStoring for testing and development.
/// Not persistent - data is lost when the app terminates.
/// Can be replaced with database-backed implementation in future stages.
public actor InMemoryMemoryStore: MemoryStoring {
    private var memories: [UUID: MemoryEntry] = [:]

    public init() {}

    public func store(_ entry: MemoryEntry) async throws {
        memories[entry.id] = entry
    }

    public func retrieve(id: UUID) async throws -> MemoryEntry? {
        return memories[id]
    }

    public func retrieveAll(category: MemoryCategory? = nil) async throws -> [MemoryEntry] {
        if let category {
            return memories.values.filter { $0.category == category }
        }
        return Array(memories.values)
    }

    public func search(query: String) async throws -> [MemoryEntry] {
        let lowerQuery = query.lowercased()
        return memories.values.filter { entry in
            entry.content.lowercased().contains(lowerQuery)
        }
    }

    public func update(_ entry: MemoryEntry) async throws {
        guard memories[entry.id] != nil else {
            throw AriaError.invalidState(reason: "Memory entry not found")
        }
        memories[entry.id] = entry
    }

    public func delete(id: UUID) async throws {
        memories.removeValue(forKey: id)
    }

    public func deleteAll(category: MemoryCategory? = nil) async throws {
        if let category {
            let toDelete = memories.values.filter { $0.category == category }.map(\.id)
            for id in toDelete {
                memories.removeValue(forKey: id)
            }
        } else {
            memories.removeAll()
        }
    }
}
