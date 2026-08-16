import Foundation
import XCTest
@testable import AriaApplication
@testable import AriaDomain
@testable import AriaInfrastructure

/// Integration tests for persistent memory with the application layer.
/// Tests verify that PersistentMemoryStore works correctly with MemoryService,
/// MemoryFormationService, and MemoryContextBuilder.
final class PersistentMemoryIntegrationTests: XCTestCase {
    
    var tempDirectory: URL!
    var fileURL: URL!
    
    override func setUp() {
        super.setUp()
        let fileManager = FileManager.default
        tempDirectory = fileManager.temporaryDirectory
            .appendingPathComponent("PersistentMemoryIntegrationTests_\(UUID().uuidString)", isDirectory: true)
        try? fileManager.createDirectory(at: tempDirectory, withIntermediateDirectories: true)
        fileURL = tempDirectory.appendingPathComponent("memories.json")
    }
    
    override func tearDown() {
        let fileManager = FileManager.default
        try? fileManager.removeItem(at: tempDirectory)
        super.tearDown()
    }
    
    // MARK: - Integration Tests
    
    func test_assistantCoordinatorIntegrationWorksUsingPersistentMemoryStore() async throws {
        // This test verifies that PersistentMemoryStore can be used with the existing MemoryService
        let store = PersistentMemoryStore(fileURL: fileURL)
        let memoryService = MemoryService(store: store)
        
        try await memoryService.store(content: "Integration test", category: .fact, importance: .high)
        
        let retrieved = try await memoryService.retrieveAll()
        XCTAssertEqual(retrieved.count, 1)
        XCTAssertEqual(retrieved.first?.content, "Integration test")
    }
    
    func test_memoryFormationServiceCreatedMemorySurvivesSimulatedRestart() async throws {
        let storeA = PersistentMemoryStore(fileURL: fileURL)
        let memoryServiceA = MemoryService(store: storeA)
        let memoryFormationA = MemoryFormationService(memoryService: memoryServiceA)
        
        // Simulate memory formation
        _ = await memoryFormationA.processUserMessage("Nama saya Salman")
        
        // Simulate restart by creating new instances
        let storeB = PersistentMemoryStore(fileURL: fileURL)
        let memoryServiceB = MemoryService(store: storeB)
        
        let memories = try await memoryServiceB.retrieveAll()
        XCTAssertGreaterThan(memories.count, 0, "Memory formation should persist across restart")
        
        // Verify the specific memory content
        let nameMemories = try await memoryServiceB.search(query: "Salman")
        XCTAssertGreaterThan(nameMemories.count, 0, "Should find the name memory after restart")
    }
    
    func test_memoryContextBuilderCanRetrieveMemoryLoadedFromDisk() async throws {
        let storeA = PersistentMemoryStore(fileURL: fileURL)
        let memoryServiceA = MemoryService(store: storeA)
        
        try await memoryServiceA.store(content: "User likes apples", category: .preference, importance: .normal)
        
        // Simulate restart
        let storeB = PersistentMemoryStore(fileURL: fileURL)
        let memoryServiceB = MemoryService(store: storeB)
        let contextBuilder = MemoryContextBuilder(memoryService: memoryServiceB)
        
        let context = await contextBuilder.buildContext(for: "What do I like?")
        XCTAssertFalse(context.isEmpty, "MemoryContextBuilder should retrieve memories loaded from disk")
    }
}
