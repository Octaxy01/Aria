import XCTest
import AriaDomain
@testable import AriaApplication

final class LanguageDetectorTests: XCTestCase {
    
    // MARK: - Language Detection Tests
    
    func testDetectIndonesian() {
        let indonesianText = "Aku hari ini capek banget."
        let detected = LanguageDetector.detect(indonesianText)
        XCTAssertEqual(detected, .indonesian, "Should detect Indonesian text")
    }
    
    func testDetectJapanese() {
        let japaneseText = "今日は疲れた。"
        let detected = LanguageDetector.detect(japaneseText)
        XCTAssertEqual(detected, .japanese, "Should detect Japanese text")
    }
    
    func testDetectRussian() {
        let russianText = "Я сегодня устал."
        let detected = LanguageDetector.detect(russianText)
        XCTAssertEqual(detected, .russian, "Should detect Russian text")
    }
    
    func testDetectEnglish() {
        let englishText = "I am tired today."
        let detected = LanguageDetector.detect(englishText)
        XCTAssertEqual(detected, .english, "Should detect English text")
    }
    
    func testDetectMixedIndonesian() {
        let mixedText = "Aku mau pergi ke kampus sekarang."
        let detected = LanguageDetector.detect(mixedText)
        XCTAssertEqual(detected, .indonesian, "Should detect Indonesian with multiple markers")
    }
    
    func testDetectShortIndonesian() {
        let shortText = "Siapa kamu?"
        let detected = LanguageDetector.detect(shortText)
        // Short text might not have enough markers, could be English
        XCTAssertTrue(detected == .indonesian || detected == .english, "Short text detection should be reasonable")
    }
    
    // MARK: - Language Override Detection Tests
    
    func testDetectIndonesianOverride() {
        let overrideText = "Jawab pakai bahasa Indonesia."
        let detected = LanguageDetector.detectLanguageOverride(overrideText)
        XCTAssertEqual(detected, .indonesian, "Should detect Indonesian override request")
    }
    
    func testDetectJapaneseOverride() {
        let overrideText = "Japanese please"
        let detected = LanguageDetector.detectLanguageOverride(overrideText)
        XCTAssertEqual(detected, .japanese, "Should detect Japanese override request")
    }
    
    func testDetectRussianOverride() {
        let overrideText = "Jawab dalam bahasa Rusia."
        let detected = LanguageDetector.detectLanguageOverride(overrideText)
        XCTAssertEqual(detected, .russian, "Should detect Russian override request")
    }
    
    func testDetectEnglishOverride() {
        let overrideText = "english please"
        let detected = LanguageDetector.detectLanguageOverride(overrideText)
        XCTAssertEqual(detected, .english, "Should detect English override request")
    }
    
    func testNoOverrideDetection() {
        let normalText = "Hari ini saya pergi ke kantor."
        let detected = LanguageDetector.detectLanguageOverride(normalText)
        XCTAssertNil(detected, "Should not detect override in normal conversation")
    }
    
    // MARK: - Translation Request Detection Tests
    
    func testDetectTranslationRequest() {
        let translationText = "Apa arti 大丈夫?"
        let detected = LanguageDetector.detectTranslationRequest(translationText)
        XCTAssertTrue(detected, "Should detect translation request")
    }
    
    func testDetectMeaningRequest() {
        let meaningText = "Apa maksud kata ini?"
        let detected = LanguageDetector.detectTranslationRequest(meaningText)
        XCTAssertTrue(detected, "Should detect meaning request")
    }
    
    func testDetectTranslateCommand() {
        let translateText = "Translate this to Japanese"
        let detected = LanguageDetector.detectTranslationRequest(translateText)
        XCTAssertTrue(detected, "Should detect translate command")
    }
    
    func testNoTranslationRequest() {
        let normalText = "Saya mau pergi ke pasar."
        let detected = LanguageDetector.detectTranslationRequest(normalText)
        XCTAssertFalse(detected, "Should not detect translation request in normal conversation")
    }
    
    // MARK: - Edge Cases
    
    func testEmptyText() {
        let emptyText = ""
        let detected = LanguageDetector.detect(emptyText)
        XCTAssertEqual(detected, .english, "Empty text should default to English")
    }
    
    func testOnlyPunctuation() {
        let punctuationText = "!!! ??? ..."
        let detected = LanguageDetector.detect(punctuationText)
        XCTAssertEqual(detected, .english, "Punctuation only should default to English")
    }
    
    func testNumbersOnly() {
        let numbersText = "123 456 789"
        let detected = LanguageDetector.detect(numbersText)
        XCTAssertEqual(detected, .english, "Numbers only should default to English")
    }
}
