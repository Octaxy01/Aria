import XCTest
@testable import AriaApplication
@testable import AriaDomain
@testable import AriaInfrastructure

private struct FakeLLMProvider: LLMResponding {
    let response: LLMResponse

    func respond(to request: LLMRequest) async throws -> LLMResponse {
        response
    }
}

private struct FailingLLMProvider: LLMResponding {
    struct Boom: Error {}
    func respond(to request: LLMRequest) async throws -> LLMResponse {
        throw Boom()
    }
}

private struct DelayedLLMProvider: LLMResponding {
    let response: LLMResponse
    let delay: TimeInterval
    
    func respond(to request: LLMRequest) async throws -> LLMResponse {
        try await Task.sleep(nanoseconds: UInt64(delay * 1_000_000_000))
        return response
    }
}

private struct EmptyResponseLLMProvider: LLMResponding {
    func respond(to request: LLMRequest) async throws -> LLMResponse {
        return LLMResponse(text: "", emotionSignal: EmotionSignal(emotion: .neutral, intensity: 0.3))
    }
}

private struct NetworkErrorLLMProvider: LLMResponding {
    func respond(to request: LLMRequest) async throws -> LLMResponse {
        throw OpenRouterProviderError.network
    }
}

private struct RateLimitLLMProvider: LLMResponding {
    func respond(to request: LLMRequest) async throws -> LLMResponse {
        throw OpenRouterProviderError.rateLimited
    }
}

/// An actor (not a struct) so it can safely accumulate every request it
/// receives across calls — used to assert that conversation context is
/// actually being sent to the provider, and that it's being trimmed by
/// `maxContextMessages`.
private actor RecordingLLMProvider: LLMResponding {
    private(set) var capturedRequests: [LLMRequest] = []
    private let response: LLMResponse

    init(response: LLMResponse) {
        self.response = response
    }

    func respond(to request: LLMRequest) async throws -> LLMResponse {
        capturedRequests.append(request)
        return response
    }
}

final class AssistantCoordinatorTests: XCTestCase {
    func testHandleUserInputProducesReplyAndUpdatesEmotion() async throws {
        let fakeLLM = FakeLLMProvider(
            response: LLMResponse(
                text: "hi there",
                emotionSignal: EmotionSignal(emotion: .happy, intensity: 0.8)
            )
        )
        let relationshipEngine = RelationshipService()
        let coordinator = AssistantCoordinator(
            llm: fakeLLM,
            conversation: ConversationService(),
            emotionEngine: EmotionService(),
            relationshipEngine: relationshipEngine,
            character: .aria
        )

        let turn = try await coordinator.handleUserInput("hello aria")

        XCTAssertEqual(turn.reply.role, ConversationRole.assistant)
        XCTAssertEqual(turn.reply.content, "hi there")
        XCTAssertEqual(turn.emotionState.current, EmotionKind.happy)
        XCTAssertEqual(turn.emotionState.intensity, 0.8, accuracy: 0.0001)
    }

    func testLLMFailureIsMappedToAriaError() async {
        let relationshipEngine = RelationshipService()
        let coordinator = AssistantCoordinator(
            llm: FailingLLMProvider(),
            conversation: ConversationService(),
            emotionEngine: EmotionService(),
            relationshipEngine: relationshipEngine,
            character: .aria
        )

        // After the change, this should NOT throw - it should return a graceful fallback
        do {
            let result = try await coordinator.handleUserInput("hello")
            // Should return a graceful fallback response
            XCTAssertFalse(result.reply.content.isEmpty)
        } catch {
            XCTFail("Expected graceful fallback instead of error: \(error)")
        }
    }

    func testConversationHistoryIsSentToProvider() async throws {
        let recorder = RecordingLLMProvider(response: LLMResponse(text: "ok"))
        let relationshipEngine = RelationshipService()
        let coordinator = AssistantCoordinator(
            llm: recorder,
            conversation: ConversationService(),
            emotionEngine: EmotionService(),
            relationshipEngine: relationshipEngine,
            character: .aria
        )

        _ = try await coordinator.handleUserInput("first message")
        _ = try await coordinator.handleUserInput("second message")

        let requests = await recorder.capturedRequests
        XCTAssertEqual(requests.count, 2)

        // Second request should include the first turn's user + assistant
        // messages plus the new user message.
        let secondRequest = requests[1]
        XCTAssertEqual(secondRequest.messages.count, 3)
        XCTAssertEqual(secondRequest.messages[0].content, "first message")
        XCTAssertEqual(secondRequest.messages[1].content, "ok")
        XCTAssertEqual(secondRequest.messages[2].content, "second message")
        XCTAssertNotNil(secondRequest.systemContext)
        XCTAssertTrue(secondRequest.systemContext?.contains("Aria") ?? false)
    }

