import Foundation

/// Represents Aria's natural speaking style for the current conversation.
/// This guides how she should phrase responses to sound like a natural companion
/// rather than an AI assistant.
public struct SpeechStyle: Sendable, Codable, Equatable {
    /// 0.0-1.0: Preference for shorter vs longer sentences
    public let sentenceLengthPreference: Double
    
    /// 0.0-1.0: How much to use emojis naturally
    public let emojiUsageLevel: Double
    
    /// 0.0-1.0: How much to use casual Indonesian markers (kan, dong, sih, deh)
    public let casualMarkerUsage: Double
    
    /// 0.0-1.0: How emotionally expressive to be
    public let emotionalExpressionLevel: Double
    
    /// Whether to react before answering (vs. direct answers)
    public let reactionBeforeAnswer: Bool
    
    /// Whether to avoid formal language patterns
    public let avoidFormalLanguage: Bool
    
    public init(
        sentenceLengthPreference: Double,
        emojiUsageLevel: Double,
        casualMarkerUsage: Double,
        emotionalExpressionLevel: Double,
        reactionBeforeAnswer: Bool,
        avoidFormalLanguage: Bool
    ) {
        self.sentenceLengthPreference = sentenceLengthPreference
        self.emojiUsageLevel = emojiUsageLevel
        self.casualMarkerUsage = casualMarkerUsage
        self.emotionalExpressionLevel = emotionalExpressionLevel
        self.reactionBeforeAnswer = reactionBeforeAnswer
        self.avoidFormalLanguage = avoidFormalLanguage
    }
    
    // MARK: - Factory Presets
    
    /// Natural, everyday conversation style
    public static let casualConversation = SpeechStyle(
        sentenceLengthPreference: 0.7, // prefer shorter sentences
        emojiUsageLevel: 0.3,
        casualMarkerUsage: 0.6,
        emotionalExpressionLevel: 0.5,
        reactionBeforeAnswer: false,
        avoidFormalLanguage: true
    )
    
    /// Supportive, caring style for emotional moments
    public static let emotionalSupport = SpeechStyle(
        sentenceLengthPreference: 0.5, // moderate length
        emojiUsageLevel: 0.2,
        casualMarkerUsage: 0.4,
        emotionalExpressionLevel: 0.7, // more emotionally expressive
        reactionBeforeAnswer: true, // react first, then support
        avoidFormalLanguage: true
    )
    
    /// Clear, focused style for technical help
    public static let technicalHelp = SpeechStyle(
        sentenceLengthPreference: 0.3, // can be longer for clarity
        emojiUsageLevel: 0.1,
        casualMarkerUsage: 0.2,
        emotionalExpressionLevel: 0.3, // keep emotion subtle
        reactionBeforeAnswer: false,
        avoidFormalLanguage: false // some formality okay for clarity
    )
    
    /// Enthusiastic, reaction-first style for achievements
    public static let achievementReaction = SpeechStyle(
        sentenceLengthPreference: 0.6,
        emojiUsageLevel: 0.4,
        casualMarkerUsage: 0.5,
        emotionalExpressionLevel: 0.8, // very expressive
        reactionBeforeAnswer: true, // always react first
        avoidFormalLanguage: true
    )
    
    /// Playful, teasing style for fun conversations
    public static let playfulConversation = SpeechStyle(
        sentenceLengthPreference: 0.8, // short, punchy sentences
        emojiUsageLevel: 0.5,
        casualMarkerUsage: 0.7,
        emotionalExpressionLevel: 0.6,
        reactionBeforeAnswer: true,
        avoidFormalLanguage: true
    )
}
