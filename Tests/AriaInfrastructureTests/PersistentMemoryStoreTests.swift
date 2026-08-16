import Foundation
import XCTest
@testable import AriaInfrastructure
@testable import AriaDomain

/// Comprehensive tests for PersistentMemoryStore.
/// Tests cover persistence, serialization, error handling, and thread safety.
final class PersistentMemoryStoreTests: XCTestCase {
    
    var tempDirectory: URL!
    var fileURL: URL!
    
    override func setUp() {
        super.setUp()
        let fileManager = FileManager.default
        tempDirectory = fileManager.temporaryDirectory
            .appendingPathComponent("PersistentMemoryStoreTests_\(UUID().uuidString)", isDirectory: true)
        try? fileManager.createDirectory(at: tempDirectory, withIntermediateDirectories: true)
        fileURL = tempDirectory.appendingPathComponent("memories.json")
    }
    
    override func tearDown() {
        let fileManager = FileManager.default
        try? fileManager.removeItem(at: tempDirectory)
        super.tearDown()
    }
    
    // MARK: - Basic Persistence Tests
    
    func test_emptyFileStartsWithEmptyMemoryStore() async {
        // Create an empty file
        try? Data().write(to: fileURL)
        
        let store = PersistentMemoryStore(fileURL: fileURL)
        let memories = try? await store.retrieveAll()
        
        XCTAssertEqual(memories?.count, 0, "Empty file should start with empty memory store")
    }
    
    func test_storePersistsMemory() async throws {
        let storeA = PersistentMemoryStore(fileURL: fileURL)
        let entry = MemoryEntry(content: "Test memory", category: .general, importance: .normal)
        
        try await storeA.store(entry)
        
        // Verify file was created
        let fileManager = FileManager.default
        XCTAssertTrue(fileManager.fileExists(atPath: fileURL.path), "File should be created after store")
        
        // Verify persistence by loading in new instance
        let storeB = PersistentMemoryStore(fileURL: fileURL)
        let retrieved = try await storeB.retrieve(id: entry.id)
        
        XCTAssertNotNil(retrieved, "Memory should be retrievable after persistence")
        XCTAssertEqual(retrieved?.content, "Test memory")
        XCTAssertEqual(retrieved?.category, .general)
        XCTAssertEqual(retrieved?.importance, .normal)
    }
    
    func test_newStoreInstanceLoadsPreviouslyPersistedMemory() async throws {
        let storeA = PersistentMemoryStore(fileURL: fileURL)
        let entry = MemoryEntry(content: "Persistent test", category: .fact, importance: .high)
        
        try await storeA.store(entry)
        
        // Create new store instance to simulate restart
        let storeB = PersistentMemoryStore(fileURL: fileURL)
        let retrieved = try await storeB.retrieve(id: entry.id)
        
        XCTAssertNotNil(retrieved, "New store instance should load previously persisted memory")
        XCTAssertEqual(retrieved?.content, "Persistent test")
        XCTAssertEqual(retrieved?.id, entry.id)
    }
    
    func test_updatePersists() async throws {
        let storeA = PersistentMemoryStore(fileURL: fileURL)
        let entry = MemoryEntry(content: "Original content", category: .general, importance: .normal)
        
        try await storeA.store(entry)
        
        let updatedEntry = MemoryEntry(
            id: entry.id,
            content: "Updated content",
            category: .preference,
            importance: .high,
            createdAt: entry.createdAt,
            lastAccessed: Date()
        )
        
        try await storeA.update(updatedEntry)
        
        // Verify persistence
        let storeB = PersistentMemoryStore(fileURL: fileURL)
        let retrieved = try await storeB.retrieve(id: entry.id)
        
        XCTAssertEqual(retrieved?.content, "Updated content")
        XCTAssertEqual(retrieved?.category, .preference)
        XCTAssertEqual(retrieved?.importance, .high)
    }
    
