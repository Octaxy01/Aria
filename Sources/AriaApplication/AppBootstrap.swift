import Foundation
import AriaDomain
import AriaInfrastructure

/// Bootstrap functions for async application initialization.
/// Handles the asynchronous setup of components that require async initialization
/// (e.g., loading persisted state before the app can start).
public enum AppBootstrap {
    
    /// Creates a configured AssistantCoordinator with persistent relationship state.
    /// This function handles the async initialization of the relationship service
    /// with its persistent store, ensuring the loaded state is available before
    /// the coordinator accepts user input.
    ///
    /// - Parameters:
    ///   - llm: The LLM provider to use
    ///   - logger: The logger for status messages
    ///   - config: The application configuration
    /// - Returns: A fully configured AssistantCoordinator ready for use
    public static func createCoordinator(
        llm: any LLMResponding,
        logger: any Logging,
        config: AppConfiguration
    ) async -> AssistantCoordinator {
        let conversationService = ConversationService()
        
        let emotionEngine: any EmotionEngining = EmotionService()
        
        // Relationship system with persistent storage
        let relationshipStateStore: any RelationshipStateStoring = PersistentRelationshipStore()
        let relationshipEngine = await RelationshipService(stateStore: relationshipStateStore)
        
        // Memory system with persistent storage
        let memoryStore: any MemoryStoring = PersistentMemoryStore()
        let memoryService = MemoryService(store: memoryStore)
        let memoryContextBuilder = MemoryContextBuilder(
            memoryService: memoryService,
            configuration: .default,
            logger: logger
        )
        let memoryFormationService = MemoryFormationService(memoryService: memoryService)
        
        // Get the loaded relationship state for initialization
        let initialRelationshipState = await relationshipEngine.getCurrentState()
        
        logger.info("Relationship state loaded: warmth=\(initialRelationshipState.warmth), familiarity=\(initialRelationshipState.familiarity), interactions=\(initialRelationshipState.interactionCount)")
        
        return AssistantCoordinator(
            llm: llm,
            conversation: conversationService,
            emotionEngine: emotionEngine,
            relationshipEngine: relationshipEngine,
            character: .aria,
            initialRelationshipState: initialRelationshipState,
            memoryContextBuilder: memoryContextBuilder,
            memoryFormationService: memoryFormationService
        )
    }
    
    /// Creates a configured TTS service with language-aware provider selection.
    /// This function initializes the TTS pipeline with the default language settings.
    ///
    /// - Parameters:
    ///   - logger: The logger for status messages
    /// - Returns: A fully configured TextToSpeechService ready for use
    public static func createTTSService(logger: any Logging) async -> TextToSpeechService? {
        // Use default language settings (Japanese output)
        let languageSettings = LanguageSettings.default
        
        // Initialize primary and fallback TTS providers based on language
        let primaryLanguage = languageSettings.effectiveOutputLanguage
        let primaryProviderType = TTSProviderResolver.provider(for: primaryLanguage)
        
        var primaryProvider: (any TextToSpeeching)?
        var fallbackProvider: (any TextToSpeeching)?
        
        switch primaryProviderType {
        case .voicevox:
            // Try VOICEVOX for Japanese
            let voicevox = VoiceVoxTTSService()
            if await voicevox.isAvailable() {
                primaryProvider = voicevox
                logger.info("VOICEVOX TTS provider initialized for Japanese")
                // Fallback to Piper if VOICEVOX fails
                if let piper = try? PiperTTSService() {
                    fallbackProvider = piper
                    logger.info("Piper TTS configured as fallback for Japanese")
                }
            } else {
                // VOICEVOX unavailable, use Piper as primary
                if let piper = try? PiperTTSService() {
                    primaryProvider = piper
                    logger.info("VOICEVOX unavailable, using Piper TTS as primary")
                }
            }
        case .piper:
            // Use Piper for other languages
            if let piper = try? PiperTTSService() {
                primaryProvider = piper
                logger.info("Piper TTS provider initialized")
            }
        default:
            logger.warning("Unsupported TTS provider type: \(primaryProviderType)")
        }
        
        guard let primary = primaryProvider else {
            logger.error("Failed to initialize any TTS provider")
            return nil
        }
        
        return TextToSpeechService(
            primaryProvider: primary,
            fallbackProvider: fallbackProvider,
            languageSettings: languageSettings
        )
    }
    
