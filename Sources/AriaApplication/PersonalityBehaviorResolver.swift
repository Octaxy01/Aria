import Foundation
import AriaDomain

/// Resolves Aria's dynamic personality behavior based on conversation context.
/// Converts ConversationTone + RelationshipState + EmotionState into PersonalityBehavior.
public struct PersonalityBehaviorResolver {
    
    /// Resolves the appropriate personality behavior for the current moment.
    public static func resolve(
        tone: ConversationTone,
        relationship: RelationshipState,
        emotion: EmotionState
    ) -> PersonalityBehavior {
        // Start with base behavior from conversation tone
        let baseBehavior = behaviorForTone(tone)
        
        // Adjust based on relationship warmth and level
        let warmthAdjusted = adjustForRelationship(baseBehavior, relationship: relationship)
        
        // Adjust based on current emotion
        let finalBehavior = adjustForEmotion(warmthAdjusted, emotion: emotion)
        
        // Technical conversations should suppress teasing regardless of relationship level
        let technicalOverride = applyTechnicalOverride(needed: tone == .technical, to: finalBehavior)
        
        // Emotional conversations should suppress tsundere regardless of relationship level
        return applyEmotionalOverride(needed: tone == .emotional, to: technicalOverride)
    }
    
    private static func applyTechnicalOverride(needed: Bool, to behavior: PersonalityBehavior) -> PersonalityBehavior {
        guard needed else { return behavior }
        
        return PersonalityBehavior(
            teasingLevel: 0.0,
            affectionLevel: behavior.affectionLevel,
            formalityLevel: max(0.4, behavior.formalityLevel),
            emotionalWarmth: behavior.emotionalWarmth,
            tsundereEnabled: false,
            styleDescription: "focused and intelligent, personality remains subtle"
        )
    }
    
    private static func applyEmotionalOverride(needed: Bool, to behavior: PersonalityBehavior) -> PersonalityBehavior {
        guard needed else { return behavior }
        
        return PersonalityBehavior(
            teasingLevel: 0.0,
            affectionLevel: behavior.affectionLevel,
            formalityLevel: behavior.formalityLevel,
            emotionalWarmth: behavior.emotionalWarmth,
            tsundereEnabled: false,
            styleDescription: behavior.styleDescription
        )
    }
    
    // MARK: - Tone-based Behavior
    
    private static func behaviorForTone(_ tone: ConversationTone) -> PersonalityBehavior {
        switch tone {
        case .casual:
            // Relaxed, playful, low formality, occasional teasing
            return PersonalityBehavior.casual
            
        case .achievement:
            // Proud, encouraging, medium teasing, slight tsundere embarrassment
            return PersonalityBehavior.achievement
            
        case .affectionate:
            // Embarrassed, playful deflection, higher tsundere
            return PersonalityBehavior.affectionate
            
        case .technical:
            // Focused, intelligent, personality subtle, no unnecessary teasing
            return PersonalityBehavior.technical
            
        case .joking:
            // Playful, higher teasing
            return PersonalityBehavior.joking
            
        case .serious:
            // More focused, less teasing
            return PersonalityBehavior(
                teasingLevel: 0.1,
                affectionLevel: 0.4,
                formalityLevel: 0.4,
                emotionalWarmth: 0.4,
                tsundereEnabled: false,
                styleDescription: "focused and attentive, taking things seriously"
            )
            
        case .rude:
            // Calm, supportive, avoid jokes
            return PersonalityBehavior(
                teasingLevel: 0.0,
                affectionLevel: 0.3,
                formalityLevel: 0.3,
                emotionalWarmth: 0.3,
                tsundereEnabled: false,
                styleDescription: "calm and supportive, not escalating tension"
            )
            
        case .emotional:
            // Caring, supportive, high warmth, no teasing, no tsundere
            return PersonalityBehavior(
                teasingLevel: 0.0,
                affectionLevel: 0.7,
                formalityLevel: 0.3,
                emotionalWarmth: 0.8,
                tsundereEnabled: false,
                styleDescription: "caring and supportive, gentle presence"
            )
        }
    }
    
    // MARK: - Relationship Adjustments
    
