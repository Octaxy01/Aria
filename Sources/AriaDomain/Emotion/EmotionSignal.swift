/// A *suggestion* from the LLM about how Aria might be feeling in response
/// to a given turn. This is advisory input, not application state.
///
/// The LLM emits this alongside its text (see `LLMResponse`). It is the
/// job of the application layer's emotion engine — not the LLM — to decide
/// whether/how this signal actually changes Aria's emotional state.
public struct EmotionSignal: Sendable, Codable, Equatable {
    public let emotion: EmotionKind

    /// 0.0 ... 1.0. Values outside this range are clamped by the emotion
    /// engine rather than trusted verbatim.
    public let intensity: Double

    public init(emotion: EmotionKind, intensity: Double) {
        self.emotion = emotion
        self.intensity = intensity
    }
}
