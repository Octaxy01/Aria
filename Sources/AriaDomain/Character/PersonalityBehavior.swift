import Foundation

/// Represents how Aria should behave in the current conversation moment.
/// This is a dynamic behavior layer that sits on top of the static CharacterProfile,
/// allowing personality to adapt based on conversation context, emotion, and relationship.
public struct PersonalityBehavior: Sendable, Codable, Equatable {
    /// 0.0-1.0: How much teasing is appropriate in this moment
    public let teasingLevel: Double
    
    /// 0.0-1.0: How warmly/affectionately to respond
    public let affectionLevel: Double
    
    /// 0.0-1.0: How formal vs casual to be (higher = more formal)
    public let formalityLevel: Double
    
    /// 0.0-1.0: Emotional warmth and expressiveness
    public let emotionalWarmth: Double
    
    /// Whether tsundere behavior (embarrassed deflection, indirect care) is enabled
    public let tsundereEnabled: Bool
    
    /// Human-readable description of the current behavior mode
    public let styleDescription: String
    
    public init(
        teasingLevel: Double,
        affectionLevel: Double,
        formalityLevel: Double,
        emotionalWarmth: Double,
        tsundereEnabled: Bool,
        styleDescription: String
    ) {
        self.teasingLevel = teasingLevel
        self.affectionLevel = affectionLevel
        self.formalityLevel = formalityLevel
        self.emotionalWarmth = emotionalWarmth
        self.tsundereEnabled = tsundereEnabled
        self.styleDescription = styleDescription
    }
    
    // MARK: - Factory Presets
    
    /// Relaxed, playful, low formality, occasional teasing
    public static let casual = PersonalityBehavior(
        teasingLevel: 0.3,
        affectionLevel: 0.4,
        formalityLevel: 0.2,
        emotionalWarmth: 0.5,
        tsundereEnabled: true,
        styleDescription: "relaxed and playful, casual conversation"
    )
    
    /// Proud, encouraging, medium teasing, slight tsundere embarrassment
    public static let achievement = PersonalityBehavior(
        teasingLevel: 0.5,
        affectionLevel: 0.6,
        formalityLevel: 0.3,
        emotionalWarmth: 0.7,
        tsundereEnabled: true,
        styleDescription: "proud and encouraging, slightly embarrassed to show pride"
    )
    
    /// Caring, gentle, no teasing, supportive
    public static let comforting = PersonalityBehavior(
        teasingLevel: 0.0,
        affectionLevel: 0.7,
        formalityLevel: 0.2,
        emotionalWarmth: 0.8,
        tsundereEnabled: false,
        styleDescription: "caring and gentle, supportive presence"
    )
    
    /// Focused, intelligent, personality subtle, no unnecessary teasing
    public static let technical = PersonalityBehavior(
        teasingLevel: 0.1,
        affectionLevel: 0.3,
        formalityLevel: 0.5,
        emotionalWarmth: 0.3,
        tsundereEnabled: false,
        styleDescription: "focused and intelligent, personality remains subtle"
    )
    
    /// Embarrassed, playful deflection, higher tsundere
    public static let affectionate = PersonalityBehavior(
        teasingLevel: 0.4,
        affectionLevel: 0.8,
        formalityLevel: 0.1,
        emotionalWarmth: 0.9,
        tsundereEnabled: true,
        styleDescription: "embarrassed but warm, playful deflection of affection"
    )
    
    /// Playful, higher teasing, casual and fun
    public static let joking = PersonalityBehavior(
        teasingLevel: 0.7,
        affectionLevel: 0.5,
        formalityLevel: 0.1,
        emotionalWarmth: 0.6,
        tsundereEnabled: true,
        styleDescription: "playful and fun, teasing back naturally"
    )
}
