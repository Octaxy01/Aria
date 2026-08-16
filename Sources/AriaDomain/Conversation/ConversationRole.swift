/// Who authored a given conversation message.
public enum ConversationRole: String, Sendable, Codable, Equatable {
    case user
    case assistant
    case system
}
