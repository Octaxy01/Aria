import XCTest
@testable import AriaApplication
import AriaDomain
import AriaInfrastructure

/// Tests for memory integration in AssistantCoordinator
final class AssistantCoordinatorMemoryIntegrationTests: XCTestCase {
    
    private struct FakeLLMProvider: LLMResponding {
        let response: LLMResponse
        
        func respond(to request: LLMRequest) async throws -> LLMResponse {
            response
        }
    }
    
    func testAssistantCoordinatorPassesMemoryContextIntoPromptGeneration() async throws {
        let memoryService = MemoryService(store: InMemoryMemoryStore())
        try await memoryService.store(content: "User prefers coffee over tea", category: MemoryCategory.preference, importance: MemoryImportance.normal)
        
        let memoryContextBuilder = MemoryContextBuilder(
            memoryService: memoryService,
            configuration: MemoryContextBuilder.Configuration(maxMemoriesPerTurn: 3)
        )
        
        let fakeLLM = FakeLLMProvider(
            response: LLMResponse(
                text: "I remember you like coffee!",
                emotionSignal: EmotionSignal(emotion: EmotionKind.happy, intensity: 0.7)
            )
        )
        
        let relationshipEngine = RelationshipService()
        _ = AssistantCoordinator(
            llm: fakeLLM,
            conversation: ConversationService(),
            emotionEngine: EmotionService(),
            relationshipEngine: relationshipEngine,
            character: .aria,
            memoryContextBuilder: memoryContextBuilder
        )
        
        // Capture the actual request sent to the LLM
        let requestCapturingLLM = RequestCapturingLLMProvider(response: fakeLLM.response)
        let capturingCoordinator = AssistantCoordinator(
            llm: requestCapturingLLM,
            conversation: ConversationService(),
            emotionEngine: EmotionService(),
            relationshipEngine: relationshipEngine,
            character: .aria,
            memoryContextBuilder: memoryContextBuilder
        )
        
        _ = try await capturingCoordinator.handleUserInput("Do you want some coffee?")
        
        let capturedRequest = await requestCapturingLLM.capturedRequest
        XCTAssertNotNil(capturedRequest, "Should have captured the LLM request")
        XCTAssertNotNil(capturedRequest?.systemContext, "Request should have system context")
        
        let systemContext = capturedRequest!.systemContext!
        XCTAssertTrue(systemContext.contains("RELEVANT MEMORY"), "System context should contain memory section")
        XCTAssertTrue(systemContext.contains("coffee"), "System context should contain the search term")
    }
    
    func testMemoryRetrievalFailureDoesNotBreakConversation() async throws {
        let memoryService = MemoryService(store: InMemoryMemoryStore())
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
            memoryContextBuilder: memoryContextBuilder
        )
        
        // Should not throw even with empty memory service
        let result = try await coordinator.handleUserInput("Hello")
        
        XCTAssertEqual(result.reply.content, "Hello!")
        XCTAssertEqual(result.emotionState.current, EmotionKind.neutral)
    }
    
    func testCoordinatorWithNilMemoryContextBuilder() async throws {
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
            memoryContextBuilder: nil
        )
        
        let result = try await coordinator.handleUserInput("Hello")
        
        XCTAssertEqual(result.reply.content, "Hello!")
        XCTAssertEqual(result.emotionState.current, EmotionKind.neutral)
    }
    
    func testExistingConversationHistoryBehaviorRemainsUnchanged() async throws {
        let requestCapturingLLM = RequestCapturingLLMProvider(
            response: LLMResponse(
                text: "ok",
                emotionSignal: EmotionSignal(emotion: EmotionKind.neutral, intensity: 0.3)
            )
        )
        
        let relationshipEngine = RelationshipService()
        let coordinator = AssistantCoordinator(
            llm: requestCapturingLLM,
            conversation: ConversationService(),
            emotionEngine: EmotionService(),
            relationshipEngine: relationshipEngine,
            character: .aria,
            memoryContextBuilder: nil
        )
        
        _ = try await coordinator.handleUserInput("first message")
        _ = try await coordinator.handleUserInput("second message")
        
        let requests = await requestCapturingLLM.capturedRequests
        XCTAssertEqual(requests.count, 2)
        
        // Second request should include the first turn's user + assistant messages plus the new user message
        let secondRequest = requests[1]
        XCTAssertEqual(secondRequest.messages.count, 3)
        XCTAssertEqual(secondRequest.messages[0].content, "first message")
        XCTAssertEqual(secondRequest.messages[1].content, "ok")
        XCTAssertEqual(secondRequest.messages[2].content, "second message")
        XCTAssertNotNil(secondRequest.systemContext)
    }
    
    func testMemoryContextIsOnlyAddedWhenMemoriesExist() async throws {
        let memoryService = MemoryService(store: InMemoryMemoryStore())
        let memoryContextBuilder = MemoryContextBuilder(
            memoryService: memoryService,
            configuration: MemoryContextBuilder.Configuration(maxMemoriesPerTurn: 3)
        )
        
        let requestCapturingLLM = RequestCapturingLLMProvider(
            response: LLMResponse(
                text: "Hello!",
                emotionSignal: EmotionSignal(emotion: EmotionKind.neutral, intensity: 0.3)
            )
        )
        
        let relationshipEngine = RelationshipService()
        let coordinator = AssistantCoordinator(
            llm: requestCapturingLLM,
            conversation: ConversationService(),
            emotionEngine: EmotionService(),
            relationshipEngine: relationshipEngine,
            character: .aria,
            memoryContextBuilder: memoryContextBuilder
        )
        
        _ = try await coordinator.handleUserInput("Hello")
        
        let capturedRequest = await requestCapturingLLM.capturedRequest
        let systemContext = capturedRequest!.systemContext!
        
        // Should not contain memory section when no memories exist
        XCTAssertFalse(systemContext.contains("RELEVANT MEMORY"), "Should not contain memory section when no memories exist")
    }
    
    // MARK: - Helper Types
    
    private actor RequestCapturingLLMProvider: LLMResponding {
        private(set) var capturedRequests: [LLMRequest] = []
        private let response: LLMResponse
        
        init(response: LLMResponse) {
            self.response = response
        }
        
        func respond(to request: LLMRequest) async throws -> LLMResponse {
            capturedRequests.append(request)
            return response
        }
        
        var capturedRequest: LLMRequest? {
            capturedRequests.last
        }
    }
}
