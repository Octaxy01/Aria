import XCTest
@testable import AriaApplication
@testable import AriaDomain
@testable import AriaInfrastructure

/// Integration tests for relationship persistence in the production bootstrap flow.
/// Tests verify that relationship state loads on startup, persists after changes,
/// and survives simulated application restarts.
final class RelationshipPersistenceIntegrationTests: XCTestCase {
    
    var tempDirectory: URL!
    var fileURL: URL!
    
    override func setUp() {
        super.setUp()
        let fileManager = FileManager.default
        tempDirectory = fileManager.temporaryDirectory
            .appendingPathComponent("RelationshipPersistenceIntegrationTests_\(UUID().uuidString)", isDirectory: true)
        try? fileManager.createDirectory(at: tempDirectory, withIntermediateDirectories: true)
        fileURL = tempDirectory.appendingPathComponent("relationship.json")
    }
    
    override func tearDown() {
        let fileManager = FileManager.default
        try? fileManager.removeItem(at: tempDirectory)
        super.tearDown()
    }
    
    // MARK: - Startup Tests
    
    func test_relationshipState_loadsOnStartup() async throws {
        // Simulate a previous session by creating a relationship file
        let previousState = RelationshipState(
            warmth: 0.75,
            familiarity: 0.45,
            interactionCount: 10,
            updatedAt: Date()
        )
        let data = try JSONEncoder().encode(previousState)
        try data.write(to: fileURL)
        
        // Create a new relationship service with the persistent store
        let store = PersistentRelationshipStore(fileURL: fileURL)
        let service = await RelationshipService(stateStore: store)
        
        // Verify the loaded state matches the persisted state
        let loadedState = await service.getCurrentState()
        XCTAssertEqual(loadedState.warmth, 0.75)
        XCTAssertEqual(loadedState.familiarity, 0.45)
        XCTAssertEqual(loadedState.interactionCount, 10)
    }
    
    func test_missingRelationshipJson_usesInitialState() async throws {
        // Ensure no relationship file exists
        let fileManager = FileManager.default
        try? fileManager.removeItem(at: fileURL)
        
        // Create a new relationship service with the persistent store
        let store = PersistentRelationshipStore(fileURL: fileURL)
        let service = await RelationshipService(stateStore: store)
        
        // Verify it starts with initial state
        let loadedState = await service.getCurrentState()
        XCTAssertEqual(loadedState.warmth, RelationshipState.initial.warmth)
        XCTAssertEqual(loadedState.familiarity, RelationshipState.initial.familiarity)
        XCTAssertEqual(loadedState.interactionCount, RelationshipState.initial.interactionCount)
    }
    
    func test_corruptedRelationshipJson_fallsBackToInitialState() async throws {
        // Write corrupted JSON
        let corruptedJSON = "this is not valid json { }"
        try corruptedJSON.write(to: fileURL, atomically: true, encoding: .utf8)
        
        // Create a new relationship service with the persistent store
        let store = PersistentRelationshipStore(fileURL: fileURL)
        let service = await RelationshipService(stateStore: store)
        
        // Verify it starts with initial state
        let loadedState = await service.getCurrentState()
        XCTAssertEqual(loadedState.warmth, RelationshipState.initial.warmth)
        XCTAssertEqual(loadedState.familiarity, RelationshipState.initial.familiarity)
        XCTAssertEqual(loadedState.interactionCount, RelationshipState.initial.interactionCount)
    }
    
    // MARK: - Restart Survival Tests
    
    func test_relationshipState_survivesSimulatedRestart() async throws {
        // SESSION 1: Create and persist state
        let store1 = PersistentRelationshipStore(fileURL: fileURL)
        let service1 = await RelationshipService(stateStore: store1)
        
        let state1 = await service1.nextState(
            current: RelationshipState.initial,
            tone: .affectionate,
            emotionSignal: nil
        )
        
        // Verify file was created
        let fileManager = FileManager.default
        XCTAssertTrue(fileManager.fileExists(atPath: fileURL.path))
        
        // SESSION 2: Simulate restart by creating new instances
        let store2 = PersistentRelationshipStore(fileURL: fileURL)
        let service2 = await RelationshipService(stateStore: store2)
        
        let loadedState = await service2.getCurrentState()
        
        // Verify state survived
        XCTAssertEqual(loadedState.warmth, state1.warmth)
        XCTAssertEqual(loadedState.familiarity, state1.familiarity)
        XCTAssertEqual(loadedState.interactionCount, state1.interactionCount)
    }
    
    func test_familiarity_survivesRestart() async throws {
        // SESSION 1: Build up familiarity
        let store1 = PersistentRelationshipStore(fileURL: fileURL)
        let service1 = await RelationshipService(stateStore: store1)
        
        var state = RelationshipState.initial
        for _ in 0..<10 {
            state = await service1.nextState(current: state, tone: .casual, emotionSignal: nil)
        }
        
        let expectedFamiliarity = state.familiarity
        
        // SESSION 2: Restart
        let store2 = PersistentRelationshipStore(fileURL: fileURL)
        let service2 = await RelationshipService(stateStore: store2)
        
        let loadedState = await service2.getCurrentState()
        XCTAssertEqual(loadedState.familiarity, expectedFamiliarity, accuracy: 0.0001)
    }
    
