import XCTest
@testable import AriaApplication
@testable import AriaDomain

final class AvatarStateManagerTests: XCTestCase {
    
    var stateManager: AvatarStateManager!
    
    override func setUp() {
        super.setUp()
        stateManager = AvatarStateManager()
    }
    
    override func tearDown() {
        stateManager = nil
        super.tearDown()
    }
    
    // MARK: - Initial State
    
    func testInitialStateIsIdle() async {
        let state = await stateManager.state
        XCTAssertEqual(state, .idle)
    }
    
    // MARK: - State Transitions
    
    func testTransitionToThinking() async throws {
        try await stateManager.transitionToThinking()
        let state = await stateManager.state
        XCTAssertEqual(state, .thinking)
    }
    
    func testTransitionToTalking() async throws {
        try await stateManager.transitionToThinking()
        try await stateManager.transitionToTalking()
        let state = await stateManager.state
        XCTAssertEqual(state, .talking)
    }
    
    func testTransitionToIdle() async throws {
        try await stateManager.transitionToThinking()
        try await stateManager.transitionToIdle()
        let state = await stateManager.state
        XCTAssertEqual(state, .idle)
    }
    
    func testTransitionToListening() async throws {
        try await stateManager.transitionToListening()
        let state = await stateManager.state
        XCTAssertEqual(state, .listening)
    }
    
    // MARK: - Invalid Transitions
    
    func testInvalidTransitionFromIdleToTalking() async {
        do {
            try await stateManager.transitionToTalking()
            XCTFail("Should have thrown invalid transition error")
        } catch AvatarError.stateTransitionInvalid(let from, let to) {
            XCTAssertEqual(from, .idle)
            XCTAssertEqual(to, .talking)
        } catch {
            XCTFail("Unexpected error: \(error)")
        }
    }
    
    func testInvalidTransitionFromTalkingToThinking() async throws {
        try await stateManager.transitionToThinking()
        try await stateManager.transitionToTalking()
        
        do {
            try await stateManager.transitionToThinking()
            XCTFail("Should have thrown invalid transition error")
        } catch AvatarError.stateTransitionInvalid(let from, let to) {
            XCTAssertEqual(from, .talking)
            XCTAssertEqual(to, .thinking)
        } catch {
            XCTFail("Unexpected error: \(error)")
        }
    }
    
    // MARK: - State Determination
    
    func testDetermineStateWithLLMProcessing() async {
        let state = await stateManager.determineState(
            hasUserInput: true,
            isProcessingLLM: true,
            isPlayingAudio: false
        )
        XCTAssertEqual(state, .thinking)
    }
    
    func testDetermineStateWithAudioPlaying() async {
        let state = await stateManager.determineState(
            hasUserInput: false,
            isProcessingLLM: false,
            isPlayingAudio: true
        )
        XCTAssertEqual(state, .talking)
    }
    
    func testDetermineStateWithUserInput() async {
        let state = await stateManager.determineState(
            hasUserInput: true,
            isProcessingLLM: false,
            isPlayingAudio: false
        )
        XCTAssertEqual(state, .listening)
    }
    
    func testDetermineStateWithNoActivity() async {
        let state = await stateManager.determineState(
            hasUserInput: false,
            isProcessingLLM: false,
            isPlayingAudio: false
        )
        XCTAssertEqual(state, .idle)
    }
    
    // MARK: - Animation Parameters
    
    func testAnimationParametersForIdle() async {
        let params = await stateManager.animationParameters(for: .idle)
        XCTAssertEqual(params.duration, 2.0)
        XCTAssertEqual(params.intensity, 0.3)
        XCTAssertTrue(params.loops)
    }
    
    func testAnimationParametersForThinking() async {
        let params = await stateManager.animationParameters(for: .thinking)
        XCTAssertEqual(params.duration, 1.0)
        XCTAssertEqual(params.intensity, 0.5)
        XCTAssertTrue(params.loops)
    }
    
    func testAnimationParametersForTalking() async {
        let params = await stateManager.animationParameters(for: .talking)
        XCTAssertEqual(params.duration, 0.1)
        XCTAssertEqual(params.intensity, 0.8)
        XCTAssertTrue(params.loops)
    }
    
    func testAnimationParametersForListening() async {
        let params = await stateManager.animationParameters(for: .listening)
        XCTAssertEqual(params.duration, 1.5)
        XCTAssertEqual(params.intensity, 0.4)
        XCTAssertTrue(params.loops)
    }
    
    // MARK: - Reset
    
    func testReset() async throws {
        try await stateManager.transitionToThinking()
        try await stateManager.reset()
        let state = await stateManager.state
        XCTAssertEqual(state, .idle)
    }
    
    func testResetFromAnyState() async throws {
        try await stateManager.transitionToThinking()
        try await stateManager.transitionToTalking()
        try await stateManager.reset()
        let state = await stateManager.state
        XCTAssertEqual(state, .idle)
    }
    
    // MARK: - Configuration
    
    func testCustomConfiguration() async {
        let customConfig = AvatarConfiguration(
            modelDirectory: URL(fileURLWithPath: "/custom/path"),
            modelName: "custom_model",
            enableIdleAnimation: false,
            enableLipSync: true
        )
        
        let customStateManager = AvatarStateManager(configuration: customConfig)
        let state = await customStateManager.state
        XCTAssertEqual(state, .idle)
    }
    
    func testDefaultConfiguration() {
        let defaultConfig = AvatarConfiguration.sumireDefault
        XCTAssertEqual(defaultConfig.modelName, "sumire_free_001")
        XCTAssertTrue(defaultConfig.enableIdleAnimation)
        XCTAssertFalse(defaultConfig.enableLipSync)
    }
    
    // MARK: - Complex State Flows
    
    func testFullConversationFlow() async throws {
        // User input
        try await stateManager.transitionToListening()
        var state = await stateManager.state
        XCTAssertEqual(state, .listening)
        
        // LLM processing
        try await stateManager.transitionToThinking()
        state = await stateManager.state
        XCTAssertEqual(state, .thinking)
        
        // TTS talking
        try await stateManager.transitionToTalking()
        state = await stateManager.state
        XCTAssertEqual(state, .talking)
        
        // Back to idle
        try await stateManager.transitionToIdle()
        state = await stateManager.state
        XCTAssertEqual(state, .idle)
    }
    
    func testMultipleConversationTurns() async throws {
        // First turn
        try await stateManager.transitionToListening()
        try await stateManager.transitionToThinking()
        try await stateManager.transitionToTalking()
        try await stateManager.transitionToIdle()
        
        // Second turn
        try await stateManager.transitionToListening()
        try await stateManager.transitionToThinking()
        try await stateManager.transitionToTalking()
        try await stateManager.transitionToIdle()
        
        let state = await stateManager.state
        XCTAssertEqual(state, .idle)
    }
}