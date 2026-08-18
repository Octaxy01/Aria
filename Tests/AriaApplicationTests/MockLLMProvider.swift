import XCTest
import AriaDomain

/// Deterministic mock LLM provider for testing.
/// Allows tests to specify exact responses without requiring OPENROUTER_API_KEY.
public actor MockLLMProvider: LLMResponding {
    
    /// Pre-configured responses to return
    private var responses: [LLMResponse]
    
    /// Current response index
    private var currentIndex: Int
    
    /// Simulated delay in seconds (0 for immediate)
    private let delay: TimeInterval
    
    /// Whether to throw an error on next response
    private var shouldThrowError: Bool
    
    /// Simulated error to throw
    private let simulatedError: Error
    
    /// Optional response sequence for multi-round testing
    public var responseSequence: [LLMResponse] = []
    private var sequenceIndex: Int = 0
    
    public init(
        responses: [LLMResponse] = [],
        delay: TimeInterval = 0,
        shouldThrowError: Bool = false,
        simulatedError: Error = NSError(domain: "MockLLM", code: 1, userInfo: nil)
    ) {
        self.responses = responses
        self.currentIndex = 0
        self.delay = delay
        self.shouldThrowError = shouldThrowError
        self.simulatedError = simulatedError
    }
    
    /// Sets the responses to return
    public func setResponses(_ responses: [LLMResponse]) {
        self.responses = responses
        self.currentIndex = 0
    }
    
    /// Adds a single response to the queue
    public func addResponse(_ response: LLMResponse) {
        responses.append(response)
    }
    
    /// Sets whether to throw an error on next response
    public func setShouldThrowError(_ shouldThrow: Bool) {
        self.shouldThrowError = shouldThrow
    }
    
    /// Resets the response queue
    public func reset() {
        responses.removeAll()
        currentIndex = 0
        shouldThrowError = false
        responseSequence.removeAll()
        sequenceIndex = 0
    }
    
    public func respond(to request: LLMRequest) async throws -> LLMResponse {
        // Simulate delay if configured
        if delay > 0 {
            try await Task.sleep(nanoseconds: UInt64(delay * 1_000_000_000))
        }
        
        // Throw error if configured
        if shouldThrowError {
            throw simulatedError
        }
        
        // Check response sequence first (for multi-round testing)
        if sequenceIndex < responseSequence.count {
            let response = responseSequence[sequenceIndex]
            sequenceIndex += 1
            return response
        }
        
        // Fall back to legacy responses array
        if currentIndex < responses.count {
            let response = responses[currentIndex]
            currentIndex += 1
            return response
        }
        
        // Default empty response when no more responses configured
        return LLMResponse(text: "")
    }
    
    /// Creates a simple text response
    public static func textResponse(_ text: String) -> LLMResponse {
        return LLMResponse(text: text)
    }
    
    /// Creates a tool call response
    public static func toolCallResponse(
        toolIdentifier: ToolIdentifier,
        arguments: [String: Sendable] = [:],
        sessionID: UUID = UUID()
    ) -> LLMResponse {
        let toolCall = ToolCall(
            toolIdentifier: toolIdentifier,
            arguments: arguments,
            sessionID: sessionID
        )
        return LLMResponse(text: "", toolCalls: [toolCall])
    }
    
    /// Creates a response with both text and tool calls
    public static func mixedResponse(
        text: String,
        toolIdentifier: ToolIdentifier,
        arguments: [String: Sendable] = [:],
        sessionID: UUID = UUID()
    ) -> LLMResponse {
        let toolCall = ToolCall(
            toolIdentifier: toolIdentifier,
            arguments: arguments,
            sessionID: sessionID
        )
        return LLMResponse(text: text, toolCalls: [toolCall])
    }
}

/// Common predefined responses for testing
extension MockLLMProvider {
    /// Standard greeting response
    public static let greetingResponse = LLMResponse(text: "Hei, aku Aria.")
    
    /// Simple acknowledgment
    public static let acknowledgmentResponse = LLMResponse(text: "Baik, mengerti.")
    
    /// Error response
    public static let errorResponse = LLMResponse(text: "Maaf, terjadi kesalahan.")
    
    /// Multiple tool calls response
    public static func multipleToolCallsResponse(
        tool1: (identifier: ToolIdentifier, args: [String: Sendable]),
        tool2: (identifier: ToolIdentifier, args: [String: Sendable]),
        sessionID: UUID = UUID()
    ) -> LLMResponse {
        let toolCall1 = ToolCall(
            toolIdentifier: tool1.identifier,
            arguments: tool1.args,
            sessionID: sessionID
        )
        let toolCall2 = ToolCall(
            toolIdentifier: tool2.identifier,
            arguments: tool2.args,
            sessionID: sessionID
        )
        return LLMResponse(text: "", toolCalls: [toolCall1, toolCall2])
    }
}