    func test_deletePersists() async throws {
        let storeA = PersistentMemoryStore(fileURL: fileURL)
        let entry = MemoryEntry(content: "To be deleted", category: .general, importance: .normal)
        
        try await storeA.store(entry)
        try await storeA.delete(id: entry.id)
        
        // Verify persistence
        let storeB = PersistentMemoryStore(fileURL: fileURL)
        let retrieved = try await storeB.retrieve(id: entry.id)
        
        XCTAssertNil(retrieved, "Deleted memory should not be retrievable after persistence")
    }
    
    func test_deleteAllPersists() async throws {
        let storeA = PersistentMemoryStore(fileURL: fileURL)
        
        let entry1 = MemoryEntry(content: "Memory 1", category: .general, importance: .normal)
        let entry2 = MemoryEntry(content: "Memory 2", category: .preference, importance: .high)
        
        try await storeA.store(entry1)
        try await storeA.store(entry2)
        try await storeA.deleteAll()
        
        // Verify persistence
        let storeB = PersistentMemoryStore(fileURL: fileURL)
        let allMemories = try await storeB.retrieveAll()
        
        XCTAssertEqual(allMemories.count, 0, "All memories should be deleted and persisted")
    }
    
    func test_searchWorksAfterReload() async throws {
        let storeA = PersistentMemoryStore(fileURL: fileURL)
        
        let entry1 = MemoryEntry(content: "Apple pie recipe", category: .preference, importance: .normal)
        let entry2 = MemoryEntry(content: "Chocolate cake", category: .preference, importance: .normal)
        
        try await storeA.store(entry1)
        try await storeA.store(entry2)
        
        // Search in new instance
        let storeB = PersistentMemoryStore(fileURL: fileURL)
        let results = try await storeB.search(query: "apple")
        
        XCTAssertEqual(results.count, 1)
        XCTAssertEqual(results.first?.content, "Apple pie recipe")
    }
    
    func test_categoryFilteringWorksAfterReload() async throws {
        let storeA = PersistentMemoryStore(fileURL: fileURL)
        
        let entry1 = MemoryEntry(content: "Like cats", category: .preference, importance: .normal)
        let entry2 = MemoryEntry(content: "Name is John", category: .fact, importance: .high)
        
        try await storeA.store(entry1)
        try await storeA.store(entry2)
        
        // Filter in new instance
        let storeB = PersistentMemoryStore(fileURL: fileURL)
        let preferences = try await storeB.retrieveAll(category: .preference)
        
        XCTAssertEqual(preferences.count, 1)
        XCTAssertEqual(preferences.first?.content, "Like cats")
    }
    
    // MARK: - Data Integrity Tests
    
    func test_importanceSurvivesSerialization() async throws {
        let storeA = PersistentMemoryStore(fileURL: fileURL)
        
        for importance in MemoryImportance.allCases {
            let entry = MemoryEntry(content: "Test \(importance)", category: .general, importance: importance)
            try await storeA.store(entry)
        }
        
        let storeB = PersistentMemoryStore(fileURL: fileURL)
        let allMemories = try await storeB.retrieveAll()
        
        XCTAssertEqual(allMemories.count, MemoryImportance.allCases.count)
        
        for memory in allMemories {
            XCTAssertTrue(MemoryImportance.allCases.contains(memory.importance))
        }
    }
    
    func test_timestampsSurviveSerialization() async throws {
        let storeA = PersistentMemoryStore(fileURL: fileURL)
        
        let fixedDate = Date(timeIntervalSince1970: 1234567890)
        let entry = MemoryEntry(
            content: "Timestamp test",
            category: .general,
            importance: .normal,
            createdAt: fixedDate,
            lastAccessed: fixedDate
        )
        
        try await storeA.store(entry)
        
        let storeB = PersistentMemoryStore(fileURL: fileURL)
        let retrieved = try await storeB.retrieve(id: entry.id)
        
        XCTAssertEqual(retrieved?.createdAt, fixedDate)
        XCTAssertEqual(retrieved?.lastAccessed, fixedDate)
    }
    
