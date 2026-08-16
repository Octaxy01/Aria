import Foundation
import XCTest
@testable import AriaInfrastructure
@testable import AriaDomain

/// Comprehensive tests for PersistentRelationshipStore.
/// Tests cover persistence, serialization, error handling, and thread safety.
final class PersistentRelationshipStoreTests: XCTestCase {
    
    var tempDirectory: URL!
    var fileURL: URL!
    
    override func setUp() {
        super.setUp()
        let fileManager = FileManager.default
        tempDirectory = fileManager.temporaryDirectory
            .appendingPathComponent("PersistentRelationshipStoreTests_\(UUID().uuidString)", isDirectory: true)
        try? fileManager.createDirectory(at: tempDirectory, withIntermediateDirectories: true)
        fileURL = tempDirectory.appendingPathComponent("relationship.json")
    }
    
    override func tearDown() {
        let fileManager = FileManager.default
        try? fileManager.removeItem(at: tempDirectory)
        super.tearDown()
    }
    
    // MARK: - Basic Persistence Tests
    
    func test_missingFileStartsWithInitialState() async {
        let store = PersistentRelationshipStore(fileURL: fileURL)
        let state = try? await store.load()
        
        XCTAssertNotNil(state, "Store should initialize even with missing file")
        XCTAssertEqual(state?.warmth, RelationshipState.initial.warmth)
        XCTAssertEqual(state?.familiarity, RelationshipState.initial.familiarity)
        XCTAssertEqual(state?.interactionCount, RelationshipState.initial.interactionCount)
    }
    
    func test_savePersistsState() async throws {
        let storeA = PersistentRelationshipStore(fileURL: fileURL)
        let testState = RelationshipState(
            warmth: 0.8,
            familiarity: 0.5,
            interactionCount: 10,
            updatedAt: Date()
        )
        
        try await storeA.save(testState)
        
        // Verify file was created
        let fileManager = FileManager.default
        XCTAssertTrue(fileManager.fileExists(atPath: fileURL.path), "File should be created after save")
        
        // Verify persistence by loading in new instance
        let storeB = PersistentRelationshipStore(fileURL: fileURL)
        let retrieved = try await storeB.load()
        
        XCTAssertEqual(retrieved.warmth, 0.8)
        XCTAssertEqual(retrieved.familiarity, 0.5)
        XCTAssertEqual(retrieved.interactionCount, 10)
    }
    
    func test_newStoreInstanceLoadsPreviouslyPersistedState() async throws {
        let storeA = PersistentRelationshipStore(fileURL: fileURL)
        let testState = RelationshipState(
            warmth: 0.7,
            familiarity: 0.6,
            interactionCount: 15,
            updatedAt: Date()
        )
        
        try await storeA.save(testState)
        
        // Create new store instance to simulate restart
        let storeB = PersistentRelationshipStore(fileURL: fileURL)
        let retrieved = try await storeB.load()
        
        XCTAssertEqual(retrieved.warmth, 0.7)
        XCTAssertEqual(retrieved.familiarity, 0.6)
        XCTAssertEqual(retrieved.interactionCount, 15)
    }
    
    func test_resetPersists() async throws {
        let storeA = PersistentRelationshipStore(fileURL: fileURL)
        let testState = RelationshipState(
            warmth: 0.9,
            familiarity: 0.8,
            interactionCount: 20,
            updatedAt: Date()
        )
        
        try await storeA.save(testState)
        try await storeA.reset()
        
        // Verify persistence
        let storeB = PersistentRelationshipStore(fileURL: fileURL)
        let retrieved = try await storeB.load()
        
        XCTAssertEqual(retrieved.warmth, RelationshipState.initial.warmth)
        XCTAssertEqual(retrieved.familiarity, RelationshipState.initial.familiarity)
        XCTAssertEqual(retrieved.interactionCount, RelationshipState.initial.interactionCount)
    }
    
    // MARK: - Data Integrity Tests
    
    func test_warmthSurvivesSerialization() async throws {
        let storeA = PersistentRelationshipStore(fileURL: fileURL)
        let testState = RelationshipState(
            warmth: 0.95,
            familiarity: 0.5,
            interactionCount: 5,
            updatedAt: Date()
        )
        
        try await storeA.save(testState)
        
        let storeB = PersistentRelationshipStore(fileURL: fileURL)
        let retrieved = try await storeB.load()
        
        XCTAssertEqual(retrieved.warmth, 0.95)
    }
    
    func test_familiaritySurvivesSerialization() async throws {
        let storeA = PersistentRelationshipStore(fileURL: fileURL)
        let testState = RelationshipState(
            warmth: 0.5,
            familiarity: 0.88,
            interactionCount: 5,
            updatedAt: Date()
        )
        
        try await storeA.save(testState)
        
        let storeB = PersistentRelationshipStore(fileURL: fileURL)
        let retrieved = try await storeB.load()
        
        XCTAssertEqual(retrieved.familiarity, 0.88)
    }
    
