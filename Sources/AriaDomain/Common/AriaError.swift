import Foundation

/// Typed error surface for the whole app. Application/Infrastructure code
/// should map failures into one of these cases instead of branching on
/// error message strings.
public enum AriaError: Error, Equatable {
    /// The configured LLM provider failed to produce a response.
    case llmProviderFailure(reason: String)

    /// The LLM (or another caller) tried to move the app into a state
    /// that the domain considers invalid.
    case invalidState(reason: String)

    /// Something required at startup (config, credentials, etc.) was
    /// missing or malformed.
    case configurationMissing(key: String)

    /// A tool/action was requested that Aria is not permitted or able to
    /// run. Not used yet in Stage 1 (no tools exist), but the shape is
    /// established now so Stage 8 doesn't have to invent it under
    /// pressure.
    case toolNotPermitted(toolName: String)
    
    /// Tool execution failed for a reason other than permission.
    case toolExecutionFailed(toolName: String, reason: String)
    
    /// A requested tool does not exist in the registry.
    case toolNotFound(toolName: String)
    
    /// Tool execution was cancelled by the user or system.
    case toolExecutionCancelled(toolName: String)
    
    /// Tool execution attempted with invalid arguments.
    case toolInvalidArguments(toolName: String, reason: String)
    
    /// TTS synthesis failed or was unavailable.
    case ttsFailure(reason: String)
    
    /// Avatar rendering or state management failed.
    case avatarFailure(reason: String)
}
