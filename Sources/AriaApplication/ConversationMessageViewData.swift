import AriaDomain
import Foundation

/// Presentation model for conversation messages.
/// This is a UI projection that contains only the data needed for rendering,
/// without backend-specific concerns or UI-specific properties like colors/fonts.
public struct ConversationMessageViewData: Identifiable, Sendable {
    public let id: UUID
    public let role: ConversationRole
    public let content: String
    public let timestamp: Date
    
    public init(id: UUID = UUID(), role: ConversationRole, content: String, timestamp: Date = Date()) {
        self.id = id
        self.role = role
        self.content = content
        self.timestamp = timestamp
    }
    
    /// Creates a view data model from a domain conversation message.
    /// - Parameter message: The domain conversation message
    /// - Returns: A presentation model for UI rendering
    public static func from(_ message: ConversationMessage) -> ConversationMessageViewData {
        ConversationMessageViewData(
            role: message.role,
            content: message.content,
            timestamp: message.timestamp
        )
    }
}
