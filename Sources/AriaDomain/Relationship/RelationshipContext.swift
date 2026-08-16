import Foundation

/// Represents the current relationship state for prompting purposes.
/// Combines relationship level with underlying metrics to guide Aria's behavior.
public struct RelationshipContext: Sendable, Codable, Equatable {
    /// The current depth of relationship
    public let level: RelationshipLevel
    
    /// Current warmth score (0.0-1.0)
    public let warmth: Double
    
    /// Current familiarity score (0.0-1.0)
    public let familiarity: Double
    
    /// Number of interactions in this session
    public let interactionCount: Int
    
    /// Human-readable description of how Aria should behave at the current relationship level
    public let behavioralDescription: String
    
    public init(
        level: RelationshipLevel,
        warmth: Double,
        familiarity: Double,
        interactionCount: Int,
        behavioralDescription: String
    ) {
        self.level = level
        self.warmth = warmth
        self.familiarity = familiarity
        self.interactionCount = interactionCount
        self.behavioralDescription = behavioralDescription
    }
    
    /// Creates a relationship context from a relationship state.
    public init(from state: RelationshipState) {
        self.level = RelationshipLevel.from(familiarity: state.familiarity)
        self.warmth = state.warmth
        self.familiarity = state.familiarity
        self.interactionCount = state.interactionCount
        self.behavioralDescription = level.behavioralDescription
    }
}