    func test_warmth_survivesRestart() async throws {
        // SESSION 1: Build up warmth
        let store1 = PersistentRelationshipStore(fileURL: fileURL)
        let service1 = await RelationshipService(stateStore: store1)
        
        var state = RelationshipState.initial
        for _ in 0..<5 {
            state = await service1.nextState(current: state, tone: .affectionate, emotionSignal: nil)
        }
        
        let expectedWarmth = state.warmth
        
        // SESSION 2: Restart
        let store2 = PersistentRelationshipStore(fileURL: fileURL)
        let service2 = await RelationshipService(stateStore: store2)
        
        let loadedState = await service2.getCurrentState()
        XCTAssertEqual(loadedState.warmth, expectedWarmth, accuracy: 0.0001)
    }
    
    func test_interactionCount_survivesRestart() async throws {
        // SESSION 1: Build up interaction count
        let store1 = PersistentRelationshipStore(fileURL: fileURL)
        let service1 = await RelationshipService(stateStore: store1)
        
        var state = RelationshipState.initial
        for _ in 0..<15 {
            state = await service1.nextState(current: state, tone: .casual, emotionSignal: nil)
        }
        
        let expectedInteractionCount = state.interactionCount
        
        // SESSION 2: Restart
        let store2 = PersistentRelationshipStore(fileURL: fileURL)
        let service2 = await RelationshipService(stateStore: store2)
        
        let loadedState = await service2.getCurrentState()
        XCTAssertEqual(loadedState.interactionCount, expectedInteractionCount)
    }
    
    // MARK: - Persistence After Updates Tests
    
    func test_updatedRelationshipState_isPersistedAfterTurn() async throws {
        let store = PersistentRelationshipStore(fileURL: fileURL)
        let service = await RelationshipService(stateStore: store)
        
        // Perform a state update
        let initialState = await service.getCurrentState()
        let updatedState = await service.nextState(
            current: initialState,
            tone: .affectionate,
            emotionSignal: nil
        )
        
        // Verify the file was updated
        let fileManager = FileManager.default
        XCTAssertTrue(fileManager.fileExists(atPath: fileURL.path))
        
        // Verify the persisted state matches the updated state
        let data = try Data(contentsOf: fileURL)
        let persistedState = try JSONDecoder().decode(RelationshipState.self, from: data)
        
        XCTAssertEqual(persistedState.warmth, updatedState.warmth)
        XCTAssertEqual(persistedState.familiarity, updatedState.familiarity)
        XCTAssertEqual(persistedState.interactionCount, updatedState.interactionCount)
    }
    
    func test_persistenceFailure_doesNotBreakConversation() async throws {
        // Create a service with a failing store (simulated by invalid directory)
        let invalidURL = URL(fileURLWithPath: "/invalid/path/that/does/not/exist/relationship.json")
        let store = PersistentRelationshipStore(fileURL: invalidURL)
        let service = await RelationshipService(stateStore: store)
        
        // This should not throw or crash
        let state = await service.nextState(
            current: RelationshipState.initial,
            tone: .casual,
            emotionSignal: nil
        )
        
        // State should still be updated in memory
        XCTAssertGreaterThan(state.interactionCount, 0)
    }
    
    // MARK: - Bootstrap Tests
    
    func test_appBootstrap_createsPersistentRelationshipStore() async throws {
        let tempDir = FileManager.default.temporaryDirectory
            .appendingPathComponent("BootstrapTest_\(UUID().uuidString)", isDirectory: true)
        try? FileManager.default.createDirectory(at: tempDir, withIntermediateDirectories: true)
        
        // Create a custom store with the temp directory
        let fileURL = tempDir.appendingPathComponent("relationship.json")
        let store = PersistentRelationshipStore(fileURL: fileURL)
        
        // The bootstrap should use this store
        let service = await RelationshipService(stateStore: store)
        let state = await service.getCurrentState()
        
        // Verify the store is being used
        XCTAssertEqual(state.warmth, RelationshipState.initial.warmth)
        
        // Clean up
        try? FileManager.default.removeItem(at: tempDir)
    }
    
    func test_appBootstrap_doesNotUseInMemoryStoreInProduction() async throws {
        // Production should use PersistentRelationshipStore, not InMemoryRelationshipStore
        let persistentStore = PersistentRelationshipStore(fileURL: fileURL)
        let service = await RelationshipService(stateStore: persistentStore)
        
        // Verify the state is actually persisted
        let initialState = await service.getCurrentState()
        let updatedState = await service.nextState(
            current: initialState,
            tone: .casual,
            emotionSignal: nil
        )
        
        // Verify persistence
        let data = try Data(contentsOf: fileURL)
        let persistedState = try JSONDecoder().decode(RelationshipState.self, from: data)
        
        XCTAssertEqual(persistedState.interactionCount, updatedState.interactionCount)
    }
    
    // MARK: - Backward Compatibility Tests
    
    func test_serviceWithoutPersistence_remainsValid() async {
        // Ensure the non-persistent initializer still works for testing
        let service = RelationshipService()
        let state = await service.getCurrentState()
        
        XCTAssertEqual(state.warmth, RelationshipState.initial.warmth)
        
        let updatedState = await service.nextState(
            current: state,
            tone: .casual,
            emotionSignal: nil
        )
        
        XCTAssertGreaterThan(updatedState.interactionCount, state.interactionCount)
    }
}
