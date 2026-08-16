import AriaDomain

/// Deterministic implementation of `EmotionEngining`.
///
/// Stage 3 replaces the Stage 1 "adopt signal verbatim" behavior with
/// simple transition rules so Aria's displayed mood doesn't flicker
/// turn-to-turn on noisy/borderline LLM signals:
///
///   - no signal            → hold current emotion, intensity decays
///   - signal matches current emotion → intensity is smoothed toward the
///     signal's intensity rather than snapping to it
///   - signal proposes a DIFFERENT emotion → only switches if the signal
///     is strong enough (>= switchThreshold); a weak/borderline signal is
///     treated as noise and the current emotion is held (with a small
///     extra decay), rather than causing Aria to flip mood on every
///     message
///
/// Still no ML, no history beyond `current` — purely a function of
/// (current state, this turn's signal).
public struct EmotionService: EmotionEngining {
    private let decayPerTurnWithoutSignal: Double
    private let smoothingFactor: Double
    private let switchThreshold: Double

    /// - Parameters:
    ///   - decayPerTurnWithoutSignal: how much intensity drains per turn
    ///     when the LLM gives no signal, or when a weak signal is ignored.
    ///   - smoothingFactor: 0...1. How much a same-emotion signal moves
    ///     intensity toward the signal's value in a single turn (1.0 =
    ///     snap immediately, like Stage 1; lower = smoother).
    ///   - switchThreshold: 0...1. Minimum (clamped) intensity a
    ///     different-emotion signal needs before it's allowed to replace
    ///     the current emotion.
    public init(
        decayPerTurnWithoutSignal: Double = 0.2,
        smoothingFactor: Double = 0.6,
        switchThreshold: Double = 0.35
    ) {
        self.decayPerTurnWithoutSignal = decayPerTurnWithoutSignal
        self.smoothingFactor = smoothingFactor
        self.switchThreshold = switchThreshold
    }

    public func nextState(current: EmotionState, signal: EmotionSignal?) -> EmotionState {
        guard let signal else {
            let decayed = max(0.0, current.intensity - decayPerTurnWithoutSignal)
            return EmotionState(current: current.current, intensity: decayed)
        }

        let clampedIntensity = min(max(signal.intensity, 0.0), 1.0)

        if signal.emotion == current.current {
            let blended = current.intensity + (clampedIntensity - current.intensity) * smoothingFactor
            return EmotionState(current: current.current, intensity: max(0.0, min(1.0, blended)))
        }

        guard clampedIntensity >= switchThreshold else {
            let nudged = max(0.0, current.intensity - decayPerTurnWithoutSignal * 0.5)
            return EmotionState(current: current.current, intensity: nudged)
        }

        return EmotionState(current: signal.emotion, intensity: clampedIntensity)
    }
}