import XCTest
import AriaDomain

final class LanguageSettingsTests: XCTestCase {
    
    // MARK: - Default Settings Tests
    
    func testDefaultSettings() {
        let settings = LanguageSettings.default
        XCTAssertEqual(settings.inputLanguage, .auto, "Default input should be auto")
        XCTAssertEqual(settings.outputLanguage, .japanese, "Default output should be Japanese")
        XCTAssertEqual(settings.translationMode, .onDemand, "Default translation should be on demand")
        XCTAssertNil(settings.conversationOverride, "Default should have no conversation override")
    }
    
    func testEffectiveOutputLanguageWithoutOverride() {
        var settings = LanguageSettings.default
        settings.outputLanguage = .indonesian
        XCTAssertEqual(settings.effectiveOutputLanguage, .indonesian, "Should use output language when no override")
    }
    
    func testEffectiveOutputLanguageWithOverride() {
        var settings = LanguageSettings.default
        settings.outputLanguage = .japanese
        settings.setConversationOverride(.indonesian)
        XCTAssertEqual(settings.effectiveOutputLanguage, .indonesian, "Should use override when set")
    }
    
    // MARK: - Conversation Override Tests
    
    func testSetConversationOverride() {
        var settings = LanguageSettings.default
        XCTAssertNil(settings.conversationOverride, "Initially no override")
        
        settings.setConversationOverride(.russian)
        XCTAssertEqual(settings.conversationOverride, .russian, "Override should be set")
    }
    
    func testClearConversationOverride() {
        var settings = LanguageSettings.default
        settings.setConversationOverride(.english)
        XCTAssertNotNil(settings.conversationOverride, "Override should be set")
        
        settings.clearConversationOverride()
        XCTAssertNil(settings.conversationOverride, "Override should be cleared")
    }
    
    func testOverrideDoesNotAffectDefault() {
        var settings = LanguageSettings.default
        let originalOutput = settings.outputLanguage
        
        settings.setConversationOverride(.indonesian)
        XCTAssertEqual(settings.outputLanguage, originalOutput, "Setting override should not change default")
    }
    
    // MARK: - Language Enum Tests
    
    func testSupportedLanguageDisplayNames() {
        XCTAssertEqual(SupportedLanguage.auto.displayName, "Auto")
        XCTAssertEqual(SupportedLanguage.indonesian.displayName, "Indonesian")
        XCTAssertEqual(SupportedLanguage.japanese.displayName, "Japanese")
        XCTAssertEqual(SupportedLanguage.english.displayName, "English")
        XCTAssertEqual(SupportedLanguage.russian.displayName, "Russian")
    }
    
    func testSupportedLanguageToTTSLanguage() {
        XCTAssertEqual(SupportedLanguage.indonesian.toTTSLanguage, .indonesian)
        XCTAssertEqual(SupportedLanguage.japanese.toTTSLanguage, .japanese)
        XCTAssertEqual(SupportedLanguage.english.toTTSLanguage, .english)
        XCTAssertEqual(SupportedLanguage.russian.toTTSLanguage, .russian)
        XCTAssertEqual(SupportedLanguage.auto.toTTSLanguage, .english) // Default fallback
    }
    
    // MARK: - Translation Mode Tests
    
    func testTranslationModeDisplayNames() {
        XCTAssertEqual(TranslationMode.onDemand.displayName, "On Demand")
        XCTAssertEqual(TranslationMode.always.displayName, "Always")
        XCTAssertEqual(TranslationMode.never.displayName, "Never")
    }
    
    // MARK: - Configuration Change Tests
    
    func testChangeDefaultOutputLanguage() {
        var settings = LanguageSettings.default
        XCTAssertEqual(settings.outputLanguage, .japanese, "Initial default should be Japanese")
        
        settings.outputLanguage = .indonesian
        XCTAssertEqual(settings.outputLanguage, .indonesian, "Should be able to change to Indonesian")
        
        settings.outputLanguage = .russian
        XCTAssertEqual(settings.outputLanguage, .russian, "Should be able to change to Russian")
        
        settings.outputLanguage = .english
        XCTAssertEqual(settings.outputLanguage, .english, "Should be able to change to English")
    }
    
    func testSingleSourceOfTruth() {
        // This test verifies that changing one setting affects all dependent behavior
        var settings = LanguageSettings.default
        settings.outputLanguage = .japanese
        
        // All parts of the system should consult settings.effectiveOutputLanguage
        // This is a conceptual test - the actual implementation is verified in integration tests
        XCTAssertEqual(settings.effectiveOutputLanguage, .japanese)
        
        settings.outputLanguage = .indonesian
        XCTAssertEqual(settings.effectiveOutputLanguage, .indonesian)
    }
    
    // MARK: - Equatable Tests
    
    func testLanguageSettingsEquality() {
        let settings1 = LanguageSettings.default
        let settings2 = LanguageSettings.default
        XCTAssertEqual(settings1, settings2, "Default settings should be equal")
        
        var settings3 = LanguageSettings.default
        settings3.outputLanguage = .indonesian
        XCTAssertNotEqual(settings1, settings3, "Different settings should not be equal")
    }
    
    // MARK: - Codable Tests
    
    func testLanguageSettingsCoding() throws {
        let originalSettings = LanguageSettings(
            inputLanguage: .auto,
            outputLanguage: .japanese,
            translationMode: .onDemand,
            conversationOverride: .indonesian
        )
        
        let encoder = JSONEncoder()
        let data = try encoder.encode(originalSettings)
        
        let decoder = JSONDecoder()
        let decodedSettings = try decoder.decode(LanguageSettings.self, from: data)
        
        XCTAssertEqual(originalSettings.inputLanguage, decodedSettings.inputLanguage)
        XCTAssertEqual(originalSettings.outputLanguage, decodedSettings.outputLanguage)
        XCTAssertEqual(originalSettings.translationMode, decodedSettings.translationMode)
        XCTAssertEqual(originalSettings.conversationOverride, decodedSettings.conversationOverride)
    }
}
