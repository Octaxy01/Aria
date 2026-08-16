import Foundation

/// Aria's lightweight, in-memory sense of "how this session has gone so
/// far" with the current user. Deliberately NOT a persistence/memory
/// system — Stage 3 explicitly excludes that. This resets every time the
/// app restarts; it exists purely to make personality feel consistent
/// *within* a running session instead of treating every turn as the
/// first one.
///
/// Computed deterministically by `RelationshipEvolving`, never written
/// directly from the LLM.
public struct RelationshipState: Sendable, Codable, Equatable {
    /// 0...1. General session fondness/rapport. Nudged up by
    /// affectionate/positive turns, down by rude/negative ones.
    public let warmth: Double

    /// 0...1. Grows monotonically (slowly) with interaction count and
    /// caps at 1.0. A simple proxy for "how long we've been talking",
    /// not sentiment.
    public let familiarity: Double

    public let interactionCount: Int
    public let updatedAt: Date

    public init(warmth: Double, familiarity: Double, interactionCount: Int, updatedAt: Date = Date()) {
        self.warmth = warmth
        self.familiarity = familiarity
        self.interactionCount = interactionCount
        self.updatedAt = updatedAt
    }

    /// Starting state for a fresh session.
    public static let initial = RelationshipState(
        warmth: 0.3,
        familiarity: 0.0,
        interactionCount: 0,
        updatedAt: .distantPast
    )
}