/// A coarse, deterministic read on the tone of a single user message.
/// This is NOT sentiment analysis or an ML classifier — see
/// `ConversationToneClassifier` in the Application layer for the simple
/// keyword/heuristic rules that produce this. It exists so
/// `RelationshipEvolving` has something more specific than raw text to
/// react to.
public enum ConversationTone: String, Sendable, Codable, Equatable, CaseIterable {
    case casual
    case serious
    case joking
    case affectionate
    case rude
    case achievement
    case technical
    case emotional
}