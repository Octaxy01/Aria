import AriaDomain
import Foundation

/// Interface for whatever renders Aria's avatar and reacts to her
/// emotional state. Live2D is Stage 7 — this exists now purely so
/// `AssistantCoordinator`/composition root never has to change shape when
/// Live2D is added, only the concrete implementation swaps in.
public protocol AvatarRendering: Sendable {
    func update(emotion: EmotionState)
    
    /// Updates avatar state based on conversation context.
    func updateState(_ state: AvatarState) async throws
    
    /// Triggers avatar animation for the current state.
    func animate(state: AvatarState, parameters: AvatarAnimationParameters) async throws
    
    /// Resets avatar to initial state.
    func reset() async throws
    
    /// Checks if avatar rendering is available.
    var isAvailable: Bool { get }
}

/// Default implementations for backward compatibility.
public extension AvatarRendering {
    func updateState(_ state: AvatarState) async throws {
        // Default: do nothing
    }
    
    func animate(state: AvatarState, parameters: AvatarAnimationParameters) async throws {
        // Default: do nothing
    }
    
    func reset() async throws {
        // Default: do nothing
    }
    
    var isAvailable: Bool {
        return false
    }
}

/// Does nothing. Used in Stage 1 (and until Stage 7) so the app can run
/// end-to-end without an avatar implementation existing yet.
public struct NullAvatarRenderer: AvatarRendering {
    public init() {}
    public func update(emotion: EmotionState) {
        // Intentionally empty — no avatar yet.
    }
}

/// macOS window-based avatar renderer for Live2D
/// Simple class that coordinates window lifecycle
@MainActor
public final class Live2DAvatarRenderer: AvatarRendering {
    
    private var live2DWindow: Live2DWindow?
    private let configuration: AvatarConfiguration
    private var isWindowVisible: Bool = false
    
    /// Creates a new Live2D avatar renderer
    /// - Parameter configuration: Avatar configuration
    public init(configuration: AvatarConfiguration = .poblancDefault) {
        self.configuration = configuration
        print("[Live2D] Initializing Live2D renderer")
        print("[Live2D] Model path: \(configuration.modelDirectory.path)")
        print("[Live2D] Model name: \(configuration.modelName)")
    }
    
    /// Shows the Live2D window
    public func showWindow() {
        if self.live2DWindow == nil {
            self.live2DWindow = Live2DWindow(configuration: self.configuration)
            print("[Live2D] Window created")
        }
        
        self.live2DWindow?.showWindow()
        self.isWindowVisible = true
        print("[Live2D] Avatar window shown")
    }
    
    /// Hides the Live2D window
    public func hideWindow() {
        self.live2DWindow?.hideWindow()
        self.isWindowVisible = false
        print("[Live2D] Avatar window hidden")
    }
    
    public nonisolated func update(emotion: EmotionState) {
        print("[Live2D] Emotion update: \(emotion.current.rawValue), intensity: \(emotion.intensity)")
    }
    
    public func updateState(_ state: AvatarState) async throws {
        self.live2DWindow?.updateAvatarState(state)
    }
    
    public func animate(state: AvatarState, parameters: AvatarAnimationParameters) async throws {
        print("[Live2D] Animation request: state=\(state), duration=\(parameters.duration)s, intensity=\(parameters.intensity)")
    }
    
    public func reset() async throws {
        try await updateState(.idle)
    }
    
    public nonisolated var isAvailable: Bool {
        return true // Assume available if renderer is instantiated
    }
}