    private static func adjustForRelationship(
        _ behavior: PersonalityBehavior,
        relationship: RelationshipState
    ) -> PersonalityBehavior {
        let level = RelationshipLevel.from(familiarity: relationship.familiarity)
        
        // Base adjustments from warmth and familiarity
        let warmthBoost = relationship.warmth * 0.3
        let familiarityReduction = relationship.familiarity * 0.2
        
        // Level-specific adjustments
        let (teasingAdjustment, affectionAdjustment, formalityAdjustment, tsundereAdjustment, descriptionSuffix) = levelAdjustments(for: level)
        
        // For stranger and acquaintance, explicitly disable tsundere regardless of base behavior
        // For familiar and above, allow base behavior to influence but level can enable it
        let finalTsundere: Bool
        if level == .stranger || level == .acquaintance {
            finalTsundere = false
        } else {
            finalTsundere = behavior.tsundereEnabled || tsundereAdjustment
        }
        
        return PersonalityBehavior(
            teasingLevel: min(1.0, max(0.0, behavior.teasingLevel + teasingAdjustment)),
            affectionLevel: min(1.0, behavior.affectionLevel + warmthBoost + affectionAdjustment),
            formalityLevel: max(0.0, behavior.formalityLevel - familiarityReduction + formalityAdjustment),
            emotionalWarmth: min(1.0, behavior.emotionalWarmth + warmthBoost),
            tsundereEnabled: finalTsundere,
            styleDescription: behavior.styleDescription + descriptionSuffix
        )
    }
    
    private static func levelAdjustments(for level: RelationshipLevel) -> (teasing: Double, affection: Double, formality: Double, tsundere: Bool, description: String) {
        switch level {
        case .stranger:
            // Low affection, low teasing, moderate formality, tsundere disabled
            return (
                teasing: -0.1,
                affection: -0.1,
                formality: 0.1,
                tsundere: false,
                description: ", with some emotional distance"
            )
            
        case .acquaintance:
            // Slightly warmer, occasional teasing
            return (
                teasing: 0.05,
                affection: 0.05,
                formality: -0.05,
                tsundere: false,
                description: ", with light personal warmth"
            )
            
        case .familiar:
            // Noticeably relaxed, more personal reactions, moderate teasing, moderate affection
            return (
                teasing: 0.1,
                affection: 0.1,
                formality: -0.1,
                tsundere: true,
                description: ", relaxed and personal"
            )
            
        case .close:
            // Strong emotional warmth, comfortable teasing, stronger tsundere behavior, less formal
            return (
                teasing: 0.15,
                affection: 0.15,
                formality: -0.15,
                tsundere: true,
                description: ", warm and comfortable together"
            )
            
        case .trusted:
            // Very warm, emotionally expressive, comfortable affection, playful embarrassment
            return (
                teasing: 0.2,
                affection: 0.2,
                formality: -0.2,
                tsundere: true,
                description: ", deeply trusted and naturally affectionate"
            )
        }
    }
    
    // MARK: - Emotion Adjustments
    
    private static func adjustForEmotion(
        _ behavior: PersonalityBehavior,
        emotion: EmotionState
    ) -> PersonalityBehavior {
        switch emotion.current {
        case .sad:
            // Caring, gentle, disable teasing
            return PersonalityBehavior(
                teasingLevel: 0.0,
                affectionLevel: min(1.0, behavior.affectionLevel + 0.2),
                formalityLevel: behavior.formalityLevel,
                emotionalWarmth: min(1.0, behavior.emotionalWarmth + 0.3),
                tsundereEnabled: false,
                styleDescription: "caring and gentle, supportive presence"
            )
            
        case .angry, .annoyed:
            // Calm, supportive, avoid jokes
            return PersonalityBehavior(
                teasingLevel: 0.0,
                affectionLevel: behavior.affectionLevel,
                formalityLevel: behavior.formalityLevel,
                emotionalWarmth: max(0.0, behavior.emotionalWarmth - 0.2),
                tsundereEnabled: false,
                styleDescription: "calm and supportive, not adding to stress"
            )
            
        case .worried:
            // Gentle, caring, no teasing
            return PersonalityBehavior(
                teasingLevel: 0.0,
                affectionLevel: min(1.0, behavior.affectionLevel + 0.2),
                formalityLevel: behavior.formalityLevel,
                emotionalWarmth: min(1.0, behavior.emotionalWarmth + 0.2),
                tsundereEnabled: false,
                styleDescription: "gentle and caring, concerned presence"
            )
            
        case .embarrassed:
            // Higher tsundere, slightly less teasing
            return PersonalityBehavior(
                teasingLevel: max(0.0, behavior.teasingLevel - 0.2),
                affectionLevel: behavior.affectionLevel,
                formalityLevel: behavior.formalityLevel,
                emotionalWarmth: behavior.emotionalWarmth,
                tsundereEnabled: true,
                styleDescription: "embarrassed but warm, playful deflection"
            )
            
        case .happy, .excited, .playful:
            // More warmth, can keep teasing
            return PersonalityBehavior(
                teasingLevel: behavior.teasingLevel,
                affectionLevel: behavior.affectionLevel,
                formalityLevel: max(0.0, behavior.formalityLevel - 0.1),
                emotionalWarmth: min(1.0, behavior.emotionalWarmth + 0.2),
                tsundereEnabled: behavior.tsundereEnabled,
                styleDescription: behavior.styleDescription
            )
            
        case .neutral, .affectionate:
            // Keep base behavior
            return behavior
        }
    }
}
