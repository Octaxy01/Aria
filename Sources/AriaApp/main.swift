import Foundation
import AppKit
import AriaDomain
import AriaApplication
import AriaInfrastructure
import AriaPresentation

// Check for console mode
let consoleMode = CommandLine.arguments.contains("--console")

// Check for Live2D-only test mode - this must be checked before console mode
// Accept both --live2d-test and live2d-test for convenience
let live2DTestMode = CommandLine.arguments.contains("--live2d-test") || CommandLine.arguments.contains("live2d-test")

NSLog("=== ARIA STARTUP ===")
NSLog("consoleMode: \(consoleMode)")
NSLog("live2DTestMode: \(live2DTestMode)")
NSLog("CommandLine.arguments: \(CommandLine.arguments)")

// Exit immediately for test mode - don't load anything else
if live2DTestMode {
    NSLog("[Live2D] TEST MODE - Setting up NSApplication")
    let app = NSApplication.shared
    app.setActivationPolicy(.regular)
    
    NSLog("[Live2D] TEST MODE - Creating avatar")
    Task { @MainActor in
        let avatar = Live2DAvatarRenderer()
        avatar.showWindow()
        
        NSLog("[Live2D] TEST MODE - Window shown")
        NSLog("[Live2D] TEST MODE - Running event loop")
        
        app.run()
    }
    
    // Keep main thread alive
    RunLoop.current.run()
}

// If not console mode, let SwiftUI app handle it
if !consoleMode {
    // SwiftUI app will take over via @main in AriaDesktopApp
    // We just need to set up NSApplication properly
    let app = NSApplication.shared
    app.setActivationPolicy(.regular)
    app.run()
} else {
    // Console mode - run existing console runtime
    let config = AppConfiguration.load()
    
    let logger: any Logging =
        ConsoleLogger(minimumLevel: config.logLevel)
    
    logger.info("Aria starting (Stage 2 — conversation core)")
    logger.info("Running in console mode")
    
    Task {
        await runConsoleRuntime(config: config, logger: logger)
        exit(0)
    }
    
    // Keep the main thread alive
    RunLoop.current.run()
}

// MARK: - Console Runtime

