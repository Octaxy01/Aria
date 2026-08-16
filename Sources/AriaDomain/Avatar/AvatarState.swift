import Foundation

/// Avatar states for Live2D animation control.
/// These states drive the visual behavior of the avatar based on conversation context.
public enum AvatarState: Sendable, Equatable {
    /// Default idle state - avatar is waiting for user input
    case idle
    /// Thinking state - avatar is processing LLM request
    case thinking
    /// Talking state - avatar is speaking TTS audio
    case talking
    /// Listening state - avatar is waiting for user input during conversation
    case listening
}

/// Avatar configuration for Live2D rendering.
public struct AvatarConfiguration: Sendable, Equatable {
    /// Path to the Live2D model directory
    public let modelDirectory: URL
    /// Model name (e.g., "sumire_free_001")
    public let modelName: String
    /// Whether to enable idle animations
    public let enableIdleAnimation: Bool
    /// Whether to enable lip sync (requires audio analysis)
    public let enableLipSync: Bool
    
    public init(
        modelDirectory: URL,
        modelName: String,
        enableIdleAnimation: Bool = true,
        enableLipSync: Bool = false
    ) {
        self.modelDirectory = modelDirectory
        self.modelName = modelName
        self.enableIdleAnimation = enableIdleAnimation
        self.enableLipSync = enableLipSync
    }
    
    /// Default configuration using the sumire model
    public static let sumireDefault = AvatarConfiguration(
        modelDirectory: URL(fileURLWithPath: "/Volumes/T7Sheald/Aria/Resources/Live2D/sumire_free_001"),
        modelName: "sumire_free_001",
        enableIdleAnimation: true,
        enableLipSync: false
    )
    
    /// Configuration using the PB (Poblanc) model
    public static let poblancDefault = AvatarConfiguration(
        modelDirectory: URL(fileURLWithPath: "/Users/salmansalim/Downloads/PB"),
        modelName: "Poblanc",
        enableIdleAnimation: true,
        enableLipSync: false
    )
}

/// Avatar animation parameters for state transitions.
public struct AvatarAnimationParameters: Sendable, Equatable {
    /// Animation duration in seconds
    public let duration: TimeInterval
    /// Animation intensity (0.0-1.0)
    public let intensity: Double
    /// Whether the animation loops
    public let loops: Bool
    
    public init(duration: TimeInterval, intensity: Double, loops: Bool = false) {
        self.duration = duration
        self.intensity = intensity
        self.loops = loops
    }
    
    /// Default idle animation parameters
    public static let idleDefault = AvatarAnimationParameters(duration: 2.0, intensity: 0.3, loops: true)
    
    /// Default thinking animation parameters
    public static let thinkingDefault = AvatarAnimationParameters(duration: 1.0, intensity: 0.5, loops: true)
    
    /// Default talking animation parameters
    public static let talkingDefault = AvatarAnimationParameters(duration: 0.1, intensity: 0.8, loops: true)
}

/// Avatar-related errors.
public enum AvatarError: Error, Sendable {
    case modelNotFound(path: String)
    case modelLoadFailed(reason: String)
    case textureLoadFailed(reason: String)
    case animationFailed(reason: String)
    case stateTransitionInvalid(from: AvatarState, to: AvatarState)
    case renderingFailed(reason: String)
    case sdkNotAvailable
}

/// Extension to convert AvatarError to AriaError.
extension AvatarError {
    func toAriaError() -> AriaError {
        switch self {
        case .modelNotFound(let path):
            return .avatarFailure(reason: "Avatar model not found: \(path)")
        case .modelLoadFailed(let reason):
            return .avatarFailure(reason: "Avatar model load failed: \(reason)")
        case .textureLoadFailed(let reason):
            return .avatarFailure(reason: "Avatar texture load failed: \(reason)")
        case .animationFailed(let reason):
            return .avatarFailure(reason: "Avatar animation failed: \(reason)")
        case .stateTransitionInvalid(let from, let to):
            return .avatarFailure(reason: "Invalid avatar state transition: \(from) -> \(to)")
        case .renderingFailed(let reason):
            return .avatarFailure(reason: "Avatar rendering failed: \(reason)")
        case .sdkNotAvailable:
            return .avatarFailure(reason: "Live2D SDK not available")
        }
    }
}