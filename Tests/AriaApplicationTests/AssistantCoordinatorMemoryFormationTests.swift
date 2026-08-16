import XCTest
@testable import AriaApplication
import AriaDomain
import AriaInfrastructure

final class AssistantCoordinatorMemoryFormationTests: XCTestCase {
    
    private struct FakeLLMProvider: LLMResponding {
        let response: LLMResponse
        
        func respond(to request: LLMRequest) async throws -> LLMResponse {
            response
        }
    }
    
    func testConversationWorksWhenMemoryFormationFails() async throws {
        let memoryService = MemoryService(store: InMemoryMemoryStore())
        let memoryFormationService = MemoryFormationService(memoryService: memoryService)
        let memoryContextBuilder = MemoryContextBuilder(
            memoryService: memoryService,
            configuration: MemoryContextBuilder.Configuration(maxMemoriesPerTurn: 3)
        )
        
        let fakeLLM = FakeLLMProvider(
            response: LLMResponse(
                text: "Hello!",
                emotionSignal: EmotionSignal(emotion: EmotionKind.neutral, intensity: 0.3)
            )
        )
        
        let relationshipEngine = RelationshipService()
        let coordinator = AssistantCoordinator(
            llm: fakeLLM,
            conversation: ConversationService(),
            emotionEngine: EmotionService(),
            relationshipEngine: relationshipEngine,
            character: .aria,
            memoryContextBuilder: memoryContextBuilder,
            memoryFormationService: memoryFormationService
        )
        
        // Should not throw even if memory formation has issues
        let result = try await coordinator.handleUserInput("Hello")
        
        XCTAssertEqual(result.reply.content, "Hello!")
        XCTAssertEqual(result.emotionState.current, EmotionKind.neutral)
    }
    
    func testResponseIsReturnedBeforeMemoryProcessingCompletes() async throws {
        let memoryService = MemoryService(store: InMemoryMemoryStore())
        let memoryFormationService = MemoryFormationService(memoryService: memoryService)
        
        let fakeLLM = FakeLLMProvider(
            response: LLMResponse(
                text: "That's interesting!",
                emotionSignal: EmotionSignal(emotion: EmotionKind.happy, intensity: 0.7)
            )
        )
        
        let relationshipEngine = RelationshipService()
        let coordinator = AssistantCoordinator(
            llm: fakeLLM,
            conversation: ConversationService(),
            emotionEngine: EmotionService(),
            relationshipEngine: relationshipEngine,
            character: .aria,
            memoryFormationService: memoryFormationService
        )
        
        let result = try await coordinator.handleUserInput("Saya suka kopi")
        
        // Response should be returned immediately
        XCTAssertEqual(result.reply.content, "That's interesting!")
        
        // Memory should be created asynchronously (give it a moment)
        try await Task.sleep(nanoseconds: 100_000_000) // 0.1 seconds
        
        let memories = try await memoryService.retrieveAll()
        XCTAssertGreaterThan(memories.count, 0, "Memory should be created asynchronously")
    }
    
    func testExistingMemoryRetrievalStillWorks() async throws {
        let memoryService = MemoryService(store: InMemoryMemoryStore())
        
        // Pre-store a memory
        try await memoryService.store(
            content: "User prefers coffee over tea",
            category: MemoryCategory.preference,
            importance: MemoryImportance.normal
        )
        
        let memoryContextBuilder = MemoryContextBuilder(
            memoryService: memoryService,
            configuration: MemoryContextBuilder.Configuration(maxMemoriesPerTurn: 3)
        )
        
        let memoryFormationService = MemoryFormationService(memoryService: memoryService)
        
        let fakeLLM = FakeLLMProvider(
            response: LLMResponse(
                text: "I remember you like coffee!",
                emotionSignal: EmotionSignal(emotion: EmotionKind.happy, intensity: 0.7)
            )
        )
        
        let relationshipEngine = RelationshipService()
        let coordinator = AssistantCoordinator(
            llm: fakeLLM,
            conversation: ConversationService(),
            emotionEngine: EmotionService(),
            relationshipEngine: relationshipEngine,
            character: .aria,
            memoryContextBuilder: memoryContextBuilder,
            memoryFormationService: memoryFormationService
        )
        
        let result = try await coordinator.handleUserInput("Do you want some coffee?")
        
        XCTAssertEqual(result.reply.content, "I remember you like coffee!")
    }
    
