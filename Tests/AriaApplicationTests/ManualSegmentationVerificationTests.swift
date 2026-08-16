import XCTest
@testable import AriaApplication

/// Manual verification tests for Japanese TTS segmentation.
/// These tests verify the segmentation logic produces expected segments and pauses.
final class ManualSegmentationVerificationTests: XCTestCase {
    
    var segmenter: JapaneseTTSSegmenter!
    var pauseConfiguration: JapaneseTTSPauseConfiguration!
    
    override func setUp() {
        segmenter = JapaneseTTSSegmenter()
        pauseConfiguration = JapaneseTTSPauseConfiguration()
    }
    
    // MARK: - Test 1: Multi-sentence with ellipsis
    
    func testTest1_MultiSentenceWithEllipsis() {
        let input = "んー……今日はちょっと疲れてる。何か食べたいな。"
        let segments = segmenter.segment(input)
        
        print("=== Test 1 ===")
        print("Input: \(input)")
        print("Segments: \(segments)")
        print("Segment count: \(segments.count)")
        
        XCTAssertEqual(segments.count, 2, "Should split into 2 segments")
        XCTAssertEqual(segments[0], "んー……今日はちょっと疲れてる。", "First segment with ellipsis")
        XCTAssertEqual(segments[1], "何か食べたいな。", "Second segment")
        
        // Calculate pauses
        let pause1 = pauseConfiguration.pauseForSegment(segments[0])
        print("Pause after segment 1: \(pause1 * 1000) ms")
        
        XCTAssertEqual(pause1, 0.25, "Normal sentence pause should be 250ms")
    }
    
    // MARK: - Test 2: Question and exclamation
    
    func testTest2_QuestionAndExclamation() {
        let input = "ほんと！？それならよかった！"
        let segments = segmenter.segment(input)
        
        print("=== Test 2 ===")
        print("Input: \(input)")
        print("Segments: \(segments)")
        print("Segment count: \(segments.count)")
        
        XCTAssertEqual(segments.count, 2, "Should split into 2 segments")
        XCTAssertEqual(segments[0], "ほんと！？", "First segment with consecutive punctuation")
        XCTAssertEqual(segments[1], "それならよかった！", "Second segment")
        
        // Calculate pauses
        let pause1 = pauseConfiguration.pauseForSegment(segments[0])
        print("Pause after segment 1: \(pause1 * 1000) ms")
        
        XCTAssertEqual(pause1, 0.30, "Expressive pause should be 300ms")
    }
    
    // MARK: - Test 3: Single short response
    
    func testTest3_SingleShortResponse() {
        let input = "うん。"
        let segments = segmenter.segment(input)
        
        print("=== Test 3 ===")
        print("Input: \(input)")
        print("Segments: \(segments)")
        print("Segment count: \(segments.count)")
        
        XCTAssertEqual(segments.count, 1, "Should be 1 segment")
        XCTAssertEqual(segments[0], "うん。", "Single segment")
        
        // No pause needed for single segment
        print("Pause: None (single segment)")
    }
    
    // MARK: - Test 4: Ellipsis not as boundary
    
    func testTest4_EllipsisNotAsBoundary() {
        let input = "んー……どうしようかな。"
        let segments = segmenter.segment(input)
        
        print("=== Test 4 ===")
        print("Input: \(input)")
        print("Segments: \(segments)")
        print("Segment count: \(segments.count)")
        
        XCTAssertEqual(segments.count, 1, "Should be 1 segment")
        XCTAssertEqual(segments[0], "んー……どうしようかな。", "Ellipsis should not split")
        
        // No pause needed for single segment
        print("Pause: None (single segment)")
    }
    
    // MARK: - Integration verification
    
    func testPauseConfigurationCoverage() {
        print("=== Pause Configuration ===")
        print("Normal sentence pause: \(pauseConfiguration.normalSentencePause * 1000) ms")
        print("Expressive sentence pause: \(pauseConfiguration.expressiveSentencePause * 1000) ms")
        
        // Test various endings
        let testCases = [
            ("今日は疲れてる。", 0.25),
            ("ほんと？", 0.30),
            ("よかった！", 0.30),
            ("元気？", 0.30),
            ("ありがとう。", 0.25),
        ]
        
        for (segment, expectedPause) in testCases {
            let actualPause = pauseConfiguration.pauseForSegment(segment)
            print("Segment: '\(segment)' → Pause: \(actualPause * 1000) ms")
            XCTAssertEqual(actualPause, expectedPause, "Pause should match expected")
        }
    }
}
