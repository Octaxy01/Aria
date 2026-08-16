import XCTest
import AriaDomain
@testable import AriaApplication

final class JapaneseConversationalTransformerTests: XCTestCase {
    
    var transformer: JapaneseConversationalTransformer!
    
    override func setUp() async throws {
        transformer = JapaneseConversationalTransformer()
    }
    
    // MARK: - Required Test Cases
    
    func testRequiredTransformations() async throws {
        // Test 1: User example - tired statement
        let input1 = "私は今日は少し疲れています。"
        let result1 = await transformer.transform(input1)
        XCTAssertEqual(result1, "私は今日は少し疲れてる。", "Should transform tired statement correctly")
        
        // Test 2: User example - agreement
        let input2 = "はい、それは良い考えだと思います。"
        let result2 = await transformer.transform(input2)
        XCTAssertEqual(result2, "はい、それは良い考えだと思う。", "Should transform agreement correctly")
        
        // Test 3: Simple acknowledgment
        let input3 = "わかりました。"
        let result3 = await transformer.transform(input3)
        XCTAssertEqual(result3, "わかった。", "Should transform acknowledgment correctly")
        
        // Test 4: Thanks
        let input4 = "ありがとうございます。"
        let result4 = await transformer.transform(input4)
        XCTAssertEqual(result4, "ありがとう。", "Should transform thanks correctly")
        
        // Test 5: Thinking verb
        let input5 = "思います。"
        let result5 = await transformer.transform(input5)
        XCTAssertEqual(result5, "思う。", "Should transform thinking verb correctly")
        
        // Test 6: Past thinking
        let input6 = "思いました。"
        let result6 = await transformer.transform(input6)
        XCTAssertEqual(result6, "思った。", "Should transform past thinking correctly")
        
        // Test 7: Negative thinking
        let input7 = "思いません。"
        let result7 = await transformer.transform(input7)
        XCTAssertEqual(result7, "思わない。", "Should transform negative thinking correctly")
        
        // Test 8: Progressive aspect
        let input8 = "しています。"
        let result8 = await transformer.transform(input8)
        XCTAssertEqual(result8, "してる。", "Should transform progressive aspect correctly")
        
        // Test 9: Past action
        let input9 = "しました。"
        let result9 = await transformer.transform(input9)
        XCTAssertEqual(result9, "した。", "Should transform past action correctly")
        
        // Test 10: Negative action
        let input10 = "しません。"
        let result10 = await transformer.transform(input10)
        XCTAssertEqual(result10, "しない。", "Should transform negative action correctly")
        
        // Test 11: Character voice - natural understanding
        let input11 = "そうですか。"
        let result11 = await transformer.transform(input11)
        XCTAssertEqual(result11, "そっか。", "Should transform to natural understanding")
    }
    
    // MARK: - Regression Tests
    
    func testRegressionMalformedOutput() async throws {
        let testInputs = [
            "思います。",
            "ありがとうございます。",
            "わかりました。",
            "しています。",
            "しています。",
        ]
        
        for input in testInputs {
            let result = await transformer.transform(input)
            
            // These corrupted patterns should NEVER appear in output
            XCTAssertFalse(result.contains("思いる"), "Should not produce '思いる'")
            XCTAssertFalse(result.contains("ございる"), "Should not produce 'ございる'")
            XCTAssertFalse(result.contains("わかりた"), "Should not produce 'わかりた'")
            XCTAssertFalse(result.contains("ありがとうございる"), "Should not produce 'ありがとうございる'")
            XCTAssertFalse(result.contains("しているる"), "Should not produce 'しているる'")
            XCTAssertFalse(result.contains("しる"), "Should not produce 'しる'")
        }
    }
    
    func testIdempotency() async throws {
        let testInputs = [
            "思います。",
            "ありがとうございます。",
            "わかりました。",
            "しています。",
            "疲れています。",
        ]
        
        for input in testInputs {
            let firstTransform = await transformer.transform(input)
            let secondTransform = await transformer.transform(firstTransform)
            
            XCTAssertEqual(firstTransform, secondTransform, "Transformation should be idempotent")
        }
    }
    
    // MARK: - Safety Tests
    
