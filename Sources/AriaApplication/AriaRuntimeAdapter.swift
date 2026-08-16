import AriaDomain
import Foundation
import SwiftUI

/// Runtime adapter that bridges the actor-based backend to the reactive UI layer.
/// This adapter observes backend state changes via AsyncStream and provides
/// MainActor-safe @Observable state for SwiftUI consumption.
@MainActor
@Observable
public final class AriaRuntimeAdapter {
    
    // MARK: - Dependencies
    
    private let coordinator: AssistantCoordinator
    private var eventStreamTask: Task<Void, Never>?
    
    // MARK: - UI State
    
    /// Current processing state
    public private(set) var isProcessing: Bool = false
    
    /// Current session ID for stale event protection
    public private(set) var currentSessionID: UUID?
    
    /// Current avatar state
    public private(set) var avatarState: AvatarState = .idle
    
    /// Audio playback state
    public private(set) var isAudioPlaying: Bool = false
    
    /// Mute state
    public private(set) var isMuted: Bool = false
    
    /// Whether a clarification request is pending
    public private(set) var isClarificationPending: Bool = false
    
    /// Pending clarification question
    public private(set) var clarificationQuestion: String?
    
    /// Pending clarification candidates
    public private(set) var clarificationCandidates: [ClarificationCandidate] = []
    
    /// Whether a confirmation request is pending
    public private(set) var isConfirmationPending: Bool = false
    
    /// Pending confirmation action description
    public private(set) var confirmationAction: String?
    
    /// Current tool activity description
    public private(set) var currentToolActivity: String?
    
    /// Whether retry is available for failed tool
    public private(set) var canRetryTool: Bool = false
    
    /// Whether a tool submission is pending (for duplicate protection)
    public private(set) var isToolSubmissionPending: Bool = false
    
    /// Last error message (if any)
    public private(set) var lastError: String?
    
    /// Conversation messages for UI display
    public var messages: [ConversationMessageViewData] = []
    
    // MARK: - Initialization
    
    /// Creates a new runtime adapter.
    /// - Parameter coordinator: The assistant coordinator to bridge to
    public init(coordinator: AssistantCoordinator) {
        self.coordinator = coordinator
        subscribeToRuntimeEvents()
        setupToolEventPublisher()
    }
    
    /// Sets up the tool event publisher to receive events from tool orchestration.
    private func setupToolEventPublisher() {
        Task {
            await coordinator.setToolEventPublisher { [weak self] event in
                Task { @MainActor in
                    self?.handleRuntimeEvent(event)
                }
            }
        }
    }
    
    // MARK: - Event Subscription
    
    /// Subscribes to backend runtime events.
    private func subscribeToRuntimeEvents() {
        eventStreamTask = Task { [weak self] in
            guard let self = self else { return }
            for await event in await self.coordinator.runtimeEvents() {
                self.handleRuntimeEvent(event)
            }
        }
    }
    
    /// Handles a runtime event from the backend.
    /// - Parameter event: The runtime event to handle
    private func handleRuntimeEvent(_ event: AriaRuntimeEvent) {
        switch event {
        case .requestStarted(let sessionID):
            handleRequestStarted(sessionID: sessionID)
            
        case .requestCompleted(let sessionID):
            handleRequestCompleted(sessionID: sessionID)
            
        case .requestCancelled(let sessionID):
            handleRequestCancelled(sessionID: sessionID)
            
        case .requestFailed(let sessionID, let error):
            handleRequestFailed(sessionID: sessionID, error: error)
            
        case .avatarStateChanged(let state):
            handleAvatarStateChanged(state: state)
            
        case .audioStateChanged(let isPlaying):
            handleAudioStateChanged(isPlaying: isPlaying)
            
        case .muteStateChanged(let isMuted):
            handleMuteStateChanged(isMuted: isMuted)
            
        case .clarificationRequested(let sessionID, let question, let candidates):
            handleClarificationRequested(sessionID: sessionID, question: question, candidates: candidates)
            
        case .clarificationResolved(let sessionID):
            handleClarificationResolved(sessionID: sessionID)
            
        case .confirmationRequested(let sessionID, let action):
            handleConfirmationRequested(sessionID: sessionID, action: action)
            
        case .confirmationResolved(let sessionID):
            handleConfirmationResolved(sessionID: sessionID)
            
        case .toolStarted(let sessionID, let activity):
            handleToolStarted(sessionID: sessionID, activity: activity)
            
        case .toolFinished(let sessionID):
            handleToolFinished(sessionID: sessionID)
            
        case .recoveryAvailable(let sessionID, let canRetry):
            handleRecoveryAvailable(sessionID: sessionID, canRetry: canRetry)
        }
    }
    
