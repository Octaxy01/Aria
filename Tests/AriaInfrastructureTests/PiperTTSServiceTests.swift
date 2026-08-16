import XCTest
@testable import AriaInfrastructure
@testable import AriaDomain

final class PiperTTSServiceTests: XCTestCase {
    
    var service: PiperTTSService!
    var tempAudioDir: URL!
    
    override func setUp() async throws {
        try await super.setUp()
        
        // Create temporary audio directory
        tempAudioDir = FileManager.default.temporaryDirectory
            .appendingPathComponent("test_tts_\(UUID().uuidString)")
        try FileManager.default.createDirectory(at: tempAudioDir, withIntermediateDirectories: true)
        
        // Try to create service - will fail if Piper not available
        do {
            service = try PiperTTSService(audioDirectory: tempAudioDir)
        } catch {
            // If Piper is not available, skip these tests
            throw XCTSkip("Piper TTS not available for testing")
        }
    }
    
    override func tearDown() async throws {
        service = nil
        
        // Clean up temporary directory
        if let tempAudioDir = tempAudioDir {
            try? FileManager.default.removeItem(at: tempAudioDir)
        }
        
        try await super.tearDown()
    }
    
    // MARK: - Basic Synthesis
    
    func testBasicSynthesis() async throws {
        let text = "Halo, aku Aria."
        let voice = VoiceConfiguration.ariaIndonesian
        
        // This will fail if voice model is not available
        let result = try await service.synthesize(text: text, language: .indonesian, voice: voice)
        
        // If synthesis succeeded, verify file exists
        if let audioFile = result {
            XCTAssertTrue(FileManager.default.fileExists(atPath: audioFile.path))
            XCTAssertEqual(audioFile.pathExtension, "wav")
        } else {
            // Voice model may not be available - that's okay for integration tests
            throw XCTSkip("Voice model not available")
        }
    }
    
    // MARK: - Empty Input
    
    func testEmptyText() async throws {
        let result = try await service.synthesize(text: "", language: .indonesian, voice: VoiceConfiguration.ariaIndonesian)
        XCTAssertNil(result)
    }
    
    func testWhitespaceText() async throws {
        let result = try await service.synthesize(text: "   ", language: .indonesian, voice: VoiceConfiguration.ariaIndonesian)
        XCTAssertNil(result)
    }
    
    // MARK: - Cancellation
    
    func testCancellation() async throws {
        let longText = String(repeating: "kata ", count: 1000)
        
        let task = Task {
            try await service.synthesize(text: longText, language: .indonesian, voice: VoiceConfiguration.ariaIndonesian)
        }
        
        // Cancel quickly
        await service.cancel()
        task.cancel()
        
        let result = try await task.value
        XCTAssertNil(result)
    }
    
    // MARK: - Voice Availability
    
    func testVoiceAvailabilityCheck() async throws {
        let indonesianVoice = VoiceConfiguration.ariaIndonesian
        let isAvailable = await service.isVoiceAvailable(indonesianVoice)
        
        // This depends on whether the voice model is installed
        // We don't assert the result, just that the method works
        _ = isAvailable
    }
    
    func testAvailableVoicesList() async throws {
        let voices = await service.availableVoices()
        
        // Just verify the method works - content depends on installed models
        _ = voices
    }
    
    // MARK: - Error Handling
    
    func testUnavailableVoice() async throws {
        let unavailableVoice = VoiceConfiguration(
            provider: .piper,
            language: .indonesian,
            voiceId: "nonexistent-model"
        )
        
        do {
            _ = try await service.synthesize(text: "Halo", language: .indonesian, voice: unavailableVoice)
            XCTFail("Should have thrown voice unavailable error")
        } catch TTSError.voiceUnavailable {
            // Expected
        } catch {
            XCTFail("Unexpected error: \(error)")
        }
    }
    
    // MARK: - Language Support
    
    func testIndonesianLanguage() async throws {
        let text = "Halo, apa kabar?"
        let voice = VoiceConfiguration.ariaIndonesian
        
        let result = try await service.synthesize(text: text, language: .indonesian, voice: voice)
        
        if let audioFile = result {
            XCTAssertTrue(FileManager.default.fileExists(atPath: audioFile.path))
        } else {
            throw XCTSkip("Indonesian voice model not available")
        }
    }
    
    func testEnglishLanguage() async throws {
        let text = "Hello, how are you?"
        let voice = VoiceConfiguration.englishDefault
        
        let result = try await service.synthesize(text: text, language: .english, voice: voice)
        
        if let audioFile = result {
            XCTAssertTrue(FileManager.default.fileExists(atPath: audioFile.path))
        } else {
            throw XCTSkip("English voice model not available")
        }
    }
    
    // MARK: - Service Initialization
    
    func testInitializationWithCustomPiperPath() async throws {
        let customTempDir = FileManager.default.temporaryDirectory
            .appendingPathComponent("custom_tts_\(UUID().uuidString)")
        try FileManager.default.createDirectory(at: customTempDir, withIntermediateDirectories: true)
        
        // This will fail if custom path doesn't exist
        let customService = try? PiperTTSService(
            piperPath: "/nonexistent/path/piper",
            audioDirectory: customTempDir
        )
        
        XCTAssertNil(customService, "Should fail with invalid Piper path")
        
        try? FileManager.default.removeItem(at: customTempDir)
    }
    
    func testInitializationWithDefaultPiperPath() async throws {
        // Test that default initialization finds Piper if it exists
        let defaultService = try? PiperTTSService(audioDirectory: tempAudioDir)
        
        // This may succeed or fail depending on whether Piper is installed
        // We just verify it doesn't crash
        _ = defaultService
    }
    
    // MARK: - Provider Properties
    
    func testProviderName() async throws {
        XCTAssertEqual(service.providerName, "Piper TTS")
    }
    
    func testIsAvailable() async throws {
        let available = await service.isAvailable()
        // This should be true if Piper is installed
        XCTAssertTrue(available)
    }
}