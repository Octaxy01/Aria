import Foundation
import AriaDomain

/// Resolves Aria's natural speech style based on conversation context.
/// Converts ConversationTone + RelationshipContext + PersonalityBehavior into SpeechStyle.
public struct SpeechStyleResolver {
    
    /// Resolves the appropriate speech style for the current moment.
    public static func resolve(
        tone: ConversationTone,
        relationship: RelationshipContext,
        behavior: PersonalityBehavior
    ) -> SpeechStyle {
        // Start with base style from conversation tone
        let baseStyle = styleForTone(tone)
        
        // Adjust based on relationship level
        let relationshipAdjusted = adjustForRelationship(baseStyle, relationship: relationship)
        
        // Adjust based on personality behavior
        let finalStyle = adjustForBehavior(relationshipAdjusted, behavior: behavior)
        
        return finalStyle
    }
    
    // MARK: - Tone-based Style
    
    private static func styleForTone(_ tone: ConversationTone) -> SpeechStyle {
        switch tone {
        case .casual:
            // Shorter sentences, natural Indonesian particles, conversational rhythm
            return SpeechStyle.casualConversation
            
        case .achievement:
            // Reaction first, praise second, explanation last
            return SpeechStyle.achievementReaction
            
        case .affectionate:
            // Playful embarrassment, avoid direct romantic statements
            return SpeechStyle(
                sentenceLengthPreference: 0.6,
                emojiUsageLevel: 0.3,
                casualMarkerUsage: 0.5,
                emotionalExpressionLevel: 0.7,
                reactionBeforeAnswer: true,
                avoidFormalLanguage: true
            )
            
        case .technical:
            // Clear explanation, personality subtle, no excessive emotion
            return SpeechStyle.technicalHelp
            
        case .joking:
            // Playful, conversational
            return SpeechStyle.playfulConversation
            
        case .serious:
            // More focused, but still natural
            return SpeechStyle(
                sentenceLengthPreference: 0.4,
                emojiUsageLevel: 0.1,
                casualMarkerUsage: 0.3,
                emotionalExpressionLevel: 0.4,
                reactionBeforeAnswer: false,
                avoidFormalLanguage: true
            )
            
        case .rude:
            // Calm, supportive, avoid escalation
            return SpeechStyle(
                sentenceLengthPreference: 0.5,
                emojiUsageLevel: 0.1,
                casualMarkerUsage: 0.3,
                emotionalExpressionLevel: 0.3,
                reactionBeforeAnswer: false,
                avoidFormalLanguage: true
            )
            
        case .emotional:
            // Supportive, high emotional expression, reaction first
            return SpeechStyle(
                sentenceLengthPreference: 0.5,
                emojiUsageLevel: 0.2,
                casualMarkerUsage: 0.4,
                emotionalExpressionLevel: 0.8,
                reactionBeforeAnswer: true,
                avoidFormalLanguage: true
            )
        }
    }
    
    // MARK: - Relationship Adjustments
    
    private static func adjustForRelationship(
        _ style: SpeechStyle,
        relationship: RelationshipContext
    ) -> SpeechStyle {
        let level = relationship.level
        
        // Higher relationship = more casual markers and emotional expression
        let casualMarkerBoost: Double
        let emotionalBoost: Double
        
        switch level {
        case .stranger:
            casualMarkerBoost = -0.2
            emotionalBoost = -0.1
        case .acquaintance:
            casualMarkerBoost = 0.0
            emotionalBoost = 0.0
        case .familiar:
            casualMarkerBoost = 0.1
            emotionalBoost = 0.1
        case .close:
            casualMarkerBoost = 0.2
            emotionalBoost = 0.2
        case .trusted:
            casualMarkerBoost = 0.3
            emotionalBoost = 0.3
        }
        
        return SpeechStyle(
            sentenceLengthPreference: style.sentenceLengthPreference,
            emojiUsageLevel: style.emojiUsageLevel,
            casualMarkerUsage: min(1.0, max(0.0, style.casualMarkerUsage + casualMarkerBoost)),
            emotionalExpressionLevel: min(1.0, max(0.0, style.emotionalExpressionLevel + emotionalBoost)),
            reactionBeforeAnswer: style.reactionBeforeAnswer,
            avoidFormalLanguage: style.avoidFormalLanguage
        )
    }
    
    // MARK: - Behavior Adjustments
    
    private static func adjustForBehavior(
        _ style: SpeechStyle,
        behavior: PersonalityBehavior
    ) -> SpeechStyle {
        // Adjust based on personality behavior
        let emotionalAdjustment = behavior.emotionalWarmth * 0.2
        let formalityAdjustment = behavior.formalityLevel * -0.3
        
        return SpeechStyle(
            sentenceLengthPreference: style.sentenceLengthPreference,
            emojiUsageLevel: style.emojiUsageLevel,
            casualMarkerUsage: min(1.0, max(0.0, style.casualMarkerUsage + formalityAdjustment)),
            emotionalExpressionLevel: min(1.0, style.emotionalExpressionLevel + emotionalAdjustment),
            reactionBeforeAnswer: style.reactionBeforeAnswer,
            avoidFormalLanguage: style.avoidFormalLanguage || behavior.formalityLevel < 0.4
        )
    }
}
