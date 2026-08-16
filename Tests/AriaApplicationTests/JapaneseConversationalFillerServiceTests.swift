import XCTest
import AriaDomain
@testable import AriaApplication

final class JapaneseConversationalFillerServiceTests: XCTestCase {
    
    var fillerService: JapaneseConversationalFillerService!
    
    override func setUp() async throws {
        fillerService = JapaneseConversationalFillerService()
    }
    
    override func tearDown() async throws {
        fillerService.resetFillerTracking()
    }
    
    // MARK: - Thinking Context Tests
    
    func testThinkingFillerCasual() async throws {
        let emotion = EmotionState(current: .worried, intensity: 0.6)
        let tone = ConversationTone.casual
        let relationship = RelationshipState.initial
        
        let input = "どうしようかな。"
        let result = fillerService.addFillers(input, tone: tone, emotion: emotion, relationship: relationship)
        
        XCTAssertEqual(result, "んー……どうしようかな。", "Should add thinking filler in casual context")
    }
    
    func testThinkingFillerSerious() async throws {
        let emotion = EmotionState(current: .worried, intensity: 0.6)
        let tone = ConversationTone.serious
        let relationship = RelationshipState.initial
        
        let input = "どうしようかな。"
        let result = fillerService.addFillers(input, tone: tone, emotion: emotion, relationship: relationship)
        
        XCTAssertEqual(result, "うーん……どうしようかな。", "Should add thinking filler in serious context")
    }
    
    func testNoThinkingFillerTechnical() async throws {
        let emotion = EmotionState(current: .worried, intensity: 0.6)
        let tone = ConversationTone.technical
        let relationship = RelationshipState.initial
        
        let input = "どうしようかな。"
        let result = fillerService.addFillers(input, tone: tone, emotion: emotion, relationship: relationship)
        
        XCTAssertEqual(result, input, "Should NOT add filler in technical context")
    }
    
    // MARK: - Happiness Context Tests
    
    func testHappinessFillerWithHappyIndicator() async throws {
        let emotion = EmotionState(current: .happy, intensity: 0.8)
        let tone = ConversationTone.casual
        let relationship = RelationshipState.initial
        
        let input = "嬉しいな。"
        let result = fillerService.addFillers(input, tone: tone, emotion: emotion, relationship: relationship)
        
        XCTAssertEqual(result, "ふふ嬉しいな。", "Should add happiness filler with happy indicator")
    }
    
    func testNoHappinessFillerWithoutIndicator() async throws {
        let emotion = EmotionState(current: .happy, intensity: 0.8)
        let tone = ConversationTone.casual
        let relationship = RelationshipState.initial
        
        let input = "今日はいい天気だね。"
        let result = fillerService.addFillers(input, tone: tone, emotion: emotion, relationship: relationship)
        
        XCTAssertEqual(result, input, "Should NOT add filler without happy indicator")
    }
    
    // MARK: - Emotional Context Tests
    
    func testEmotionalFillerCasual() async throws {
        let emotion = EmotionState(current: .sad, intensity: 0.7)
        let tone = ConversationTone.casual
        let relationship = RelationshipState.initial
        
        let input = "悲しいな。"
        let result = fillerService.addFillers(input, tone: tone, emotion: emotion, relationship: relationship)
        
        XCTAssertEqual(result, "んー……悲しいな。", "Should add emotional filler in casual context")
    }
    
    func testEmotionalFillerContext() async throws {
        let emotion = EmotionState(current: .sad, intensity: 0.7)
        let tone = ConversationTone.emotional
        let relationship = RelationshipState.initial
        
        let input = "悲しいな。"
        let result = fillerService.addFillers(input, tone: tone, emotion: emotion, relationship: relationship)
        
        XCTAssertEqual(result, "そっか……悲しいな。", "Should add gentle acknowledgment in emotional context")
    }
    
    // MARK: - Embarrassment Context Tests
    
    func testEmbarrassmentFiller() async throws {
        let emotion = EmotionState(current: .embarrassed, intensity: 0.6)
        let tone = ConversationTone.casual
        let relationship = RelationshipState.initial
        
        let input = "恥ずかしいな。"
        let result = fillerService.addFillers(input, tone: tone, emotion: emotion, relationship: relationship)
        
        XCTAssertEqual(result, "えっと……恥ずかしいな。", "Should add embarrassment filler")
    }
    
    // MARK: - Neutral Context Tests
    
    func testNoFillerNeutralContext() async throws {
        let emotion = EmotionState(current: .neutral, intensity: 0.0)
        let tone = ConversationTone.casual
        let relationship = RelationshipState.initial
        
        let input = "今日はいい天気だね。"
        let result = fillerService.addFillers(input, tone: tone, emotion: emotion, relationship: relationship)
        
        XCTAssertEqual(result, input, "Should NOT add filler in neutral context")
    }
    
