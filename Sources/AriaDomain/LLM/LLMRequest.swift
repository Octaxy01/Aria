/// Everything a provider needs to produce Aria's next reply. Kept
/// deliberately small — just the (already context-limited) conversation
/// history and an optional rendered system instruction. No emotion state
/// is included here: Stage 2 only needs the LLM to read conversation
/// history, not Aria's current mood. If a future stage needs the LLM to
/// see emotion as read-only context, add it here explicitly rather than
/// growing this type's responsibilities implicitly.
public struct LLMRequest: Sendable, Equatable {
    public let messages: [ConversationMessage]
    public let systemContext: String?
    public let toolDefinitions: [ToolDefinition]?

    public init(messages: [ConversationMessage], systemContext: String? = nil, toolDefinitions: [ToolDefinition]? = nil) {
        self.messages = messages
        self.systemContext = systemContext
        self.toolDefinitions = toolDefinitions
    }
    
    public static func == (lhs: LLMRequest, rhs: LLMRequest) -> Bool {
        lhs.messages == rhs.messages &&
        lhs.systemContext == rhs.systemContext &&
        lhs.toolDefinitions?.count == rhs.toolDefinitions?.count
    }
}
