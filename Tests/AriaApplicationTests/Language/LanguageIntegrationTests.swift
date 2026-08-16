import XCTest
import AriaDomain
@testable import AriaApplication

final class LanguageIntegrationTests: XCTestCase {
    
    // MARK: - Test 1: Indonesian input, Japanese output
    
    func testIndonesianInputJapaneseOutput() {
        let settings = LanguageSettings(
            inputLanguage: .auto,
            outputLanguage: .japanese,
            translationMode: .onDemand
        )
        
        let userInput = "Aku hari ini capek banget."
        let detectedLanguage = LanguageDetector.detect(userInput)
        
        XCTAssertEqual(detectedLanguage, .indonesian, "Should detect Indonesian input")
        XCTAssertEqual(settings.effectiveOutputLanguage, .japanese, "Should output in Japanese")
        
        // Verify that detection doesn't automatically change output language
        XCTAssertNotEqual(detectedLanguage, settings.effectiveOutputLanguage, "Input and output should be independent")
    }
    
    // MARK: - Test 2: Japanese input, Japanese output
    
    func testJapaneseInputJapaneseOutput() {
        let settings = LanguageSettings(
            inputLanguage: .auto,
            outputLanguage: .japanese,
            translationMode: .onDemand
        )
        
        let userInput = "今日は疲れた。"
        let detectedLanguage = LanguageDetector.detect(userInput)
        
        XCTAssertEqual(detectedLanguage, .japanese, "Should detect Japanese input")
        XCTAssertEqual(settings.effectiveOutputLanguage, .japanese, "Should output in Japanese")
    }
    
    // MARK: - Test 3: Russian input, Japanese output
    
    func testRussianInputJapaneseOutput() {
        let settings = LanguageSettings(
            inputLanguage: .auto,
            outputLanguage: .japanese,
            translationMode: .onDemand
        )
        
        let userInput = "Я сегодня устал."
        let detectedLanguage = LanguageDetector.detect(userInput)
        
        XCTAssertEqual(detectedLanguage, .russian, "Should detect Russian input")
        XCTAssertEqual(settings.effectiveOutputLanguage, .japanese, "Should output in Japanese")
        
        // Verify language independence
        XCTAssertNotEqual(detectedLanguage, settings.effectiveOutputLanguage, "Russian input should not force Russian output")
    }
    
    // MARK: - Test 4: Explicit Indonesian request
    
    func testExplicitIndonesianRequest() {
        var settings = LanguageSettings(
            inputLanguage: .auto,
            outputLanguage: .japanese,
            translationMode: .onDemand
        )
        
        let overrideRequest = "Jawab pakai bahasa Indonesia."
        let detectedOverride = LanguageDetector.detectLanguageOverride(overrideRequest)
        
        XCTAssertEqual(detectedOverride, .indonesian, "Should detect Indonesian override request")
        
        // Simulate setting the override
        settings.setConversationOverride(detectedOverride!)
        XCTAssertEqual(settings.effectiveOutputLanguage, .indonesian, "Should use Indonesian after override")
    }
    
    // MARK: - Test 5: Translation request
    
    func testTranslationRequest() {
        let translationRequest = "Apa arti 大丈夫?"
        let isTranslationRequest = LanguageDetector.detectTranslationRequest(translationRequest)
        
        XCTAssertTrue(isTranslationRequest, "Should detect translation request")
        
        // The system should understand this as a translation/meaning request
        // and handle it appropriately (not as normal conversation)
    }
    
    // MARK: - Test 6: Default change
    
    func testDefaultChange() {
        var settings = LanguageSettings.default
        
        // Initially Japanese
        XCTAssertEqual(settings.outputLanguage, .japanese, "Initial default should be Japanese")
        XCTAssertEqual(settings.effectiveOutputLanguage, .japanese, "Effective should be Japanese")
        
        // Change to Indonesian
        settings.outputLanguage = .indonesian
        XCTAssertEqual(settings.outputLanguage, .indonesian, "Should be Indonesian after change")
        XCTAssertEqual(settings.effectiveOutputLanguage, .indonesian, "Effective should be Indonesian")
        
        // Change to Russian
        settings.outputLanguage = .russian
        XCTAssertEqual(settings.outputLanguage, .russian, "Should be Russian after change")
        XCTAssertEqual(settings.effectiveOutputLanguage, .russian, "Effective should be Russian")
        
        // Change to English
        settings.outputLanguage = .english
        XCTAssertEqual(settings.outputLanguage, .english, "Should be English after change")
        XCTAssertEqual(settings.effectiveOutputLanguage, .english, "Effective should be English")
    }
    
    // MARK: - Test 7: TTS Provider Selection
    
    func testTTSProviderSelection() {
        // Japanese should use VOICEVOX
        let japaneseProvider = TTSProviderResolver.provider(for: .japanese)
        XCTAssertEqual(japaneseProvider, .voicevox, "Japanese should use VOICEVOX")
        
        // Indonesian should use Piper
        let indonesianProvider = TTSProviderResolver.provider(for: .indonesian)
        XCTAssertEqual(indonesianProvider, .piper, "Indonesian should use Piper")
        
        // English should use Piper
        let englishProvider = TTSProviderResolver.provider(for: .english)
        XCTAssertEqual(englishProvider, .piper, "English should use Piper")
        
        // Russian should use Piper
        let russianProvider = TTSProviderResolver.provider(for: .russian)
        XCTAssertEqual(russianProvider, .piper, "Russian should use Piper")
    }
    
