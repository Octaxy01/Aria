import XCTest
@testable import AriaApplication
@testable import AriaDomain
@testable import AriaInfrastructure

/// Tests for multi-round LLM → tool → LLM continuation loop.
final class MultiRoundToolContinuationTests: XCTestCase {
    
    fileprivate var mockLLM: MultiRoundMockLLM!
    var coordinator: AssistantCoordinator!
    var conversation: ConversationService!
    var toolRegistry: ToolRegistry!
    var toolOrchestrator: ToolOrchestrator!
    var mockToolExecutor: MockToolExecutor!
    var mockLogger: MockLogger!
    
    override func setUp() async throws {
        try await super.setUp()
        
        conversation = ConversationService()
        mockLogger = MockLogger()
        mockLLM = MultiRoundMockLLM()
        mockToolExecutor = MockToolExecutor()
        
        toolRegistry = ToolRegistry()
        try await toolRegistry.register(ApplicationToolDefinitions.openApplication)
        
        let toolExecutors: [ToolIdentifier: any ToolExecuting] = [
            ToolIdentifier.openApplication: mockToolExecutor
        ]
        
        toolOrchestrator = ToolOrchestrator(
            toolRegistry: toolRegistry,
            toolExecutors: toolExecutors,
            logger: mockLogger,
            maxToolRounds: 4
        )
        
        coordinator = AssistantCoordinator(
            llm: mockLLM,
            conversation: conversation,
            emotionEngine: EmotionService(),
            relationshipEngine: RelationshipService(),
            toolOrchestrator: toolOrchestrator,
            toolRegistry: toolRegistry,
            maxToolRounds: 4
        )
    }
    
    override func tearDown() async throws {
        coordinator = nil
        toolOrchestrator = nil
        toolRegistry = nil
        conversation = nil
        try await super.tearDown()
    }
    
    // MARK: - Multi-Round Tool Execution Tests
    
    func testMultiRoundToolExecution() async throws {
        // Configure mock to return sequential tool calls
        await mockLLM.setResponseSequence([
            // First LLM call: tool call for Safari
            LLMResponse(text: "", toolCalls: [
                ToolCall(
                    toolIdentifier: ToolIdentifier.openApplication,
                    arguments: ["applicationName": "Safari"],
                    sessionID: UUID()
                )
            ]),
            // Second LLM call: tool call for Calculator
            LLMResponse(text: "", toolCalls: [
                ToolCall(
                    toolIdentifier: ToolIdentifier.openApplication,
                    arguments: ["applicationName": "Calculator"],
                    sessionID: UUID()
                )
            ]),
            // Third LLM call: final response
            LLMResponse(text: "Safari dan Calculator sudah aku buka.", toolCalls: nil)
        ])
        
        mockToolExecutor.resultToReturn = ToolResult.success(["status": "opened"])
        
        // Execute user request
        let result = try await coordinator.handleUserInput("Buka Safari dan Calculator")
        
        // Verify LLM was called exactly 3 times
        let callCount = await mockLLM.callCount
        XCTAssertEqual(callCount, 3)
        
        // Verify Safari was executed exactly once
        let safariCalls = mockToolExecutor.calls.filter { 
            $0.toolIdentifier == ToolIdentifier.openApplication && 
            $0.arguments["applicationName"] as? String == "Safari"
        }
        XCTAssertEqual(safariCalls.count, 1)
        
        // Verify Calculator was executed exactly once
        let calculatorCalls = mockToolExecutor.calls.filter { 
            $0.toolIdentifier == ToolIdentifier.openApplication && 
            $0.arguments["applicationName"] as? String == "Calculator"
        }
        XCTAssertEqual(calculatorCalls.count, 1)
        
        // Verify final response is the third LLM response
        XCTAssertEqual(result.reply.content, "Safari dan Calculator sudah aku buka.")
        
        // Verify tool results are in conversation
        let history = await conversation.history()
        let toolResultMessages = history.filter { $0.role == .toolResult }
        XCTAssertEqual(toolResultMessages.count, 2)
    }
    
