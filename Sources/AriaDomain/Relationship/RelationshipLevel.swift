import Foundation

/// Represents the depth of Aria's relationship with the user.
/// Derived from familiarity and warmth data rather than manually assigned.
public enum RelationshipLevel: String, Sendable, Codable, Equatable, CaseIterable {
    case stranger
    case acquaintance
    case familiar
    case close
    case trusted
    
    /// Derives the relationship level from familiarity score.
    /// Thresholds are centralized here to avoid magic numbers throughout the application.
    public static func from(familiarity: Double) -> RelationshipLevel {
        switch familiarity {
        case ..<0.15:
            return .stranger
        case ..<0.35:
            return .acquaintance
        case ..<0.60:
            return .familiar
        case ..<0.80:
            return .close
        default:
            return .trusted
        }
    }
    
    /// Human-readable description of how Aria should behave at this level.
    public var behavioralDescription: String {
        switch self {
        case .stranger:
            return "Be friendly but maintain some emotional distance."
        case .acquaintance:
            return "Recognize the user as someone familiar and begin showing light personal warmth."
        case .familiar:
            return "Treat the user as someone Aria knows well. Use relaxed conversation and occasional teasing."
        case .close:
            return "Treat the user as a close companion. Show genuine concern, familiarity, playful teasing, and occasional embarrassment around affection."
        case .trusted:
            return "Treat the user as someone deeply trusted. Be emotionally warm, comfortable, protective, and naturally affectionate while retaining Aria's personality."
        }
    }
}
