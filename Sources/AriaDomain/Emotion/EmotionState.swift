import Foundation

/// Aria's actual current emotional state, as decided by the deterministic
/// emotion engine in the Application layer — never written directly from
/// an `EmotionSignal`.
///
/// This is the value that Presentation (Live2D expressions/animations,
/// future emotion-aware TTS) will read from. Stage 1 only defines the
/// shape; transition/smoothing/cooldown logic arrives in Stage 3.
public struct EmotionState: Sendable, Codable, Equatable {
    public let current: EmotionKind
    public let intensity: Double
    public let updatedAt: Date

    public init(current: EmotionKind, intensity: Double, updatedAt: Date = Date()) {
        self.current = current
        self.intensity = intensity
        self.updatedAt = updatedAt
    }

    /// Starting state for a fresh session.
    public static let initial = EmotionState(current: .neutral, intensity: 0.0, updatedAt: .distantPast)
}