    func test_idsSurviveSerialization() async throws {
        let storeA = PersistentMemoryStore(fileURL: fileURL)
        
        let fixedId = UUID(uuidString: "12345678-1234-1234-1234-123456789012")!
        let entry = MemoryEntry(
            id: fixedId,
            content: "ID test",
            category: .general,
            importance: .normal
        )
        
        try await storeA.store(entry)
        
        let storeB = PersistentMemoryStore(fileURL: fileURL)
        let retrieved = try await storeB.retrieve(id: fixedId)
        
        XCTAssertEqual(retrieved?.id, fixedId)
    }
    
    // MARK: - Error Handling Tests
    
    func test_missingFileDoesNotFail() async {
        // Don't create the file
        let store = PersistentMemoryStore(fileURL: fileURL)
        let memories = try? await store.retrieveAll()
        
        XCTAssertNotNil(memories, "Store should initialize even with missing file")
        XCTAssertEqual(memories?.count, 0, "Missing file should result in empty collection")
    }
    
    func test_malformedJSONDoesNotCrashInitialization() async {
        // Write malformed JSON
        let malformedJSON = "this is not valid json { }"
        try? malformedJSON.write(to: fileURL, atomically: true, encoding: .utf8)
        
        let store = PersistentMemoryStore(fileURL: fileURL)
        let memories = try? await store.retrieveAll()
        
        XCTAssertNotNil(memories, "Store should initialize even with malformed JSON")
        XCTAssertEqual(memories?.count, 0, "Malformed JSON should result in empty collection")
    }
    
    func test_multipleMutationsPersistCorrectly() async throws {
        let storeA = PersistentMemoryStore(fileURL: fileURL)
        
        let entry1 = MemoryEntry(content: "First", category: .general, importance: .normal)
        let entry2 = MemoryEntry(content: "Second", category: .preference, importance: .high)
        let entry3 = MemoryEntry(content: "Third", category: .fact, importance: .critical)
        
        try await storeA.store(entry1)
        try await storeA.store(entry2)
        try await storeA.store(entry3)
        
        try await storeA.delete(id: entry2.id)
        
        let updatedEntry1 = MemoryEntry(
            id: entry1.id,
            content: "First updated",
            category: entry1.category,
            importance: entry1.importance,
            createdAt: entry1.createdAt,
            lastAccessed: Date()
        )
        try await storeA.update(updatedEntry1)
        
        // Verify all mutations persisted
        let storeB = PersistentMemoryStore(fileURL: fileURL)
        let allMemories = try await storeB.retrieveAll()
        
        XCTAssertEqual(allMemories.count, 2)
        
        let retrieved1 = try await storeB.retrieve(id: entry1.id)
        XCTAssertEqual(retrieved1?.content, "First updated")
        
        let retrieved2 = try await storeB.retrieve(id: entry2.id)
        XCTAssertNil(retrieved2, "Deleted entry should not exist")
        
        let retrieved3 = try await storeB.retrieve(id: entry3.id)
        XCTAssertNotNil(retrieved3, "Third entry should still exist")
    }
    
    // MARK: - Thread Safety Tests
    
    func test_concurrentMutationOperationsRemainConsistent() async throws {
        let store = PersistentMemoryStore(fileURL: fileURL)
        
        // Perform concurrent operations
        await withTaskGroup(of: Void.self) { group in
            for i in 0..<10 {
                group.addTask {
                    let entry = MemoryEntry(content: "Concurrent \(i)", category: .general, importance: .normal)
                    try? await store.store(entry)
                }
            }
        }
        
        // Verify all writes persisted
        let storeB = PersistentMemoryStore(fileURL: fileURL)
        let allMemories = try await storeB.retrieveAll()
        
        XCTAssertEqual(allMemories.count, 10, "All concurrent writes should persist")
    }
    
    // MARK: - Integration Tests
    
    // Note: Integration tests with MemoryService, MemoryFormationService, and MemoryContextBuilder
    // are located in AriaApplicationTests to maintain proper module boundaries.
    // This test file focuses purely on PersistentMemoryStore persistence behavior.
}
