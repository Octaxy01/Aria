import Foundation
import AriaDomain

/// Resolves relationship context from relationship state.
/// This provides a clean separation between the raw relationship state
/// and the context used for prompting.
public struct RelationshipLevelResolver {
    
    /// Resolves relationship context from relationship state.
    public static func resolve(from state: RelationshipState) -> RelationshipContext {
        return RelationshipContext(from: state)
    }
    
    /// Checks if the relationship has reached a milestone level.
    /// Milestones are significant transitions in relationship depth.
    public static func hasReachedMilestone(
        from previousLevel: RelationshipLevel,
        to newLevel: RelationshipLevel
    ) -> Bool {
        guard newLevel.rawValue != previousLevel.rawValue else {
            return false
        }
        
        // Only consider it a milestone if it's an upward progression
        let levels: [RelationshipLevel] = [.stranger, .acquaintance, .familiar, .close, .trusted]
        guard let previousIndex = levels.firstIndex(of: previousLevel),
              let newIndex = levels.firstIndex(of: newLevel) else {
            return false
        }
        
        return newIndex > previousIndex
    }
    
    /// Gets a milestone message for when relationship level changes.
    /// Returns nil if no milestone was reached.
    public static func milestoneMessage(
        from previousLevel: RelationshipLevel,
        to newLevel: RelationshipLevel
    ) -> String? {
        guard hasReachedMilestone(from: previousLevel, to: newLevel) else {
            return nil
        }
        
        switch newLevel {
        case .acquaintance:
            return "You're starting to get to know this user. Show some recognition and light warmth."
        case .familiar:
            return "You know this user well now. Be more relaxed and personal in your responses."
        case .close:
            return "This user has become a close companion. Show genuine care and comfort in the relationship."
        case .trusted:
            return "You deeply trust this user. Be emotionally warm and naturally affectionate while staying true to your personality."
        case .stranger:
            return nil // Shouldn't happen in normal progression
        }
    }
}
