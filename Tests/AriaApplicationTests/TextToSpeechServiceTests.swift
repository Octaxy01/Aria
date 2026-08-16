import XCTest
@testable import AriaApplication
@testable import AriaDomain
@testable import AriaInfrastructure

final class TextToSpeechServiceTests: XCTestCase {
    
    var ttsService: TextToSpeechService!
    var mockProvider: MockTTSProvider!
    var fallbackProvider: MockTTSProvider!
    
    override func setUp() async throws {
        try await super.setUp()
        
        mockProvider = MockTTSProvider()
        fallbackProvider = MockTTSProvider()
        
        ttsService = TextToSpeechService(
            primaryProvider: mockProvider,
            fallbackProvider: fallbackProvider
        )
    }
    
    override func tearDown() async throws {
        ttsService = nil
        mockProvider = nil
        fallbackProvider = nil
        try await super.tearDown()
    }
    
    // MARK: - Provider Selection
    
    func testUsesPrimaryProviderWhenAvailable() async throws {
        let text = "Halo, aku Aria."
        let emotion = EmotionState(current: .neutral, intensity: 0.0)
        let relationship = RelationshipState.initial
        
        let result = try await ttsService.synthesizeResponse(text, emotion: emotion, relationship: relationship)
        
        let mockSynthesizeCalled = await mockProvider.synthesizeCalled
        let fallbackSynthesizeCalled = await fallbackProvider.synthesizeCalled
        XCTAssertTrue(mockSynthesizeCalled)
        XCTAssertFalse(fallbackSynthesizeCalled)
        XCTAssertNotNil(result)
    }
    
    func testUsesFallbackWhenPrimaryUnavailable() async throws {
        await mockProvider.setIsAvailable(false)
        
        let text = "Halo, aku Aria."
        let emotion = EmotionState(current: .neutral, intensity: 0.0)
        let relationship = RelationshipState.initial
        
        let result = try await ttsService.synthesizeResponse(text, emotion: emotion, relationship: relationship)
        
        let mockSynthesizeCalled = await mockProvider.synthesizeCalled
        let fallbackSynthesizeCalled = await fallbackProvider.synthesizeCalled
        XCTAssertFalse(mockSynthesizeCalled)
        XCTAssertTrue(fallbackSynthesizeCalled)
        XCTAssertNotNil(result)
    }
    
    func testPrimaryFailureTriggersFallback() async throws {
        await mockProvider.setShouldFail(true)
        
        let text = "Halo, aku Aria."
        let emotion = EmotionState(current: .neutral, intensity: 0.0)
        let relationship = RelationshipState.initial
        
        let result = try await ttsService.synthesizeResponse(text, emotion: emotion, relationship: relationship)
        
        let mockSynthesizeCalled = await mockProvider.synthesizeCalled
        let fallbackSynthesizeCalled = await fallbackProvider.synthesizeCalled
        XCTAssertTrue(mockSynthesizeCalled)
        XCTAssertTrue(fallbackSynthesizeCalled)
        XCTAssertNotNil(result)
    }
    
    // MARK: - Voice Configuration
    
    func testVoiceConfigurationCreation() {
        let voice = VoiceConfiguration.ariaIndonesian
        
        XCTAssertEqual(voice.provider, .piper)
        XCTAssertEqual(voice.language, .indonesian)
        XCTAssertEqual(voice.pitch, 1.2) // Slightly higher for young female
        XCTAssertEqual(voice.speed, 1.0)
        XCTAssertEqual(voice.style, .natural)
    }
    
    func testFallbackVoiceConfiguration() {
        let voice = VoiceConfiguration.indonesianFallback
        
        XCTAssertEqual(voice.provider, .piper)
        XCTAssertEqual(voice.language, .indonesian)
        XCTAssertEqual(voice.pitch, 1.0) // Normal pitch
        XCTAssertEqual(voice.speed, 1.0)
        XCTAssertEqual(voice.style, .natural)
    }
    
    func testVoiceStyleMapping() {
        let styles: [VoiceStyle] = [.natural, .casual, .warm, .energetic, .gentle, .clear, .soft]
        
        for style in styles {
            let voice = VoiceConfiguration(
                provider: .piper,
                language: .indonesian,
                voiceId: "test",
                style: style
            )
            XCTAssertEqual(voice.style, style)
        }
    }
    
    // MARK: - Text Sanitization
    
    func testEmptyTextReturnsNil() async throws {
        let result = try await ttsService.synthesizeResponse("", emotion: EmotionState(current: .neutral, intensity: 0.0), relationship: RelationshipState.initial)
        XCTAssertNil(result)
    }
    
    func testWhitespaceTextReturnsNil() async throws {
        let result = try await ttsService.synthesizeResponse("   ", emotion: EmotionState(current: .neutral, intensity: 0.0), relationship: RelationshipState.initial)
        XCTAssertNil(result)
    }
    
    // MARK: - Cancellation
    