    func testNoFillerTechnicalContext() async throws {
        let emotion = EmotionState(current: .neutral, intensity: 0.0)
        let tone = ConversationTone.technical
        let relationship = RelationshipState.initial
        
        let input = "Swift Actorは。"
        let result = fillerService.addFillers(input, tone: tone, emotion: emotion, relationship: relationship)
        
        XCTAssertEqual(result, input, "Should NOT add filler in technical context")
    }
    
    // MARK: - No Filler Cases
    
    func testNoFillerWhenTextHasConversationalPrefix() async throws {
        let emotion = EmotionState(current: .worried, intensity: 0.6)
        let tone = ConversationTone.casual
        let relationship = RelationshipState.initial
        
        let input = "うん、わかった。"
        let result = fillerService.addFillers(input, tone: tone, emotion: emotion, relationship: relationship)
        
        XCTAssertEqual(result, input, "Should NOT add filler when text already has conversational prefix")
    }
    
    func testNoFillerEmptyText() async throws {
        let emotion = EmotionState(current: .happy, intensity: 0.8)
        let tone = ConversationTone.casual
        let relationship = RelationshipState.initial
        
        let input = ""
        let result = fillerService.addFillers(input, tone: tone, emotion: emotion, relationship: relationship)
        
        XCTAssertEqual(result, input, "Should handle empty text safely")
    }
    
    // MARK: - Repetition Prevention Tests
    
    func testPreventsImmediateRepetition() async throws {
        let emotion = EmotionState(current: .worried, intensity: 0.6)
        let tone = ConversationTone.casual
        let relationship = RelationshipState.initial
        
        let input = "どうしようかな。"
        
        // First call should add filler
        let result1 = fillerService.addFillers(input, tone: tone, emotion: emotion, relationship: relationship)
        XCTAssertEqual(result1, "んー……どうしようかな。")
        
        // Second call with same context should also add filler (allowed up to 2 times)
        let result2 = fillerService.addFillers(input, tone: tone, emotion: emotion, relationship: relationship)
        XCTAssertEqual(result2, "んー……どうしようかな。")
        
        // Third call should skip filler (would be 3rd consecutive)
        let result3 = fillerService.addFillers(input, tone: tone, emotion: emotion, relationship: relationship)
        XCTAssertEqual(result3, input, "Should skip filler after 2 consecutive uses")
    }
    
    // MARK: - Negative Tests
    
    func testNoExaggeratedAnimeStyle() async throws {
        let emotion = EmotionState(current: .happy, intensity: 0.8)
        let tone = ConversationTone.casual
        let relationship = RelationshipState.initial
        
        let input = "嬉しいな。"
        let result = fillerService.addFillers(input, tone: tone, emotion: emotion, relationship: relationship)
        
        // Should not produce exaggerated patterns
        XCTAssertFalse(result.contains("えへへ〜♡"), "Should not produce exaggerated anime style")
        XCTAssertFalse(result.contains("だよぉ〜"), "Should not produce exaggerated anime style")
        XCTAssertFalse(result.contains("ですぅ"), "Should not produce exaggerated anime style")
        XCTAssertFalse(result.contains("にゃ"), "Should not produce exaggerated anime style")
    }
    
    func testNoMultipleFillersInSingleResponse() async throws {
        let emotion = EmotionState(current: .worried, intensity: 0.6)
        let tone = ConversationTone.casual
        let relationship = RelationshipState.initial
        
        let input = "どうしようかな。"
        let result = fillerService.addFillers(input, tone: tone, emotion: emotion, relationship: relationship)
        
        // Should only add one filler at most
        let fillerCount = result.components(separatedBy: "……").count - 1
        XCTAssertLessThanOrEqual(fillerCount, 1, "Should not add multiple fillers")
    }
    
    // MARK: - Determinism Tests
    
    func testDeterministicBehavior() async throws {
        let emotion = EmotionState(current: .worried, intensity: 0.6)
        let tone = ConversationTone.casual
        let relationship = RelationshipState.initial
        let input = "どうしようかな。"
        
        // Reset tracking first
        fillerService.resetFillerTracking()
        
        // Run multiple times with same context
        let result1 = fillerService.addFillers(input, tone: tone, emotion: emotion, relationship: relationship)
        fillerService.resetFillerTracking()
        let result2 = fillerService.addFillers(input, tone: tone, emotion: emotion, relationship: relationship)
        
        XCTAssertEqual(result1, result2, "Should be deterministic with same context")
    }
}