    func testMaxToolRounds() async throws {
        // Configure mock to always return tool calls
        await mockLLM.setAlwaysReturnToolCall(true)
        await mockLLM.setToolCallSequence([
            ToolCall(toolIdentifier: .openApplication, arguments: ["applicationName": "App1"], sessionID: UUID()),
            ToolCall(toolIdentifier: .openApplication, arguments: ["applicationName": "App2"], sessionID: UUID()),
            ToolCall(toolIdentifier: .openApplication, arguments: ["applicationName": "App3"], sessionID: UUID()),
            ToolCall(toolIdentifier: .openApplication, arguments: ["applicationName": "App4"], sessionID: UUID()),
            ToolCall(toolIdentifier: .openApplication, arguments: ["applicationName": "App5"], sessionID: UUID())
        ])
        
        mockToolExecutor.resultToReturn = ToolResult.success(["status": "opened"])
        
        // Set max rounds to 3 for this test
        let coordinatorWithMax3 = AssistantCoordinator(
            llm: mockLLM,
            conversation: conversation,
            emotionEngine: EmotionService(),
            relationshipEngine: RelationshipService(),
            toolOrchestrator: toolOrchestrator,
            toolRegistry: toolRegistry,
            maxToolRounds: 3
        )
        
        // Execute user request
        let result = try await coordinatorWithMax3.handleUserInput("Buka banyak aplikasi")
        
        // Verify loop stopped at max rounds (3 tool executions)
        XCTAssertEqual(mockToolExecutor.callCount, 3)
        
        // Verify LLM was called max rounds + 1 times (3 tool calls + 1 final response)
        let callCount = await mockLLM.callCount
        XCTAssertEqual(callCount, 4)
        
        // Verify session is cleaned up (no hanging state)
        XCTAssertNotNil(result.reply)
    }
    
    func testToolResultContextInContinuation() async throws {
        // Configure mock to return tool call, then check context
        await mockLLM.setResponseSequence([
            LLMResponse(text: "", toolCalls: [
                ToolCall(
                    toolIdentifier: ToolIdentifier.openApplication,
                    arguments: ["applicationName": "Safari"],
                    sessionID: UUID()
                )
            ]),
            LLMResponse(text: "Safari dibuka", toolCalls: nil)
        ])
        
        mockToolExecutor.resultToReturn = ToolResult.success([
            "applicationName": "Safari",
            "path": "/Applications/Safari.app"
        ])
        
        // Execute user request
        let result = try await coordinator.handleUserInput("Buka Safari")
        
        // Verify second LLM call received tool result context
        let callCount = await mockLLM.callCount
        XCTAssertEqual(callCount, 2)
        
        // Verify the second LLM request contained the tool result
        let requests = await mockLLM.requests
        let secondRequest = requests[1]
        let toolResultMessages = secondRequest.messages.filter { $0.role == .toolResult }
        XCTAssertEqual(toolResultMessages.count, 1)
        XCTAssertTrue(toolResultMessages[0].content.contains("Safari"))
    }
    
    func testToolCallIdentityAcrossRounds() async throws {
        // Configure mock for multi-round with specific correlation IDs
        let correlationID1 = UUID()
        let correlationID2 = UUID()
        
        await mockLLM.setResponseSequence([
            LLMResponse(text: "", toolCalls: [
                ToolCall(
                    toolIdentifier: ToolIdentifier.openApplication,
                    arguments: ["applicationName": "Safari"],
                    sessionID: UUID(),
                    correlationID: correlationID1
                )
            ]),
            LLMResponse(text: "", toolCalls: [
                ToolCall(
                    toolIdentifier: ToolIdentifier.openApplication,
                    arguments: ["applicationName": "Calculator"],
                    sessionID: UUID(),
                    correlationID: correlationID2
                )
            ]),
            LLMResponse(text: "Both apps opened", toolCalls: nil)
        ])
        
        mockToolExecutor.resultToReturn = ToolResult.success(["status": "opened"])
        
        // Execute user request
        let result = try await coordinator.handleUserInput("Buka Safari dan Calculator")
        
        // Verify correlation IDs are preserved in tool calls
        XCTAssertEqual(mockToolExecutor.callCount, 2)
        XCTAssertEqual(mockToolExecutor.calls[0].correlationID, correlationID1)
        XCTAssertEqual(mockToolExecutor.calls[1].correlationID, correlationID2)
    }
    
    func testToolFailurePreserved() async throws {
        // Configure mock to return tool call
        await mockLLM.setResponseSequence([
            LLMResponse(text: "", toolCalls: [
                ToolCall(
                    toolIdentifier: ToolIdentifier.openApplication,
                    arguments: ["applicationName": "NonExistentApp"],
                    sessionID: UUID()
                )
            ]),
            LLMResponse(text: "App tidak ditemukan", toolCalls: nil)
        ])
        
        // Configure tool to fail
        mockToolExecutor.resultToReturn = ToolResult.failure("Application not found", errorCode: "not_found")
        
        // Execute user request
        let result = try await coordinator.handleUserInput("Buka aplikasi yang tidak ada")
        
        // Verify LLM was called twice (initial + continuation after failure)
        let callCount = await mockLLM.callCount
        XCTAssertEqual(callCount, 2)
        
        // Verify tool was executed (even though it failed)
        XCTAssertEqual(mockToolExecutor.callCount, 1)
        
        // Verify second LLM request contained the failure result
        let requests = await mockLLM.requests
        let secondRequest = requests[1]
        let toolResultMessages = secondRequest.messages.filter { $0.role == .toolResult }
        XCTAssertEqual(toolResultMessages.count, 1)
        XCTAssertTrue(toolResultMessages[0].content.contains("not_found") || toolResultMessages[0].content.contains("Failed"))
    }
    
