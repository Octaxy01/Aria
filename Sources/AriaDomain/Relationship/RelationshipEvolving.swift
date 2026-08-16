/// Interface for the component that turns this turn's conversational
/// tone (and optionally the LLM's emotion signal) into a new
/// `RelationshipState`. Mirrors `EmotionEngining`'s shape deliberately —
/// same "signal suggests, deterministic engine decides" pattern.
public protocol RelationshipEvolving: Sendable {
    func nextState(
        current: RelationshipState,
        tone: ConversationTone,
        emotionSignal: EmotionSignal?
    ) async -> RelationshipState
}