    func testContextIsTrimmedToMaxContextMessages() async throws {
        let recorder = RecordingLLMProvider(response: LLMResponse(text: "ok"))
        let relationshipEngine = RelationshipService()
        let coordinator = AssistantCoordinator(
            llm: recorder,
            conversation: ConversationService(),
            emotionEngine: EmotionService(),
            relationshipEngine: relationshipEngine,
            character: .aria,
            maxContextMessages: 3
        )

        for i in 1...5 {
            _ = try await coordinator.handleUserInput("message \(i)")
        }

        let requests = await recorder.capturedRequests
        let lastRequest = try XCTUnwrap(requests.last)
        XCTAssertLessThanOrEqual(lastRequest.messages.count, 3)
    }
    
    // MARK: - Runtime Session Management Tests
    
    func testRapidInputHandlesStaleRequests() async throws {
        let delayedLLM = DelayedLLMProvider(
            response: LLMResponse(text: "slow response"),
            delay: 0.3
        )
        let relationshipEngine = RelationshipService()
        let coordinator = AssistantCoordinator(
            llm: delayedLLM,
            conversation: ConversationService(),
            emotionEngine: EmotionService(),
            relationshipEngine: relationshipEngine,
            character: .aria
        )
        
        // Start first request (will be delayed)
        let task1 = Task {
            try await coordinator.handleUserInput("first message")
        }
        
        // Wait a bit then send second request (should invalidate first)
        try await Task.sleep(nanoseconds: 50_000_000) // 50ms
        let task2 = Task {
            try await coordinator.handleUserInput("second message")
        }
        
        // The second request should complete successfully
        let result2 = try await task2.value
        XCTAssertEqual(result2.reply.content, "slow response")
        
        // Cancel the first task
        task1.cancel()
    }
    
    func testEmptyResponseUsesFallback() async throws {
        let emptyLLM = EmptyResponseLLMProvider()
        let relationshipEngine = RelationshipService()
        let coordinator = AssistantCoordinator(
            llm: emptyLLM,
            conversation: ConversationService(),
            emotionEngine: EmotionService(),
            relationshipEngine: relationshipEngine,
            character: .aria,
            languageSettings: LanguageSettings(outputLanguage: .english)
        )
        
        let result = try await coordinator.handleUserInput("test message")
        
        // Should return a fallback response, not empty
        XCTAssertFalse(result.reply.content.isEmpty)
        XCTAssertTrue(result.reply.content.contains("Sorry"))
        
        // History should have the fallback assistant message
        let history = await coordinator.currentConversationHistory()
        XCTAssertGreaterThanOrEqual(history.count, 2) // user + assistant fallback
        XCTAssertEqual(history[0].role, .user)
        XCTAssertEqual(history[1].role, .assistant)
    }
    
    func testNetworkErrorReturnsGracefulFallback() async throws {
        let networkLLM = NetworkErrorLLMProvider()
        let relationshipEngine = RelationshipService()
        let coordinator = AssistantCoordinator(
            llm: networkLLM,
            conversation: ConversationService(),
            emotionEngine: EmotionService(),
            relationshipEngine: relationshipEngine,
            character: .aria,
            languageSettings: LanguageSettings(outputLanguage: .english)
        )
        
        let result = try await coordinator.handleUserInput("test message")
        
        // Should return a graceful fallback response
        XCTAssertFalse(result.reply.content.isEmpty)
        // Network error fallback contains "connection" 
        XCTAssertTrue(result.reply.content.contains("connection") || result.reply.content.contains("Sorry"))
        
        // History should have the fallback assistant message
        let history = await coordinator.currentConversationHistory()
        XCTAssertGreaterThanOrEqual(history.count, 2) // user + assistant fallback
    }
    
    func testRateLimitErrorReturnsGracefulFallback() async throws {
        let rateLimitLLM = RateLimitLLMProvider()
        let relationshipEngine = RelationshipService()
        let coordinator = AssistantCoordinator(
            llm: rateLimitLLM,
            conversation: ConversationService(),
            emotionEngine: EmotionService(),
            relationshipEngine: relationshipEngine,
            character: .aria,
            languageSettings: LanguageSettings(outputLanguage: .english)
        )
        
        let result = try await coordinator.handleUserInput("test message")
        
        // Should return a graceful fallback response
        XCTAssertFalse(result.reply.content.isEmpty)
        // Rate limit fallback contains "request limit"
        XCTAssertTrue(result.reply.content.contains("request limit") || result.reply.content.contains("Sorry"))
        
        // History should have the fallback assistant message
        let history = await coordinator.currentConversationHistory()
        XCTAssertGreaterThanOrEqual(history.count, 2) // user + assistant fallback
    }
    
