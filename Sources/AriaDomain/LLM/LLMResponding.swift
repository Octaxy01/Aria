/// Provider-agnostic interface for "something that can generate Aria's
/// next reply". Gemini, a local Ollama model, Claude, etc. all implement
/// this from Infrastructure — Application code never imports a specific
/// provider's SDK, only this protocol.
///
/// Stage 1 passed `messages`/`character` as separate parameters. Stage 2
/// wraps them into `LLMRequest` instead of adding more parameters,
/// because Stage 2 needs to also carry a rendered system instruction
/// string (built once, in one place, from `CharacterProfile` — see
/// `SystemPromptBuilder` in AriaApplication) without every provider
/// re-deriving it. The information carried is the same; this is a
/// reshape, not a rewrite of the underlying concept.
public protocol LLMResponding: Sendable {
    func respond(to request: LLMRequest) async throws -> LLMResponse
}

/// What a provider hands back: text to show/speak, plus an optional
/// semantic emotion signal. The signal is advisory (see `EmotionSignal`)
/// — the provider does not get to set `EmotionState` directly.
public struct LLMResponse: Sendable, Equatable {
    public let text: String
    public let emotionSignal: EmotionSignal?
    public let toolCalls: [ToolCall]?

    public init(text: String, emotionSignal: EmotionSignal? = nil, toolCalls: [ToolCall]? = nil) {
        self.text = text
        self.emotionSignal = emotionSignal
        self.toolCalls = toolCalls
    }
    
    public static func == (lhs: LLMResponse, rhs: LLMResponse) -> Bool {
        lhs.text == rhs.text &&
        lhs.emotionSignal == rhs.emotionSignal &&
        lhs.toolCalls?.count == rhs.toolCalls?.count
    }
}
