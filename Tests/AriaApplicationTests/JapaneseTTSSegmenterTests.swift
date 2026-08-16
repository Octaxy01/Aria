import XCTest
@testable import AriaApplication

final class JapaneseTTSSegmenterTests: XCTestCase {
    
    var segmenter: JapaneseTTSSegmenter!
    
    override func setUp() {
        segmenter = JapaneseTTSSegmenter()
    }
    
    // MARK: - Required Tests
    
    func testSegmentationWithEllipsisAndSentences() {
        let input = "んー……今日はちょっと疲れてる。何か食べたいな。"
        let result = segmenter.segment(input)
        
        XCTAssertEqual(result.count, 2, "Should split into 2 segments")
        XCTAssertEqual(result[0], "んー……今日はちょっと疲れてる。", "First segment should include ellipsis")
        XCTAssertEqual(result[1], "何か食べたいな。", "Second segment should be the second sentence")
    }
    
    func testSegmentationWithQuestionAndExclamation() {
        let input = "ほんと？それならよかった！"
        let result = segmenter.segment(input)
        
        XCTAssertEqual(result.count, 2, "Should split into 2 segments")
        XCTAssertEqual(result[0], "ほんと？", "First segment should end with question mark")
        XCTAssertEqual(result[1], "それならよかった！", "Second segment should end with exclamation")
    }
    
    func testNoSplitOnComma() {
        let input = "うん、それいいと思う。"
        let result = segmenter.segment(input)
        
        XCTAssertEqual(result.count, 1, "Should NOT split on comma")
        XCTAssertEqual(result[0], "うん、それいいと思う。", "Should remain as one segment")
    }
    
    func testNoSplitOnCommaPhrase() {
        let input = "あっ、そうだ。"
        let result = segmenter.segment(input)
        
        XCTAssertEqual(result.count, 1, "Should NOT split on comma-like punctuation")
        XCTAssertEqual(result[0], "あっ、そうだ。", "Should remain as one segment")
    }
    
    func testSegmentationWithNewlines() {
        let input = "今日はちょっと疲れてる。\n何か食べたいな。"
        let result = segmenter.segment(input)
        
        XCTAssertEqual(result.count, 2, "Should split on newline")
        XCTAssertEqual(result[0], "今日はちょっと疲れてる。", "First segment should be first line")
        XCTAssertEqual(result[1], "何か食べたいな。", "Second segment should be second line")
    }
    
    func testEllipsisNotAsBoundary() {
        let input = "んー……どうしようかな。"
        let result = segmenter.segment(input)
        
        XCTAssertEqual(result.count, 1, "Should NOT split on ellipsis")
        XCTAssertEqual(result[0], "んー……どうしようかな。", "Should remain as one segment")
    }
    
    func testShortResponse() {
        let input = "うん。"
        let result = segmenter.segment(input)
        
        XCTAssertEqual(result.count, 1, "Should be one segment")
        XCTAssertEqual(result[0], "うん。", "Short response should be one segment")
    }
    
    func testQuestionAndExclamation() {
        let input = "こんにちは！元気？"
        let result = segmenter.segment(input)
        
        XCTAssertEqual(result.count, 2, "Should split into 2 segments")
        XCTAssertEqual(result[0], "こんにちは！", "First segment with exclamation")
        XCTAssertEqual(result[1], "元気？", "Second segment with question")
    }
    
    func testCommaFollowedBySentenceBoundary() {
        let input = "うん、それいいと思う。何食べたい？"
        let result = segmenter.segment(input)
        
        XCTAssertEqual(result.count, 2, "Should split at sentence boundaries only")
        XCTAssertEqual(result[0], "うん、それいいと思う。", "First segment should include comma")
        XCTAssertEqual(result[1], "何食べたい？", "Second segment should be the question")
    }
    
    func testSingleSentence() {
        let input = "こんにちは。"
        let result = segmenter.segment(input)
        
        XCTAssertEqual(result.count, 1, "Should be one segment")
        XCTAssertEqual(result[0], "こんにちは。", "Single sentence should be one segment")
    }
    
    // MARK: - Edge Cases
    
    func testEmptyInput() {
        let input = ""
        let result = segmenter.segment(input)
        
        XCTAssertEqual(result.count, 0, "Empty input should produce no segments")
    }
    
    func testWhitespaceOnlyInput() {
        let input = "   \n\n   "
        let result = segmenter.segment(input)
        
        XCTAssertEqual(result.count, 0, "Whitespace-only input should produce no segments")
    }
    
    func testMultipleConsecutivePunctuation() {
        let input = "えええ！？"
        let result = segmenter.segment(input)
        
        XCTAssertEqual(result.count, 1, "Should remain as one segment")
        XCTAssertEqual(result[0], "えええ！？", "Should preserve punctuation")
    }
    
    func testConsecutivePunctuationWithSentence() {
        let input = "えっ！？ほんと？"
        let result = segmenter.segment(input)
        
        XCTAssertEqual(result.count, 2, "Should split into 2 segments")
        XCTAssertEqual(result[0], "えっ！？", "First segment with consecutive punctuation")
        XCTAssertEqual(result[1], "ほんと？", "Second segment")
    }
    
    func testEllipsisWithQuestion() {
        let input = "ほんと……？"
        let result = segmenter.segment(input)
        
        XCTAssertEqual(result.count, 1, "Should remain as one segment")
        XCTAssertEqual(result[0], "ほんと……？", "Should keep ellipsis with question")
    }
    
    func testMultipleExclamationWithSentence() {
        let input = "ええっ！！ほんと！？"
        let result = segmenter.segment(input)
        
        XCTAssertEqual(result.count, 2, "Should split into 2 segments")
        XCTAssertEqual(result[0], "ええっ！！", "First segment with multiple exclamations")
        XCTAssertEqual(result[1], "ほんと！？", "Second segment with consecutive punctuation")
    }
    
    func testConsecutiveNewlinesNoEmptySegments() {
        let input = "今日は疲れてる。\n\n\n何か食べたいな。"
        let result = segmenter.segment(input)
        
        XCTAssertEqual(result.count, 2, "Should split into 2 segments without empty segments")
        XCTAssertEqual(result[0], "今日は疲れてる。", "First segment")
        XCTAssertEqual(result[1], "何か食べたいな。", "Second segment")
    }
    
    func testMixedPunctuation() {
        let input = "えっ？本当に！"
        let result = segmenter.segment(input)
        
        XCTAssertEqual(result.count, 2, "Should split at sentence boundaries")
        XCTAssertEqual(result[0], "えっ？", "First segment")
        XCTAssertEqual(result[1], "本当に！", "Second segment")
    }
    
    func testLongSegmentWithinLimit() {
        let input = String(repeating: "あ", count: 50) + "。"
        let result = segmenter.segment(input)
        
        XCTAssertEqual(result.count, 1, "Should be one segment if within limit")
    }
    
    func testTrimmedWhitespace() {
        let input = "  こんにちは。  "
        let result = segmenter.segment(input)
        
        XCTAssertEqual(result.count, 1, "Should trim whitespace")
        XCTAssertEqual(result[0], "こんにちは。", "Should not have leading/trailing whitespace")
    }
}