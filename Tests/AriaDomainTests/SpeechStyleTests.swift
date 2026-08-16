import XCTest
@testable import AriaDomain

final class SpeechStyleTests: XCTestCase {
    
    // MARK: - Test: Presets exist
    
    func testCasualConversationPresetExists() {
        let style = SpeechStyle.casualConversation
        
        XCTAssertLessThan(style.sentenceLengthPreference, 1.0)
        XCTAssertGreaterThan(style.sentenceLengthPreference, 0.0)
        XCTAssertLessThan(style.emojiUsageLevel, 1.0)
        XCTAssertGreaterThan(style.emojiUsageLevel, 0.0)
        XCTAssertLessThan(style.casualMarkerUsage, 1.0)
        XCTAssertGreaterThan(style.casualMarkerUsage, 0.0)
        XCTAssertLessThan(style.emotionalExpressionLevel, 1.0)
        XCTAssertGreaterThan(style.emotionalExpressionLevel, 0.0)
        XCTAssertFalse(style.reactionBeforeAnswer)
        XCTAssertTrue(style.avoidFormalLanguage)
    }
    
    func testEmotionalSupportPresetExists() {
        let style = SpeechStyle.emotionalSupport
        
        XCTAssertLessThan(style.sentenceLengthPreference, 1.0)
        XCTAssertGreaterThan(style.sentenceLengthPreference, 0.0)
        XCTAssertLessThan(style.emojiUsageLevel, 1.0)
        XCTAssertGreaterThan(style.emojiUsageLevel, 0.0)
        XCTAssertLessThan(style.casualMarkerUsage, 1.0)
        XCTAssertGreaterThan(style.casualMarkerUsage, 0.0)
        XCTAssertLessThan(style.emotionalExpressionLevel, 1.0)
        XCTAssertGreaterThan(style.emotionalExpressionLevel, 0.0)
        XCTAssertTrue(style.reactionBeforeAnswer)
        XCTAssertTrue(style.avoidFormalLanguage)
    }
    
    func testTechnicalHelpPresetExists() {
        let style = SpeechStyle.technicalHelp
        
        XCTAssertLessThan(style.sentenceLengthPreference, 1.0)
        XCTAssertGreaterThan(style.sentenceLengthPreference, 0.0)
        XCTAssertLessThan(style.emojiUsageLevel, 1.0)
        XCTAssertGreaterThan(style.emojiUsageLevel, 0.0)
        XCTAssertLessThan(style.casualMarkerUsage, 1.0)
        XCTAssertGreaterThan(style.casualMarkerUsage, 0.0)
        XCTAssertLessThan(style.emotionalExpressionLevel, 1.0)
        XCTAssertGreaterThan(style.emotionalExpressionLevel, 0.0)
        XCTAssertFalse(style.reactionBeforeAnswer)
        XCTAssertFalse(style.avoidFormalLanguage) // technical allows some formality
    }
    
    func testAchievementReactionPresetExists() {
        let style = SpeechStyle.achievementReaction
        
        XCTAssertLessThan(style.sentenceLengthPreference, 1.0)
        XCTAssertGreaterThan(style.sentenceLengthPreference, 0.0)
        XCTAssertLessThan(style.emojiUsageLevel, 1.0)
        XCTAssertGreaterThan(style.emojiUsageLevel, 0.0)
        XCTAssertLessThan(style.casualMarkerUsage, 1.0)
        XCTAssertGreaterThan(style.casualMarkerUsage, 0.0)
        XCTAssertLessThan(style.emotionalExpressionLevel, 1.0)
        XCTAssertGreaterThan(style.emotionalExpressionLevel, 0.0)
        XCTAssertTrue(style.reactionBeforeAnswer)
        XCTAssertTrue(style.avoidFormalLanguage)
    }
    
