import Foundation
import AriaDomain
import AriaInfrastructure

/// Orchestrates tool calling and execution for LLM responses.
/// Manages the tool loop, validation, execution, and conversation history.
public actor ToolOrchestrator {
    
    private let toolRegistry: ToolRegistry
    private let toolExecutors: [ToolIdentifier: any ToolExecuting]
    private let toolAdapter: OpenRouterToolAdapter
    private let logger: any Logging
    private let maxToolRounds: Int
    private let entityContext: RuntimeEntityContext?
    private let referenceResolver: ReferenceResolver?
    private let clarificationManager: ClarificationManager?
    private let clarificationMessageBuilder: ClarificationMessageBuilder?
    private let resultInterpreter: ToolResultInterpreter?
    private let taskContextManager: TaskContextManager?
    private let confirmationPolicy: ToolConfirmationPolicy
    private let failureRecoveryPolicy: ToolFailureRecoveryPolicy
    
    private var currentSessionID: UUID?
    private var currentRound: Int = 0
    private var pendingConfirmation: PendingToolConfirmation? = nil
    
    /// Callback for publishing runtime events to UI
    private var eventPublisher: ((AriaRuntimeEvent) -> Void)?
    
    public init(
        toolRegistry: ToolRegistry,
        toolExecutors: [ToolIdentifier: any ToolExecuting],
        logger: any Logging,
        maxToolRounds: Int = 4,
        entityContext: RuntimeEntityContext? = nil,
        referenceResolver: ReferenceResolver? = nil,
        clarificationManager: ClarificationManager? = nil,
        clarificationMessageBuilder: ClarificationMessageBuilder? = nil,
        resultInterpreter: ToolResultInterpreter? = nil,
        taskContextManager: TaskContextManager? = nil,
        confirmationPolicy: ToolConfirmationPolicy = ToolConfirmationPolicy(),
        failureRecoveryPolicy: ToolFailureRecoveryPolicy = ToolFailureRecoveryPolicy()
    ) {
        self.toolRegistry = toolRegistry
        self.toolExecutors = toolExecutors
        self.toolAdapter = OpenRouterToolAdapter()
        self.logger = logger
        self.maxToolRounds = maxToolRounds
        self.entityContext = entityContext
        self.referenceResolver = referenceResolver
        self.clarificationManager = clarificationManager
        self.clarificationMessageBuilder = clarificationMessageBuilder
        self.resultInterpreter = resultInterpreter
        self.taskContextManager = taskContextManager
        self.confirmationPolicy = confirmationPolicy
        self.failureRecoveryPolicy = failureRecoveryPolicy
    }
    
    /// Sets the event publisher callback for UI integration.
    /// - Parameter publisher: Callback to publish runtime events
    public func setEventPublisher(_ publisher: @escaping (AriaRuntimeEvent) -> Void) {
        self.eventPublisher = publisher
    }
    
    /// Publishes a runtime event if publisher is available.
    /// - Parameter event: The event to publish
    private func publishEvent(_ event: AriaRuntimeEvent) {
        eventPublisher?(event)
    }
    
    /// Processes an LLM response, executing tool calls if present.
    /// - Parameters:
    ///   - response: The LLM response to process
    ///   - sessionID: Current session ID for validation
    ///   - conversation: Conversation service for history management
    /// - Returns: Final LLM response after tool execution loop
    /// - Throws: ToolOrchestrationError if orchestration fails
    public func processResponse(
        _ response: LLMResponse,
        sessionID: UUID,
        conversation: ConversationService
    ) async throws -> LLMResponse {
        
        // Check for tool calls
        guard let toolCalls = response.toolCalls, !toolCalls.isEmpty else {
            // No tool calls, return response as-is
            return response
        }
        
        // Set current session
        currentSessionID = sessionID
        currentRound = 0
        
        // Set session ID in entity context if available
        if let entityContext = entityContext {
            await entityContext.setSessionID(sessionID)
        }
        
        // Set session ID in clarification manager if available
        if let clarificationManager = clarificationManager {
            await clarificationManager.setSessionID(sessionID)
        }
        
        // Set session ID in task context manager if available
        if let taskContextManager = taskContextManager {
            await taskContextManager.setSessionID(sessionID)
        }
        
        logger.info("Tool orchestration started with \(toolCalls.count) tool calls")
        
        // Execute tool loop
        return try await executeToolLoop(
            originalResponse: response,
            toolCalls: toolCalls,
            sessionID: sessionID,
            conversation: conversation
        )
    }
    
    /// Executes the tool loop with max rounds enforcement.
    private func executeToolLoop(
        originalResponse: LLMResponse,
        toolCalls: [ToolCall],
        sessionID: UUID,
        conversation: ConversationService
    ) async throws -> LLMResponse {
        
        let currentToolCalls = toolCalls
        var toolResults: [ToolResult] = []
        
        while currentRound < maxToolRounds {
            // Check for cancellation
            try Task.checkCancellation()
            
            // Validate session is still active
            guard currentSessionID == sessionID else {
                logger.warning("Tool orchestration cancelled due to stale session")
                throw ToolOrchestrationError.staleSession
            }
            
            // Validate and execute tool calls
            for toolCall in currentToolCalls {
                // Check for cancellation before each tool
                try Task.checkCancellation()
                
                // Validate session
                guard currentSessionID == sessionID else {
                    logger.warning("Tool execution cancelled due to stale session")
                    throw ToolOrchestrationError.staleSession
                }
                
                // Validate tool call
                try await validateToolCall(toolCall)
                
                // Resolve references in tool arguments if reference resolver is available
                let resolvedToolCall = try await resolveReferences(in: toolCall)
                
                // Check if resolution resulted in ambiguity
                if let ambiguity = await checkForAmbiguity(in: resolvedToolCall) {
                    // Store clarification request and return special result
                    logger.info("Ambiguity detected in tool call, clarification needed")
                    
                    // Publish clarification requested event
                    if case .ambiguous(let candidates) = ambiguity {
                        let clarificationCandidates = candidates.map { candidate in
                            ClarificationCandidate(
                                displayName: candidate.displayName,
                                type: candidate.kind.rawValue
                            )
                        }
                        publishEvent(.clarificationRequested(
                            sessionID: sessionID,
                            question: "Aku menemukan beberapa item. Yang mana yang kamu maksud?",
                            candidates: clarificationCandidates
                        ))
                    }
                    
                    return try await handleAmbiguity(
                        ambiguity,
                        originalToolCall: toolCall,
                        resolvedToolCall: resolvedToolCall,
                        sessionID: sessionID,
                        conversation: conversation
                    )
                }
                
                // Check confirmation policy
                guard let toolDefinition = await toolRegistry.tool(for: resolvedToolCall.toolIdentifier) else {
                    throw ToolOrchestrationError.toolNotFound(resolvedToolCall.toolIdentifier)
                }
                
                let requiresConfirmation = await confirmationPolicy.requiresConfirmation(
                    toolDefinition: toolDefinition,
                    toolCall: resolvedToolCall
                )
                
                if requiresConfirmation {
                    // Store pending confirmation and return special result
                    logger.info("Confirmation required for tool: \(resolvedToolCall.toolIdentifier.rawValue)")
                    
                    // Publish confirmation requested event
                    let actionDescription = await confirmationPolicy.confirmationMessage(
                        toolDefinition: toolDefinition,
                        toolCall: resolvedToolCall
                    )
                    publishEvent(.confirmationRequested(
                        sessionID: sessionID,
                        action: actionDescription
                    ))
                    
                    return try await handleConfirmationRequired(
                        toolCall: resolvedToolCall,
                        toolDefinition: toolDefinition,
                        sessionID: sessionID,
                        conversation: conversation
                    )
                }
                
                // Publish tool started event
                let toolName = toolDefinition.description
                publishEvent(.toolStarted(sessionID: sessionID, activity: "Aria sedang \(toolName)..."))
                
                // Execute tool
                let result = try await executeTool(resolvedToolCall)
                toolResults.append(result)
                
                // Publish tool finished event
                publishEvent(.toolFinished(sessionID: sessionID))
                
                // Interpret result if interpreter is available
                let interpretation = if let resultInterpreter = resultInterpreter {
                    await resultInterpreter.interpret(result, for: resolvedToolCall, sessionID: sessionID)
                } else {
                    // Fallback to raw result if no interpreter
                    ToolResultInterpretation(
                        success: result.success,
                        summary: result.success ? "Operasi berhasil." : (result.error ?? "Operasi gagal."),
                        details: result.data,
                        entities: nil,
                        errorCategory: nil,
                        displayToUser: true
                    )
                }
                
                // Check for recovery availability on failure
                if !result.success {
                    // Determine error category from result
                    let errorCategory: ToolErrorCategory
                    if let error = result.error {
                        if error.contains("cancelled") {
                            errorCategory = .cancelled
                        } else if error.contains("permission") {
                            errorCategory = .permissionDenied
                        } else if error.contains("not found") {
                            errorCategory = .notFound
                        } else if error.contains("unavailable") {
                            errorCategory = .unavailable
                        } else {
                            errorCategory = .executionFailed
                        }
                    } else {
                        errorCategory = .executionFailed
                    }
                    
                    let canRetry = await failureRecoveryPolicy.shouldRetry(
                        errorCategory: errorCategory,
                        currentRetryCount: currentRound,
                        toolCall: resolvedToolCall,
                        sessionID: sessionID
                    )
                    publishEvent(.recoveryAvailable(sessionID: sessionID, canRetry: canRetry))
                }
                
                // Record entity from interpretation if entity context is available
                // STATE MUTATION GATE: Only record entities on success
                // Failed, cancelled, or stale operations must not create entities
                if interpretation.success, let entities = interpretation.entities {
                    // Validate session before recording
                    if currentSessionID == sessionID {
                        if let entityContext = entityContext {
                            for entity in entities {
                                await entityContext.record(entity, sessionID: sessionID)
                            }
                        }
                    } else {
                        logger.warning("Attempted to record entity with stale session ID")
                    }
                } else if result.success {
                    // Fallback to legacy entity recording if interpretation doesn't provide entities
                    // Validate session before recording
                    if currentSessionID == sessionID {
                        if let entityContext = entityContext {
                            await recordEntity(from: result, for: toolCall, sessionID: sessionID, entityContext: entityContext)
                        }
                    } else {
                        logger.warning("Attempted to record entity with stale session ID")
                    }
                }
                
                // Update task context if available and tool succeeded
                // STATE MUTATION GATE: Only update task context on success
                // Failed, cancelled, or stale operations must not update task context
                if result.success {
                    // Validate session before updating
                    if currentSessionID == sessionID {
                        if let taskContextManager = taskContextManager {
                            await updateTaskContext(from: result, for: toolCall, interpretation: interpretation, sessionID: sessionID, taskContextManager: taskContextManager)
                        }
                    } else {
                        logger.warning("Attempted to update task context with stale session ID")
                    }
                }
                
                // Add interpreted result to conversation history
                await addInterpretedResultToConversation(interpretation, for: toolCall, conversation: conversation)
            }
            
            currentRound += 1
            
            // Check if we should continue the loop
            // For now, we'll stop after one round since we don't have LLM continuation yet
            // This will be enhanced when we implement the full loop
            break
        }
        
        if currentRound >= maxToolRounds {
            logger.warning("Tool loop reached max rounds (\(maxToolRounds))")
        }
        
        // Build final response from interpretations
        // If we have interpretations, use their summaries to build a natural response
        // For now, we return the original response text - this will be enhanced
        // when we implement LLM continuation with tool results
        return originalResponse
    }
    
    /// Validates a tool call against the tool registry.
    private func validateToolCall(_ toolCall: ToolCall) async throws {
        // Check if tool is registered
        let toolExists = await toolRegistry.hasTool(toolCall.toolIdentifier)
        guard toolExists else {
            logger.warning("Tool not found: \(toolCall.toolIdentifier.rawValue)")
            throw ToolOrchestrationError.toolNotFound(toolCall.toolIdentifier)
        }
        
        // Get tool definition for validation
        guard let definition = await toolRegistry.tool(for: toolCall.toolIdentifier) else {
            throw ToolOrchestrationError.toolNotFound(toolCall.toolIdentifier)
        }
        
        // Validate arguments
        if let validationError = toolCall.validateAgainst(definition) {
            logger.warning("Tool validation failed: \(validationError)")
            throw ToolOrchestrationError.invalidArguments(validationError.localizedDescription)
        }
        
        // Check risk level
        if definition.riskLevel == .destructive {
            logger.error("Destructive tool not allowed: \(toolCall.toolIdentifier.rawValue)")
            throw ToolOrchestrationError.permissionDenied
        }
        
        // Sensitive tools could require confirmation (future enhancement)
        if definition.riskLevel == .sensitive {
            logger.info("Sensitive tool requested: \(toolCall.toolIdentifier.rawValue)")
            // For now, allow sensitive tools without confirmation
            // This could be enhanced with user confirmation UI
        }
    }
    
    /// Executes a tool call using the appropriate executor.
    private func executeTool(_ toolCall: ToolCall) async throws -> ToolResult {
        // CROSS-SESSION SAFETY: Validate session before execution
        guard currentSessionID == toolCall.sessionID else {
            logger.warning("Tool execution rejected: stale session ID")
            return ToolResult.staleSession()
        }
        
        guard let executor = toolExecutors[toolCall.toolIdentifier] else {
            logger.error("No executor for tool: \(toolCall.toolIdentifier.rawValue)")
            return ToolResult.failure("No executor available for tool", errorCode: "executor_not_found")
        }
        
        logger.info("Executing tool: \(toolCall.toolIdentifier.rawValue)")
        
        do {
            let result = try await executor.execute(toolCall)
            logger.info("Tool execution succeeded: \(toolCall.toolIdentifier.rawValue)")
            return result
        } catch ToolExecutionError.cancelled {
            logger.warning("Tool execution cancelled: \(toolCall.toolIdentifier.rawValue)")
            return ToolResult.cancelled()
        } catch ToolExecutionError.staleSession {
            logger.warning("Tool execution stale session: \(toolCall.toolIdentifier.rawValue)")
            return ToolResult.staleSession()
        } catch {
            logger.error("Tool execution failed: \(toolCall.toolIdentifier.rawValue) - \(error)")
            return ToolResult.failure(error.localizedDescription, errorCode: "execution_failed")
        }
    }
    
    /// Adds an interpreted tool result to the conversation history.
    private func addInterpretedResultToConversation(
        _ interpretation: ToolResultInterpretation,
        for toolCall: ToolCall,
        conversation: ConversationService
    ) async {
        // CROSS-SESSION SAFETY: Validate session before adding to conversation
        guard currentSessionID == toolCall.sessionID else {
            logger.warning("Attempted to add tool result to conversation with stale session ID")
            return
        }
        
        // Only add to conversation if it should be displayed to the user
        guard interpretation.displayToUser else {
            return
        }
        
        // Add interpretation summary to conversation
        await conversation.append(role: .assistant, content: interpretation.summary)
    }
    
    /// Adds a tool result to the conversation history (legacy method for fallback).
    private func addToolResultToConversation(
        _ result: ToolResult,
        for toolCall: ToolCall,
        conversation: ConversationService
    ) async {
        // Format tool result for conversation
        let resultText = formatToolResult(result, for: toolCall)
        
        // Add as a system message to indicate tool result
        // This will be enhanced to use proper tool role when conversation model supports it
        await conversation.append(role: .system, content: resultText)
    }
    
    /// Formats a tool result for conversation display.
    private func formatToolResult(_ result: ToolResult, for toolCall: ToolCall) -> String {
        var parts: [String] = []
        parts.append("Tool: \(toolCall.toolIdentifier.rawValue)")
        
        if result.success {
            parts.append("Status: Success")
            if let data = result.data {
                parts.append("Data: \(formatData(data))")
            }
        } else {
            parts.append("Status: Failed")
            if let error = result.error {
                parts.append("Error: \(error)")
            }
            if let errorCode = result.errorCode {
                parts.append("Code: \(errorCode)")
            }
        }
        
        return parts.joined(separator: " | ")
    }
    
    /// Formats tool result data for display.
    private func formatData(_ data: [String: Sendable]) -> String {
        // Simplified formatting - can be enhanced
        return "\(data.count) fields"
    }
    
    /// Cancels the current orchestration session.
    public func cancelSession() {
        currentSessionID = nil
        currentRound = 0
        logger.info("Tool orchestration session cancelled")
    }
    
    /// Records an entity from a successful tool result.
    /// - Parameters:
    ///   - result: The tool result to extract entity from
    ///   - toolCall: The tool call that produced the result
    ///   - sessionID: The current session ID
    ///   - entityContext: The entity context to record to
    private func recordEntity(
        from result: ToolResult,
        for toolCall: ToolCall,
        sessionID: UUID,
        entityContext: RuntimeEntityContext
    ) async {
        guard let data = result.data else {
            return
        }
        
        switch toolCall.toolIdentifier {
        case .openApplication:
            if let appName = data["applicationName"] as? String,
               let bundleID = data["bundleIdentifier"] as? String,
               let path = data["path"] as? String {
                let entity = RuntimeEntity(
                    kind: .application,
                    displayName: appName,
                    path: path,
                    applicationIdentifier: bundleID,
                    sessionID: sessionID
                )
                await entityContext.record(entity, sessionID: sessionID)
            }
            
        case .openFile:
            if let path = data["path"] as? String,
               let fileName = data["fileName"] as? String {
                let entity = RuntimeEntity(
                    kind: .file,
                    displayName: fileName,
                    path: path,
                    sessionID: sessionID
                )
                await entityContext.record(entity, sessionID: sessionID)
            }
            
        case .openFolder:
            if let path = data["path"] as? String,
               let fileName = data["fileName"] as? String {
                let entity = RuntimeEntity(
                    kind: .folder,
                    displayName: fileName,
                    path: path,
                    sessionID: sessionID
                )
                await entityContext.record(entity, sessionID: sessionID)
            }
            
        case .findFile:
            // Handle search results as an ordered result set
            if let results = data["results"] as? [[String: Sendable]] {
                await entityContext.startResultSet(sessionID: sessionID)
                
                for (index, resultItem) in results.enumerated() {
                    if let path = resultItem["path"] as? String,
                       let fileName = resultItem["fileName"] as? String {
                        let entity = RuntimeEntity(
                            kind: .searchResult,
                            displayName: fileName,
                            path: path,
                            position: index + 1,
                            sessionID: sessionID
                        )
                        await entityContext.recordInResultSet(entity, sessionID: sessionID)
                    }
                }
                
                await entityContext.finalizeResultSet(sessionID: sessionID)
            }
            
        default:
            // Other tools don't produce entities for reference resolution
            break
        }
    }
    
    /// Updates task context based on tool result and interpretation.
    /// - Parameters:
    ///   - result: The tool result
    ///   - toolCall: The tool call that produced the result
    ///   - interpretation: The interpreted result
    ///   - sessionID: The current session ID
    ///   - taskContextManager: The task context manager to update
    private func updateTaskContext(
        from result: ToolResult,
        for toolCall: ToolCall,
        interpretation: ToolResultInterpretation,
        sessionID: UUID,
        taskContextManager: TaskContextManager
    ) async {
        guard let data = result.data else {
            return
        }
        
        switch toolCall.toolIdentifier {
        case .findFile:
            // Create file search task context
            if let results = data["results"] as? [[String: Sendable]] {
                let taskResults = results.compactMap { resultItem -> TaskResult? in
                    guard let fileName = resultItem["fileName"] as? String,
                          let path = resultItem["path"] as? String else {
                        return nil
                    }
                    
                    // Extract modification date if available
                    var modificationDate: Date?
                    if let modDateStr = resultItem["modificationDate"] as? String {
                        modificationDate = ISO8601DateFormatter().date(from: modDateStr)
                    }
                    
                    return TaskResult(
                        displayName: fileName,
                        path: path,
                        modificationDate: modificationDate
                    )
                }
                
                // Extract scope from arguments if available
                let scope = toolCall.arguments["query"] as? String ?? toolCall.arguments["path"] as? String
                
                await taskContextManager.updateTask(
                    taskKind: .fileSearch,
                    targetEntityKind: .file,
                    scope: scope,
                    results: taskResults,
                    sessionID: sessionID
                )
            }
            
        case .openFile:
            // Create file interaction task context
            if let fileName = data["fileName"] as? String,
               let path = data["path"] as? String {
                let taskResult = TaskResult(
                    displayName: fileName,
                    path: path
                )
                
                await taskContextManager.updateTask(
                    taskKind: .fileInteraction,
                    targetEntityKind: .file,
                    results: [taskResult],
                    sessionID: sessionID
                )
            }
            
        case .openFolder:
            // Create folder interaction task context
            if let folderName = data["folderName"] as? String,
               let path = data["path"] as? String {
                let taskResult = TaskResult(
                    displayName: folderName,
                    path: path
                )
                
                await taskContextManager.updateTask(
                    taskKind: .folderInteraction,
                    targetEntityKind: .folder,
                    results: [taskResult],
                    sessionID: sessionID
                )
            }
            
        case .openApplication:
            // Create application interaction task context
            if let appName = data["applicationName"] as? String,
               let bundleID = data["bundleIdentifier"] as? String {
                let taskResult = TaskResult(
                    displayName: appName,
                    applicationIdentifier: bundleID
                )
                
                await taskContextManager.updateTask(
                    taskKind: .applicationInteraction,
                    targetEntityKind: .application,
                    results: [taskResult],
                    sessionID: sessionID
                )
            }
            
        default:
            // Other tools don't create task context
            break
        }
    }
    
    /// Resolves references in tool arguments using the ReferenceResolver.
    /// - Parameter toolCall: The tool call to resolve references in
    /// - Returns: Tool call with resolved references
    /// - Throws: ToolOrchestrationError if resolution fails
    private func resolveReferences(in toolCall: ToolCall) async throws -> ToolCall {
        guard let referenceResolver = referenceResolver else {
            return toolCall
        }
        
        var resolvedArguments = toolCall.arguments
        
        // Check each argument for references
        for (key, value) in toolCall.arguments {
            if let stringValue = value as? String {
                if referenceResolver.isReference(stringValue) {
                    let resolutionResult = await referenceResolver.resolve(stringValue)
                    
                    switch resolutionResult {
                    case .resolved(let entity):
                        // Replace reference with concrete value
                        if let path = entity.path {
                            // Validate resolved path is not empty
                            let trimmedPath = path.trimmingCharacters(in: .whitespacesAndNewlines)
                            guard !trimmedPath.isEmpty else {
                                logger.warning("Resolved reference '\(stringValue)' produced empty path")
                                throw ToolOrchestrationError.invalidArguments("Resolved reference produced empty path")
                            }
                            resolvedArguments[key] = trimmedPath
                            logger.debug("Resolved reference '\(stringValue)' to path: \(trimmedPath)")
                        } else if let appIdentifier = entity.applicationIdentifier {
                            // Validate resolved app identifier is not empty
                            let trimmedAppId = appIdentifier.trimmingCharacters(in: .whitespacesAndNewlines)
                            guard !trimmedAppId.isEmpty else {
                                logger.warning("Resolved reference '\(stringValue)' produced empty app identifier")
                                throw ToolOrchestrationError.invalidArguments("Resolved reference produced empty app identifier")
                            }
                            resolvedArguments[key] = trimmedAppId
                            logger.debug("Resolved reference '\(stringValue)' to app identifier: \(trimmedAppId)")
                        } else {
                            let displayName = entity.displayName.trimmingCharacters(in: .whitespacesAndNewlines)
                            guard !displayName.isEmpty else {
                                logger.warning("Resolved reference '\(stringValue)' produced empty display name")
                                throw ToolOrchestrationError.invalidArguments("Resolved reference produced empty display name")
                            }
                            resolvedArguments[key] = displayName
                            logger.debug("Resolved reference '\(stringValue)' to display name: \(displayName)")
                        }
                        
                    case .unresolved:
                        logger.warning("Could not resolve reference '\(stringValue)'")
                        throw ToolOrchestrationError.invalidArguments("Could not resolve reference: \(stringValue)")
                        
                    case .ambiguous(let candidates):
                        logger.debug("Reference '\(stringValue)' is ambiguous - \(candidates.count) candidates")
                        // Handle ambiguity through clarification manager
                        if let clarificationManager = clarificationManager {
                            let clarification = ClarificationRequest(
                                originalUserMessage: stringValue,
                                candidates: candidates,
                                sessionID: toolCall.sessionID,
                                pendingToolCall: toolCall
                            )
                            await clarificationManager.storeClarification(clarification, sessionID: toolCall.sessionID)
                            throw ToolOrchestrationError.invalidArguments("Ambiguous reference: \(stringValue)")
                        } else {
                            // If no clarification manager, fail
                            throw ToolOrchestrationError.invalidArguments("Ambiguous reference: \(stringValue)")
                        }
                        
                    case .invalidPosition:
                        logger.warning("Invalid positional reference: \(stringValue)")
                        throw ToolOrchestrationError.invalidArguments("Invalid position: \(stringValue)")
                    }
                }
            }
        }
        
        return ToolCall(
            toolIdentifier: toolCall.toolIdentifier,
            arguments: resolvedArguments,
            sessionID: toolCall.sessionID,
            correlationID: toolCall.correlationID
        )
    }
    
    /// Checks if a tool call contains ambiguous references.
    /// - Parameter toolCall: The tool call to check
    /// - Returns: Ambiguity result if found, nil otherwise
    private func checkForAmbiguity(in toolCall: ToolCall) async -> ResolutionResult? {
        guard let referenceResolver = referenceResolver else {
            return nil
        }
        
        for (_, value) in toolCall.arguments {
            if let stringValue = value as? String {
                if referenceResolver.isReference(stringValue) {
                    let resolutionResult = await referenceResolver.resolve(stringValue)
                    if case .ambiguous = resolutionResult {
                        return resolutionResult
                    }
                }
            }
        }
        
        return nil
    }
    
    /// Handles ambiguity by storing clarification request and returning special response.
    /// - Parameters:
    ///   - ambiguity: The ambiguity result
    ///   - originalToolCall: The original tool call
    ///   - resolvedToolCall: The resolved tool call (with unresolved references)
    ///   - sessionID: The session ID
    ///   - conversation: The conversation service
    /// - Returns: LLM response with clarification message
    /// - Throws: ToolOrchestrationError if handling fails
    private func handleAmbiguity(
        _ ambiguity: ResolutionResult,
        originalToolCall: ToolCall,
        resolvedToolCall: ToolCall,
        sessionID: UUID,
        conversation: ConversationService
    ) async throws -> LLMResponse {
        guard case .ambiguous(let candidates) = ambiguity else {
            throw ToolOrchestrationError.invalidArguments("Expected ambiguous result")
        }
        
        guard let clarificationManager = clarificationManager,
              let clarificationMessageBuilder = clarificationMessageBuilder else {
            // If clarification components are not available, throw error
            throw ToolOrchestrationError.invalidArguments("Ambiguity detected but clarification not available")
        }
        
        // Generate clarification message
        let clarificationMessage = clarificationMessageBuilder.buildClarificationMessage(
            candidates: candidates,
            reference: "itu" // Generic reference for now
        )
        
        // Store clarification request
        let clarificationRequest = ClarificationRequest(
            originalUserMessage: "", // Will be filled by AssistantCoordinator
            candidates: candidates,
            sessionID: sessionID,
            pendingToolCall: originalToolCall
        )
        
        await clarificationManager.storeClarification(clarificationRequest, sessionID: sessionID)
        
        // Return LLM response with clarification message
        return LLMResponse(
            text: clarificationMessage,
            toolCalls: nil
        )
    }
    
    /// Handles confirmation requirement by storing pending confirmation and returning special response.
    /// - Parameters:
    ///   - toolCall: The tool call requiring confirmation
    ///   - toolDefinition: The tool definition
    ///   - sessionID: The session ID
    ///   - conversation: The conversation service
    /// - Returns: LLM response with confirmation message
    /// - Throws: ToolOrchestrationError if handling fails
    private func handleConfirmationRequired(
        toolCall: ToolCall,
        toolDefinition: ToolDefinition,
        sessionID: UUID,
        conversation: ConversationService
    ) async throws -> LLMResponse {
        // Generate confirmation message
        let confirmationMessage = await confirmationPolicy.confirmationMessage(
            toolDefinition: toolDefinition,
            toolCall: toolCall
        )
        
        // Store pending confirmation
        pendingConfirmation = PendingToolConfirmation(
            sessionID: sessionID,
            toolCall: toolCall,
            toolDefinition: toolDefinition,
            createdAt: Date(),
            summary: toolDefinition.description
        )
        
        // Return response with confirmation message
        return LLMResponse(
            text: confirmationMessage,
            emotionSignal: nil,
            toolCalls: nil
        )
    }
    
    /// Resolves a pending confirmation with user's answer.
    /// - Parameters:
    ///   - answer: The user's answer
    ///   - sessionID: The current session ID
    ///   - conversation: The conversation service
    /// - Returns: LLM response after handling the confirmation
    /// - Throws: ToolOrchestrationError if resolution fails
    public func resolveConfirmation(
        answer: ConfirmationAnswerParser.Answer,
        sessionID: UUID,
        conversation: ConversationService
    ) async throws -> LLMResponse {
        guard let pending = pendingConfirmation else {
            // No pending confirmation, treat as normal conversation
            throw ToolOrchestrationError.invalidArguments("No pending confirmation")
        }
        
        // Validate session
        if pending.isStale(for: sessionID) {
            pendingConfirmation = nil
            throw ToolOrchestrationError.staleSession
        }
        
        // Check expiration
        if pending.isExpired() {
            pendingConfirmation = nil
            let expiredMessage = await conversation.append(role: .assistant, content: "Maaf, konfirmasi sudah kadaluarsa.")
            return LLMResponse(text: expiredMessage.content, emotionSignal: nil, toolCalls: nil)
        }
        
        switch answer {
        case .confirmed:
            // Clear pending confirmation before execution
            let toolCallToExecute = pending.toolCall
            pendingConfirmation = nil
            
            // Execute the tool
            let result = try await executeTool(toolCallToExecute)
            
            // Interpret result
            let interpretation = if let resultInterpreter = resultInterpreter {
                await resultInterpreter.interpret(result, for: toolCallToExecute, sessionID: sessionID)
            } else {
                ToolResultInterpretation(
                    success: result.success,
                    summary: result.success ? "Operasi berhasil." : (result.error ?? "Operasi gagal."),
                    details: result.data,
                    entities: nil,
                    errorCategory: nil,
                    displayToUser: true
                )
            }
            
            // Add interpreted result to conversation
            await addInterpretedResultToConversation(interpretation, for: toolCallToExecute, conversation: conversation)
            
            return LLMResponse(text: interpretation.summary, emotionSignal: nil, toolCalls: nil)
            
        case .rejected, .cancelled:
            // Clear pending confirmation
            pendingConfirmation = nil
            
            // Return natural rejection message
            let rejectionMessage = await conversation.append(role: .assistant, content: "Oke, nggak jadi.")
            return LLMResponse(text: rejectionMessage.content, emotionSignal: nil, toolCalls: nil)
            
        case .ambiguous:
            // Clear pending confirmation
            pendingConfirmation = nil
            
            // Ask for clarification
            let clarificationMessage = await conversation.append(role: .assistant, content: "Maaf, aku nggak mengerti. Jawab 'ya' atau 'tidak'.")
            return LLMResponse(text: clarificationMessage.content, emotionSignal: nil, toolCalls: nil)
        }
    }
    
    /// Cancels any pending confirmation.
    public func cancelConfirmation() {
        pendingConfirmation = nil
    }
    
    /// Errors that can occur during tool orchestration.
    public enum ToolOrchestrationError: Error, Equatable {
        case toolNotFound(ToolIdentifier)
        case invalidArguments(String)
        case permissionDenied
        case staleSession
        case maxRoundsExceeded
        case executionFailed(String)
    }
}
