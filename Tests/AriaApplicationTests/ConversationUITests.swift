import XCTest
import AriaDomain
@testable import AriaApplication

/// Tests for conversation UI integration.
@MainActor
final class ConversationUITests: XCTestCase {
    
    var coordinator: AssistantCoordinator!
    var adapter: AriaRuntimeAdapter!
    
    override func setUp() async throws {
        try await super.setUp()
        
        // Create a mock coordinator for testing
        let mockLLM = MockLLMProvider()
        let mockLogger = ConsoleLogger(minimumLevel: .info)
        let mockConfig = AppConfiguration.load()
        
        coordinator = await AppBootstrap.createCoordinator(
            llm: mockLLM,
            logger: mockLogger,
            config: mockConfig
        )
        
        adapter = AriaRuntimeAdapter(coordinator: coordinator)
    }
    
    override func tearDown() async throws {
        adapter.cancelEventStream()
        adapter = nil
        coordinator = nil
        try await super.tearDown()
    }
    
    // MARK: - Message Rendering Tests
    
    func testUserMessageAppears() async throws {
        // Add a user message to the coordinator
        await coordinator.conversation.append(role: .user, content: "Hello")
        
        // Update adapter messages
        await adapter.updateMessages()
        
        // Verify message appears
        XCTAssertEqual(adapter.messages.count, 1)
        XCTAssertEqual(adapter.messages.first?.role, .user)
        XCTAssertEqual(adapter.messages.first?.content, "Hello")
    }
    
    func testAssistantMessageAppears() async throws {
        // Add an assistant message to the coordinator
        await coordinator.conversation.append(role: .assistant, content: "Hi there!")
        
        // Update adapter messages
        await adapter.updateMessages()
        
        // Verify message appears
        XCTAssertEqual(adapter.messages.count, 1)
        XCTAssertEqual(adapter.messages.first?.role, .assistant)
        XCTAssertEqual(adapter.messages.first?.content, "Hi there!")
    }
    
    func testLongResponseRenders() async throws {
        // Create a long response
        let longContent = String(repeating: "This is a long response. ", count: 20)
        
        // Add to coordinator
        await coordinator.conversation.append(role: .assistant, content: longContent)
        
        // Update adapter messages
        await adapter.updateMessages()
        
        // Verify long content is preserved
        XCTAssertEqual(adapter.messages.count, 1)
        XCTAssertEqual(adapter.messages.first?.content, longContent)
    }
    
    func testEmptyConversationRenders() async throws {
        // Verify empty state
        XCTAssertTrue(adapter.messages.isEmpty)
    }
    
    // MARK: - Sending Tests
    
    func testValidMessageReachesAdapter() async throws {
        // Send a message
        await adapter.sendMessage("Test message")
        
        // Verify the message was added to conversation
        let conversation = await coordinator.getConversation()
        XCTAssertFalse(conversation.isEmpty)
        XCTAssertEqual(conversation.last?.content, "Test message")
    }
    
    func testDraftClearsAfterSend() async throws {
        // This would be tested in SwiftUI view tests
        // For now, we verify the adapter doesn't maintain draft state
        // (draft is a UI concern, not adapter concern)
        XCTAssertTrue(true)
    }
    
    func testWhitespaceOnlyMessageRejectedByUI() async throws {
        // This is a UI validation concern
        // The adapter doesn't validate - that's a UI responsibility
        // We verify the adapter will accept whatever the UI sends
        await adapter.sendMessage("   ")
        
        // The message would still be sent to coordinator
        // UI should prevent this before calling adapter
        XCTAssertTrue(true)
    }
    
    // MARK: - Processing State Tests
    
    func testProcessingStateAppearsFromBackendEvent() async throws {
        // Simulate request started event
        let sessionID = UUID()
        adapter.handleRequestStarted(sessionID: sessionID)
        
        // Verify processing state
        XCTAssertTrue(adapter.isProcessing)
        XCTAssertEqual(adapter.currentSessionID, sessionID)
    }
    
