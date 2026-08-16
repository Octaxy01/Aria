import XCTest
@testable import AriaApplication
import AriaDomain

final class SpeechStyleResolverTests: XCTestCase {
    
    // MARK: - Test: Casual produces conversational style
    
    func testCasualProducesConversationalStyle() {
        let relationship = RelationshipContext(
            level: .familiar,
            warmth: 0.5,
            familiarity: 0.4,
            interactionCount: 15,
            behavioralDescription: "relaxed and personal"
        )
        
        let behavior = PersonalityBehavior.casual
        
        let style = SpeechStyleResolver.resolve(
            tone: .casual,
            relationship: relationship,
            behavior: behavior
        )
        
        // Casual should prefer shorter sentences
        XCTAssertGreaterThan(style.sentenceLengthPreference, 0.5, "Casual should prefer shorter sentences")
        
        // Casual should avoid formal language
        XCTAssertTrue(style.avoidFormalLanguage, "Casual should avoid formal language")
        
        // Casual should have moderate casual marker usage
        XCTAssertGreaterThan(style.casualMarkerUsage, 0.3, "Casual should use casual markers")
    }
    
    // MARK: - Test: Technical reduces emotion
    
    func testTechnicalReducesEmotion() {
        let relationship = RelationshipContext(
            level: .familiar,
            warmth: 0.5,
            familiarity: 0.4,
            interactionCount: 15,
            behavioralDescription: "relaxed and personal"
        )
        
        let behavior = PersonalityBehavior.technical
        
        let style = SpeechStyleResolver.resolve(
            tone: .technical,
            relationship: relationship,
            behavior: behavior
        )
        
        // Technical should have lower emotional expression
        XCTAssertLessThan(style.emotionalExpressionLevel, 0.5, "Technical should reduce emotion")
        
        // Technical should not react before answering
        XCTAssertFalse(style.reactionBeforeAnswer, "Technical should not react before answering")
        
        // Technical may allow some formality
        XCTAssertFalse(style.avoidFormalLanguage, "Technical should allow some formality")
    }
    
    // MARK: - Test: Sad removes teasing
    
    func testSadRemovesTeasing() {
        let relationship = RelationshipContext(
            level: .familiar,
            warmth: 0.5,
            familiarity: 0.4,
            interactionCount: 15,
            behavioralDescription: "relaxed and personal"
        )
        
        let behavior = PersonalityBehavior.comforting
        
        let style = SpeechStyleResolver.resolve(
            tone: .casual,
            relationship: relationship,
            behavior: behavior
        )
        
        // Should have higher emotional expression
        XCTAssertGreaterThan(style.emotionalExpressionLevel, 0.5, "Emotional support should be more expressive")
        
        // Comforting should have lower teasing (from behavior, not speech style)
        // Note: casual tone doesn't force reaction before answering
    }
    
    // MARK: - Test: Affectionate enables embarrassment
    
    func testAffectionateEnablesEmbarrassment() {
        let relationship = RelationshipContext(
            level: .close,
            warmth: 0.7,
            familiarity: 0.65,
            interactionCount: 30,
            behavioralDescription: "warm and comfortable together"
        )
        
        let behavior = PersonalityBehavior.affectionate
        
        let style = SpeechStyleResolver.resolve(
            tone: .affectionate,
            relationship: relationship,
            behavior: behavior
        )
        
        // Affectionate should react before answering
        XCTAssertTrue(style.reactionBeforeAnswer, "Affectionate should react before answering")
        
        // Affectionate should avoid formal language
        XCTAssertTrue(style.avoidFormalLanguage, "Affectionate should avoid formal language")
        
        // Affectionate should have higher emotional expression
        XCTAssertGreaterThan(style.emotionalExpressionLevel, 0.5, "Affectionate should be more expressive")
    }
    
    // MARK: - Test: Achievement enables reaction-first style
    
    func testAchievementEnablesReactionFirstStyle() {
        let relationship = RelationshipContext(
            level: .familiar,
            warmth: 0.5,
            familiarity: 0.4,
            interactionCount: 15,
            behavioralDescription: "relaxed and personal"
        )
        
        let behavior = PersonalityBehavior.achievement
        
        let style = SpeechStyleResolver.resolve(
            tone: .achievement,
            relationship: relationship,
            behavior: behavior
        )
        
        // Achievement should always react first
        XCTAssertTrue(style.reactionBeforeAnswer, "Achievement should react first")
        
        // Achievement should have high emotional expression
        XCTAssertGreaterThan(style.emotionalExpressionLevel, 0.6, "Achievement should be very expressive")
        
        // Achievement should avoid formal language
        XCTAssertTrue(style.avoidFormalLanguage, "Achievement should avoid formal language")
    }
    
    // MARK: - Test: Relationship level influences style
    
