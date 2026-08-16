import Foundation

/// Protocol for text-to-speech services.
/// Allows different TTS implementations (Piper, system TTS, cloud APIs, etc.) to be swapped in.
public protocol TextToSpeeching: Sendable {
    /// Convert text to audio file and return the file path.
    /// Returns nil if synthesis fails.
    func synthesize(text: String, language: Language, voice: VoiceConfiguration, style: SpeechStyle?) async throws -> URL?
    
    /// Synthesize segmented text with pauses between segments.
    /// Used for Japanese to create natural conversational rhythm.
    /// Default implementation should fall back to normal synthesis.
    func synthesizeSegmented(segments: [String], pauses: [TimeInterval], language: Language, voice: VoiceConfiguration, style: SpeechStyle?) async throws -> URL?
    
    /// Cancel any ongoing synthesis.
    func cancel() async
    
    /// Check if the provider is available.
    func isAvailable() async -> Bool
    
    /// Get the provider name for logging/debugging.
    var providerName: String { get }
}

/// Default implementation for backward compatibility.
extension TextToSpeeching {
    public func synthesize(text: String, language: Language, voice: VoiceConfiguration) async throws -> URL? {
        return try await synthesize(text: text, language: language, voice: voice, style: nil)
    }
    
    public func synthesizeSegmented(segments: [String], pauses: [TimeInterval], language: Language, voice: VoiceConfiguration) async throws -> URL? {
        return try await synthesizeSegmented(segments: segments, pauses: pauses, language: language, voice: voice, style: nil)
    }
}

/// Supported languages for TTS.
public enum Language: String, Sendable, CaseIterable {
    case indonesian = "id_ID"
    case japanese = "ja_JP"
    case russian = "ru_RU"
    case english = "en_US"
}

/// TTS provider types for configuration and fallback.
public enum TTSProvider: String, Sendable, CaseIterable {
    case piper = "piper"
    case system = "system"
    case openai = "openai"
    case elevenlabs = "elevenlabs"
    case azure = "azure"
    case google = "google"
    case amazon = "amazon"
    case voicevox = "voicevox"
}

/// Enhanced voice configuration with style parameters.
public struct VoiceConfiguration: Sendable, Equatable {
    public let provider: TTSProvider
    public let language: Language
    public let voiceId: String
    public let pitch: Double           // 0.5-2.0, 1.0 = normal
    public let speed: Double           // 0.5-2.0, 1.0 = normal
    public let style: VoiceStyle
    public let speaker: Int?          // For multi-speaker models
    
    public init(
        provider: TTSProvider,
        language: Language,
        voiceId: String,
        pitch: Double = 1.0,
        speed: Double = 1.0,
        style: VoiceStyle = .natural,
        speaker: Int? = nil
    ) {
        self.provider = provider
        self.language = language
        self.voiceId = voiceId
        self.pitch = pitch
        self.speed = speed
        self.style = style
        self.speaker = speaker
    }
    
    /// Default Indonesian voice for Aria (anime-inspired, young female)
    public static let ariaIndonesian = VoiceConfiguration(
        provider: .piper,
        language: .indonesian,
        voiceId: "id_ID-news_tts-medium", // Placeholder - will be replaced with anime voice
        pitch: 1.2,                      // Slightly higher pitch for young female
        speed: 1.0,
        style: .natural
    )
    
    /// Fallback Indonesian voice
    public static let indonesianFallback = VoiceConfiguration(
        provider: .piper,
        language: .indonesian,
        voiceId: "id_ID-news_tts-medium",
        pitch: 1.0,
        speed: 1.0,
        style: .natural
    )
    
    /// Default English voice
    public static let englishDefault = VoiceConfiguration(
        provider: .piper,
        language: .english,
        voiceId: "en_US-lessac-medium",
        pitch: 1.0,
        speed: 1.0,
        style: .natural
    )
    
    /// Default Japanese voice for Aria (VOICEVOX - 冥鳴ひまり)
    public static let ariaJapanese = VoiceConfiguration(
        provider: .voicevox,
        language: .japanese,
        voiceId: "mei_himari",
        pitch: 1.0,
        speed: 1.0,
        style: .natural,
        speaker: 14
    )
    
    /// Default Russian voice
    public static let russianDefault = VoiceConfiguration(
        provider: .piper,
        language: .russian,
        voiceId: "ru_RU-govorilka-medium",
        pitch: 1.0,
        speed: 1.0,
        style: .natural
    )
}

/// Voice style for different speech contexts.
public enum VoiceStyle: String, Sendable, CaseIterable {
    case natural = "natural"
    case casual = "casual"
    case warm = "warm"
    case energetic = "energetic"
    case gentle = "gentle"
    case clear = "clear"
    case soft = "soft"
}

/// Result of TTS synthesis.
public struct SynthesisResult: Sendable {
    public let audioFile: URL
    public let duration: TimeInterval
    public let voice: VoiceConfiguration
    public let provider: TTSProvider
    
    public init(audioFile: URL, duration: TimeInterval, voice: VoiceConfiguration, provider: TTSProvider) {
        self.audioFile = audioFile
        self.duration = duration
        self.voice = voice
        self.provider = provider
    }
}

/// TTS-specific errors.
public enum TTSError: Error, Sendable {
    case synthesisFailed(reason: String)
    case voiceUnavailable(voice: VoiceConfiguration)
    case languageNotSupported(language: Language)
    case audioFileCreationFailed
    case externalProcessUnavailable
    case providerUnavailable(provider: TTSProvider)
    case configurationInvalid(reason: String)
}

/// Extension to convert TTSError to AriaError.
extension TTSError {
    func toAriaError() -> AriaError {
        switch self {
        case .synthesisFailed(let reason):
            return .ttsFailure(reason: "TTS synthesis failed: \(reason)")
        case .voiceUnavailable(let voice):
            return .ttsFailure(reason: "Voice unavailable: \(voice.voiceId)")
        case .languageNotSupported(let language):
            return .ttsFailure(reason: "Language not supported: \(language.rawValue)")
        case .audioFileCreationFailed:
            return .ttsFailure(reason: "Failed to create audio file")
        case .externalProcessUnavailable:
            return .ttsFailure(reason: "External TTS process unavailable")
        case .providerUnavailable(let provider):
            return .ttsFailure(reason: "TTS provider unavailable: \(provider.rawValue)")
        case .configurationInvalid(let reason):
            return .ttsFailure(reason: "TTS configuration invalid: \(reason)")
        }
    }
}