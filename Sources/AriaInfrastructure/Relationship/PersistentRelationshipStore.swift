import Foundation
import AriaDomain

/// Persistent file-based implementation of RelationshipStateStoring using JSON.
/// Stores relationship state in a local JSON file that survives application restarts.
/// Thread-safe through actor isolation.
public actor PersistentRelationshipStore: RelationshipStateStoring {
    private var currentState: RelationshipState?
    private let fileURL: URL
    private var hasLoaded = false
    
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
        
        self.fileURL = appDirectory.appendingPathComponent("relationship.json")
    }
    
    // MARK: - RelationshipStateStoring Implementation
    
    public func load() async throws -> RelationshipState {
        ensureLoaded()
        return currentState ?? RelationshipState.initial
    }
    
    public func save(_ state: RelationshipState) async throws {
        currentState = state
        saveToFile()
    }
    
    public func reset() async throws {
        currentState = RelationshipState.initial
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
            // File doesn't exist - start with initial state
            currentState = RelationshipState.initial
            return
        }
        
        guard let data = fileManager.contents(atPath: fileURL.path) else {
            // Can't read file - start with initial state
            currentState = RelationshipState.initial
            return
        }
        
        do {
            currentState = try JSONDecoder().decode(RelationshipState.self, from: data)
        } catch {
            // Malformed JSON - start with initial state rather than crashing
            // In production, this should be logged
            currentState = RelationshipState.initial
        }
    }
    
    private func saveToFile() {
        guard let state = currentState else { return }
        
        do {
            let data = try JSONEncoder().encode(state)
            try data.write(to: fileURL, options: .atomic)
        } catch {
            // In production, this should be logged
            // Relationship persistence failures should not break the application
        }
    }
}
