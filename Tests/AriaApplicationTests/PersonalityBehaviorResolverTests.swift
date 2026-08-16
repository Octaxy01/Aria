import XCTest
@testable import AriaApplication
import AriaDomain

final class PersonalityBehaviorResolverTests: XCTestCase {
    
    // MARK: - Test 1: Achievement creates proud/teasing behavior
    
    func testAchievementCreatesProudTeasingBehavior() {
        // Use a familiar relationship since stranger/acquaintance disable tsundere
        let relationship = RelationshipState(
            warmth: 0.5,
            familiarity: 0.4,
            interactionCount: 15,
            updatedAt: Date()
        )
        let emotion = EmotionState.initial
        
        let behavior = PersonalityBehaviorResolver.resolve(
            tone: .achievement,
            relationship: relationship,
            emotion: emotion
        )
        
        // Achievement should have medium-high teasing
        XCTAssertGreaterThanOrEqual(behavior.teasingLevel, 0.4, "Achievement should enable teasing")
        XCTAssertLessThan(behavior.teasingLevel, 0.8, "Achievement teasing should not be extreme")
        
        // Achievement should have higher affection
        XCTAssertGreaterThan(behavior.affectionLevel, 0.5, "Achievement should show affection/pride")
        
        // Tsundere should be enabled for achievement
        XCTAssertTrue(behavior.tsundereEnabled, "Achievement should enable tsundere behavior")
        
        // Should mention proud/encouraging in description
        XCTAssertTrue(behavior.styleDescription.contains("proud") || behavior.styleDescription.contains("encouraging"),
                     "Achievement behavior should mention proud or encouraging")
    }
    
    // MARK: - Test 2: Technical disables teasing
    
    func testTechnicalDisablesTeasing() {
        let relationship = RelationshipState.initial
        let emotion = EmotionState.initial
        
        let behavior = PersonalityBehaviorResolver.resolve(
            tone: .technical,
            relationship: relationship,
            emotion: emotion
        )
        
        // Technical should have very low teasing
        XCTAssertLessThan(behavior.teasingLevel, 0.2, "Technical should disable teasing")
        
        // Technical should disable tsundere
        XCTAssertFalse(behavior.tsundereEnabled, "Technical should disable tsundere behavior")
        
        // Should mention focused/intelligent in description
        XCTAssertTrue(behavior.styleDescription.contains("focused") || behavior.styleDescription.contains("intelligent"),
                     "Technical behavior should mention focused or intelligent")
        
        // Should have higher formality
        XCTAssertGreaterThan(behavior.formalityLevel, 0.4, "Technical should be more formal")
    }
    
    // MARK: - Test 3: Affectionate enables tsundere
    
    func testAffectionateEnablesTsundere() {
        // Use a familiar relationship since stranger/acquaintance disable tsundere
        let relationship = RelationshipState(
            warmth: 0.5,
            familiarity: 0.4,
            interactionCount: 15,
            updatedAt: Date()
        )
        let emotion = EmotionState.initial
        
        let behavior = PersonalityBehaviorResolver.resolve(
            tone: .affectionate,
            relationship: relationship,
            emotion: emotion
        )
        
        // Affectionate should enable tsundere
        XCTAssertTrue(behavior.tsundereEnabled, "Affectionate should enable tsundere behavior")
        
        // Should have high affection level
        XCTAssertGreaterThan(behavior.affectionLevel, 0.7, "Affectionate should have high affection level")
        
        // Should mention embarrassed/warm in description
        XCTAssertTrue(behavior.styleDescription.contains("embarrassed") || behavior.styleDescription.contains("warm"),
                     "Affectionate behavior should mention embarrassed or warm")
        
        // Should be very informal
        XCTAssertLessThanOrEqual(behavior.formalityLevel, 0.2, "Affectionate should be very informal")
    }
    
    // MARK: - Test 4: Sad disables teasing
    
    func testSadDisablesTeasing() {
        let relationship = RelationshipState.initial
        let sadEmotion = EmotionState(current: .sad, intensity: 0.7)
        
        let behavior = PersonalityBehaviorResolver.resolve(
            tone: .casual,
            relationship: relationship,
            emotion: sadEmotion
        )
        
        // Sad should disable teasing regardless of tone
        XCTAssertEqual(behavior.teasingLevel, 0.0, "Sad emotion should disable teasing")
        
        // Sad should disable tsundere
        XCTAssertFalse(behavior.tsundereEnabled, "Sad emotion should disable tsundere behavior")
        
        // Should increase emotional warmth for comfort
        XCTAssertGreaterThan(behavior.emotionalWarmth, 0.5, "Sad should increase emotional warmth for comfort")
        
        // Should mention caring/gentle in description
        XCTAssertTrue(behavior.styleDescription.contains("caring") || behavior.styleDescription.contains("gentle"),
                     "Sad behavior should mention caring or gentle")
    }
    
    // MARK: - Test 5: High relationship increases warmth
    
