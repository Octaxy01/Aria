/// Interface for the component that turns an (optional) semantic signal
/// from the LLM into a new, deterministic `EmotionState`.
///
/// Concrete rules (transitions, cooldown, smoothing) live in the
/// Application layer's `EmotionService`, which conforms to this protocol.
/// The protocol lives in Domain so that other Domain/Application code can
/// depend on "something that computes emotion" without depending on a
/// concrete implementation.
public protocol EmotionEngining: Sendable {
    /// Compute the next emotional state given the current one and an
    /// optional signal suggested by the LLM for this turn. `signal` is
    /// `nil` when the LLM didn't provide one (e.g. provider doesn't
    /// support structured output, or parsing failed) — the engine must
    /// still return a valid state in that case (Stage 1: just decays
    /// toward neutral or holds; see EmotionService).
    func nextState(current: EmotionState, signal: EmotionSignal?) -> EmotionState
}
