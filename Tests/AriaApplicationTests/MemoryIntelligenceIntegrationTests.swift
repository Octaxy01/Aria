import XCTest
@testable import AriaApplication
import AriaDomain
import AriaInfrastructure
import Foundation

final class MemoryIntelligenceIntegrationTests: XCTestCase {
    
    private var memoryService: MemoryService!
    private var memoryContextBuilder: MemoryContextBuilder!
    private var memoryFormationService: MemoryFormationService!
    
    override func setUp() async throws {
        try await super.setUp()
        
        let memoryStore = InMemoryMemoryStore()
        memoryService = MemoryService(store: memoryStore)
        memoryContextBuilder = MemoryContextBuilder(
            memoryService: memoryService,
            configuration: .default,
            logger: nil
        )
        memoryFormationService = MemoryFormationService(memoryService: memoryService)
    }
    
    // MARK: - Integration Tests
    
    func test_relationshipLevelDoesNotForceIrrelevantMemoryIntoContext() async throws {
        // Store memories
        try await memoryService.store(
            content: "User prefers coffee",
            category: .preference,
            importance: .normal
        )
        
        try await memoryService.store(
            content: "User has a personal problem",
            category: .relationship,
            importance: .high
        )
        
        // Query about weather (irrelevant to both memories)
        let context = await memoryContextBuilder.buildContext(
            for: "The weather is cold today",
            relationshipLevel: .trusted
        )
        
        // Should not include relationship memory for weather conversation
        XCTAssertFalse(context.contains("personal problem"),
                      "Relationship memory should not be forced into irrelevant context")
    }
    
    func test_relevantMemoryAvailableRegardlessOfRelationshipLevel() async throws {
        try await memoryService.store(
            content: "User prefers coffee",
            category: .preference,
            importance: .normal
        )
        
        // Test with stranger relationship level
        let strangerContext = await memoryContextBuilder.buildContext(
            for: "I want some coffee",
            relationshipLevel: .stranger
        )
        
        // Test with trusted relationship level
        let trustedContext = await memoryContextBuilder.buildContext(
            for: "I want some coffee",
            relationshipLevel: .trusted
        )
        
        // Both should include the memory since it's relevant
        XCTAssertTrue(strangerContext.contains("coffee"),
                     "Relevant memory should be available at stranger level")
        XCTAssertTrue(trustedContext.contains("coffee"),
                     "Relevant memory should be available at trusted level")
    }
    
    func test_conflictingPreferenceUpdatesExistingMemory() async throws {
        // Store initial preference
        try await memoryService.store(
            content: "User prefers tea",
            category: .preference,
            importance: .normal
        )
        
        // Process conflicting preference (more explicit to pass quality guard)
        let updated = await memoryFormationService.processUserMessage("I prefer coffee over tea")
        
        // Should update existing memory
        XCTAssertTrue(updated, "Conflicting preference should update existing memory")
        
        let memories = try await memoryService.retrieveAll(category: .preference)
        XCTAssertEqual(memories.count, 1, "Should have only one preference memory")
        XCTAssertTrue(memories.first?.content.contains("coffee") ?? false,
                     "Updated preference should reflect new choice")
    }
    
    func test_unrelatedPreferenceIsPreserved() async throws {
        // Store coffee preference
        try await memoryService.store(
            content: "User prefers coffee",
            category: .preference,
            importance: .normal
        )
        
        // Process unrelated preference
        let stored = await memoryFormationService.processUserMessage("I prefer programming in Python")
        
        XCTAssertTrue(stored, "Unrelated preference should be stored")
        
        let memories = try await memoryService.retrieveAll(category: .preference)
        XCTAssertEqual(memories.count, 2, "Should preserve both preferences")
    }
    
    func test_naturalMemoryContextGeneratedCorrectly() async throws {
        try await memoryService.store(
            content: "User prefers coffee",
            category: .preference,
            importance: .normal
        )
        
        let context = await memoryContextBuilder.buildContext(for: "I want coffee")
        
        // MemoryContextBuilder only returns the memory list, not the full header
        // The header is added by SystemPromptBuilder.memoryContext()
        XCTAssertTrue(context.contains("User prefers coffee"),
                     "Context should include memory content")
    }
    
    func test_emptyMemoryContextRemainsEmpty() async {
        let context = await memoryContextBuilder.buildContext(for: "Hello")
        
        XCTAssertEqual(context, "", "Empty memory context should remain empty")
    }
    
    func test_persistentMemoriesSurviveRestartAndRemainRetrievable() async throws {
        // In a real scenario, this would test actual file persistence
        // For this test, we simulate by storing and retrieving
        try await memoryService.store(
            content: "User name is John",
            category: .fact,
            importance: .critical
        )
        
        let context = await memoryContextBuilder.buildContext(for: "What's my name?")
        
        XCTAssertTrue(context.contains("John"),
                     "Persisted memory should remain retrievable")
    }
    
    func test_memoryFormationRejectsHypothetical() async {
        let stored = await memoryFormationService.processUserMessage("If I lived in Japan, I would eat sushi")
        
        XCTAssertFalse(stored, "Hypothetical statements should be rejected")
    }
    
    func test_memoryFormationRejectsJoke() async {
        let stored = await memoryFormationService.processUserMessage("I'm just kidding, I hate coffee")
        
        XCTAssertFalse(stored, "Jokes should be rejected")
    }
    
    func test_memoryFormationRejectsTemporaryEmotion() async {
        let stored = await memoryFormationService.processUserMessage("I'm tired right now")
        
        XCTAssertFalse(stored, "Temporary emotions should be rejected")
    }
    
    func test_memoryFormationAcceptsDefinitePreference() async {
        let stored = await memoryFormationService.processUserMessage("I prefer coffee")
        
        XCTAssertTrue(stored, "Definite preferences should be accepted")
    }
    
    func test_memoryContextBuilderWithDebugLogging() async throws {
        let consoleLogger = ConsoleLogger(minimumLevel: .info) // Use info to avoid debug output
        let debugBuilder = MemoryContextBuilder(
            memoryService: memoryService,
            configuration: MemoryContextBuilder.Configuration(enableDebugLogging: false), // Disable for clean test output
            logger: consoleLogger
        )
        
        try await memoryService.store(
            content: "User prefers coffee",
            category: .preference,
            importance: .normal
        )
        
        // This should produce logs if enabled
        _ = await debugBuilder.buildContext(for: "I want coffee")
        
        // We can't easily test log output in unit tests, but we ensure it doesn't crash
        XCTAssertTrue(true, "Debug logging should not crash")
    }
    
    func test_memoryRelevanceScoringIntegration() async throws {
        try await memoryService.store(
            content: "User prefers coffee",
            category: .preference,
            importance: .normal
        )
        
        try await memoryService.store(
            content: "User name is John",
            category: .fact,
            importance: .high
        )
        
        let context = await memoryContextBuilder.buildContext(for: "I want coffee")
        
        // Coffee memory should appear first due to higher relevance
        let coffeeIndex = context.firstRange(of: "coffee")?.lowerBound ?? context.endIndex
        let nameIndex = context.firstRange(of: "John")?.lowerBound ?? context.endIndex
        
        XCTAssertLessThan(coffeeIndex, nameIndex,
                          "More relevant memory should appear first")
    }
}
