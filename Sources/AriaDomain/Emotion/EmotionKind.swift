/// The closed set of emotional states Aria can be in. This is a fixed
/// vocabulary owned by the domain — the LLM can only ever *suggest* one of
/// these via `EmotionSignal`, never invent a new one.
public enum EmotionKind: String, Sendable, Codable, Equatable, CaseIterable {
    case neutral
    case happy
    case affectionate
    case embarrassed
    case annoyed
    case sad
    case worried
    case excited
    case playful
    case angry
}
