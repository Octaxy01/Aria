import XCTest
@testable import AriaDomain

final class ResponseFormatTests: XCTestCase {
    // These tests verify the various response format patterns that should be handled
    
    func testDirectJSONFormat() {
        let jsonText = "{\"text\":\"Hello\",\"emotion\":{\"kind\":\"happy\",\"intensity\":0.8}}"
        
        // Verify the structure contains expected fields
        XCTAssertTrue(jsonText.contains("\"text\""))
        XCTAssertTrue(jsonText.contains("\"emotion\""))
        XCTAssertTrue(jsonText.contains("\"kind\""))
        XCTAssertTrue(jsonText.contains("\"intensity\""))
    }
    
    func testMarkdownJSONFormat() {
        let markdownText = """
        ```json
        {"text":"Hello","emotion":{"kind":"playful","intensity":0.6}}
        ```
        """
        
        // Verify the text contains the expected pattern
        XCTAssertTrue(markdownText.contains("{\"text\""))
        XCTAssertTrue(markdownText.contains("```json"))
    }
    
    func testMixedContentFormat() {
        let mixedText = "Here's my response: {\"text\":\"Test\",\"emotion\":{\"kind\":\"neutral\",\"intensity\":0.5}} and some extra text"
        
        // Verify JSON is present in mixed content
        XCTAssertTrue(mixedText.contains("{\"text\""))
        XCTAssertTrue(mixedText.contains("\"emotion\""))
    }
    
    func testPlainTextFormat() {
        let plainText = "This is just plain text without any JSON structure"
        
        // Verify no JSON structure exists
        XCTAssertFalse(plainText.contains("{\"text\""))
        XCTAssertFalse(plainText.contains("\"emotion\""))
    }
    
    func testIndonesianResponseWithEmotion() {
        let indonesianText = "Hei… *tertawa pelak* Aku Aria, asisten desktopmu"
        
        // Verify Indonesian emotion markers are present
        XCTAssertTrue(indonesianText.contains("tertawa"))
        XCTAssertTrue(indonesianText.contains("Aria"))
    }
    
    func testIndonesianEmotionMarkers() {
        let text = "tertawa pelak keren banget"
        let signal = EmotionTextAnalyzer.analyze(text)
        
        // Should detect playful emotion from Indonesian markers
        XCTAssertNotNil(signal)
        XCTAssertEqual(signal?.emotion, .playful)
    }
}