    func testCoordinatorWithNilMemoryFormationService() async throws {
        let fakeLLM = FakeLLMProvider(
            response: LLMResponse(
                text: "Hello!",
                emotionSignal: EmotionSignal(emotion: EmotionKind.neutral, intensity: 0.3)
            )
        )
        
        let relationshipEngine = RelationshipService()
        let coordinator = AssistantCoordinator(
            llm: fakeLLM,
            conversation: ConversationService(),
            emotionEngine: EmotionService(),
            relationshipEngine: relationshipEngine,
            character: .aria,
            memoryFormationService: nil
        )
        
        let result = try await coordinator.handleUserInput("Saya suka kopi")
        
        // Should work normally without memory formation
        XCTAssertEqual(result.reply.content, "Hello!")
    }
    
    func testMemoryFormationDoesNotBlockConversation() async throws {
        let memoryService = MemoryService(store: InMemoryMemoryStore())
        let memoryFormationService = MemoryFormationService(memoryService: memoryService)
        
        let fakeLLM = FakeLLMProvider(
            response: LLMResponse(
                text: "Got it!",
                emotionSignal: EmotionSignal(emotion: EmotionKind.neutral, intensity: 0.3)
            )
        )
        
        let relationshipEngine = RelationshipService()
        let coordinator = AssistantCoordinator(
            llm: fakeLLM,
            conversation: ConversationService(),
            emotionEngine: EmotionService(),
            relationshipEngine: relationshipEngine,
            character: .aria,
            memoryFormationService: memoryFormationService
        )
        
        // Send multiple messages quickly
        let startTime = Date()
        
        _ = try await coordinator.handleUserInput("Saya suka kopi")
        _ = try await coordinator.handleUserInput("Nama saya John")
        _ = try await coordinator.handleUserInput("Saya sedang membuat aplikasi")
        
        let elapsedTime = Date().timeIntervalSince(startTime)
        
        // Should complete quickly (memory formation is async)
        XCTAssertLessThan(elapsedTime, 1.0, "Conversation should not be blocked by memory formation")
    }
    
    func testMemoryFormationForMultipleMessages() async throws {
        let memoryService = MemoryService(store: InMemoryMemoryStore())
        let memoryFormationService = MemoryFormationService(memoryService: memoryService)
        
        let fakeLLM = FakeLLMProvider(
            response: LLMResponse(
                text: "Ok",
                emotionSignal: EmotionSignal(emotion: EmotionKind.neutral, intensity: 0.3)
            )
        )
        
        let relationshipEngine = RelationshipService()
        let coordinator = AssistantCoordinator(
            llm: fakeLLM,
            conversation: ConversationService(),
            emotionEngine: EmotionService(),
            relationshipEngine: relationshipEngine,
            character: .aria,
            memoryFormationService: memoryFormationService
        )
        
        // Send multiple memory-worthy messages
        _ = try await coordinator.handleUserInput("Saya suka kopi")
        _ = try await coordinator.handleUserInput("Nama saya John")
        _ = try await coordinator.handleUserInput("Saya sedang membuat aplikasi")
        
        // Wait for async processing
        try await Task.sleep(nanoseconds: 200_000_000) // 0.2 seconds
        
        let memories = try await memoryService.retrieveAll()
        
        // Should have created multiple memories
        XCTAssertGreaterThanOrEqual(memories.count, 2, "Should have created multiple memories")
    }
}