    func testDefaultVoiceConfiguration() {
        // Japanese should use ariaJapanese
        let japaneseVoice = TTSProviderResolver.defaultVoice(for: .japanese)
        XCTAssertEqual(japaneseVoice.provider, .voicevox, "Japanese voice should use VOICEVOX")
        XCTAssertEqual(japaneseVoice.speaker, 14, "Japanese voice should use speaker 14 (冥鳴ひまり)")
        
        // Indonesian should use ariaIndonesian
        let indonesianVoice = TTSProviderResolver.defaultVoice(for: .indonesian)
        XCTAssertEqual(indonesianVoice.provider, .piper, "Indonesian voice should use Piper")
        
        // English should use englishDefault
        let englishVoice = TTSProviderResolver.defaultVoice(for: .english)
        XCTAssertEqual(englishVoice.provider, .piper, "English voice should use Piper")
    }
    
    // MARK: - Test 8: Language Override Persistence
    
    func testLanguageOverridePersistence() {
        var settings = LanguageSettings.default
        
        // Set override
        settings.setConversationOverride(.indonesian)
        XCTAssertEqual(settings.effectiveOutputLanguage, .indonesian, "Should use override")
        
        // Clear override
        settings.clearConversationOverride()
        XCTAssertEqual(settings.effectiveOutputLanguage, .japanese, "Should return to default after clearing")
    }
    
    // MARK: - Test 9: System Prompt Integration
    
    func testSystemPromptLanguagePolicy() {
        let settings = LanguageSettings(
            inputLanguage: .auto,
            outputLanguage: .japanese,
            translationMode: .onDemand
        )
        
        let detectedLanguage = LanguageDetector.detect("Aku capek.")
        let languagePolicy = SystemPromptBuilder.languagePolicyContext(
            for: settings,
            detectedInputLanguage: detectedLanguage
        )
        
        // Verify the language policy context contains key information
        XCTAssertTrue(languagePolicy.contains("LANGUAGE POLICY"), "Should have language policy header")
        XCTAssertTrue(languagePolicy.contains("Japanese"), "Should mention output language")
        XCTAssertTrue(languagePolicy.contains("Indonesian"), "Should mention detected input language")
        XCTAssertTrue(languagePolicy.contains("Input language"), "Should mention input language")
        XCTAssertTrue(languagePolicy.contains("Configured output language"), "Should mention output language configuration")
    }
    
    // MARK: - Test 10: Multiple Language Changes
    
    func testMultipleLanguageChanges() {
        var settings = LanguageSettings.default
        
        // Sequence of language changes
        settings.outputLanguage = .indonesian
        XCTAssertEqual(settings.effectiveOutputLanguage, .indonesian)
        
        settings.setConversationOverride(.japanese)
        XCTAssertEqual(settings.effectiveOutputLanguage, .japanese)
        
        settings.clearConversationOverride()
        XCTAssertEqual(settings.effectiveOutputLanguage, .indonesian)
        
        settings.outputLanguage = .russian
        XCTAssertEqual(settings.effectiveOutputLanguage, .russian)
        
        settings.setConversationOverride(.english)
        XCTAssertEqual(settings.effectiveOutputLanguage, .english)
        
        settings.clearConversationOverride()
        XCTAssertEqual(settings.effectiveOutputLanguage, .russian)
    }
    
    // MARK: - Test 11: Auto Detection vs Explicit
    
    func testAutoDetectionVsExplicit() {
        let autoSettings = LanguageSettings(inputLanguage: .auto, outputLanguage: .japanese)
        let explicitSettings = LanguageSettings(inputLanguage: .indonesian, outputLanguage: .japanese)
        
        let text = "Aku lapar."
        let detected = LanguageDetector.detect(text)
        
        // Auto setting should use detection
        if autoSettings.inputLanguage == .auto {
            XCTAssertEqual(detected, .indonesian, "Should detect language when auto")
        }
        
        // Explicit setting should ignore detection
        XCTAssertEqual(explicitSettings.inputLanguage, .indonesian, "Explicit setting should be respected")
    }
    
    // MARK: - Test 12: Translation Mode Behavior
    
    func testTranslationModeOnDemand() {
        let settings = LanguageSettings(
            inputLanguage: .auto,
            outputLanguage: .japanese,
            translationMode: .onDemand
        )
        
        XCTAssertEqual(settings.translationMode, .onDemand, "Should be on demand mode")
        
        // In on-demand mode, normal conversation should not trigger translation
        let normalText = "Aku pergi ke kantor."
        let isTranslationRequest = LanguageDetector.detectTranslationRequest(normalText)
        XCTAssertFalse(isTranslationRequest, "Normal text should not be treated as translation request")
    }
}
