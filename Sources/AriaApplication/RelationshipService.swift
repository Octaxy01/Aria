import Foundation
import AriaDomain

/// Deterministic implementation of `RelationshipEvolving` with persistence.
///
/// Stage 3 rules, deliberately simple (no ML, deterministic logic):
///   - familiarity increases by a small fixed step every turn, capped at 1.0
///   - warmth moves by a tone-specific step, so a single rude or
///     affectionate message nudges it rather than swinging it to an extreme
///   - a strongly positive emotion signal (happy/affectionate/playful/
///     excited) gives warmth a small extra nudge; a strongly negative one
///     (sad/annoyed/angry/worried) nudges it down slightly — this is a
///     secondary factor, tone is primary
///
/// Thread-safe through actor isolation. Integrates with RelationshipStateStoring
/// for persistence across application restarts.
public actor RelationshipService: RelationshipEvolving {
    private let familiarityStep: Double
    private let warmthStep: Double
    private let emotionWarmthNudge: Double
    private let stateStore: (any RelationshipStateStoring)?
    private var currentState: RelationshipState

    /// Initialize without persistence (for testing/backward compatibility).
    public init(
        familiarityStep: Double = 0.02,
        warmthStep: Double = 0.05,
        emotionWarmthNudge: Double = 0.02
    ) {
        self.familiarityStep = familiarityStep
        self.warmthStep = warmthStep
        self.emotionWarmthNudge = emotionWarmthNudge
        self.stateStore = nil
        self.currentState = RelationshipState.initial
    }

    /// Initialize with persistence (for production use).
    /// - Parameter stateStore: The persistent store to load/save relationship state
    public init(
        stateStore: any RelationshipStateStoring,
        familiarityStep: Double = 0.02,
        warmthStep: Double = 0.05,
        emotionWarmthNudge: Double = 0.02
    ) async {
        self.familiarityStep = familiarityStep
        self.warmthStep = warmthStep
        self.emotionWarmthNudge = emotionWarmthNudge
        self.stateStore = stateStore
        
        // Load persisted state or use initial
        do {
            self.currentState = try await stateStore.load()
        } catch {
            // If loading fails, use initial state
            self.currentState = RelationshipState.initial
        }
    }

    public func nextState(
        current: RelationshipState,
        tone: ConversationTone,
        emotionSignal: EmotionSignal?
    ) async -> RelationshipState {
        // Use the internally maintained state, not the passed-in current
        let familiarity = min(1.0, currentState.familiarity + familiarityStep)

        var warmth = currentState.warmth
        switch tone {
        case .affectionate:
            warmth += warmthStep
        case .joking:
            warmth += warmthStep * 0.4
        case .achievement:
            warmth += warmthStep * 0.6
        case .serious, .casual, .technical:
            warmth += warmthStep * 0.1
        case .rude:
            warmth -= warmthStep * 1.5
        case .emotional:
            warmth += warmthStep * 0.3
        }

        if let emotionSignal {
            switch emotionSignal.emotion {
            case .happy, .affectionate, .playful, .excited:
                warmth += emotionWarmthNudge
            case .sad, .annoyed, .angry, .worried:
                warmth -= emotionWarmthNudge
            case .neutral, .embarrassed:
                break
            }
        }

        warmth = min(1.0, max(0.0, warmth))

        let newState = RelationshipState(
            warmth: warmth,
            familiarity: familiarity,
            interactionCount: currentState.interactionCount + 1,
            updatedAt: Date()
        )
        
        currentState = newState
        
        // Persist asynchronously if store is available
        if let stateStore {
            try? await stateStore.save(newState)
        }
        
        return newState
    }
    
    /// Get the current state (for initialization)
    public func getCurrentState() -> RelationshipState {
        return currentState
    }
}