    func testLLMFailureReturnsGracefulFallback() async throws {
        let failingLLM = FailingLLMProvider()
        let relationshipEngine = RelationshipService()
        let coordinator = AssistantCoordinator(
            llm: failingLLM,
            conversation: ConversationService(),
            emotionEngine: EmotionService(),
            relationshipEngine: relationshipEngine,
            character: .aria
        )
        
        // This should NOT throw anymore - it should return a graceful fallback
        let result = try await coordinator.handleUserInput("test message")
        
        // Should return a graceful fallback response
        XCTAssertFalse(result.reply.content.isEmpty)
        
        // History should have the fallback assistant message
        let history = await coordinator.currentConversationHistory()
        XCTAssertGreaterThanOrEqual(history.count, 2) // user + assistant fallback
    }
    
    func testClearConversationResetsState() async throws {
        let fakeLLM = FakeLLMProvider(
            response: LLMResponse(
                text: "hi there",
                emotionSignal: EmotionSignal(emotion: .happy, intensity: 0.8)
            )
        )
        let relationshipEngine = RelationshipService()
        let coordinator = AssistantCoordinator(
            llm: fakeLLM,
            conversation: ConversationService(),
            emotionEngine: EmotionService(),
            relationshipEngine: relationshipEngine,
            character: .aria
        )
        
        // Have a conversation
        _ = try await coordinator.handleUserInput("first message")
        _ = try await coordinator.handleUserInput("second message")
        
        let historyBefore = await coordinator.currentConversationHistory()
        XCTAssertGreaterThanOrEqual(historyBefore.count, 4) // 2 user + 2 assistant
        
        // Clear conversation
        await coordinator.clearConversation()
        
        let historyAfter = await coordinator.currentConversationHistory()
        XCTAssertEqual(historyAfter.count, 0)
        
        // Should be able to have a new conversation
        let result = try await coordinator.handleUserInput("new message")
        XCTAssertEqual(result.reply.content, "hi there")
        
        let historyNew = await coordinator.currentConversationHistory()
        XCTAssertGreaterThanOrEqual(historyNew.count, 2) // user + assistant
    }
    
    func testRuntimeStatusReflectsActualState() async throws {
        let fakeLLM = FakeLLMProvider(
            response: LLMResponse(
                text: "hi there",
                emotionSignal: EmotionSignal(emotion: .happy, intensity: 0.8)
            )
        )
        let relationshipEngine = RelationshipService()
        let coordinator = AssistantCoordinator(
            llm: fakeLLM,
            conversation: ConversationService(),
            emotionEngine: EmotionService(),
            relationshipEngine: relationshipEngine,
            character: .aria
        )
        
        // Add avatar state manager for testing
        let avatarStateManager = AvatarStateManager()
        await coordinator.setAvatarStateManager(avatarStateManager)
        
        // Check initial status
        let initialStatus = await coordinator.getRuntimeStatus()
        XCTAssertEqual(initialStatus.conversationState, "idle")
        XCTAssertEqual(initialStatus.avatarState, .idle)
        XCTAssertFalse(initialStatus.hasActiveRequest)
        XCTAssertNil(initialStatus.currentRequestID)
        
        // Handle input
        let result = try await coordinator.handleUserInput("test message")
        XCTAssertEqual(result.reply.content, "hi there")
        
        // Check status after completion
        let finalStatus = await coordinator.getRuntimeStatus()
        XCTAssertEqual(finalStatus.conversationState, "idle")
        XCTAssertFalse(finalStatus.hasActiveRequest)
        XCTAssertNil(finalStatus.currentRequestID)
    }
    
    func testAvatarStateIntegration() async throws {
        let fakeLLM = FakeLLMProvider(
            response: LLMResponse(
                text: "hi there",
                emotionSignal: EmotionSignal(emotion: .happy, intensity: 0.8)
            )
        )
        let relationshipEngine = RelationshipService()
        let coordinator = AssistantCoordinator(
            llm: fakeLLM,
            conversation: ConversationService(),
            emotionEngine: EmotionService(),
            relationshipEngine: relationshipEngine,
            character: .aria
        )
        
        let avatarStateManager = AvatarStateManager()
        await coordinator.setAvatarStateManager(avatarStateManager)
        
        // Initial state should be idle
        let initialState = await avatarStateManager.state
        XCTAssertEqual(initialState, .idle)
        
        // Handle input - should transition to thinking
        _ = try await coordinator.handleUserInput("test message")
        
        // After completion, should be in talking state (set by coordinator)
        let finalState = await avatarStateManager.state
        XCTAssertEqual(finalState, .talking)
    }
}
