import XCTest
import AriaDomain
import AriaInfrastructure
@testable import AriaApplication

/// Tests for the runtime adapter's state management and lifecycle.
final class RuntimeAdapterTests: XCTestCase {
    
    var coordinator: AssistantCoordinator!
    var runtimeAdapter: AriaRuntimeAdapter!
    
    override func setUp() async throws {
        // Use AppBootstrap for consistent setup
        let mockLLM = MockLLMProvider()
        let mockLogger = ConsoleLogger(minimumLevel: .info)
        let mockConfig = AppConfiguration.load()
        
        coordinator = await AppBootstrap.createCoordinator(
            llm: mockLLM,
            logger: mockLogger,
            config: mockConfig
        )
        
        runtimeAdapter = await AriaRuntimeAdapter(coordinator: coordinator, ttsService: nil)
    }
    
    override func tearDown() async throws {
        await MainActor.run {
            runtimeAdapter.cancelEventStream()
            runtimeAdapter = nil
            coordinator = nil
        }
    }
    
    func testInitialState() async {
        await MainActor.run {
            XCTAssertFalse(runtimeAdapter.isProcessing)
            XCTAssertNil(runtimeAdapter.currentSessionID)
            XCTAssertEqual(runtimeAdapter.avatarState, .idle)
            XCTAssertFalse(runtimeAdapter.isAudioPlaying)
            XCTAssertFalse(runtimeAdapter.isMuted)
            XCTAssertFalse(runtimeAdapter.isClarificationPending)
            XCTAssertFalse(runtimeAdapter.isConfirmationPending)
            XCTAssertNil(runtimeAdapter.lastError)
        }
    }
    
    func testEventStreamCancellation() async {
        await MainActor.run {
            runtimeAdapter.cancelEventStream()
            
            // Should not crash when cancelled
            runtimeAdapter.cancelEventStream()
        }
    }
    
    func testSendMessage() async {
        // Test that sendMessage doesn't crash
        await runtimeAdapter.sendMessage("test message")
    }
    
    func testClearConversation() async {
        // Test that clearConversation doesn't crash
        await runtimeAdapter.clearConversation()
    }
    
    func testRespondToClarification() async {
        // Test that respondToClarification doesn't crash
        await runtimeAdapter.respondToClarification("test answer")
    }
    
    func testRespondToConfirmation() async {
        // Test that respondToConfirmation doesn't crash
        await runtimeAdapter.respondToConfirmation(true)
    }
    
    func testToggleMute() async {
        // When TTS service is nil, toggleMute should not change state
        await MainActor.run {
            XCTAssertFalse(runtimeAdapter.isMuted)
        }
        
        await runtimeAdapter.toggleMute()
        
        await MainActor.run {
            // Without TTS service, state should remain unchanged
            XCTAssertFalse(runtimeAdapter.isMuted)
        }
    }
    
    func testStopSpeech() async {
        // Should not throw even without TTS service
        await runtimeAdapter.stopSpeech()
        
        await MainActor.run {
            XCTAssertFalse(runtimeAdapter.isAudioPlaying)
        }
    }
}