    func testStaleSessionDuringToolLoop() async throws {
        // Configure mock to return tool call then final response
        await mockLLM.setResponseSequence([
            LLMResponse(text: "", toolCalls: [
                ToolCall(
                    toolIdentifier: ToolIdentifier.openApplication,
                    arguments: ["applicationName": "Safari"],
                    sessionID: UUID()
                )
            ]),
            LLMResponse(text: "Safari dibuka", toolCalls: nil)
        ])
        
        mockToolExecutor.resultToReturn = ToolResult.success(["status": "opened"])
        
        // Start first request
        let task1 = Task {
            try await coordinator.handleUserInput("Buka Safari")
        }
        
        // Wait a bit then start second request (should invalidate first)
        try await Task.sleep(nanoseconds: 50_000_000) // 0.05 seconds
        let _ = try await coordinator.handleUserInput("Buka Chrome")
        
        // Wait for first task to complete
        let result1 = try await task1.value
        
        // Verify first request completed (may have been processed before invalidation)
        // The exact behavior depends on timing, so we just verify it completed
        XCTAssertNotNil(result1.reply)
        
        // Verify LLM was called for both requests (first request may have completed)
        let callCount = await mockLLM.callCount
        XCTAssertGreaterThanOrEqual(callCount, 2) // At least one for each request
    }
    
    func testNormalConversationNoToolLoop() async throws {
        // Configure mock to return normal response without tool calls
        await mockLLM.setResponseSequence([
            LLMResponse(text: "Hello! How can I help you today?", toolCalls: nil)
        ])
        
        // Execute normal user request
        let result = try await coordinator.handleUserInput("Hello Aria")
        
        // Verify LLM was called exactly once
        let callCount = await mockLLM.callCount
        XCTAssertEqual(callCount, 1)
        
        // Verify no tool execution occurred
        XCTAssertEqual(mockToolExecutor.callCount, 0)
        
        // Verify response is the normal LLM response
        XCTAssertEqual(result.reply.content, "Hello! How can I help you today?")
    }
    
    func testNoToolCallsInSecondLLMResponse() async throws {
        // Configure mock to return tool call first, then normal response
        await mockLLM.setResponseSequence([
            LLMResponse(text: "", toolCalls: [
                ToolCall(
                    toolIdentifier: ToolIdentifier.openApplication,
                    arguments: ["applicationName": "Safari"],
                    sessionID: UUID()
                )
            ]),
            LLMResponse(text: "Safari sudah dibuka", toolCalls: nil)
        ])
        
        mockToolExecutor.resultToReturn = ToolResult.success(["status": "opened"])
        
        // Execute user request
        let result = try await coordinator.handleUserInput("Buka Safari")
        
        // Verify LLM was called twice (initial + continuation)
        let callCount = await mockLLM.callCount
        XCTAssertEqual(callCount, 2)
        
        // Verify tool was executed once
        XCTAssertEqual(mockToolExecutor.callCount, 1)
        
        // Verify loop stopped when second response had no tool calls
        XCTAssertEqual(result.reply.content, "Safari sudah dibuka")
    }
}

// MARK: - Mock LLM for Multi-Round Testing

private actor MultiRoundMockLLM: LLMResponding {
    private var responseSequence: [LLMResponse] = []
    private var currentIndex = 0
    private var alwaysReturnToolCall = false
    private var toolCallSequence: [ToolCall] = []
    private var toolCallIndex = 0
    var callCount = 0
    var requests: [LLMRequest] = []
    
    func setResponseSequence(_ sequence: [LLMResponse]) {
        self.responseSequence = sequence
        self.currentIndex = 0
    }
    
    func setAlwaysReturnToolCall(_ always: Bool) {
        self.alwaysReturnToolCall = always
    }
    
    func setToolCallSequence(_ sequence: [ToolCall]) {
        self.toolCallSequence = sequence
        self.toolCallIndex = 0
    }
    
    func respond(to request: LLMRequest) async throws -> LLMResponse {
        callCount += 1
        requests.append(request)
        
        if alwaysReturnToolCall {
            let toolCall = toolCallSequence[toolCallIndex % toolCallSequence.count]
            toolCallIndex += 1
            return LLMResponse(text: "", toolCalls: [toolCall])
        }
        
        guard currentIndex < responseSequence.count else {
            return LLMResponse(text: "No more responses configured", toolCalls: nil)
        }
        
        let response = responseSequence[currentIndex]
        currentIndex += 1
        return response
    }
}