    // MARK: - Event Handlers
    
    private func handleRequestStarted(sessionID: UUID) {
        // Reject stale events
        guard let currentID = currentSessionID else {
            currentSessionID = sessionID
            isProcessing = true
            lastError = nil
            return
        }
        
        // Only update if this is the current or newer session
        if sessionID >= currentID {
            currentSessionID = sessionID
            isProcessing = true
            lastError = nil
        }
    }
    
    private func handleRequestCompleted(sessionID: UUID) {
        // Reject stale events
        guard let currentID = currentSessionID, sessionID == currentID else {
            return
        }
        
        isProcessing = false
        isClarificationPending = false
        isConfirmationPending = false
        currentToolActivity = nil
        canRetryTool = false
        isToolSubmissionPending = false
    }
    
    private func handleRequestCancelled(sessionID: UUID) {
        // Reject stale events
        guard let currentID = currentSessionID, sessionID == currentID else {
            return
        }
        
        isProcessing = false
        isClarificationPending = false
        isConfirmationPending = false
        currentToolActivity = nil
        canRetryTool = false
        isToolSubmissionPending = false
    }
    
    private func handleRequestFailed(sessionID: UUID, error: String) {
        // Reject stale events
        guard let currentID = currentSessionID, sessionID == currentID else {
            return
        }
        
        isProcessing = false
        lastError = error
        currentToolActivity = nil
        isToolSubmissionPending = false
    }
    
    private func handleAvatarStateChanged(state: AvatarState) {
        avatarState = state
    }
    
    private func handleAudioStateChanged(isPlaying: Bool) {
        self.isAudioPlaying = isPlaying
    }
    
    private func handleMuteStateChanged(isMuted: Bool) {
        self.isMuted = isMuted
    }
    
    private func handleClarificationRequested(sessionID: UUID, question: String, candidates: [ClarificationCandidate]) {
        // Reject stale events
        guard let currentID = currentSessionID, sessionID == currentID else {
            return
        }
        
        isClarificationPending = true
        clarificationQuestion = question
        clarificationCandidates = candidates
    }
    
    private func handleClarificationResolved(sessionID: UUID) {
        // Reject stale events
        guard let currentID = currentSessionID, sessionID == currentID else {
            return
        }
        
        isClarificationPending = false
        clarificationQuestion = nil
        clarificationCandidates = []
        isToolSubmissionPending = false
    }
    
    private func handleConfirmationRequested(sessionID: UUID, action: String) {
        // Reject stale events
        guard let currentID = currentSessionID, sessionID == currentID else {
            return
        }
        
        isConfirmationPending = true
        confirmationAction = action
    }
    
    private func handleConfirmationResolved(sessionID: UUID) {
        // Reject stale events
        guard let currentID = currentSessionID, sessionID == currentID else {
            return
        }
        
        isConfirmationPending = false
        confirmationAction = nil
        isToolSubmissionPending = false
    }
    
    private func handleToolStarted(sessionID: UUID, activity: String) {
        // Reject stale events
        guard let currentID = currentSessionID, sessionID == currentID else {
            return
        }
        
        currentToolActivity = activity
    }
    
