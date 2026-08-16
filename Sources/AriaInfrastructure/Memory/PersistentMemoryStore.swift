import Foundation
import AriaDomain

/// Persistent file-based implementation of MemoryStoring using JSON.
/// Stores memories in a local JSON file that survives application restarts.
/// Thread-safe through actor isolation.
public actor PersistentMemoryStore: MemoryStoring {
    private var memories: [UUID: MemoryEntry] = [:]
    private let fileURL: URL
    private var hasLoaded = false
    
    /// Container for JSON serialization/deserialization.
    private struct MemoryFile: Codable {
        var memories: [MemoryEntry]
    }
    
    /// Initialize with a specific file URL (useful for testing).
    /// - Parameter fileURL: URL where the JSON file should be stored/loaded
    public init(fileURL: URL) {
        self.fileURL = fileURL
    }
    
    /// Initialize with default Application Support directory for production use.
    /// - Parameter appName: Application name for the directory (defaults to "Aria")
    public init(appName: String = "Aria") {
        let fileManager = FileManager.default
        let appSupportURL = fileManager.urls(for: .applicationSupportDirectory, in: .userDomainMask).first!
        let appDirectory = appSupportURL.appendingPathComponent(appName, isDirectory: true)
        
        // Create directory if it doesn't exist
        try? fileManager.createDirectory(at: appDirectory, withIntermediateDirectories: true)
        
        self.fileURL = appDirectory.appendingPathComponent("memories.json")
    }
    
    // MARK: - MemoryStoring Implementation
    
    public func store(_ entry: MemoryEntry) async throws {
        ensureLoaded()
        memories[entry.id] = entry
        saveToFile()
    }
    
    public func retrieve(id: UUID) async throws -> MemoryEntry? {
        ensureLoaded()
        return memories[id]
    }
    
    public func retrieveAll(category: MemoryCategory? = nil) async throws -> [MemoryEntry] {
        ensureLoaded()
        if let category {
            return memories.values.filter { $0.category == category }
        }
        return Array(memories.values)
    }
    
    public func search(query: String) async throws -> [MemoryEntry] {
        ensureLoaded()
        let lowerQuery = query.lowercased()
        return memories.values.filter { entry in
            entry.content.lowercased().contains(lowerQuery)
        }
    }
    
    public func update(_ entry: MemoryEntry) async throws {
        ensureLoaded()
        guard memories[entry.id] != nil else {
            throw AriaError.invalidState(reason: "Memory entry not found")
        }
        memories[entry.id] = entry
        saveToFile()
    }
    
    public func delete(id: UUID) async throws {
        ensureLoaded()
        memories.removeValue(forKey: id)
        saveToFile()
    }
    
    public func deleteAll(category: MemoryCategory? = nil) async throws {
        ensureLoaded()
        if let category {
            let toDelete = memories.values.filter { $0.category == category }.map(\.id)
            for id in toDelete {
                memories.removeValue(forKey: id)
            }
        } else {
            memories.removeAll()
        }
        saveToFile()
    }
    
    // MARK: - Private Persistence Methods
    
    private func ensureLoaded() {
        guard !hasLoaded else { return }
        loadFromFile()
        hasLoaded = true
    }
    
    private func loadFromFile() {
        let fileManager = FileManager.default
        guard fileManager.fileExists(atPath: fileURL.path) else {
            // File doesn't exist - start with empty collection
            return
        }
        
        guard let data = fileManager.contents(atPath: fileURL.path) else {
            // Can't read file - start with empty collection
            return
        }
        
        do {
            let memoryFile = try JSONDecoder().decode(MemoryFile.self, from: data)
            // Convert array to dictionary for efficient lookup
            memories = Dictionary(uniqueKeysWithValues: memoryFile.memories.map { ($0.id, $0) })
        } catch {
            // Malformed JSON - start with empty collection rather than crashing
            // In production, this should be logged
            memories = [:]
        }
    }
    
    private func saveToFile() {
        let memoryFile = MemoryFile(memories: Array(memories.values))
        
        do {
            let data = try JSONEncoder().encode(memoryFile)
            try data.write(to: fileURL, options: .atomic)
        } catch {
            // In production, this should be logged
            // Memory failures should not break the application
        }
    }
}
