import Foundation
import AriaDomain

/// Coordinates TTS synthesis with text sanitization and provider management.
/// Orchestrates the complete TTS pipeline from LLM response to audio file with fallback support.
/// Now includes language-aware provider selection.
public actor TextToSpeechService {
    
    private let primaryProvider: TextToSpeeching
    private let fallbackProvider: TextToSpeeching?
    private let sanitizer = TextSanitizer()
    private let audioPlayer: AudioPlaybackService
    private let languageSettings: LanguageSettings
    private let japaneseTransformer = JapaneseConversationalTransformer(relationshipLevel: .stranger)
    private var japaneseFillerService = JapaneseConversationalFillerService()
    private let japaneseSegmenter = JapaneseTTSSegmenter()
    private let pauseConfiguration = JapaneseTTSPauseConfiguration()
    
    public init(
        primaryProvider: TextToSpeeching,
        fallbackProvider: TextToSpeeching? = nil,
        languageSettings: LanguageSettings = .default
    ) {
        self.primaryProvider = primaryProvider
        self.fallbackProvider = fallbackProvider
        self.languageSettings = languageSettings
        self.audioPlayer = AudioPlaybackService()
    }
    
    /// Sets the avatar state manager for speaking state integration.
    /// - Parameter manager: Avatar state manager to notify of playback state changes
    public func setAvatarStateManager(_ manager: AvatarStateManager) async {
        await audioPlayer.setAvatarStateManager(manager)
    }
    
    /// Synthesizes speech from an LLM response.
    /// Handles text sanitization, style resolution, and TTS engine coordination with fallback.
    public func synthesizeResponse(_ text: String, emotion: EmotionState, relationship: RelationshipState, tone: ConversationTone = .casual) async throws -> URL? {
        // Validate input
        guard !text.isEmpty else { return nil }
        
        // Extract spoken text
        let spokenText = sanitizer.extractSpokenText(text)
        guard !spokenText.isEmpty else { return nil }
        
        // Sanitize for TTS
        var sanitizedText = sanitizer.sanitize(spokenText)
        
        // Apply Japanese conversational transformation if output language is Japanese
        let outputLanguage = languageSettings.effectiveOutputLanguage
        print("[TTS] language=\(outputLanguage.displayName)")
        
        if outputLanguage == .japanese {
            let relationshipLevel = RelationshipLevel.from(familiarity: relationship.familiarity)
            await japaneseTransformer.updateRelationshipLevel(relationshipLevel)
            sanitizedText = await japaneseTransformer.transform(sanitizedText)
            
            // Apply context-aware fillers
            sanitizedText = japaneseFillerService.addFillers(
                sanitizedText,
                tone: tone,
                emotion: emotion,
                relationship: relationship
            )
        }
        
        // Validate sanitized text is not empty after processing
        guard !sanitizedText.isEmpty else {
            print("[TTS] Sanitized text is empty, skipping synthesis")
            return nil
        }
        
        // Check length limits
        if sanitizer.isTooLong(sanitizedText) {
            let truncatedText = sanitizer.truncate(sanitizedText)
            print("[TTS] Text truncated for synthesis")
            return try await synthesize(truncatedText, emotion: emotion, relationship: relationship, tone: tone)
        }
        
        return try await synthesize(sanitizedText, emotion: emotion, relationship: relationship, tone: tone)
    }
    
    /// Synthesizes speech from pre-sanitized text with provider fallback.
    private func synthesize(_ text: String, emotion: EmotionState, relationship: RelationshipState, tone: ConversationTone) async throws -> URL? {
        // Get effective output language
        let outputLanguage = languageSettings.effectiveOutputLanguage
        
        // For Japanese, use segmented synthesis with pauses
        if outputLanguage == .japanese {
            return try await synthesizeSegmentedJapanese(text, emotion: emotion, relationship: relationship, tone: tone)
        }
        
        // For other languages, use normal synthesis
        return try await synthesizeDirect(text, emotion: emotion, relationship: relationship, tone: tone)
    }
    
    /// Synthesizes Japanese text with segmentation and pauses.
    private func synthesizeSegmentedJapanese(_ text: String, emotion: EmotionState, relationship: RelationshipState, tone: ConversationTone) async throws -> URL? {
        // Determine speech style first (needed for both paths)
        let behavior = PersonalityBehaviorResolver.resolve(tone: tone, relationship: relationship, emotion: emotion)
        let relationshipContext = RelationshipContext(from: relationship)
        let style = SpeechStyleResolver.resolve(tone: tone, relationship: relationshipContext, behavior: behavior)
        
        // Segment the text
        let segments = japaneseSegmenter.segment(text)
        
        // If only one segment, use direct synthesis
        if segments.count == 1 {
            return try await synthesizeDirect(text, emotion: emotion, relationship: relationship, tone: tone, style: style)
        }
        
        // Calculate pauses for each segment boundary
        var pauses: [TimeInterval] = []
        for i in 0..<(segments.count - 1) {
            let pause = pauseConfiguration.pauseForSegment(segments[i])
            pauses.append(pause)
        }
        
        // Get voice configuration
        let outputLanguage = languageSettings.effectiveOutputLanguage
        let ttsLanguage = outputLanguage.toTTSLanguage
        let voice = mapStyleToVoice(style, language: ttsLanguage)
        
        // Try primary provider with segmented synthesis with timeout
        if await primaryProvider.isAvailable() {
            do {
                let result = try await withTimeout(seconds: 30) { [self] in
                    try await primaryProvider.synthesizeSegmented(
                        segments: segments,
                        pauses: pauses,
                        language: voice.language,
                        voice: voice,
                        style: style
                    )
                }
                if let result = result {
                    return result
                }
            } catch {
                print("Primary provider segmented synthesis failed: \(error), trying fallback")
            }
        }
        
        // Try fallback provider if available
        if let fallback = fallbackProvider, await fallback.isAvailable() {
            return try await synthesizeDirect(text, emotion: emotion, relationship: relationship, tone: tone, style: style)
        }
        
        throw TTSError.providerUnavailable(provider: .voicevox)
    }
    
    /// Direct synthesis without segmentation (for non-Japanese or fallback).
    private func synthesizeDirect(_ text: String, emotion: EmotionState, relationship: RelationshipState, tone: ConversationTone, style: SpeechStyle? = nil) async throws -> URL? {
        // Determine speech style using existing resolver (if not provided)
        let resolvedStyle: SpeechStyle
        if let providedStyle = style {
            resolvedStyle = providedStyle
        } else {
            let behavior = PersonalityBehaviorResolver.resolve(tone: tone, relationship: relationship, emotion: emotion)
            let relationshipContext = RelationshipContext(from: relationship)
            resolvedStyle = SpeechStyleResolver.resolve(tone: tone, relationship: relationshipContext, behavior: behavior)
        }
        
        // Get effective output language from settings
        let outputLanguage = languageSettings.effectiveOutputLanguage
        let ttsLanguage = outputLanguage.toTTSLanguage
        
        // Map style to voice configuration using language-aware selection
        let voice = mapStyleToVoice(resolvedStyle, language: ttsLanguage)
        
        // Try primary provider first with timeout
        if await primaryProvider.isAvailable() {
            print("[TTS] provider=\(primaryProvider.providerName)")
            do {
                let result = try await withTimeout(seconds: 30) { [self] in
                    try await primaryProvider.synthesize(text: text, language: voice.language, voice: voice, style: resolvedStyle)
                }
                if let result = result {
                    return result
                }
            } catch {
                // Primary provider failed, try fallback
                print("[TTS] primary provider failed: \(error), trying fallback")
            }
        }
        
        // Try fallback provider if available
        if let fallback = fallbackProvider, await fallback.isAvailable() {
            print("[TTS] provider=\(fallback.providerName)")
            let fallbackVoice = mapStyleToVoice(resolvedStyle, language: ttsLanguage, useFallback: true)
            return try await fallback.synthesize(text: text, language: fallbackVoice.language, voice: fallbackVoice, style: resolvedStyle)
        }
        
        // Both providers failed
        throw TTSError.providerUnavailable(provider: .piper)
    }
    
    /// Maps speech style to voice configuration with style-aware parameters.
    private func mapStyleToVoice(_ style: SpeechStyle, language: Language, useFallback: Bool = false) -> VoiceConfiguration {
        let baseVoice: VoiceConfiguration
        
        // Select base voice based on language
        if language == .japanese {
            baseVoice = VoiceConfiguration.ariaJapanese
        } else if language == .indonesian {
            baseVoice = useFallback ? VoiceConfiguration.indonesianFallback : VoiceConfiguration.ariaIndonesian
        } else if language == .english {
            baseVoice = VoiceConfiguration.englishDefault
        } else if language == .russian {
            baseVoice = VoiceConfiguration.russianDefault
        } else {
            baseVoice = VoiceConfiguration.englishDefault // Default fallback
        }
        
        // Map SpeechStyle to VoiceStyle only
        // Emotional prosody is now handled by VoiceVoxTTSService.applySpeechStyle()
        let voiceStyle: VoiceStyle
        
        if style.emotionalExpressionLevel > 0.7 {
            voiceStyle = .warm
        } else if style.reactionBeforeAnswer {
            voiceStyle = .energetic
        } else if style.avoidFormalLanguage {
            voiceStyle = .casual
        } else {
            voiceStyle = .natural
        }
        
        return VoiceConfiguration(
            provider: baseVoice.provider,
            language: language,
            voiceId: baseVoice.voiceId,
            pitch: baseVoice.pitch,
            speed: baseVoice.speed,
            style: voiceStyle,
            speaker: baseVoice.speaker
        )
    }
    
    /// Plays the synthesized audio file.
    public func playAudio(_ audioFile: URL) async throws {
        try await audioPlayer.play(audioFile)
    }
    
    /// Stops current audio playback.
    public func stopAudio() async {
        await audioPlayer.stop()
    }
    
    /// Stops current speech playback with guaranteed avatar cleanup.
    /// This is the main method for stopping voice output.
    public func stopCurrentSpeech() async {
        print("[TTS] Stopping current speech")
        await primaryProvider.cancel()
        await fallbackProvider?.cancel()
        await audioPlayer.stop()
    }
    
    /// Sets the mute state for audio playback.
    /// - Parameter muted: Whether audio should be muted
    public func setMuted(_ muted: Bool) async {
        await audioPlayer.setMuted(muted)
    }
    
    /// Gets the current mute state.
    public var isMuted: Bool {
        get async {
            return await audioPlayer.muted
        }
    }
    
    /// Cancels any ongoing synthesis and stops audio.
    public func cancel() async {
        await primaryProvider.cancel()
        await fallbackProvider?.cancel()
        await audioPlayer.stop()
    }
    
    /// Checks if TTS is available for the given language.
    public func isAvailable(language: Language) async -> Bool {
        let primaryAvailable = await primaryProvider.isAvailable()
        let fallbackAvailable = fallbackProvider != nil ? await fallbackProvider!.isAvailable() : false
        return primaryAvailable || fallbackAvailable
    }
    
    /// Gets the currently active provider name.
    public var activeProvider: String {
        get async {
            if await primaryProvider.isAvailable() {
                return primaryProvider.providerName
            } else if let fallback = fallbackProvider, await fallback.isAvailable() {
                return fallback.providerName
            } else {
                return "none"
            }
        }
    }
    
    /// Ensures avatar returns to idle state (for error recovery).
    /// This should be called when audio playback fails or is interrupted.
    public func ensureAvatarIdle() async {
        await audioPlayer.ensureAvatarIdle()
    }
    
    /// Helper function to add timeout to async operations
    private func withTimeout<T>(seconds: TimeInterval, operation: @escaping () async throws -> T) async throws -> T {
        try await withThrowingTaskGroup(of: T.self) { group in
            group.addTask {
                try await operation()
            }
            
            group.addTask {
                try await Task.sleep(nanoseconds: UInt64(seconds * 1_000_000_000))
                throw TTSError.synthesisFailed(reason: "Operation timed out after \(seconds) seconds")
            }
            
            guard let result = try await group.next() else {
                // Ensure avatar returns to idle on timeout
                await ensureAvatarIdle()
                throw TTSError.synthesisFailed(reason: "Operation completed without result")
            }
            
            group.cancelAll()
            return result
        }
    }
}