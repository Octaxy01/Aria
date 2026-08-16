import Foundation
import AriaDomain

/// Resolves the appropriate TTS provider based on language and configuration.
/// Centralized provider selection to avoid scattered language checks throughout the codebase.
public struct TTSProviderResolver {
    
    /// Returns the appropriate TTS provider for the given language.
    /// This is the single source of truth for language-to-provider mapping.
    public static func provider(for language: SupportedLanguage) -> TTSProvider {
        switch language {
        case .japanese:
            return .voicevox  // Japanese uses VOICEVOX with 冥鳴ひまり
        case .indonesian:
            return .piper     // Indonesian uses Piper
        case .english:
            return .piper     // English uses Piper
        case .russian:
            return .piper     // Russian uses Piper
        case .auto:
            return .piper     // Default fallback
        }
    }
    
    /// Returns the default voice configuration for the given language.
    public static func defaultVoice(for language: SupportedLanguage) -> VoiceConfiguration {
        switch language {
        case .japanese:
            return .ariaJapanese  // VOICEVOX 冥鳴ひまり (speaker 14)
        case .indonesian:
            return .ariaIndonesian
        case .english:
            return .englishDefault
        case .russian:
            return .russianDefault
        case .auto:
            return .englishDefault
        }
    }
    
    /// Returns the fallback provider type for a given language if the primary fails.
    public static func fallbackProviderType(for language: SupportedLanguage) -> TTSProvider? {
        // For Japanese, fallback to Piper if VOICEVOX fails
        if language == .japanese {
            return .piper
        }
        
        // For other languages, Piper is already the primary, so no fallback
        return nil
    }
}
