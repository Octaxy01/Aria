import AriaDomain
import AriaInfrastructure
import Foundation

/// Result of handling one user turn: what Aria says, and what her
/// resulting emotional and relationship state are. Presentation reads
/// this — it never talks to the LLM, emotion engine, or relationship
/// engine directly.
public struct AssistantTurnResult: Sendable, Equatable {
    public let reply: ConversationMessage
    public let emotionState: EmotionState
    public let relationshipState: RelationshipState

    public init(reply: ConversationMessage, emotionState: EmotionState, relationshipState: RelationshipState) {
        self.reply = reply
        self.emotionState = emotionState
        self.relationshipState = relationshipState
    }
}

/// The single orchestration point for "user said something, what happens
/// next". This is where Presentation, LLM, conversation history, emotion,
/// and (Stage 3) session relationship state meet — deliberately kept
/// thin. It does not know which LLM provider is in use, does not know how
/// emotion/relationship state is computed, and does not know how (or
/// whether) anything gets rendered on screen.
public actor AssistantCoordinator {
    private let llm: any LLMResponding
    private let conversation: ConversationService
    private let emotionEngine: any EmotionEngining
    private let relationshipEngine: any RelationshipEvolving
    private let character: CharacterProfile
    private let maxContextMessages: Int
    private let memoryContextBuilder: MemoryContextBuilder?
    private let memoryFormationService: MemoryFormationService?
    private let toolOrchestrator: ToolOrchestrator?
    private let toolRegistry: ToolRegistry?
    private let toolDiscovery: ToolDiscovery?
    private let entityContext: RuntimeEntityContext?
    private let referenceResolver: ReferenceResolver?
    private let clarificationManager: ClarificationManager?
    private let clarificationAnswerParser: ClarificationAnswerParser?
    private let resultInterpreter: ToolResultInterpreter?
    private let taskContextManager: TaskContextManager?
    private let maxToolRounds: Int
    private let confirmationAnswerParser: ConfirmationAnswerParser
    private let intentHistory: IntentHistory

    /// Rendered once at init, not on every turn — core personality
    /// doesn't change mid-session. Per-turn relationship context is
    /// layered on top of this fresh each turn instead (see
    /// `handleUserInput`), since that DOES change as the session goes on.
    private let basePrompt: String

    private var emotionState: EmotionState
    private var relationshipState: RelationshipState
    private var languageSettings: LanguageSettings
    
    /// Tracks the current active request to prevent overlapping conversations
    private var currentRequestTask: Task<Void, Never>?
    
    /// Tracks the current request ID for stale response validation
    private var currentRequestID: UUID?
    
    /// Avatar state manager for visual state integration
    private var avatarStateManager: AvatarStateManager?
    
    /// Continuation for runtime event stream
    private var eventContinuation: AsyncStream<AriaRuntimeEvent>.Continuation?

    public init(
        llm: any LLMResponding,
        conversation: ConversationService,
        emotionEngine: any EmotionEngining,
        relationshipEngine: any RelationshipEvolving,
        character: CharacterProfile = .aria,
        maxContextMessages: Int = 20,
        initialEmotionState: EmotionState = .initial,
        initialRelationshipState: RelationshipState = .initial,
        memoryContextBuilder: MemoryContextBuilder? = nil,
        memoryFormationService: MemoryFormationService? = nil,
        languageSettings: LanguageSettings = .default,
        toolOrchestrator: ToolOrchestrator? = nil,
        toolRegistry: ToolRegistry? = nil,
        entityContext: RuntimeEntityContext? = nil,
        referenceResolver: ReferenceResolver? = nil,
        clarificationManager: ClarificationManager? = nil,
        clarificationAnswerParser: ClarificationAnswerParser? = nil,
        resultInterpreter: ToolResultInterpreter? = nil,
        taskContextManager: TaskContextManager? = nil,
        maxToolRounds: Int = 4
    ) {
        self.llm = llm
        self.conversation = conversation
        self.emotionEngine = emotionEngine
        self.relationshipEngine = relationshipEngine
        self.character = character
        self.maxContextMessages = maxContextMessages
        self.maxToolRounds = maxToolRounds
        self.memoryContextBuilder = memoryContextBuilder
        self.memoryFormationService = memoryFormationService
        self.languageSettings = languageSettings
        self.toolOrchestrator = toolOrchestrator
        self.toolRegistry = toolRegistry
        self.toolDiscovery = toolRegistry != nil ? ToolDiscovery(toolRegistry: toolRegistry!) : nil
        self.entityContext = entityContext
        self.referenceResolver = referenceResolver
        self.clarificationManager = clarificationManager
        self.clarificationAnswerParser = clarificationAnswerParser
        self.resultInterpreter = resultInterpreter
        self.taskContextManager = taskContextManager
        self.confirmationAnswerParser = ConfirmationAnswerParser()
        self.intentHistory = IntentHistory()
        self.basePrompt = SystemPromptBuilder.build(for: character)
        self.emotionState = initialEmotionState
        self.relationshipState = initialRelationshipState
    }
    
    /// Sets the avatar state manager for conversation state integration.
    /// - Parameter manager: Avatar state manager to notify of conversation state changes
    public func setAvatarStateManager(_ manager: AvatarStateManager) async {
        self.avatarStateManager = manager
    }
    
    /// Sets the event publisher for tool orchestration events.
    /// - Parameter publisher: Callback to publish runtime events from tool orchestration
    public func setToolEventPublisher(_ publisher: @escaping (AriaRuntimeEvent) -> Void) async {
        if let toolOrchestrator = toolOrchestrator {
            await toolOrchestrator.setEventPublisher(publisher)
        }
    }
    
    /// Cancels the current request.
    public func cancelCurrentRequest() async {
        currentRequestTask?.cancel()
        currentRequestID = nil
        
        // Return avatar to idle
        if let manager = avatarStateManager {
            try? await manager.transitionToIdle()
        }
    }
    
    /// Returns the current conversation history.
    /// - Returns: Array of conversation messages
    public func getConversation() async -> [ConversationMessage] {
        return await conversation.history()
    }
    
    /// Provides a stream of runtime events for UI observation.
    /// - Returns: An AsyncStream of AriaRuntimeEvent
    public func runtimeEvents() -> AsyncStream<AriaRuntimeEvent> {
        AsyncStream { continuation in
            self.eventContinuation = continuation
        }
    }
    
    /// Publishes a runtime event to the event stream.
    /// - Parameter event: The event to publish
    private func publishEvent(_ event: AriaRuntimeEvent) {
        eventContinuation?.yield(event)
    }

    public func handleUserInput(_ text: String) async throws -> AssistantTurnResult {
        print("[Conversation] input received: \(text.prefix(50))...")
        
        // Cancel any ongoing request to prevent overlapping conversations
        currentRequestTask?.cancel()
        
        // Generate unique request ID for this conversation turn
        let requestID = UUID()
        currentRequestID = requestID
        print("[Conversation] Request ID: \(requestID)")
        
        // Publish request started event
        publishEvent(.requestStarted(sessionID: requestID))
        
        // Transition avatar to thinking state
        if let manager = avatarStateManager {
            try? await manager.transitionToThinking()
        }
        
        // Create a new task for this request
        let currentTask = Task<Void, Never> {
            // Task body will be executed below
        }
        currentRequestTask = currentTask
        
        // Check if this task was cancelled before starting
        try Task.checkCancellation()
        
        // Validate this request is still active (user may have sent another input)
        guard currentRequestID == requestID else {
            print("[Conversation] Request \(requestID) was invalidated by newer request")
            // Publish cancellation event
            publishEvent(.requestCancelled(sessionID: requestID))
            // Return avatar to idle since this request is stale
            if let manager = avatarStateManager {
                try? await manager.transitionToIdle()
            }
            throw AriaError.invalidState(reason: "Request was superseded by newer input")
        }
        
        // Set session ID in intent history
        await intentHistory.setSessionID(requestID)
        
        // Check if this is a clarification answer
        if let clarificationManager = clarificationManager,
           let clarificationAnswerParser = clarificationAnswerParser,
           let pendingClarification = await clarificationManager.getPendingClarification(sessionID: requestID) {
            print("[Conversation] Processing clarification answer")
            
            let answer = clarificationAnswerParser.parseAnswer(text, clarification: pendingClarification)
            
            switch answer {
            case .cancelled:
                print("[Conversation] User cancelled clarification")
                await clarificationManager.clearClarification(sessionID: requestID)
                
                // Publish clarification resolved event
                publishEvent(.clarificationResolved(sessionID: requestID))
                
                // Return to idle and provide cancellation message
                if let manager = avatarStateManager {
                    try? await manager.transitionToIdle()
                }
                
                let cancelMessage = await conversation.append(role: .assistant, content: "Oke, tidak apa-apa.")
                let cancelEmotion = EmotionSignal(emotion: .neutral, intensity: 0.3)
                emotionState = emotionEngine.nextState(current: emotionState, signal: cancelEmotion)
                relationshipState = await relationshipEngine.nextState(
                    current: relationshipState,
                    tone: .casual,
                    emotionSignal: cancelEmotion
                )
                
                currentRequestID = nil
                return AssistantTurnResult(
                    reply: cancelMessage,
                    emotionState: emotionState,
                    relationshipState: relationshipState
                )
                
            case .invalid:
                print("[Conversation] Invalid clarification answer")
                let invalidMessage = await conversation.append(role: .assistant, content: "Maaf, saya tidak mengerti. Pilih nomor atau nama dari daftar.")
                
                let invalidEmotion = EmotionSignal(emotion: .neutral, intensity: 0.4)
                emotionState = emotionEngine.nextState(current: emotionState, signal: invalidEmotion)
                relationshipState = await relationshipEngine.nextState(
                    current: relationshipState,
                    tone: .casual,
                    emotionSignal: invalidEmotion
                )
                
                if let manager = avatarStateManager {
                    try? await manager.transitionToIdle()
                }
                
                currentRequestID = nil
                return AssistantTurnResult(
                    reply: invalidMessage,
                    emotionState: emotionState,
                    relationshipState: relationshipState
                )
                
            case .selectedPosition(let position):
                print("[Conversation] User selected position: \(position)")
                guard position <= pendingClarification.candidates.count else {
                    print("[Conversation] Invalid position: \(position)")
                    let invalidPosMessage = await conversation.append(role: .assistant, content: "Nomor tidak valid. Pilih nomor dari daftar.")
                    
                    let invalidPosEmotion = EmotionSignal(emotion: .neutral, intensity: 0.4)
                    emotionState = emotionEngine.nextState(current: emotionState, signal: invalidPosEmotion)
                    relationshipState = await relationshipEngine.nextState(
                        current: relationshipState,
                        tone: .casual,
                        emotionSignal: invalidPosEmotion
                    )
                    
                    if let manager = avatarStateManager {
                        try? await manager.transitionToIdle()
                    }
                    
                    currentRequestID = nil
                    return AssistantTurnResult(
                        reply: invalidPosMessage,
                        emotionState: emotionState,
                        relationshipState: relationshipState
                    )
                }
                
                let selectedEntity = pendingClarification.candidates[position - 1]
                await clarificationManager.clearClarification(sessionID: requestID)
                
                // Publish clarification resolved event
                publishEvent(.clarificationResolved(sessionID: requestID))
                
                return try await continueWithResolvedEntity(selectedEntity, pendingClarification: pendingClarification, requestID: requestID, text: text)
                
            case .selectedEntity(let entity):
                print("[Conversation] User selected entity: \(entity.displayName)")
                await clarificationManager.clearClarification(sessionID: requestID)
                
                // Publish clarification resolved event
                publishEvent(.clarificationResolved(sessionID: requestID))
                
                return try await continueWithResolvedEntity(entity, pendingClarification: pendingClarification, requestID: requestID, text: text)
            }
        }
        
        // Check if this is a confirmation answer
        if let toolOrchestrator = toolOrchestrator {
            let answer = confirmationAnswerParser.parse(text)
            if confirmationAnswerParser.isConfirmationAnswer(text) {
                print("[Conversation] Processing confirmation answer")
                
                do {
                    let response = try await toolOrchestrator.resolveConfirmation(
                        answer: answer,
                        sessionID: requestID,
                        conversation: conversation
                    )
                    
                    // Publish confirmation resolved event
                    publishEvent(.confirmationResolved(sessionID: requestID))
                    
                    // Return avatar to idle
                    if let manager = avatarStateManager {
                        try? await manager.transitionToIdle()
                    }
                    
                    let confirmMessage = await conversation.append(role: .assistant, content: response.text)
                    let confirmEmotion = EmotionSignal(emotion: .neutral, intensity: 0.3)
                    emotionState = emotionEngine.nextState(current: emotionState, signal: confirmEmotion)
                    relationshipState = await relationshipEngine.nextState(
                        current: relationshipState,
                        tone: .casual,
                        emotionSignal: confirmEmotion
                    )
                    
                    currentRequestID = nil
                    return AssistantTurnResult(
                        reply: confirmMessage,
                        emotionState: emotionState,
                        relationshipState: relationshipState
                    )
                } catch {
                    // If confirmation resolution fails, cancel and continue as normal
                    print("[Conversation] Confirmation resolution failed: \(error)")
                    await toolOrchestrator.cancelConfirmation()
                    
                    // Publish confirmation resolved event (cancelled)
                    publishEvent(.confirmationResolved(sessionID: requestID))
                    
                    // Return to idle
                    if let manager = avatarStateManager {
                        try? await manager.transitionToIdle()
                    }
                    
                    // Continue processing as normal conversation
                }
            } else {
                // Not a confirmation answer, cancel any pending confirmation
                await toolOrchestrator.cancelConfirmation()
            }
        }
        
        await conversation.append(role: .user, content: text)

        // Detect input language
        let detectedLanguage = LanguageDetector.detect(text)
        print("[Conversation] language=\(detectedLanguage.displayName)")
        
        // Check for explicit language override requests
        if let overrideLanguage = LanguageDetector.detectLanguageOverride(text) {
            languageSettings.setConversationOverride(overrideLanguage)
            print("[Conversation] language override to=\(overrideLanguage.displayName)")
        }
        
        let tone = ConversationToneClassifier.classify(text)
        print("[Conversation] tone=\(tone.rawValue)")
        
        // Get conversation history with smarter context strategy
        // Priority: Current message → Recent conversation → Relevant memory → Older context
        let recentHistory = await conversation.recentHistory(maxMessages: maxContextMessages)

        // Resolve personality behavior for this turn
        let behavior = PersonalityBehaviorResolver.resolve(
            tone: tone,
            relationship: relationshipState,
            emotion: emotionState
        )
        
        // Resolve relationship context
        let relationshipContext = RelationshipContext(
            level: RelationshipLevel.from(familiarity: relationshipState.familiarity),
            warmth: relationshipState.warmth,
            familiarity: relationshipState.familiarity,
            interactionCount: relationshipState.interactionCount,
            behavioralDescription: ""
        )
        
        // Resolve speech style
        let speechStyle = SpeechStyleResolver.resolve(
            tone: tone,
            relationship: relationshipContext,
            behavior: behavior
        )
        
        // Build relationship context
        let sessionContext = SystemPromptBuilder.relationshipContext(for: relationshipState, tone: tone)
        
        // Build behavior context (ACTIONABLE personality instructions)
        let behaviorContext = SystemPromptBuilder.behaviorContext(for: behavior)
        
        // Build speech style context (concrete speaking instructions)
        let speechStyleContext = SystemPromptBuilder.speechStyleContext(for: speechStyle)
        
        // Build relationship depth context (how close to behave)
        let relationshipDepthContext = SystemPromptBuilder.relationshipDepthContext(for: relationshipContext)
        
        // Build language policy context
        let languagePolicyContext = SystemPromptBuilder.languagePolicyContext(
            for: languageSettings,
            detectedInputLanguage: detectedLanguage
        )
        
        // Build memory context if memory service is available
        var memoryContext = ""
        if let memoryBuilder = memoryContextBuilder {
            let relationshipLevel = RelationshipLevel.from(familiarity: relationshipState.familiarity)
            let rawMemoryContext = await memoryBuilder.buildContext(for: text, relationshipLevel: relationshipLevel)
            memoryContext = SystemPromptBuilder.memoryContext(for: rawMemoryContext)
            print("[Conversation] memoryContext=\(!memoryContext.isEmpty)")
        }
        
        // Combine all context sections in priority order
        var turnContext = basePrompt + "\n\n" + sessionContext
        turnContext += "\n\n" + languagePolicyContext
        turnContext += "\n\n" + behaviorContext
        turnContext += "\n\n" + speechStyleContext
        turnContext += "\n\n" + relationshipDepthContext
        if !memoryContext.isEmpty {
            turnContext += "\n\n" + memoryContext
        }
        
        // Get tool definitions if tool orchestration is available
        // Use ToolDiscovery for intent-based filtering
        var toolDefinitions: [ToolDefinition]? = nil
        if let toolDiscovery = toolDiscovery {
            toolDefinitions = await toolDiscovery.tools(relevantTo: text)
            print("[Conversation] toolDefinitions=\(toolDefinitions?.count ?? 0) (intent-based)")
        } else if let toolRegistry = toolRegistry {
            // Fallback to all tools if discovery not available
            toolDefinitions = await toolRegistry.allTools()
            print("[Conversation] toolDefinitions=\(toolDefinitions?.count ?? 0) (all tools)")
        }
        
        let request = LLMRequest(messages: recentHistory, systemContext: turnContext, toolDefinitions: toolDefinitions)

        print("[Conversation] LLM request started")
        let response: LLMResponse
        do {
            response = try await llm.respond(to: request)
            print("[Conversation] LLM response received")
        } catch {
            // Check if cancellation was the cause
            if Task.isCancelled {
                print("[Conversation] LLM failed: Request cancelled")
                // Publish cancellation event
                publishEvent(.requestCancelled(sessionID: requestID))
                // Ensure avatar returns to idle
                if let manager = avatarStateManager {
                    try? await manager.transitionToIdle()
                }
                throw AriaError.llmProviderFailure(reason: "Request cancelled")
            }
            
            // On LLM failure, keep the user message and add fallback assistant message
            print("[Conversation] LLM failed: \(error)")
            
            // Publish failure event
            publishEvent(.requestFailed(sessionID: requestID, error: error.localizedDescription))
            
            // Ensure avatar returns to idle on LLM failure
            if let manager = avatarStateManager {
                try? await manager.transitionToIdle()
            }
            
            // Instead of throwing, return a graceful fallback response
            let currentLanguage = languageSettings.effectiveOutputLanguage
            let fallbackResponse = generateFallbackResponse(for: currentLanguage, error: error)
            let fallbackMessage = await conversation.append(role: .assistant, content: fallbackResponse.text)
            
            // Use neutral emotion for fallback responses
            let fallbackEmotion = EmotionSignal(emotion: .neutral, intensity: 0.3)
            emotionState = emotionEngine.nextState(current: emotionState, signal: fallbackEmotion)
            relationshipState = await relationshipEngine.nextState(
                current: relationshipState,
                tone: tone,
                emotionSignal: fallbackEmotion
            )

            // Process memory formation asynchronously
            if let memoryFormation = memoryFormationService {
                print("[Conversation] memory formation scheduled")
                Task {
                    await memoryFormation.processUserMessage(text)
                }
            }

            // Clear the request ID after fallback (LLM failure case)
            currentRequestID = nil

            return AssistantTurnResult(
                reply: fallbackMessage,
                emotionState: emotionState,
                relationshipState: relationshipState
            )
        }
        
        // Validate this request is still active (user may have sent another input during LLM processing)
        guard currentRequestID == requestID else {
            print("[Conversation] Request \(requestID) was invalidated during LLM processing")
            // Return avatar to idle since this request is stale
            if let manager = avatarStateManager {
                try? await manager.transitionToIdle()
            }
            // Return a graceful response indicating the request was cancelled
            let currentLanguage = languageSettings.effectiveOutputLanguage
            let staleResponse = generateFallbackResponse(for: currentLanguage)
            let staleMessage = await conversation.append(role: .assistant, content: staleResponse.text)
            
            // Use neutral emotion for stale responses
            let staleEmotion = EmotionSignal(emotion: .neutral, intensity: 0.3)
            emotionState = emotionEngine.nextState(current: emotionState, signal: staleEmotion)
            relationshipState = await relationshipEngine.nextState(
                current: relationshipState,
                tone: tone,
                emotionSignal: staleEmotion
            )

            return AssistantTurnResult(
                reply: staleMessage,
                emotionState: emotionState,
                relationshipState: relationshipState
            )
        }

        // Process tool calls with multi-round LLM continuation
        let finalResponse: LLMResponse
        if let toolOrchestrator = toolOrchestrator {
            finalResponse = try await executeToolLoop(
                initialResponse: response,
                requestID: requestID,
                toolOrchestrator: toolOrchestrator
            )
        } else {
            finalResponse = response
        }

        // Clear the request ID after tool orchestration
        currentRequestID = nil
        
        // Publish request completed event
        publishEvent(.requestCompleted(sessionID: requestID))

        // Validate response text before processing
        let validatedText = validateResponseText(finalResponse.text)
        print("[Conversation] response validated")
        
        // Additional response quality guard
        let qualityGuardedText = guardResponseQuality(validatedText)
        
        // If validation fails (empty/whitespace only), provide graceful fallback
        guard !qualityGuardedText.isEmpty else {
            print("[Conversation] Empty response, using fallback")
            
            // Ensure avatar returns to idle on empty response
            if let manager = avatarStateManager {
                try? await manager.transitionToIdle()
            }
            
            // Return a graceful error response instead of throwing
            let currentLanguage = languageSettings.effectiveOutputLanguage
            let fallbackResponse = generateFallbackResponse(for: currentLanguage, error: nil)
            let fallbackMessage = await conversation.append(role: .assistant, content: fallbackResponse.text)
            
            // Use neutral emotion for fallback responses
            let fallbackEmotion = EmotionSignal(emotion: .neutral, intensity: 0.3)
            emotionState = emotionEngine.nextState(current: emotionState, signal: fallbackEmotion)
            relationshipState = await relationshipEngine.nextState(
                current: relationshipState,
                tone: tone,
                emotionSignal: fallbackEmotion
            )

            // Process memory formation asynchronously
            if let memoryFormation = memoryFormationService {
                print("[Conversation] memory formation scheduled")
                Task {
                    await memoryFormation.processUserMessage(text)
                }
            }

            // Clear the request ID after fallback (empty response case)
            currentRequestID = nil

            return AssistantTurnResult(
                reply: fallbackMessage,
                emotionState: emotionState,
                relationshipState: relationshipState
            )
        }

        let replyMessage = await conversation.append(role: .assistant, content: qualityGuardedText)
        emotionState = emotionEngine.nextState(current: emotionState, signal: finalResponse.emotionSignal)
        relationshipState = await relationshipEngine.nextState(
            current: relationshipState,
            tone: tone,
            emotionSignal: finalResponse.emotionSignal
        )

        // Process memory formation asynchronously - never blocks or fails the conversation
        if let memoryFormation = memoryFormationService {
            print("[Conversation] memory formation scheduled")
            Task {
                await memoryFormation.processUserMessage(text)
            }
        }

        // Transition avatar to talking state (TTS will handle this, but we set the state here)
        if let manager = avatarStateManager {
            try? await manager.transitionToTalking()
        }

        // Clear the request ID after successful completion
        currentRequestID = nil

        return AssistantTurnResult(
            reply: replyMessage,
            emotionState: emotionState,
            relationshipState: relationshipState
        )
    }
    
    /// Clears the conversation history.
    /// This resets the conversation while preserving persistent memory and personality.
    /// CLEAR/STOP HARDENING: Clears all runtime context to prevent late results from restoring state
    public func clearConversation() async {
        await conversation.clear()
        print("[Conversation] Conversation history cleared")
        
        // Clear entity context if available
        if let entityContext = entityContext {
            await entityContext.clear()
            print("[Conversation] Entity context cleared")
        }
        
        // Clear clarification state if available
        if let clarificationManager = clarificationManager {
            await clarificationManager.clearAll()
            print("[Conversation] Clarification state cleared")
        }
        
        // Clear task context if available
        if let taskContextManager = taskContextManager {
            await taskContextManager.clearAll()
            print("[Conversation] Task context cleared")
        }
        
        // Clear pending confirmation if available
        if let toolOrchestrator = toolOrchestrator {
            await toolOrchestrator.cancelConfirmation()
            print("[Conversation] Pending confirmation cleared")
        }
        
        // Clear intent history
        await intentHistory.clear()
        print("[Conversation] Intent history cleared")
        
        // Reset emotion and relationship to initial states for fresh conversation
        emotionState = .initial
        relationshipState = .initial
        
        // Ensure avatar returns to idle state
        if let manager = avatarStateManager {
            try? await manager.transitionToIdle()
        }
        
        // Clear any language override
        languageSettings.clearConversationOverride()
        
        print("[Conversation] Conversation state reset to initial")
    }
    
    /// Gets the current runtime status of the conversation system.
    public func getRuntimeStatus() async -> ConversationRuntimeStatus {
        let conversationState: String
        if currentRequestID != nil {
            conversationState = "thinking"
        } else {
            conversationState = "idle"
        }
        
        let avatarState = await avatarStateManager?.state ?? .idle
        
        return ConversationRuntimeStatus(
            conversationState: conversationState,
            avatarState: avatarState,
            hasActiveRequest: currentRequestID != nil,
            currentRequestID: currentRequestID
        )
    }
    
    /// Runtime status information for the conversation system.
    public struct ConversationRuntimeStatus: Sendable {
        public let conversationState: String
        public let avatarState: AvatarState
        public let hasActiveRequest: Bool
        public let currentRequestID: UUID?
    }
    
    /// Internal conversation state for runtime status
    private enum ConversationState: Sendable {
        case idle
        case thinking
        case processing
    }
    
    /// Validates response text, ensuring it's not empty or whitespace-only.
    private func validateResponseText(_ text: String) -> String {
        let trimmed = text.trimmingCharacters(in: .whitespacesAndNewlines)
        return trimmed.isEmpty ? "" : text
    }
    
    /// Guards against obviously bad response outputs.
    private func guardResponseQuality(_ text: String) -> String {
        let trimmed = text.trimmingCharacters(in: .whitespacesAndNewlines)
        
        // Check for raw JSON exposure
        if trimmed.hasPrefix("{") && trimmed.contains("\"text\"") {
            // This looks like raw JSON - extract the text field if possible
            if let textRange = trimmed.range(of: "\"text\":\\s*\"([^\"]+)\"", options: .regularExpression) {
                let jsonText = String(trimmed[textRange])
                // Extract the content between quotes
                if let quoteStart = jsonText.range(of: "\"", options: .caseInsensitive),
                   let quoteEnd = jsonText.range(of: "\"", options: .caseInsensitive, range: jsonText.index(after: quoteStart.lowerBound)..<jsonText.endIndex) {
                    return String(jsonText[quoteStart.upperBound..<quoteEnd.lowerBound])
                }
            }
        }
        
        // Check for repetitive content (basic heuristic)
        let words = trimmed.components(separatedBy: .whitespaces)
        if words.count > 10 {
            let uniqueWords = Set(words)
            if Double(uniqueWords.count) / Double(words.count) < 0.3 {
                // Too repetitive, return empty to trigger fallback
                print("[Conversation] Response too repetitive, using fallback")
                return ""
            }
        }
        
        // Check for exposed system instructions
        let systemPatterns = ["SYSTEM INSTRUCTION", "INTERNAL CONTEXT", "DO NOT EXPOSE", "TOOL METADATA"]
        for pattern in systemPatterns {
            if trimmed.uppercased().contains(pattern) {
                print("[Conversation] System instruction exposure detected, using fallback")
                return ""
            }
        }
        
        return trimmed.isEmpty ? "" : text
    }
    
    /// Executes the multi-round LLM → tool → LLM continuation loop.
    /// - Parameters:
    ///   - initialResponse: The initial LLM response
    ///   - requestID: Current request ID for validation
    ///   - toolOrchestrator: Tool orchestrator for tool execution
    /// - Returns: Final LLM response after tool loop completes
    /// - Throws: Error if loop execution fails
    private func executeToolLoop(
        initialResponse: LLMResponse,
        requestID: UUID,
        toolOrchestrator: ToolOrchestrator
    ) async throws -> LLMResponse {
        
        var currentResponse = initialResponse
        var currentRound = 0
        
        while currentRound < maxToolRounds {
            // Check for cancellation
            try Task.checkCancellation()
            
            // Validate session is still active
            guard currentRequestID == requestID else {
                print("[Conversation] Tool loop cancelled due to stale session")
                let currentLanguage = languageSettings.effectiveOutputLanguage
                return generateFallbackResponse(for: currentLanguage)
            }
            
            // Check if current response has tool calls
            guard let toolCalls = currentResponse.toolCalls, !toolCalls.isEmpty else {
                print("[Conversation] No tool calls in response, tool loop complete")
                return currentResponse
            }
            
            print("[Conversation] Tool loop round \(currentRound + 1): Processing \(toolCalls.count) tool calls")
            
            // Update tool calls to use the correct session ID
            let updatedToolCalls = toolCalls.map { toolCall in
                ToolCall(
                    toolIdentifier: toolCall.toolIdentifier,
                    arguments: toolCall.arguments,
                    sessionID: requestID,
                    correlationID: toolCall.correlationID
                )
            }
            
            // Create updated response with correct session IDs
            let updatedResponse = LLMResponse(
                text: currentResponse.text,
                emotionSignal: currentResponse.emotionSignal,
                toolCalls: updatedToolCalls
            )
            
            // Execute tools via orchestrator
            let orchestrationResult = try await toolOrchestrator.processResponse(
                updatedResponse,
                sessionID: requestID,
                conversation: conversation
            )
            
            print("[Conversation] Tool orchestration completed for round \(currentRound + 1)")
            
            // Check if user interaction is required
            if orchestrationResult.requiresUserInteraction {
                print("[Conversation] User interaction required, stopping tool loop")
                return orchestrationResult.originalResponse
            }
            
            // Check if continuation should proceed
            guard orchestrationResult.shouldContinueToLLM else {
                print("[Conversation] No continuation needed, tool loop complete")
                return orchestrationResult.originalResponse
            }
            
            // Add tool results to conversation
            for (toolCall, result) in orchestrationResult.toolResults {
                let toolResultContent = formatToolResultForConversation(toolCall: toolCall, result: result)
                _ = await conversation.append(role: .toolResult, content: toolResultContent)
            }
            
            print("[Conversation] Tool results added to conversation, calling LLM again")
            
            // Call LLM again with updated conversation
            currentResponse = try await continueWithToolResults(
                originalResponse: orchestrationResult.originalResponse,
                sessionID: requestID
            )
            
            currentRound += 1
        }
        
        // Max rounds reached
        print("[Conversation] Tool loop reached max rounds (\(maxToolRounds))")
        return currentResponse
    }
    
    /// Continues conversation with LLM after tool execution.
    /// - Parameters:
    ///   - originalResponse: The original LLM response that triggered tool execution
    ///   - sessionID: Current session ID for validation
    /// - Returns: Final LLM response after processing tool results
    /// - Throws: Error if continuation fails
    private func continueWithToolResults(
        originalResponse: LLMResponse,
        sessionID: UUID
    ) async throws -> LLMResponse {
        // Validate session is still active
        guard currentRequestID == sessionID else {
            print("[Conversation] Session invalidated during tool continuation")
            // Use current detected language from conversation context
            let currentLanguage = languageSettings.effectiveOutputLanguage
            return generateFallbackResponse(for: currentLanguage)
        }
        
        // Build continuation request with updated conversation history
        let messages = await conversation.recentHistory(maxMessages: maxContextMessages)
        
        // Build LLM request with tool definitions
        let toolDefinitions = toolRegistry != nil ? await toolRegistry!.allTools() : nil
        
        let continuationRequest = LLMRequest(
            messages: messages,
            systemContext: basePrompt,
            toolDefinitions: toolDefinitions
        )
        
        print("[Conversation] Calling LLM with tool results")
        
        // Call LLM with tool results in conversation
        let continuationResponse = try await llm.respond(to: continuationRequest)
        
        print("[Conversation] LLM continuation completed")
        
        return continuationResponse
    }
    
    /// Formats tool result for conversation history.
    /// - Parameters:
    ///   - toolCall: The tool call that was executed
    ///   - result: The result from tool execution
    /// - Returns: Formatted string for conversation
    private func formatToolResultForConversation(toolCall: ToolCall, result: ToolResult) -> String {
        var components: [String] = []
        
        components.append("Tool: \(toolCall.toolIdentifier.rawValue)")
        
        if result.success {
            components.append("Status: Success")
            if let data = result.data {
                components.append("Result: \(formatDataForDisplay(data))")
            }
        } else {
            components.append("Status: Failed")
            if let error = result.error {
                components.append("Error: \(error)")
            }
        }
        
        return components.joined(separator: " | ")
    }
    
    /// Formats data dictionary for display in conversation.
    /// - Parameter data: The data dictionary to format
    /// - Returns: Formatted string representation
    private func formatDataForDisplay(_ data: [String: Sendable]) -> String {
        let limitedData = Array(data.prefix(5)) // Limit to 5 key-value pairs
        let formatted = limitedData.map { key, value in
            "\(key): \(value)"
        }.joined(separator: ", ")
        
        if data.count > 5 {
            return "\(formatted)..."
        }
        return formatted
    }
    
    /// Generates a graceful fallback response when LLM fails or returns empty content.
    private func generateFallbackResponse(for language: SupportedLanguage, error: Error? = nil) -> LLMResponse {
        let fallbackText: String
        
        // Choose fallback message based on error type if available
        if let ariaError = error as? AriaError {
            switch ariaError {
            case .llmProviderFailure(let reason):
                // Check for specific error patterns
                if reason.contains("network") || reason.contains("timeout") {
                    fallbackText = networkFailureMessage(for: language)
                } else if reason.contains("rate") || reason.contains("429") {
                    fallbackText = rateLimitMessage(for: language)
                } else {
                    fallbackText = genericFailureMessage(for: language)
                }
            default:
                fallbackText = genericFailureMessage(for: language)
            }
        } else {
            fallbackText = genericFailureMessage(for: language)
        }
        
        return LLMResponse(
            text: fallbackText,
            emotionSignal: EmotionSignal(emotion: .neutral, intensity: 0.3)
        )
    }
    
    /// Network-specific failure message
    private func networkFailureMessage(for language: SupportedLanguage) -> String {
        switch language {
        case .indonesian:
            return "Kayaknya koneksiku lagi bermasalah. Coba sebentar lagi ya."
        case .japanese:
            return "接続に問題があるようです。しばらお待ちください。"
        case .russian:
            return "Похоже, проблема с соединением. Попробуйте позже."
        case .english, .auto:
            return "My connection seems to be having issues. Please try again in a moment."
        }
    }
    
    /// Rate limit specific failure message
    private func rateLimitMessage(for language: SupportedLanguage) -> String {
        switch language {
        case .indonesian:
            return "Aku lagi kena batas request sebentar. Tunggu sedikit ya."
        case .japanese:
            return "リクエスト制限にかかっています。少し待ってください。"
        case .russian:
            return "Я сейчас ограничен по запросам. Подождите немного."
        case .english, .auto:
            return "I'm hitting a request limit right now. Please wait a moment."
        }
    }
    
    /// Generic failure message
    private func genericFailureMessage(for language: SupportedLanguage) -> String {
        switch language {
        case .indonesian:
            return "Maaf, aku lagi nggak bisa merespons sekarang. Coba lagi sebentar ya."
        case .japanese:
            return "すみません、今は応答できません。もう一度試してみてください。"
        case .russian:
            return "Извините, я сейчас не могу ответить. Попробуйте еще раз позже."
        case .english, .auto:
            return "Sorry, I can't respond right now. Please try again in a moment."
        }
    }

    public func currentEmotionState() -> EmotionState {
        emotionState
    }

    public func currentRelationshipState() -> RelationshipState {
        relationshipState
    }
    
    public func currentLanguageSettings() -> LanguageSettings {
        languageSettings
    }
    
    /// Update language settings (useful for configuration changes)
    public func updateLanguageSettings(_ settings: LanguageSettings) {
        languageSettings = settings
    }
    
    /// Continues the original tool intent with a resolved entity after clarification.
    /// - Parameters:
    ///   - entity: The resolved entity selected by the user
    ///   - pendingClarification: The pending clarification request
    ///   - requestID: The current request ID
    ///   - text: The original user text
    /// - ReturnsThe assistant turn result after executing the tool with the resolved entity
    /// - Throws: AriaError if tool execution fails
    private func continueWithResolvedEntity(
        _ entity: RuntimeEntity,
        pendingClarification: ClarificationRequest,
        requestID: UUID,
        text: String
    ) async throws -> AssistantTurnResult {
        print("[Conversation] Continuing with resolved entity: \(entity.displayName)")
        
        // Reconstruct the tool call with the resolved entity
        guard let originalToolCall = pendingClarification.pendingToolCall else {
            print("[Conversation] No pending tool call in clarification request")
            throw AriaError.invalidState(reason: "No pending tool call")
        }
        
        // Replace the ambiguous reference with the resolved entity's path/identifier
        var resolvedArguments = originalToolCall.arguments
        for (key, value) in originalToolCall.arguments {
            if let stringValue = value as? String, stringValue == "itu" {
                if let path = entity.path {
                    resolvedArguments[key] = path
                } else if let appIdentifier = entity.applicationIdentifier {
                    resolvedArguments[key] = appIdentifier
                } else {
                    resolvedArguments[key] = entity.displayName
                }
            }
        }
        
        let resolvedToolCall = ToolCall(
            toolIdentifier: originalToolCall.toolIdentifier,
            arguments: resolvedArguments,
            sessionID: originalToolCall.sessionID,
            correlationID: originalToolCall.correlationID
        )
        
        // Execute the tool with the resolved entity
        guard let toolOrchestrator = toolOrchestrator else {
            print("[Conversation] Tool orchestrator not available")
            throw AriaError.invalidState(reason: "Tool orchestrator not available")
        }
        
        // Create a response with the resolved tool call
        let resolvedResponse = LLMResponse(
            text: "",
            emotionSignal: EmotionSignal(emotion: .neutral, intensity: 0.3),
            toolCalls: [resolvedToolCall]
        )
        
        do {
            let orchestrationResult = try await toolOrchestrator.processResponse(
                resolvedResponse,
                sessionID: requestID,
                conversation: conversation
            )
            
            print("[Conversation] Tool execution with resolved entity completed")
            
            // Extract the actual LLM response from orchestration result
            let finalResponse = orchestrationResult.originalResponse
            
            // Process the response normally
            let currentLanguage = languageSettings.effectiveOutputLanguage
            let tone = ConversationToneClassifier.classify(text)
            
            let validatedText = validateResponseText(finalResponse.text)
            let qualityGuardedText = guardResponseQuality(validatedText)
            
            guard !qualityGuardedText.isEmpty else {
                print("[Conversation] Empty response after tool execution, using fallback")
                let fallbackResponse = generateFallbackResponse(for: currentLanguage, error: nil)
                let fallbackMessage = await conversation.append(role: .assistant, content: fallbackResponse.text)
                
                let fallbackEmotion = EmotionSignal(emotion: .neutral, intensity: 0.3)
                emotionState = emotionEngine.nextState(current: emotionState, signal: fallbackEmotion)
                relationshipState = await relationshipEngine.nextState(
                    current: relationshipState,
                    tone: tone,
                    emotionSignal: fallbackEmotion
                )
                
                if let manager = avatarStateManager {
                    try? await manager.transitionToIdle()
                }
                
                currentRequestID = nil
                return AssistantTurnResult(
                    reply: fallbackMessage,
                    emotionState: emotionState,
                    relationshipState: relationshipState
                )
            }
            
            let replyMessage = await conversation.append(role: .assistant, content: qualityGuardedText)
            emotionState = emotionEngine.nextState(current: emotionState, signal: finalResponse.emotionSignal)
            relationshipState = await relationshipEngine.nextState(
                current: relationshipState,
                tone: tone,
                emotionSignal: finalResponse.emotionSignal
            )
            
            // Do not create memories for clarification interactions
            // Skip memory formation for clarification continuation
            
            if let manager = avatarStateManager {
                try? await manager.transitionToTalking()
            }
            
            currentRequestID = nil
            return AssistantTurnResult(
                reply: replyMessage,
                emotionState: emotionState,
                relationshipState: relationshipState
            )
        } catch {
            print("[Conversation] Tool execution with resolved entity failed: \(error)")
            
            if let manager = avatarStateManager {
                try? await manager.transitionToIdle()
            }
            
            let currentLanguage = languageSettings.effectiveOutputLanguage
            let fallbackResponse = generateFallbackResponse(for: currentLanguage, error: error)
            let fallbackMessage = await conversation.append(role: .assistant, content: fallbackResponse.text)
            
            let fallbackEmotion = EmotionSignal(emotion: .neutral, intensity: 0.3)
            emotionState = emotionEngine.nextState(current: emotionState, signal: fallbackEmotion)
            relationshipState = await relationshipEngine.nextState(
                current: relationshipState,
                tone: .casual,
                emotionSignal: fallbackEmotion
            )
            
            currentRequestID = nil
            return AssistantTurnResult(
                reply: fallbackMessage,
                emotionState: emotionState,
                relationshipState: relationshipState
            )
        }
    }
    
    /// Clear conversation language override and return to default
    public func clearLanguageOverride() {
        languageSettings.clearConversationOverride()
    }
    
    /// Get current conversation history (for testing/debugging)
    public func currentConversationHistory() async -> [ConversationMessage] {
        return await conversation.history()
    }
    
    /// Get the conversation service actor (for testing)
    public func currentConversationHistoryActor() -> ConversationService {
        return conversation
    }
}