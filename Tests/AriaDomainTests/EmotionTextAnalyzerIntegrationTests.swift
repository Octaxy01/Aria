import XCTest
@testable import AriaDomain

final class EmotionTextAnalyzerIntegrationTests: XCTestCase {
    // MARK: - Integration-style tests for emotion detection in different contexts
    
    func testDetectsEmotionInPlayfulResponse() {
        let text = "Haha that's so funny! 😂 You always make me laugh"
        let signal = EmotionTextAnalyzer.analyze(text)
        
        XCTAssertEqual(signal?.emotion, .playful)
        XCTAssertEqual(signal?.intensity ?? 0.0, 0.6, accuracy: 0.01)
    }
    
    func testDetectsEmotionInIndonesianPlayfulResponse() {
        let text = "wkwk ketawa terus ini lucu banget tertawa pelak"
        let signal = EmotionTextAnalyzer.analyze(text)
        
        XCTAssertEqual(signal?.emotion, .playful)
        XCTAssertEqual(signal?.intensity ?? 0.0, 0.6, accuracy: 0.01)
    }
    
    func testDetectsEmotionInHappyResponse() {
        let text = "Yay! Finally finished! 🎉 This is amazing"
        let signal = EmotionTextAnalyzer.analyze(text)
        
        XCTAssertEqual(signal?.emotion, .excited)
        XCTAssertEqual(signal?.intensity ?? 0.0, 0.7, accuracy: 0.01)
    }
    
    func testReturnsNilForNeutralResponse() {
        let text = "The project is coming along well with the new features."
        let signal = EmotionTextAnalyzer.analyze(text)
        
        XCTAssertNil(signal)
    }
    
    func testDetectsEmotionInAffectionateResponse() {
        let text = "I care about you so much ❤ You're important to me"
        let signal = EmotionTextAnalyzer.analyze(text)
        
        XCTAssertEqual(signal?.emotion, .affectionate)
        XCTAssertEqual(signal?.intensity ?? 0.0, 0.5, accuracy: 0.01)
    }
    
    func testDetectsEmotionInWorriedResponse() {
        let text = "I'm worried about the outcome, but hopefully it works"
        let signal = EmotionTextAnalyzer.analyze(text)
        
        XCTAssertEqual(signal?.emotion, .worried)
        XCTAssertEqual(signal?.intensity ?? 0.0, 0.4, accuracy: 0.01)
    }
    
    func testDetectsEmotionInAnnoyedResponse() {
        let text = "Ugh, seriously? This is getting annoying *sighs*"
        let signal = EmotionTextAnalyzer.analyze(text)
        
        XCTAssertEqual(signal?.emotion, .annoyed)
        XCTAssertEqual(signal?.intensity ?? 0.0, 0.5, accuracy: 0.01)
    }
    
    func testDetectsEmotionInEmbarrassedResponse() {
        let text = "*blushes* um, well, I kind of like that"
        let signal = EmotionTextAnalyzer.analyze(text)
        
        XCTAssertEqual(signal?.emotion, .embarrassed)
        XCTAssertEqual(signal?.intensity ?? 0.0, 0.4, accuracy: 0.01)
    }
    
    func testHandlesLongerTextWithMixedEmotion() {
        let text = "Haha! This is great, but I'm a bit nervous about the deadline"
        let signal = EmotionTextAnalyzer.analyze(text)
        
        // Should detect the strongest emotion (playful in this case)
        XCTAssertEqual(signal?.emotion, .playful)
    }
    
    func testDetectsEmotionInMixedFormatResponse() {
        let text = "```json\n{\"text\":\"Haha! Lucu banget\",\"emotion\":{\"kind\":\"playful\",\"intensity\":0.7}}\n```"
        let signal = EmotionTextAnalyzer.analyze(text)
        
        // Even though this is JSON, the analyzer should still detect playful content
        // in case JSON parsing fails
        XCTAssertEqual(signal?.emotion, .playful)
    }
}