    private func handleToolFinished(sessionID: UUID) {
        // Reject stale events
        guard let currentID = currentSessionID, sessionID == currentID else {
            return
        }
        
        currentToolActivity = nil
        canRetryTool = false
    }
    
    private func handleRecoveryAvailable(sessionID: UUID, canRetry: Bool) {
        // Reject stale events
        guard let currentID = currentSessionID, sessionID == currentID else {
            return
        }
        
        canRetryTool = canRetry
    }
    
    // MARK: - User Actions
    
    /// Sends a user message to the backend.
    /// - Parameter text: The user message to send
    public func sendMessage(_ text: String) async {
        do {
            _ = try await coordinator.handleUserInput(text)
            
            // Update messages from conversation
            await updateMessages()
        } catch {
            lastError = error.localizedDescription
        }
    }
    
    /// Updates messages from the coordinator's conversation history.
    private func updateMessages() async {
        let conversation = await coordinator.getConversation()
        messages = conversation.map { ConversationMessageViewData.from($0) }
    }
    
    /// Cancels the current request.
    public func cancelRequest() async {
        await coordinator.cancelCurrentRequest()
    }
    
    /// Clears the conversation history.
    public func clearConversation() async {
        await coordinator.clearConversation()
        lastError = nil
        clarificationQuestion = nil
        clarificationCandidates = []
        confirmationAction = nil
        currentToolActivity = nil
        canRetryTool = false
        isToolSubmissionPending = false
        await updateMessages()
    }
    
    /// Responds to a clarification request.
    /// - Parameter answer: The user's answer to the clarification
    public func respondToClarification(_ answer: String) async {
        guard !isToolSubmissionPending else { return }
        isToolSubmissionPending = true
        
        do {
            _ = try await coordinator.handleUserInput(answer)
        } catch {
            lastError = error.localizedDescription
        }
    }
    
    /// Selects a clarification candidate by position.
    /// - Parameter position: The 1-based position of the candidate
    public func selectClarificationCandidate(_ position: Int) async {
        guard !isToolSubmissionPending else { return }
        isToolSubmissionPending = true
        
        let answer = String(position)
        do {
            _ = try await coordinator.handleUserInput(answer)
        } catch {
            lastError = error.localizedDescription
        }
    }
    
    /// Cancels a pending clarification.
    public func cancelClarification() async {
        guard !isToolSubmissionPending else { return }
        isToolSubmissionPending = true
        
        do {
            _ = try await coordinator.handleUserInput("batal")
        } catch {
            lastError = error.localizedDescription
        }
    }
    
    /// Responds to a confirmation request.
    /// - Parameter approved: Whether the user approved the action
    public func respondToConfirmation(_ approved: Bool) async {
        guard !isToolSubmissionPending else { return }
        isToolSubmissionPending = true
        
        let response = approved ? "ya" : "tidak"
        do {
            _ = try await coordinator.handleUserInput(response)
        } catch {
            lastError = error.localizedDescription
        }
    }
    
    /// Retries a failed tool action.
    public func retryTool() async {
        guard !isToolSubmissionPending else { return }
        isToolSubmissionPending = true
        
        do {
            _ = try await coordinator.handleUserInput("coba lagi")
        } catch {
            lastError = error.localizedDescription
        }
    }
    
    /// Sets the mute state.
    /// - Parameter muted: Whether to mute audio
    public func setMuted(_ muted: Bool) async {
        // This needs to be added to AssistantCoordinator
        // For now, this is a placeholder
        // In a future update, we should add a dedicated setMuted() method
    }
    
    /// Stops current speech playback.
    public func stopSpeech() async {
        // This needs to be added to AssistantCoordinator
        // For now, this is a placeholder
        // In a future update, we should add a dedicated stopSpeech() method
    }
    
    // MARK: - Cleanup
    
    /// Cancels the event stream subscription.
    public func cancelEventStream() {
        eventStreamTask?.cancel()
        eventStreamTask = nil
    }
}