    func testHighRelationshipIncreasesWarmth() {
        let highWarmthRelationship = RelationshipState(
            warmth: 0.9,
            familiarity: 0.8,
            interactionCount: 50,
            updatedAt: Date()
        )
        
        let lowWarmthRelationship = RelationshipState(
            warmth: 0.2,
            familiarity: 0.1,
            interactionCount: 2,
            updatedAt: Date()
        )
        
        let emotion = EmotionState.initial
        
        let highWarmthBehavior = PersonalityBehaviorResolver.resolve(
            tone: .casual,
            relationship: highWarmthRelationship,
            emotion: emotion
        )
        
        let lowWarmthBehavior = PersonalityBehaviorResolver.resolve(
            tone: .casual,
            relationship: lowWarmthRelationship,
            emotion: emotion
        )
        
        // High warmth should result in higher emotional warmth
        XCTAssertGreaterThan(highWarmthBehavior.emotionalWarmth, lowWarmthBehavior.emotionalWarmth,
                            "High relationship warmth should increase emotional warmth")
        
        // High warmth should result in higher affection
        XCTAssertGreaterThan(highWarmthBehavior.affectionLevel, lowWarmthBehavior.affectionLevel,
                            "High relationship warmth should increase affection level")
        
        // High familiarity should reduce formality
        XCTAssertLessThan(highWarmthBehavior.formalityLevel, lowWarmthBehavior.formalityLevel,
                         "High familiarity should reduce formality")
    }
    
    // MARK: - Additional tests for completeness
    
    func testJokingEnablesHighTeasing() {
        // Use a familiar relationship for this test since stranger/acquaintance disable tsundere
        let relationship = RelationshipState(
            warmth: 0.5,
            familiarity: 0.4,
            interactionCount: 15,
            updatedAt: Date()
        )
        let emotion = EmotionState.initial
        
        let behavior = PersonalityBehaviorResolver.resolve(
            tone: .joking,
            relationship: relationship,
            emotion: emotion
        )
        
        // Joking should have high teasing
        XCTAssertGreaterThanOrEqual(behavior.teasingLevel, 0.6, "Joking should enable high teasing")
        
        // Joking should enable tsundere
        XCTAssertTrue(behavior.tsundereEnabled, "Joking should enable tsundere behavior")
    }
    
    func testSeriousReducesTeasing() {
        let relationship = RelationshipState.initial
        let emotion = EmotionState.initial
        
        let behavior = PersonalityBehaviorResolver.resolve(
            tone: .serious,
            relationship: relationship,
            emotion: emotion
        )
        
        // Serious should have very low teasing
        XCTAssertLessThan(behavior.teasingLevel, 0.2, "Serious should reduce teasing")
        
        // Serious should disable tsundere
        XCTAssertFalse(behavior.tsundereEnabled, "Serious should disable tsundere behavior")
        
        // Should be more formal
        XCTAssertGreaterThan(behavior.formalityLevel, 0.3, "Serious should be more formal")
    }
    
    func testRudeDisablesTeasing() {
        let relationship = RelationshipState.initial
        let emotion = EmotionState.initial
        
        let behavior = PersonalityBehaviorResolver.resolve(
            tone: .rude,
            relationship: relationship,
            emotion: emotion
        )
        
        // Rude should disable teasing to avoid escalation
        XCTAssertEqual(behavior.teasingLevel, 0.0, "Rude should disable teasing")
        
        // Rude should disable tsundere
        XCTAssertFalse(behavior.tsundereEnabled, "Rude should disable tsundere behavior")
    }
    
    func testAngryEmotionDisablesTeasing() {
        let relationship = RelationshipState.initial
        let angryEmotion = EmotionState(current: .angry, intensity: 0.8)
        
        let behavior = PersonalityBehaviorResolver.resolve(
            tone: .casual,
            relationship: relationship,
            emotion: angryEmotion
        )
        
        // Angry should disable teasing
        XCTAssertEqual(behavior.teasingLevel, 0.0, "Angry emotion should disable teasing")
        
        // Angry should disable tsundere
        XCTAssertFalse(behavior.tsundereEnabled, "Angry emotion should disable tsundere behavior")
    }
    
    func testWorriedEmotionDisablesTeasing() {
        let relationship = RelationshipState.initial
        let worriedEmotion = EmotionState(current: .worried, intensity: 0.6)
        
        let behavior = PersonalityBehaviorResolver.resolve(
            tone: .casual,
            relationship: relationship,
            emotion: worriedEmotion
        )
        
        // Worried should disable teasing
        XCTAssertEqual(behavior.teasingLevel, 0.0, "Worried emotion should disable teasing")
        
        // Worried should disable tsundere
        XCTAssertFalse(behavior.tsundereEnabled, "Worried emotion should disable tsundere behavior")
    }
    
