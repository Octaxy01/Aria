import XCTest
@testable import AriaApplication
@testable import AriaDomain
@testable import AriaInfrastructure

final class ToolRuntimeIntegrationTests: XCTestCase {
    
    var coordinator: AssistantCoordinator!
    var mockLLM: MockLLMResponding!
    var conversation: ConversationService!
    var mockEmotionEngine: MockEmotionEngine!
    var mockRelationshipEngine: MockRelationshipEngine!
    var toolRegistry: ToolRegistry!
    var toolOrchestrator: ToolOrchestrator!
    var mockToolExecutor: RuntimeMockToolExecutor!
    var avatarStateManager: AvatarStateManager!
    
    override func setUp() async throws {
        try await super.setUp()
        
        mockLLM = MockLLMResponding()
        conversation = ConversationService()
        mockEmotionEngine = MockEmotionEngine()
        mockRelationshipEngine = MockRelationshipEngine()
        toolRegistry = ToolRegistry()
        mockToolExecutor = RuntimeMockToolExecutor()
        avatarStateManager = AvatarStateManager()
        
        // Register a test tool
        let testTool = ToolDefinition(
            identifier: ToolIdentifier("test_tool"),
            description: "Test tool",
            riskLevel: .safe,
            parameters: [
                ToolParameter(name: "param1", description: "Test parameter", isRequired: true, type: .string)
            ],
            requiresConfirmation: false,
            category: .system
        )
        
        try await toolRegistry.register(testTool)
        
        // Create tool orchestrator
        toolOrchestrator = ToolOrchestrator(
            toolRegistry: toolRegistry,
            toolExecutors: [ToolIdentifier("test_tool"): mockToolExecutor],
            logger: ConsoleLogger(minimumLevel: .info),
            maxToolRounds: 4
        )
        
        // Create coordinator with tool support
        coordinator = AssistantCoordinator(
            llm: mockLLM,
            conversation: conversation,
            emotionEngine: mockEmotionEngine,
            relationshipEngine: mockRelationshipEngine,
            toolOrchestrator: toolOrchestrator,
            toolRegistry: toolRegistry
        )
        
        await coordinator.setAvatarStateManager(avatarStateManager)
    }
    
    override func tearDown() async throws {
        coordinator = nil
        mockLLM = nil
        conversation = nil
        mockEmotionEngine = nil
        mockRelationshipEngine = nil
        toolRegistry = nil
        toolOrchestrator = nil
        mockToolExecutor = nil
        avatarStateManager = nil
        try await super.tearDown()
    }
    
    // MARK: - Normal Conversation Tests
    
    func testNormalConversationWithoutTools() async throws {
        mockLLM.responseToReturn = LLMResponse(
            text: "Hello! How can I help you?",
            emotionSignal: EmotionSignal(emotion: .happy, intensity: 0.5)
        )
        
        let result = try await coordinator.handleUserInput("Siapa kamu?")
        
        XCTAssertEqual(result.reply.content, "Hello! How can I help you?")
        XCTAssertFalse(mockToolExecutor.wasCalled)
        
        // Verify avatar state transitions
        let finalState = await avatarStateManager.state
        XCTAssertEqual(finalState, .talking)
    }
    
    // MARK: - Tool Success Tests
    
    func testSuccessfulToolConversation() async throws {
        // Set up LLM to request tool call
        let toolCall = ToolCall(
            toolIdentifier: ToolIdentifier("test_tool"),
            arguments: ["param1": "test_value"],
            sessionID: UUID()
        )
        
        mockLLM.responseToReturn = LLMResponse(
            text: "I'll help you with that.",
            emotionSignal: nil,
            toolCalls: [toolCall]
        )
        
        mockToolExecutor.resultToReturn = ToolResult.success(["status": "completed"])
        
        _ = try await coordinator.handleUserInput("Test tool request")
        
        XCTAssertTrue(mockToolExecutor.wasCalled)
        XCTAssertEqual(mockToolExecutor.lastCall?.toolIdentifier.rawValue, "test_tool")
        
        // Verify avatar state transitions
        let finalState = await avatarStateManager.state
        XCTAssertEqual(finalState, .talking)
    }
    
    // MARK: - Tool Failure Tests
    
    func testFailedToolConversation() async throws {
        let toolCall = ToolCall(
            toolIdentifier: ToolIdentifier("test_tool"),
            arguments: ["param1": "test_value"],
            sessionID: UUID()
        )
        
        mockLLM.responseToReturn = LLMResponse(
            text: "I'll help you with that.",
            emotionSignal: nil,
            toolCalls: [toolCall]
        )
        
        mockToolExecutor.resultToReturn = ToolResult.failure("Tool execution failed", errorCode: "test_error")
        
        let result = try await coordinator.handleUserInput("Test tool request")
        
        XCTAssertTrue(mockToolExecutor.wasCalled)
        // Should still return a response even if tool failed
        XCTAssertNotNil(result.reply.content)
    }
    