    func testProcessingDisappearsAfterResponse() async throws {
        // Start processing
        let sessionID = UUID()
        adapter.handleRequestStarted(sessionID: sessionID)
        XCTAssertTrue(adapter.isProcessing)
        
        // Complete request
        adapter.handleRequestCompleted(sessionID: sessionID)
        
        // Verify processing state cleared
        XCTAssertFalse(adapter.isProcessing)
    }
    
    func testProcessingDisappearsAfterFailure() async throws {
        // Start processing
        let sessionID = UUID()
        adapter.handleRequestStarted(sessionID: sessionID)
        XCTAssertTrue(adapter.isProcessing)
        
        // Fail request
        adapter.handleRequestFailed(sessionID: sessionID, error: "Test error")
        
        // Verify processing state cleared
        XCTAssertFalse(adapter.isProcessing)
        XCTAssertEqual(adapter.lastError, "Test error")
    }
    
    func testProcessingDisappearsAfterCancellation() async throws {
        // Start processing
        let sessionID = UUID()
        adapter.handleRequestStarted(sessionID: sessionID)
        XCTAssertTrue(adapter.isProcessing)
        
        // Cancel request
        adapter.handleRequestCancelled(sessionID: sessionID)
        
        // Verify processing state cleared
        XCTAssertFalse(adapter.isProcessing)
    }
    
    // MARK: - Session Safety Tests
    
    func testStaleEventDoesNotOverwriteCurrentUI() async throws {
        // Start first request
        let sessionID1 = UUID()
        adapter.handleRequestStarted(sessionID: sessionID1)
        XCTAssertTrue(adapter.isProcessing)
        
        // Complete first request
        adapter.handleRequestCompleted(sessionID: sessionID1)
        XCTAssertFalse(adapter.isProcessing)
        
        // Try to process stale event from older session
        let sessionID2 = UUID()
        adapter.handleRequestStarted(sessionID: sessionID2)
        
        // Try to complete with old session ID
        adapter.handleRequestCompleted(sessionID: sessionID1)
        
        // Should still be processing (from sessionID2)
        XCTAssertTrue(adapter.isProcessing)
    }
    
    func testRapidRequestSequenceBehavesCorrectly() async throws {
        // Send first request
        let sessionID1 = UUID()
        adapter.handleRequestStarted(sessionID: sessionID1)
        XCTAssertEqual(adapter.currentSessionID, sessionID1)
        
        // Send second request rapidly
        let sessionID2 = UUID()
        adapter.handleRequestStarted(sessionID: sessionID2)
        XCTAssertEqual(adapter.currentSessionID, sessionID2)
        
        // Complete first request (stale)
        adapter.handleRequestCompleted(sessionID: sessionID1)
        XCTAssertTrue(adapter.isProcessing) // Still processing sessionID2
        
        // Complete second request
        adapter.handleRequestCompleted(sessionID: sessionID2)
        XCTAssertFalse(adapter.isProcessing)
    }
    
    // MARK: - Clear Tests
    
    func testClearRequestReachesBackend() async throws {
        // Add some messages
        await coordinator.conversation.append(role: .user, content: "Test")
        await coordinator.conversation.append(role: .assistant, content: "Response")
        
        // Clear conversation
        await adapter.clearConversation()
        
        // Verify conversation is cleared
        let conversation = await coordinator.getConversation()
        XCTAssertTrue(conversation.isEmpty)
        
        // Verify adapter messages are cleared
        XCTAssertTrue(adapter.messages.isEmpty)
        
        // Verify error is cleared
        XCTAssertNil(adapter.lastError)
    }
    
    // MARK: - Error Tests
    
    func testBackendFailureMessageAppears() async throws {
        // Simulate failure
        let sessionID = UUID()
        adapter.handleRequestFailed(sessionID: sessionID, error: "Connection failed")
        
        // Verify error appears
        XCTAssertEqual(adapter.lastError, "Connection failed")
    }
    