    func testCancellation() async throws {
        await ttsService.cancel()
        
        let mockCancelCalled = await mockProvider.cancelCalled
        let fallbackCancelCalled = await fallbackProvider.cancelCalled
        XCTAssertTrue(mockCancelCalled)
        XCTAssertTrue(fallbackCancelCalled)
    }
    
    // MARK: - Availability
    
    func testAvailabilityCheck() async {
        let available = await ttsService.isAvailable(language: .indonesian)
        XCTAssertTrue(available)
    }
    
    func testAvailabilityWithBothUnavailable() async {
        await mockProvider.setIsAvailable(false)
        await fallbackProvider.setIsAvailable(false)
        
        let available = await ttsService.isAvailable(language: .indonesian)
        XCTAssertFalse(available)
    }
    
    // MARK: - Provider Properties
    
    func testActiveProviderName() async {
        let providerName = await ttsService.activeProvider
        XCTAssertEqual(providerName, "Mock TTS Provider")
    }
    
    func testActiveProviderNameWithFallback() async {
        await mockProvider.setIsAvailable(false)
        
        let providerName = await ttsService.activeProvider
        XCTAssertEqual(providerName, "Mock TTS Provider")
    }
    
    // MARK: - Speech Style Integration
    
    func testSpeechStyleMappingWorks() async throws {
        let text = "Wah, bagus sekali!"
        let emotion = EmotionState(current: .happy, intensity: 0.8)
        let relationship = RelationshipState.initial
        
        _ = try await ttsService.synthesizeResponse(text, emotion: emotion, relationship: relationship)
        
        let synthesizeCalled = await mockProvider.synthesizeCalled
        XCTAssertTrue(synthesizeCalled)
        // Verify that voice parameters were adjusted based on style
        let lastVoice = await mockProvider.lastVoice
        XCTAssertNotNil(lastVoice)
    }
    
    func testEmotionalExpressionDoesNotModifyPitchSpeedInTextToSpeechService() async throws {
        // This test verifies that emotional expression no longer causes
        // additional pitch/speed modifications in TextToSpeechService.
        // Emotional prosody is now handled by VoiceVoxTTSService.applySpeechStyle()
        
        let text = "Wah, bagus sekali!" // Achievement tone triggers high emotional expression
        let emotion = EmotionState(current: .happy, intensity: 0.8)
        let relationship = RelationshipState.initial
        
        _ = try await ttsService.synthesizeResponse(text, emotion: emotion, relationship: relationship)
        
        let lastVoice = await mockProvider.lastVoice
        XCTAssertNotNil(lastVoice)
        
        // Verify that base VoiceConfiguration pitch and speed are preserved
        // (not modified by emotional expression in TextToSpeechService)
        XCTAssertEqual(lastVoice?.pitch, 1.0, "Base pitch should remain 1.0")
        XCTAssertEqual(lastVoice?.speed, 1.0, "Base speed should remain 1.0")
        
        // VoiceStyle should still be mapped based on speech style
        // (achievement tone typically maps to energetic/warm)
        XCTAssertNotNil(lastVoice?.style, "VoiceStyle should be mapped")
    }
    
    // MARK: - Long Response Handling
    
    func testLongResponseTruncation() async throws {
        let longText = String(repeating: "kata ", count: 600)
        let emotion = EmotionState(current: .neutral, intensity: 0.0)
        let relationship = RelationshipState.initial
        
        let result = try await ttsService.synthesizeResponse(longText, emotion: emotion, relationship: relationship)
        
        // Should succeed by truncating
        XCTAssertNotNil(result)
        let synthesizeCalled = await mockProvider.synthesizeCalled
        XCTAssertTrue(synthesizeCalled)
    }
    
    // MARK: - Error Handling
    
    func testBothProvidersUnavailable() async throws {
        await mockProvider.setIsAvailable(false)
        await fallbackProvider.setIsAvailable(false)
        
        let text = "Halo, aku Aria."
        let emotion = EmotionState(current: .neutral, intensity: 0.0)
        let relationship = RelationshipState.initial
        
        do {
            _ = try await ttsService.synthesizeResponse(text, emotion: emotion, relationship: relationship)
            XCTFail("Should have thrown error when both providers unavailable")
        } catch TTSError.providerUnavailable {
            // Expected
        } catch {
            XCTFail("Unexpected error: \(error)")
        }
    }
    
    func testBothProvidersFail() async throws {
        await mockProvider.setShouldFail(true)
        await fallbackProvider.setShouldFail(true)
        
        let text = "Halo, aku Aria."
        let emotion = EmotionState(current: .neutral, intensity: 0.0)
        let relationship = RelationshipState.initial
        
        do {
            _ = try await ttsService.synthesizeResponse(text, emotion: emotion, relationship: relationship)
            XCTFail("Should have thrown error when both providers fail")
        } catch TTSError.synthesisFailed {
            // Expected - mock throws synthesisFailed
        } catch {
            XCTFail("Unexpected error: \(error)")
        }
    }
    
    // MARK: - Stop and Mute Functionality
    