    // MARK: - Session Safety Tests
    
    func testSessionSafetyWithRapidRequests() async throws {
        mockLLM.responseToReturn = LLMResponse(
            text: "Response",
            emotionSignal: nil
        )
        
        // Send first request
        let task1 = Task {
            try await coordinator.handleUserInput("First request")
        }
        
        // Immediately send second request (should invalidate first)
        let task2 = Task {
            try await coordinator.handleUserInput("Second request")
        }
        
        let result2 = try await task2.value
        
        // Second request should complete successfully
        XCTAssertNotNil(result2.reply.content)
        
        // Cancel first task
        task1.cancel()
    }
    
    // MARK: - Avatar State Tests
    
    func testAvatarStateTransitionsDuringToolExecution() async throws {
        let toolCall = ToolCall(
            toolIdentifier: ToolIdentifier("test_tool"),
            arguments: ["param1": "test_value"],
            sessionID: UUID()
        )
        
        mockLLM.responseToReturn = LLMResponse(
            text: "Tool result",
            emotionSignal: nil,
            toolCalls: [toolCall]
        )
        
        mockToolExecutor.resultToReturn = ToolResult.success(["status": "done"])
        
        // Initial state should be idle
        let initialState = await avatarStateManager.state
        XCTAssertEqual(initialState, .idle)
        
        _ = try await coordinator.handleUserInput("Execute tool")
        
        // Final state should be talking
        let finalState = await avatarStateManager.state
        XCTAssertEqual(finalState, .talking)
    }
    
    // MARK: - Conversation History Tests
    
    func testConversationHistoryWithToolExecution() async throws {
        let toolCall = ToolCall(
            toolIdentifier: ToolIdentifier("test_tool"),
            arguments: ["param1": "test_value"],
            sessionID: UUID()
        )
        
        mockLLM.responseToReturn = LLMResponse(
            text: "Tool executed successfully",
            emotionSignal: nil,
            toolCalls: [toolCall]
        )
        
        mockToolExecutor.resultToReturn = ToolResult.success(["status": "done"])
        
        _ = try await coordinator.handleUserInput("Execute tool")
        
        let history = await conversation.recentHistory(maxMessages: 10)
        
        // Should have user message and assistant message
        XCTAssertGreaterThanOrEqual(history.count, 2)
        XCTAssertEqual(history.first?.role, .user)
        XCTAssertEqual(history.last?.role, .assistant)
    }
    
    // MARK: - Personality Integration Tests
    
    func testToolResponseUsesPersonality() async throws {
        let toolCall = ToolCall(
            toolIdentifier: ToolIdentifier("test_tool"),
            arguments: ["param1": "test_value"],
            sessionID: UUID()
        )
        
        mockLLM.responseToReturn = LLMResponse(
            text: "Oke, aku udah selesai ngerjain itu.",
            emotionSignal: EmotionSignal(emotion: .happy, intensity: 0.7),
            toolCalls: [toolCall]
        )
        
        mockToolExecutor.resultToReturn = ToolResult.success(["status": "done"])
        
        let result = try await coordinator.handleUserInput("Buka aplikasi")
        
        // Verify emotion state was updated
        XCTAssertNotNil(result.emotionState)
        XCTAssertTrue(mockEmotionEngine.wasCalled)
    }
}

// MARK: - Mock Classes

class MockLLMResponding: @unchecked Sendable, LLMResponding {
    var responseToReturn: LLMResponse = LLMResponse(text: "Default response")
    
    func respond(to request: LLMRequest) async throws -> LLMResponse {
        return responseToReturn
    }
}

class MockEmotionEngine: @unchecked Sendable, EmotionEngining {
    var wasCalled = false
    var lastSignal: EmotionSignal?
    
    func nextState(current: EmotionState, signal: EmotionSignal?) -> EmotionState {
        wasCalled = true
        lastSignal = signal
        return current
    }
}

class MockRelationshipEngine: @unchecked Sendable, RelationshipEvolving {
    var wasCalled = false
    
    func nextState(current: RelationshipState, tone: ConversationTone, emotionSignal: EmotionSignal?) async -> RelationshipState {
        wasCalled = true
        return current
    }
}

class RuntimeMockToolExecutor: @unchecked Sendable, ToolExecuting {
    var wasCalled = false
    var lastCall: ToolCall?
    var resultToReturn: ToolResult = ToolResult.success()
    
    func execute(_ call: ToolCall) async throws -> ToolResult {
        wasCalled = true
        lastCall = call
        return resultToReturn
    }
}