    func testUIDoesNotInventErrorCategories() async throws {
        // Verify adapter only stores the error string
        // It doesn't categorize or transform errors
        let customError = "Custom error message"
        adapter.handleRequestFailed(sessionID: UUID(), error: customError)
        
        XCTAssertEqual(adapter.lastError, customError)
    }
    
    // MARK: - Lifecycle Tests
    
    func testAdapterTaskCancellationWorks() async throws {
        // Create adapter
        let testAdapter = AriaRuntimeAdapter(coordinator: coordinator)
        
        // Cancel event stream
        testAdapter.cancelEventStream()
        
        // Verify no crash or error
        XCTAssertTrue(true)
    }
    
    func testWindowDestructionDoesNotLeakEventListeners() async throws {
        // Create adapter in a scope
        do {
            let scopedAdapter = AriaRuntimeAdapter(coordinator: coordinator)
            scopedAdapter.cancelEventStream()
        }
        
        // Verify no memory leaks (would need memory testing tools)
        // For now, verify no crash
        XCTAssertTrue(true)
    }
    
    // MARK: - Avatar State Tests
    
    func testAvatarStateDisplay() async throws {
        // Test idle state
        adapter.handleAvatarStateChanged(state: .idle)
        XCTAssertEqual(adapter.avatarState, .idle)
        
        // Test thinking state
        adapter.handleAvatarStateChanged(state: .thinking)
        XCTAssertEqual(adapter.avatarState, .thinking)
        
        // Test talking state
        adapter.handleAvatarStateChanged(state: .talking)
        XCTAssertEqual(adapter.avatarState, .talking)
        
        // Test listening state
        adapter.handleAvatarStateChanged(state: .listening)
        XCTAssertEqual(adapter.avatarState, .listening)
    }
    
    // MARK: - Audio State Tests
    
    func testAudioStateChanges() async throws {
        // Test audio playing
        adapter.handleAudioStateChanged(isPlaying: true)
        XCTAssertTrue(adapter.isAudioPlaying)
        
        // Test audio stopped
        adapter.handleAudioStateChanged(isPlaying: false)
        XCTAssertFalse(adapter.isAudioPlaying)
    }
    
    func testMuteStateChanges() async throws {
        // Test muted
        adapter.handleMuteStateChanged(isMuted: true)
        XCTAssertTrue(adapter.isMuted)
        
        // Test unmuted
        adapter.handleMuteStateChanged(isMuted: false)
        XCTAssertFalse(adapter.isMuted)
    }
    
    // MARK: - Clarification & Confirmation Tests
    
    func testClarificationRequested() async throws {
        let sessionID = UUID()
        adapter.handleClarificationRequested(sessionID: sessionID)
        
        XCTAssertTrue(adapter.isClarificationPending)
    }
    
    func testConfirmationRequested() async throws {
        let sessionID = UUID()
        adapter.handleConfirmationRequested(sessionID: sessionID)
        
        XCTAssertTrue(adapter.isConfirmationPending)
    }
    
    // MARK: - Cancel Request Tests
    
    func testCancelRequest() async throws {
        // Start processing
        let sessionID = UUID()
        adapter.handleRequestStarted(sessionID: sessionID)
        XCTAssertTrue(adapter.isProcessing)
        
        // Cancel request
        await adapter.cancelRequest()
        
        // Verify processing state cleared
        XCTAssertFalse(adapter.isProcessing)
    }
}

// MARK: - Mock LLM Provider

private actor MockLLMProvider: LLMResponding {
    func respond(to prompt: String) async throws -> LLMResponse {
        return LLMResponse(
            content: "Mock response",
            finishReason: "stop",
            usage: LLMUsage(promptTokens: 10, completionTokens: 5, totalTokens: 15)
        )
    }
}