@MainActor
func runConsoleRuntime(config: AppConfiguration, logger: any Logging) async {
    print("[Live2D] About to create Live2DAvatarRenderer")

    // Initialize avatar early (will show even if API fails)
    let avatar: any AvatarRendering =
        Live2DAvatarRenderer()

    print("[Live2D] Live2DAvatarRenderer created")

    // Show Live2D window immediately
    print("[Live2D] About to show window")

    if let live2DAvatar = avatar as? Live2DAvatarRenderer {
        live2DAvatar.showWindow()
    }

    print("[Live2D] Window show dispatched")

    let openRouterConfiguration: OpenRouterConfiguration

    do {
        openRouterConfiguration = try OpenRouterConfiguration.make(
            apiKey: config.openRouterAPIKey,
            model: config.openRouterModel,
            temperature: config.openRouterTemperature,
            timeout: config.openRouterRequestTimeoutSeconds
        )
    } catch {
        logger.error(
            "Startup failed: \(error). Set OPENROUTER_API_KEY and try again."
        )
        logger.error(
            "Example: OPENROUTER_API_KEY=\"...\" swift run AriaApp"
        )
        logger.info("Note: Live2D window should still be visible for testing")
        logger.info("For Live2D-only testing, use: swift run AriaApp --live2d-test")
        // Don't exit - let Live2D window stay open for testing
        // Keep the app running with a minimal console loop
        print("Live2D window test mode. Type 'exit' to quit.")
        while true {
            print("Test: ", terminator: "")
            guard let line = readLine(strippingNewline: true) else { break }
            if line.trimmingCharacters(in: .whitespaces).lowercased() == "exit" {
                break
            }
        }
        exit(1)
    }

    let llmProvider: any LLMResponding =
        OpenRouterProvider(
            configuration: openRouterConfiguration,
            logger: logger
        )

    // Use async bootstrap to initialize coordinator with persistent relationship state
    let coordinator = await AppBootstrap.createCoordinator(
        llm: llmProvider,
        logger: logger,
        config: config
    )

    // Initialize avatar state manager
    let avatarStateManager = AppBootstrap.createAvatarStateManager()

    // Connect avatar state manager to coordinator
    await coordinator.setAvatarStateManager(avatarStateManager)

    // Initialize audio playback service for status reporting
    let audioPlayer = await AppBootstrap.createAudioPlaybackService(avatarStateManager: avatarStateManager)

    // Initialize TTS service with avatar state manager integration
    let ttsService = await AppBootstrap.createTTSServiceWithAvatar(
        logger: logger,
        avatarStateManager: avatarStateManager
    )

    let ui: any DesktopUIRendering =
        ConsoleUIRenderer()

    print(
        "Aria (Stage 2 — console conversation core, OpenRouter-backed). Type a message and press Enter. Type 'exit' to quit."
    )

    print(
        "Commands: 'help', 'status', 'mute', 'unmute', 'stop', 'clear', 'exit'.\n"
    )

    print(
        "Note: OpenRouter free models with automatic fallback enabled.\n"
    )

    while true {
        print("You: ", terminator: "")

        guard let line = readLine(strippingNewline: true) else {
            break
        }

        let trimmedLine = line.trimmingCharacters(in: .whitespaces)
        let lowercasedLine = trimmedLine.lowercased()

        if lowercasedLine == "exit" {
            break
        }
        
        // Handle help command
        if lowercasedLine == "help" {
            print("Available commands:")
            print("  help    - Show this help message")
            print("  status  - Show current runtime status")
            print("  mute    - Toggle voice mute")
            print("  unmute  - Unmute voice")
            print("  stop    - Stop current speech")
            print("  clear   - Clear conversation history")
            print("  exit    - Exit the application")
            continue
        }
        
        // Handle status command
        if lowercasedLine == "status" {
            let runtimeStatus = await coordinator.getRuntimeStatus()
            print("ARIA STATUS")
            print("-----------")
            print("Conversation: \(runtimeStatus.conversationState)")
            print("Avatar: \(runtimeStatus.avatarState)")
            print("Active Request: \(runtimeStatus.hasActiveRequest ? "Yes" : "No")")
            
            let isMuted = await audioPlayer.muted
            let isPlaying = await audioPlayer.currentlyPlaying
            print("Audio: \(isPlaying ? "Playing" : "Idle")")
            print("Muted: \(isMuted ? "Yes" : "No")")
            continue
        }
        
        // Handle clear command
        if lowercasedLine == "clear" {
            await coordinator.clearConversation()
            // Also stop any ongoing audio
            if let tts = ttsService {
                await tts.stopCurrentSpeech()
            }
            print("Conversation cleared")
            continue
        }
        
        // Handle mute command
        if lowercasedLine == "mute" {
            if let tts = ttsService {
                let currentMuted = await tts.isMuted
                await tts.setMuted(!currentMuted)
                let newState = await tts.isMuted
                print(newState ? "Voice muted" : "Voice unmuted")
            } else {
                print("TTS service not available")
            }
            continue
        }
        
        // Handle unmute command
        if lowercasedLine == "unmute" {
            if let tts = ttsService {
                await tts.setMuted(false)
                print("Voice unmuted")
            } else {
                print("TTS service not available")
            }
            continue
        }
        
        // Handle stop command
        if lowercasedLine == "stop" {
            if let tts = ttsService {
                await tts.stopCurrentSpeech()
                print("Speech stopped")
            } else {
                print("TTS service not available")
            }
            continue
        }

        guard !trimmedLine.isEmpty else {
            continue
        }

        do {
            let turn =
                try await coordinator.handleUserInput(line)

            avatar.update(emotion: turn.emotionState)

            ui.present(
                turn: AssistantTurnResultDisplay(
                    replyText: turn.reply.content,
                    emotion: turn.emotionState,
                    relationshipState: turn.relationshipState
                )
            )
            
            // Synthesize and play audio if TTS service is available
            if let tts = ttsService {
                do {
                    // Stop any existing audio playback to prevent overlap
                    await tts.stopCurrentSpeech()
                    
                    // Get the conversation tone for filler context
                    let tone = ConversationToneClassifier.classify(line)
                    
                    logger.info("[TTS] synthesis started")
                    
                    if let audioFile = try await tts.synthesizeResponse(
                        turn.reply.content,
                        emotion: turn.emotionState,
                        relationship: turn.relationshipState,
                        tone: tone
                    ) {
                        logger.info("[TTS] synthesis completed")
                        logger.info("[Audio] playback started")
                        logger.info("[Avatar] state=talking")
                        
                        try await tts.playAudio(audioFile)
                        
                        logger.info("[Audio] playback completed")
                        logger.info("[Avatar] state=idle")
                    }
                } catch {
                    logger.warning("[TTS] provider failed: \(error)")
                    logger.warning("[Avatar] recovering to idle")
                    // Ensure avatar returns to idle state on TTS failure
                    await tts.ensureAvatarIdle()
                }
            }
        } catch {
            logger.error(
                "Failed to handle input: \(error)"
            )
        }
    }

    logger.info("Aria shutting down")
}