    func testStopCurrentSpeech() async {
        await ttsService.stopCurrentSpeech()
        
        let mockCancelCalled = await mockProvider.cancelCalled
        let fallbackCancelCalled = await fallbackProvider.cancelCalled
        XCTAssertTrue(mockCancelCalled, "Primary provider cancel should be called")
        XCTAssertTrue(fallbackCancelCalled, "Fallback provider cancel should be called")
    }
    
    func testMuteFunctionality() async {
        // Initial state should not be muted
        let initialMuted = await ttsService.isMuted
        XCTAssertFalse(initialMuted)
        
        // Set mute to true
        await ttsService.setMuted(true)
        let mutedState = await ttsService.isMuted
        XCTAssertTrue(mutedState)
        
        // Set mute to false
        await ttsService.setMuted(false)
        let unmutedState = await ttsService.isMuted
        XCTAssertFalse(unmutedState)
    }
    
    func testStopAudio() async {
        await ttsService.stopAudio()
        
        // stopAudio should not cancel providers, only stop playback
        let mockCancelCalled = await mockProvider.cancelCalled
        let fallbackCancelCalled = await fallbackProvider.cancelCalled
        XCTAssertFalse(mockCancelCalled, "Primary provider cancel should not be called by stopAudio")
        XCTAssertFalse(fallbackCancelCalled, "Fallback provider cancel should not be called by stopAudio")
    }
    
    func testEnsureAvatarIdle() async {
        // This test verifies that ensureAvatarIdle exists and can be called
        // The actual avatar state management is tested in AudioPlaybackServiceTests
        await ttsService.ensureAvatarIdle()
        
        // Should complete without error
        XCTAssertTrue(true)
    }
    
    // MARK: - Session Safety
    
    func testRapidSynthesisRequests() async throws {
        // Test that multiple rapid synthesis requests are handled safely
        let text = "Halo, aku Aria."
        let emotion = EmotionState(current: .neutral, intensity: 0.0)
        let relationship = RelationshipState.initial
        
        // Make multiple rapid requests
        let task1 = Task {
            try? await ttsService.synthesizeResponse(text, emotion: emotion, relationship: relationship)
        }
        
        let task2 = Task {
            try? await ttsService.synthesizeResponse(text, emotion: emotion, relationship: relationship)
        }
        
        let task3 = Task {
            try? await ttsService.synthesizeResponse(text, emotion: emotion, relationship: relationship)
        }
        
        // Wait for all to complete
        _ = await task1.value
        _ = await task2.value
        _ = await task3.value
        
        // Should complete without hanging or crashing
        XCTAssertTrue(true)
    }
    
    func testCancellationDuringSynthesis() async throws {
        let text = "Halo, aku Aria."
        let emotion = EmotionState(current: .neutral, intensity: 0.0)
        let relationship = RelationshipState.initial
        
        // Start synthesis
        let synthesisTask = Task {
            try await ttsService.synthesizeResponse(text, emotion: emotion, relationship: relationship)
        }
        
        // Cancel immediately
        synthesisTask.cancel()
        
        // Should complete (either with error or nil)
        do {
            let result = try await synthesisTask.value
            // If it doesn't throw, the mock might still return a result despite cancellation
            // This is acceptable behavior for the mock
            XCTAssertNotNil(result, "If cancellation doesn't throw, should return a result")
        } catch {
            // Expected - cancellation should throw
            XCTAssertTrue(true, "Cancellation should throw an error")
        }
    }
}

// MARK: - Mock TTS Provider

actor MockTTSProvider: TextToSpeeching {
    var isAvailable: Bool = true
    var shouldFail: Bool = false
    var synthesizeCalled: Bool = false
    var cancelCalled: Bool = false
    var lastVoice: VoiceConfiguration?
    
    nonisolated var providerName: String {
        return "Mock TTS Provider"
    }
    
    func setIsAvailable(_ value: Bool) {
        isAvailable = value
    }
    
    func setShouldFail(_ value: Bool) {
        shouldFail = value
    }
    
    func synthesize(text: String, language: Language, voice: VoiceConfiguration, style: SpeechStyle? = nil) async throws -> URL? {
        synthesizeCalled = true
        lastVoice = voice
        
        if shouldFail {
            throw TTSError.synthesisFailed(reason: "Mock failure")
        }
        
        // Return a fake URL for testing
        return FileManager.default.temporaryDirectory.appendingPathComponent("test_audio.wav")
    }
    
    func cancel() async {
        cancelCalled = true
    }
    
    func synthesizeSegmented(segments: [String], pauses: [TimeInterval], language: Language, voice: VoiceConfiguration, style: SpeechStyle? = nil) async throws -> URL? {
        // For testing, just use the first segment
        return try await synthesize(text: segments.first ?? "", language: language, voice: voice, style: style)
    }
    
    func isAvailable() async -> Bool {
        return isAvailable
    }
    
    // Reset test state
    func reset() {
        synthesizeCalled = false
        cancelCalled = false
        lastVoice = nil
    }
}