    func testPlayfulConversationPresetExists() {
        let style = SpeechStyle.playfulConversation
        
        XCTAssertLessThan(style.sentenceLengthPreference, 1.0)
        XCTAssertGreaterThan(style.sentenceLengthPreference, 0.0)
        XCTAssertLessThan(style.emojiUsageLevel, 1.0)
        XCTAssertGreaterThan(style.emojiUsageLevel, 0.0)
        XCTAssertLessThan(style.casualMarkerUsage, 1.0)
        XCTAssertGreaterThan(style.casualMarkerUsage, 0.0)
        XCTAssertLessThan(style.emotionalExpressionLevel, 1.0)
        XCTAssertGreaterThan(style.emotionalExpressionLevel, 0.0)
        XCTAssertTrue(style.reactionBeforeAnswer)
        XCTAssertTrue(style.avoidFormalLanguage)
    }
    
    // MARK: - Test: Properties valid
    
    func testAllPropertiesInRange() {
        let style = SpeechStyle(
            sentenceLengthPreference: 0.5,
            emojiUsageLevel: 0.5,
            casualMarkerUsage: 0.5,
            emotionalExpressionLevel: 0.5,
            reactionBeforeAnswer: true,
            avoidFormalLanguage: true
        )
        
        XCTAssertGreaterThanOrEqual(style.sentenceLengthPreference, 0.0)
        XCTAssertLessThanOrEqual(style.sentenceLengthPreference, 1.0)
        XCTAssertGreaterThanOrEqual(style.emojiUsageLevel, 0.0)
        XCTAssertLessThanOrEqual(style.emojiUsageLevel, 1.0)
        XCTAssertGreaterThanOrEqual(style.casualMarkerUsage, 0.0)
        XCTAssertLessThanOrEqual(style.casualMarkerUsage, 1.0)
        XCTAssertGreaterThanOrEqual(style.emotionalExpressionLevel, 0.0)
        XCTAssertLessThanOrEqual(style.emotionalExpressionLevel, 1.0)
    }
    
    func testEquality() {
        let style1 = SpeechStyle.casualConversation
        let style2 = SpeechStyle.casualConversation
        let style3 = SpeechStyle.technicalHelp
        
        XCTAssertEqual(style1, style2)
        XCTAssertNotEqual(style1, style3)
    }
    
    // MARK: - Test: Preset characteristics
    
    func testCasualConversationPrefersShorterSentences() {
        let style = SpeechStyle.casualConversation
        XCTAssertGreaterThan(style.sentenceLengthPreference, 0.5, "Casual should prefer shorter sentences")
    }
    
    func testEmotionalSupportHasHigherEmotionalExpression() {
        let style = SpeechStyle.emotionalSupport
        XCTAssertGreaterThan(style.emotionalExpressionLevel, 0.5, "Emotional support should be more expressive")
    }
    
    func testTechnicalHelpHasLowerEmotionalExpression() {
        let style = SpeechStyle.technicalHelp
        XCTAssertLessThan(style.emotionalExpressionLevel, 0.5, "Technical help should have subtle emotion")
    }
    
    func testAchievementReactionAlwaysReactsFirst() {
        let style = SpeechStyle.achievementReaction
        XCTAssertTrue(style.reactionBeforeAnswer, "Achievement should always react first")
    }
    
    func testPlayfulConversationHasHighCasualMarkerUsage() {
        let style = SpeechStyle.playfulConversation
        XCTAssertGreaterThan(style.casualMarkerUsage, 0.5, "Playful should use more casual markers")
    }
    
    func testTechnicalHelpAllowsFormality() {
        let style = SpeechStyle.technicalHelp
        XCTAssertFalse(style.avoidFormalLanguage, "Technical help should allow some formality")
    }
    
    func testEmotionalSupportReactsBeforeAnswering() {
        let style = SpeechStyle.emotionalSupport
        XCTAssertTrue(style.reactionBeforeAnswer, "Emotional support should react first")
    }
}