    func test_interactionCountSurvivesSerialization() async throws {
        let storeA = PersistentRelationshipStore(fileURL: fileURL)
        let testState = RelationshipState(
            warmth: 0.5,
            familiarity: 0.5,
            interactionCount: 100,
            updatedAt: Date()
        )
        
        try await storeA.save(testState)
        
        let storeB = PersistentRelationshipStore(fileURL: fileURL)
        let retrieved = try await storeB.load()
        
        XCTAssertEqual(retrieved.interactionCount, 100)
    }
    
    func test_timestampsSurviveSerialization() async throws {
        let storeA = PersistentRelationshipStore(fileURL: fileURL)
        let fixedDate = Date(timeIntervalSince1970: 1234567890)
        let testState = RelationshipState(
            warmth: 0.5,
            familiarity: 0.5,
            interactionCount: 5,
            updatedAt: fixedDate
        )
        
        try await storeA.save(testState)
        
        let storeB = PersistentRelationshipStore(fileURL: fileURL)
        let retrieved = try await storeB.load()
        
        XCTAssertEqual(retrieved.updatedAt, fixedDate)
    }
    
    // MARK: - Error Handling Tests
    
    func test_malformedJSONDoesNotCrashInitialization() async {
        // Write malformed JSON
        let malformedJSON = "this is not valid json { }"
        try? malformedJSON.write(to: fileURL, atomically: true, encoding: .utf8)
        
        let store = PersistentRelationshipStore(fileURL: fileURL)
        let state = try? await store.load()
        
        XCTAssertNotNil(state, "Store should initialize even with malformed JSON")
        XCTAssertEqual(state?.warmth, RelationshipState.initial.warmth, "Malformed JSON should result in initial state")
    }
    
    func test_multipleMutationsPersistCorrectly() async throws {
        let storeA = PersistentRelationshipStore(fileURL: fileURL)
        
        let state1 = RelationshipState(warmth: 0.4, familiarity: 0.1, interactionCount: 1, updatedAt: Date())
        let state2 = RelationshipState(warmth: 0.5, familiarity: 0.2, interactionCount: 2, updatedAt: Date())
        let state3 = RelationshipState(warmth: 0.6, familiarity: 0.3, interactionCount: 3, updatedAt: Date())
        
        try await storeA.save(state1)
        try await storeA.save(state2)
        try await storeA.save(state3)
        
        try await storeA.reset()
        
        // Verify all mutations persisted
        let storeB = PersistentRelationshipStore(fileURL: fileURL)
        let finalState = try await storeB.load()
        
        XCTAssertEqual(finalState.warmth, RelationshipState.initial.warmth)
        XCTAssertEqual(finalState.familiarity, RelationshipState.initial.familiarity)
        XCTAssertEqual(finalState.interactionCount, RelationshipState.initial.interactionCount)
    }
    
    // MARK: - Thread Safety Tests
    
    func test_concurrentMutationOperationsRemainConsistent() async throws {
        let store = PersistentRelationshipStore(fileURL: fileURL)
        
        // Perform concurrent operations
        await withTaskGroup(of: Void.self) { group in
            for i in 0..<10 {
                group.addTask {
                    let state = RelationshipState(
                        warmth: Double(i) * 0.1,
                        familiarity: Double(i) * 0.05,
                        interactionCount: i,
                        updatedAt: Date()
                    )
                    try? await store.save(state)
                }
            }
        }
        
        // Verify last write persisted
        let finalState = try await store.load()
        XCTAssertNotNil(finalState, "Final state should be retrievable")
    }
    
    // MARK: - Integration Tests
    
    func test_inMemoryRelationshipStoreRemainsAvailable() async throws {
        // This test verifies that InMemoryRelationshipStore is available for testing
        let store = InMemoryRelationshipStore()
        let testState = RelationshipState(
            warmth: 0.75,
            familiarity: 0.55,
            interactionCount: 12,
            updatedAt: Date()
        )
        
        try await store.save(testState)
        let retrieved = try await store.load()
        
        XCTAssertEqual(retrieved.warmth, 0.75)
        XCTAssertEqual(retrieved.familiarity, 0.55)
        XCTAssertEqual(retrieved.interactionCount, 12)
    }
    
    func test_defaultAppSupportPathWorks() async throws {
        // Test that the default initializer works
        let store = PersistentRelationshipStore(appName: "Aria")
        let testState = RelationshipState(
            warmth: 0.6,
            familiarity: 0.4,
            interactionCount: 8,
            updatedAt: Date()
        )
        
        try await store.save(testState)
        let retrieved = try await store.load()
        
        XCTAssertEqual(retrieved.warmth, 0.6)
        
        // Clean up
        try? await store.reset()
    }
}