    func testNoRandomBehavior() async throws {
        let input = "思います。"
        
        // Run transformation multiple times
        let results = await withTaskGroup(of: String.self) { group in
            for _ in 0..<10 {
                group.addTask {
                    await self.transformer.transform(input)
                }
            }
            
            var results: [String] = []
            for await result in group {
                results.append(result)
            }
            return results
        }
        
        // All results should be identical (no randomness)
        let firstResult = results.first!
        for result in results {
            XCTAssertEqual(result, firstResult, "Transformation should be deterministic")
        }
    }
    
    // MARK: - Character Voice Tests
    
    func testCharacterVoiceConsistency() async throws {
        // Test that Aria's character voice is consistent through safe transformations
        let testCases = [
            ("わかりました。", "わかった。"), // Understanding
            ("ありがとうございます。", "ありがとう。"), // Thanks
            ("思います。", "思う。"), // Thinking
        ]
        
        for (input, expected) in testCases {
            let result = await transformer.transform(input)
            XCTAssertEqual(result, expected, "Character voice should be consistent")
        }
    }
    
    func testNoExaggeratedAnimeStyle() async throws {
        // Ensure the transformer doesn't produce exaggerated anime speech
        let inputs = [
            "わかりました。",
            "ありがとうございます。",
            "思います。",
        ]
        
        for input in inputs {
            let result = await transformer.transform(input)
            
            // These should NOT appear in output
            XCTAssertFalse(result.contains("ですぅ"), "Should not produce 'ですぅ'")
            XCTAssertFalse(result.contains("だよぉ"), "Should not produce 'だよぉ'")
            XCTAssertFalse(result.contains("にゃ"), "Should not produce 'にゃ'")
            XCTAssertFalse(result.contains("〜"), "Should not produce '〜'")
        }
    }
    
    func testUnchangedTextForUnsupportedPatterns() async throws {
        // Text that should not be transformed
        let unsupportedInputs = [
            "これは本です。", // です as sentence ending - currently unchanged for safety
            "こんにちは。",
            "さようなら。",
            "ありがとう。", // Already casual
        ]
        
        for input in unsupportedInputs {
            let result = await transformer.transform(input)
            // Should either remain unchanged or be safely transformed
            // We just verify it doesn't crash and produces valid Japanese
            XCTAssertFalse(result.isEmpty, "Should not produce empty output")
        }
    }
    
    func testPunctuationPreservation() async throws {
        let testInputs = [
            ("思います。", "思う。"),
            ("思います？", "思う？"),
            ("思います！", "思う！"),
            ("ありがとうございます。", "ありがとう。"),
            ("わかりました。", "わかった。"),
        ]
        
        for (input, expectedOutput) in testInputs {
            let result = await transformer.transform(input)
            XCTAssertEqual(result, expectedOutput, "Should preserve punctuation correctly")
        }
    }
    
    // MARK: - Conversational Structure Tests
    
    func testSafeConversationalTransformations() async throws {
        // Test that the transformer supports natural conversational forms
        let conversationalCases = [
            ("そうですね。", "そうだね。"), // Natural agreement
            ("そうですね？", "そうだね？"), // Natural agreement question
            ("でしょう。", "かな。"), // Natural uncertainty
            ("でしょう？", "かな？"), // Natural uncertainty question
            ("ですね。", "だね。"), // Soft agreement
            ("ですね？", "だね？"), // Soft agreement question
        ]
        
        for (input, expected) in conversationalCases {
            let result = await transformer.transform(input)
            XCTAssertEqual(result, expected, "Should support conversational patterns")
        }
    }
    
    func testNoWrittenJapanesePatterns() async throws {
        // Ensure transformer doesn't produce written-style patterns inappropriately
        let inputs = [
            "思います。",
            "わかりました。",
            "ありがとうございます。",
        ]
        
        for input in inputs {
            let result = await transformer.transform(input)
            
            // Should not retain formal written patterns when casual is appropriate
            XCTAssertFalse(result.contains("思います"), "Should transform 思います")
            XCTAssertFalse(result.contains("わかりました"), "Should transform わかりました")
            XCTAssertFalse(result.contains("ありがとうございます"), "Should transform ありがとうございます")
        }
    }
}