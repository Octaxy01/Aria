import AriaDomain

/// Owns the single source of truth for conversation history in the
/// current session. Stage 1: in-memory only, no persistence, no context
/// windowing/truncation strategy yet (that's Stage 2, once a real LLM
/// context-length budget matters).
public actor ConversationService {
    private var messages: [ConversationMessage] = []

    public init() {}

    @discardableResult
    public func append(role: ConversationRole, content: String) -> ConversationMessage {
        let message = ConversationMessage(role: role, content: content)
        messages.append(message)
        return message
    }

    /// Returns the complete conversation history.
    public func history() -> [ConversationMessage] {
        return messages
    }

    /// Returns at most the last `maxMessages` messages, in original order.
    /// This is the simple "prevent unbounded growth" mechanism for Stage 2
    /// — not real token counting, just a message-count cap. Token-aware
    /// trimming can replace this later without changing the call site's
    /// contract (still "give me recent, order-preserved history").
    public func recentHistory(maxMessages: Int) -> [ConversationMessage] {
        guard maxMessages > 0, messages.count > maxMessages else {
            return messages
        }
        return Array(messages.suffix(maxMessages))
    }

    public func clear() {
        messages.removeAll()
    }
    
    /// Removes the last message from conversation history.
    /// Used for maintaining history consistency when LLM fails after user message is appended.
    /// Returns the removed message, or nil if history is empty.
    @discardableResult
    public func removeLast() -> ConversationMessage? {
        guard !messages.isEmpty else { return nil }
        return messages.removeLast()
    }
    
    /// Checks if the last message in history is from the user.
    /// Used for recovery scenarios where we need to know if we should remove a dangling user message.
    public func isLastMessageFromUser() -> Bool {
        guard let last = messages.last else { return false }
        return last.role == .user
    }
}
