import Foundation

/// A single turn in a conversation. Immutable by design — the
/// ConversationService owns the ordered history, individual messages don't
/// mutate after creation.
public struct ConversationMessage: Sendable, Codable, Equatable, Identifiable {
    public let id: UUID
    public let role: ConversationRole
    public let content: String
    public let timestamp: Date

    public init(
        id: UUID = UUID(),
        role: ConversationRole,
        content: String,
        timestamp: Date = Date()
    ) {
        self.id = id
        self.role = role
        self.content = content
        self.timestamp = timestamp
    }
}