    func testEmbarrassedEmotionEnablesTsundere() {
        let relationship = RelationshipState.initial
        let embarrassedEmotion = EmotionState(current: .embarrassed, intensity: 0.5)
        
        let behavior = PersonalityBehaviorResolver.resolve(
            tone: .casual,
            relationship: relationship,
            emotion: embarrassedEmotion
        )
        
        // Embarrassed should enable tsundere
        XCTAssertTrue(behavior.tsundereEnabled, "Embarrassed emotion should enable tsundere behavior")
        
        // Embarrassed should reduce teasing slightly
        XCTAssertLessThan(behavior.teasingLevel, 0.3, "Embarrassed should reduce teasing")
    }
    
    // MARK: - Relationship Level Tests
    
    func testStrangerHasLowerAffection() {
        let strangerRelationship = RelationshipState(
            warmth: 0.1,
            familiarity: 0.1,
            interactionCount: 1,
            updatedAt: Date()
        )
        
        let emotion = EmotionState.initial
        
        let behavior = PersonalityBehaviorResolver.resolve(
            tone: .casual,
            relationship: strangerRelationship,
            emotion: emotion
        )
        
        // Stranger should have lower affection
        XCTAssertLessThan(behavior.affectionLevel, 0.5, "Stranger should have lower affection")
        
        // Stranger should have lower teasing
        XCTAssertLessThan(behavior.teasingLevel, 0.3, "Stranger should have lower teasing")
        
        // Stranger should be more formal
        XCTAssertGreaterThan(behavior.formalityLevel, 0.2, "Stranger should be more formal")
    }
    
    func testFamiliarIsWarmer() {
        let familiarRelationship = RelationshipState(
            warmth: 0.5,
            familiarity: 0.4,
            interactionCount: 15,
            updatedAt: Date()
        )
        
        let emotion = EmotionState.initial
        
        let behavior = PersonalityBehaviorResolver.resolve(
            tone: .casual,
            relationship: familiarRelationship,
            emotion: emotion
        )
        
        // Familiar should be warmer than stranger
        XCTAssertGreaterThan(behavior.affectionLevel, 0.4, "Familiar should be warmer")
        
        // Familiar should enable tsundere
        XCTAssertTrue(behavior.tsundereEnabled, "Familiar should enable tsundere")
        
        // Familiar should be less formal
        XCTAssertLessThan(behavior.formalityLevel, 0.3, "Familiar should be less formal")
    }
    
    func testCloseEnablesStrongerTsundere() {
        let closeRelationship = RelationshipState(
            warmth: 0.7,
            familiarity: 0.65,
            interactionCount: 30,
            updatedAt: Date()
        )
        
        let emotion = EmotionState.initial
        
        let behavior = PersonalityBehaviorResolver.resolve(
            tone: .casual,
            relationship: closeRelationship,
            emotion: emotion
        )
        
        // Close should have high affection
        XCTAssertGreaterThan(behavior.affectionLevel, 0.6, "Close should have high affection")
        
        // Close should enable stronger tsundere
        XCTAssertTrue(behavior.tsundereEnabled, "Close should enable tsundere")
        
        // Close should be very informal
        XCTAssertLessThan(behavior.formalityLevel, 0.2, "Close should be very informal")
        
        // Close should have higher teasing
        XCTAssertGreaterThan(behavior.teasingLevel, 0.3, "Close should have higher teasing")
    }
    
    func testTrustedIsWarmButNotExcessive() {
        let trustedRelationship = RelationshipState(
            warmth: 0.9,
            familiarity: 0.85,
            interactionCount: 50,
            updatedAt: Date()
        )
        
        let emotion = EmotionState.initial
        
        let behavior = PersonalityBehaviorResolver.resolve(
            tone: .casual,
            relationship: trustedRelationship,
            emotion: emotion
        )
        
        // Trusted should be very warm
        XCTAssertGreaterThan(behavior.affectionLevel, 0.7, "Trusted should be very warm")
        
        // Trusted should enable tsundere
        XCTAssertTrue(behavior.tsundereEnabled, "Trusted should enable tsundere")
        
        // Trusted should be very informal
        XCTAssertLessThan(behavior.formalityLevel, 0.15, "Trusted should be very informal")
        
        // But affection should not exceed reasonable bounds
        XCTAssertLessThanOrEqual(behavior.affectionLevel, 1.0, "Trusted affection should not exceed 1.0")
    }
    
    func testTechnicalSuppressesTeasingRegardlessOfRelationship() {
        let closeRelationship = RelationshipState(
            warmth: 0.9,
            familiarity: 0.85,
            interactionCount: 50,
            updatedAt: Date()
        )
        
        let emotion = EmotionState.initial
        
        let behavior = PersonalityBehaviorResolver.resolve(
            tone: .technical,
            relationship: closeRelationship,
            emotion: emotion
        )
        
        // Technical should disable teasing even with close relationship
        XCTAssertEqual(behavior.teasingLevel, 0.0, "Technical should disable teasing regardless of relationship")
        
        // Technical should disable tsundere even with close relationship
        XCTAssertFalse(behavior.tsundereEnabled, "Technical should disable tsundere regardless of relationship")
        
        // Technical should be more formal
        XCTAssertGreaterThan(behavior.formalityLevel, 0.3, "Technical should be more formal")
    }
}
