import XCTest
@testable import AriaDomain

final class EmotionTextAnalyzerTests: XCTestCase {
    func testDetectsPlayfulEmotion() {
        let text = "Haha that's so funny! 😂"
        let signal = EmotionTextAnalyzer.analyze(text)
        
        XCTAssertNotNil(signal)
        XCTAssertEqual(signal?.emotion, .playful)
        XCTAssertEqual(signal?.intensity ?? 0.0, 0.6, accuracy: 0.01)
    }
    
    func testDetectsPlayfulEmotionIndonesian() {
        let text = "tertawa pelak ini lucu banget"
        let signal = EmotionTextAnalyzer.analyze(text)
        
        XCTAssertNotNil(signal)
        XCTAssertEqual(signal?.emotion, .playful)
        XCTAssertEqual(signal?.intensity ?? 0.0, 0.6, accuracy: 0.01)
    }
    
    func testDetectsHappyEmotion() {
        let text = "Yay! Finally finished! 🎉"
        let signal = EmotionTextAnalyzer.analyze(text)
        
        XCTAssertNotNil(signal)
        XCTAssertEqual(signal?.emotion, .excited)
        XCTAssertEqual(signal?.intensity ?? 0.0, 0.7, accuracy: 0.01)
    }
    
    func testDetectsHappyEmotionIndonesian() {
        let text = "bagus banget kerja kamu keren"
        let signal = EmotionTextAnalyzer.analyze(text)
        
        XCTAssertNotNil(signal)
        XCTAssertEqual(signal?.emotion, .excited)
        XCTAssertEqual(signal?.intensity ?? 0.0, 0.7, accuracy: 0.01)
    }
    
    func testDetectsAffectionateEmotion() {
        let text = "I care about you so much ❤"
        let signal = EmotionTextAnalyzer.analyze(text)
        
        XCTAssertNotNil(signal)
        XCTAssertEqual(signal?.emotion, .affectionate)
        XCTAssertEqual(signal?.intensity ?? 0.0, 0.5, accuracy: 0.01)
    }
    
    func testDetectsWorriedEmotion() {
        let text = "I'm worried about the outcome"
        let signal = EmotionTextAnalyzer.analyze(text)
        
        XCTAssertNotNil(signal)
        XCTAssertEqual(signal?.emotion, .worried)
        XCTAssertEqual(signal?.intensity ?? 0.0, 0.4, accuracy: 0.01)
    }
    
    func testDetectsAnnoyedEmotion() {
        let text = "Ugh, seriously? This is annoying"
        let signal = EmotionTextAnalyzer.analyze(text)
        
        XCTAssertNotNil(signal)
        XCTAssertEqual(signal?.emotion, .annoyed)
        XCTAssertEqual(signal?.intensity ?? 0.0, 0.5, accuracy: 0.01)
    }
    
    func testDetectsEmbarrassedEmotion() {
        let text = "*blushes* um, well, I kind of like it"
        let signal = EmotionTextAnalyzer.analyze(text)
        
        XCTAssertNotNil(signal)
        XCTAssertEqual(signal?.emotion, .embarrassed)
        XCTAssertEqual(signal?.intensity ?? 0.0, 0.4, accuracy: 0.01)
    }
    
    func testReturnsNilForNeutralText() {
        let text = "The project is coming along well."
        let signal = EmotionTextAnalyzer.analyze(text)
        
        XCTAssertNil(signal)
    }
    
    func testCaseInsensitive() {
        let text = "HHAHA that's FUNNY"
        let signal = EmotionTextAnalyzer.analyze(text)
        
        XCTAssertNotNil(signal)
        XCTAssertEqual(signal?.emotion, .playful)
    }
    
    func testPlayfulTakesPriority() {
        let text = "Haha! I love this so much ❤"
        let signal = EmotionTextAnalyzer.analyze(text)
        
        // Playful should be detected first in priority
        XCTAssertNotNil(signal)
        XCTAssertEqual(signal?.emotion, .playful)
    }
    
    func testEmptyText() {
        let signal = EmotionTextAnalyzer.analyze("")
        XCTAssertNil(signal)
    }
}
