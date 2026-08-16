import Foundation
import AriaDomain

/// Manages avatar state transitions based on conversation context.
/// Coordinates with emotion and relationship systems to drive avatar behavior.
public actor AvatarStateManager {
    
    private var currentState: AvatarState = .idle
    private let configuration: AvatarConfiguration
    
    public init(configuration: AvatarConfiguration = .sumireDefault) {
        self.configuration = configuration
    }
    
    /// Current avatar state
    public var state: AvatarState {
        get async {
            return currentState
        }
    }
    
    /// Transitions avatar to thinking state.
    /// Called when user input is received and LLM processing begins.
    public func transitionToThinking() async throws {
        try transition(from: currentState, to: .thinking)
    }
    
    /// Transitions avatar to talking state.
    /// Called when TTS synthesis begins and audio playback starts.
    public func transitionToTalking() async throws {
        try transition(from: currentState, to: .talking)
    }
    
    /// Transitions avatar to idle state.
    /// Called when conversation ends or after talking completes.
    public func transitionToIdle() async throws {
        try transition(from: currentState, to: .idle)
    }
    
    /// Transitions avatar to listening state.
    /// Called when actively waiting for user input during conversation.
    public func transitionToListening() async throws {
        try transition(from: currentState, to: .listening)
    }
    
    /// Performs state transition with validation.
    /// AVATAR STATE HARDENING: Prevents invalid transitions and stuck states
    private func transition(from: AvatarState, to: AvatarState) throws {
        // Validate transition
        guard isValidTransition(from: from, to: to) else {
            throw AvatarError.stateTransitionInvalid(from: from, to: to)
        }
        
        currentState = to
    }
    
    /// Validates whether a state transition is allowed.
    private func isValidTransition(from: AvatarState, to: AvatarState) -> Bool {
        // Define valid transitions
        let validTransitions: [AvatarState: [AvatarState]] = [
            .idle: [.thinking, .listening],
            .thinking: [.talking, .idle],
            .talking: [.idle, .listening],
            .listening: [.thinking, .idle]
        ]
        
        return validTransitions[from]?.contains(to) ?? false
    }
    
    /// Determines appropriate avatar state based on conversation context.
    public nonisolated func determineState(
        hasUserInput: Bool,
        isProcessingLLM: Bool,
        isPlayingAudio: Bool
    ) -> AvatarState {
        if isProcessingLLM {
            return .thinking
        } else if isPlayingAudio {
            return .talking
        } else if hasUserInput {
            return .listening
        } else {
            return .idle
        }
    }
    
    /// Gets animation parameters for the current state.
    public nonisolated func animationParameters(for state: AvatarState) -> AvatarAnimationParameters {
        switch state {
        case .idle:
            return .idleDefault
        case .thinking:
            return .thinkingDefault
        case .talking:
            return .talkingDefault
        case .listening:
            return AvatarAnimationParameters(duration: 1.5, intensity: 0.4, loops: true)
        }
    }
    
    /// Resets avatar to initial state.
    public func reset() async throws {
        try transition(from: currentState, to: .idle)
    }
}