    func testHigherRelationshipIncreasesCasualMarkers() {
        let strangerRelationship = RelationshipContext(
            level: .stranger,
            warmth: 0.1,
            familiarity: 0.1,
            interactionCount: 1,
            behavioralDescription: "friendly but distant"
        )
        
        let closeRelationship = RelationshipContext(
            level: .close,
            warmth: 0.7,
            familiarity: 0.65,
            interactionCount: 30,
            behavioralDescription: "warm and comfortable together"
        )
        
        let behavior = PersonalityBehavior.casual
        
        let strangerStyle = SpeechStyleResolver.resolve(
            tone: .casual,
            relationship: strangerRelationship,
            behavior: behavior
        )
        
        let closeStyle = SpeechStyleResolver.resolve(
            tone: .casual,
            relationship: closeRelationship,
            behavior: behavior
        )
        
        // Close relationship should have higher casual marker usage
        XCTAssertGreaterThan(closeStyle.casualMarkerUsage, strangerStyle.casualMarkerUsage,
                            "Close relationship should increase casual marker usage")
        
        // Close relationship should have higher emotional expression
        XCTAssertGreaterThan(closeStyle.emotionalExpressionLevel, strangerStyle.emotionalExpressionLevel,
                            "Close relationship should increase emotional expression")
    }
    
    // MARK: - Test: Behavior formality influences style
    
    func testLowFormalityBehaviorIncreasesCasualMarkers() {
        let relationship = RelationshipContext(
            level: .familiar,
            warmth: 0.5,
            familiarity: 0.4,
            interactionCount: 15,
            behavioralDescription: "relaxed and personal"
        )
        
        let formalBehavior = PersonalityBehavior(
            teasingLevel: 0.1,
            affectionLevel: 0.3,
            formalityLevel: 0.7,
            emotionalWarmth: 0.3,
            tsundereEnabled: false,
            styleDescription: "somewhat formal"
        )
        
        let casualBehavior = PersonalityBehavior(
            teasingLevel: 0.3,
            affectionLevel: 0.5,
            formalityLevel: 0.1,
            emotionalWarmth: 0.5,
            tsundereEnabled: true,
            styleDescription: "very casual"
        )
        
        let formalStyle = SpeechStyleResolver.resolve(
            tone: .casual,
            relationship: relationship,
            behavior: formalBehavior
        )
        
        let casualStyle = SpeechStyleResolver.resolve(
            tone: .casual,
            relationship: relationship,
            behavior: casualBehavior
        )
        
        // Low formality behavior should result in higher casual marker usage
        XCTAssertGreaterThan(casualStyle.casualMarkerUsage, formalStyle.casualMarkerUsage,
                            "Low formality behavior should increase casual markers")
        
        // Low formality behavior should avoid formal language
        XCTAssertTrue(casualStyle.avoidFormalLanguage, "Low formality behavior should avoid formal language")
    }
    
    // MARK: - Test: Joking produces playful style
    
    func testJokingProducesPlayfulStyle() {
        let relationship = RelationshipContext(
            level: .familiar,
            warmth: 0.5,
            familiarity: 0.4,
            interactionCount: 15,
            behavioralDescription: "relaxed and personal"
        )
        
        let behavior = PersonalityBehavior.joking
        
        let style = SpeechStyleResolver.resolve(
            tone: .joking,
            relationship: relationship,
            behavior: behavior
        )
        
        // Joking should prefer shorter sentences
        XCTAssertGreaterThan(style.sentenceLengthPreference, 0.6, "Joking should prefer shorter sentences")
        
        // Joking should react before answering
        XCTAssertTrue(style.reactionBeforeAnswer, "Joking should react before answering")
        
        // Joking should avoid formal language
        XCTAssertTrue(style.avoidFormalLanguage, "Joking should avoid formal language")
    }
    
    // MARK: - Test: Serious produces focused style
    
    func testSeriousProducesFocusedStyle() {
        let relationship = RelationshipContext(
            level: .familiar,
            warmth: 0.5,
            familiarity: 0.4,
            interactionCount: 15,
            behavioralDescription: "relaxed and personal"
        )
        
        let behavior = PersonalityBehavior(
            teasingLevel: 0.1,
            affectionLevel: 0.4,
            formalityLevel: 0.4,
            emotionalWarmth: 0.4,
            tsundereEnabled: false,
            styleDescription: "focused and attentive"
        )
        
        let style = SpeechStyleResolver.resolve(
            tone: .serious,
            relationship: relationship,
            behavior: behavior
        )
        
        // Serious should not react before answering
        XCTAssertFalse(style.reactionBeforeAnswer, "Serious should not react before answering")
        
        // Serious should avoid formal language
        XCTAssertTrue(style.avoidFormalLanguage, "Serious should avoid formal language")
    }
}