    /// Creates avatar state manager for avatar state coordination.
    /// - Returns: Configured AvatarStateManager
    public static func createAvatarStateManager() -> AvatarStateManager {
        let manager = AvatarStateManager()
        print("[Live2D] Avatar state manager created")
        return manager
    }
    
    /// Creates TTS service with avatar state manager integration.
    /// - Parameters:
    ///   - logger: The logger for status messages
    ///   - avatarStateManager: Avatar state manager for speaking state coordination
    /// - Returns: A fully configured TextToSpeechService ready for use
    public static func createTTSServiceWithAvatar(
        logger: any Logging,
        avatarStateManager: AvatarStateManager
    ) async -> TextToSpeechService? {
        let ttsService = await createTTSService(logger: logger)
        if let tts = ttsService {
            await tts.setAvatarStateManager(avatarStateManager)
        }
        return ttsService
    }
    
    /// Creates audio playback service with avatar state manager integration.
    /// - Parameters:
    ///   - avatarStateManager: Avatar state manager for speaking state coordination
    /// - Returns: A fully configured AudioPlaybackService ready for use
    public static func createAudioPlaybackService(
        avatarStateManager: AvatarStateManager
    ) async -> AudioPlaybackService {
        let audioPlayer = AudioPlaybackService()
        await audioPlayer.setAvatarStateManager(avatarStateManager)
        return audioPlayer
    }
    
    /// Creates a tool registry with application, filesystem, and system tools registered.
    /// - Returns: A ToolRegistry with application control, filesystem, and system tools registered
    public static func createToolRegistry() async -> ToolRegistry {
        let registry = ToolRegistry()
        
        // Register all application tools
        for toolDefinition in ApplicationToolDefinitions.all {
            do {
                try await registry.register(toolDefinition)
            } catch {
                print("[AppBootstrap] Failed to register tool: \(toolDefinition.identifier.rawValue)")
            }
        }
        
        // Register all filesystem tools
        for toolDefinition in FileSystemToolDefinitions.all {
            do {
                try await registry.register(toolDefinition)
            } catch {
                print("[AppBootstrap] Failed to register tool: \(toolDefinition.identifier.rawValue)")
            }
        }
        
        // Register all system tools
        for toolDefinition in SystemToolDefinitions.all {
            do {
                try await registry.register(toolDefinition)
            } catch {
                print("[AppBootstrap] Failed to register tool: \(toolDefinition.identifier.rawValue)")
            }
        }
        
        return registry
    }
    
    /// Creates an application tool executor with native macOS resolution.
    /// - Returns: A configured ApplicationToolExecutor
    public static func createApplicationToolExecutor() -> ApplicationToolExecutor {
        return ApplicationToolExecutor()
    }
    
    /// Creates a filesystem tool executor with native macOS resolution.
    /// - Returns: A configured FileSystemToolExecutor
    public static func createFileSystemToolExecutor() -> FileSystemToolExecutor {
        return FileSystemToolExecutor()
    }
    
    /// Creates a system tool executor with native macOS APIs.
    /// - Returns: A configured SystemToolExecutor
    public static func createSystemToolExecutor() -> SystemToolExecutor {
        return SystemToolExecutor()
    }
    
    /// Creates a runtime adapter for UI integration.
    /// - Parameter coordinator: The assistant coordinator to bridge to
    /// - Returns: A configured AriaRuntimeAdapter
    @MainActor
    public static func createRuntimeAdapter(coordinator: AssistantCoordinator) -> AriaRuntimeAdapter {
        return AriaRuntimeAdapter(coordinator: coordinator)
    }

}
