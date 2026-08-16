import AriaDomain

/// Interface for however Aria's turn results get shown to the user.
/// The real floating desktop window is Stage 6 — Stage 1 only needs a
/// console implementation to prove the pipeline works end-to-end.
public protocol DesktopUIRendering: Sendable {
    func present(turn: AssistantTurnResultDisplay)
}

/// Presentation-layer copy of what a turn produced, so this module
/// doesn't need to depend on AriaApplication for a single struct.
public struct AssistantTurnResultDisplay: Sendable, Equatable {
    public let replyText: String
    public let emotion: EmotionState
    public let relationshipState: RelationshipState

    public init(replyText: String, emotion: EmotionState, relationshipState: RelationshipState) {
        self.replyText = replyText
        self.emotion = emotion
        self.relationshipState = relationshipState
    }
}

public struct ConsoleUIRenderer: DesktopUIRendering {
    public init() {}

    public func present(turn: AssistantTurnResultDisplay) {
        print("Aria (\(turn.emotion.current.rawValue), \(String(format: "%.2f", turn.emotion.intensity))): \(turn.replyText)")
    }
}
