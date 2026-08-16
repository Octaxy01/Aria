import Foundation
import AriaDomain

/// Manages the current desktop task context for multi-turn conversations.
/// This actor maintains a single active task context that answers "What is the user currently doing?"
/// Separate from RuntimeEntityContext (which tracks recent entities) and MemoryService (long-term memory).
public actor TaskContextManager {
    
    /// Current active task context (only one at a time)
    private var currentTask: DesktopTaskContext?
    
    /// Current session ID for validation
    private var currentSessionID: UUID?
    
    public init() {}
    
    /// Sets the current session ID for task context validation.
    /// - Parameter sessionID: The session ID to set
    public func setSessionID(_ sessionID: UUID) {
        currentSessionID = sessionID
    }
    
    /// Updates or creates the current task context based on a tool result.
    /// - Parameters:
    ///   - taskKind: The kind of task
    ///   - targetEntityKind: The kind of entity this task targets
    ///   - scope: The scope of the task (e.g., "Downloads")
    ///   - results: Results from this task (e.g., search results)
    ///   - sessionID: The session ID for validation
    public func updateTask(
        taskKind: TaskKind,
        targetEntityKind: EntityKind? = nil,
        scope: String? = nil,
        results: [TaskResult] = [],
        sessionID: UUID
    ) {
        // Validate session
        guard currentSessionID == sessionID else {
            return
        }
        
        // Create or update task
        currentTask = DesktopTaskContext(
            sessionID: sessionID,
            taskKind: taskKind,
            targetEntityKind: targetEntityKind,
            scope: scope,
            recentResults: results,
            createdAt: currentTask?.createdAt ?? Date(),
            updatedAt: Date()
        )
    }
    
    /// Updates the current task with new results.
    /// - Parameters:
    ///   - results: New results to add
    ///   - sessionID: The session ID for validation
    public func updateResults(_ results: [TaskResult], sessionID: UUID) {
        guard currentSessionID == sessionID, let existingTask = currentTask else {
            return
        }
        
        currentTask = existingTask.withUpdatedResults(results)
    }
    
    /// Retrieves the current task context.
    /// - Parameter sessionID: The session ID for validation
    /// - Returns: The current task context, or nil if none exists or session mismatch
    public func getCurrentTask(sessionID: UUID) -> DesktopTaskContext? {
        guard currentSessionID == sessionID else {
            return nil
        }
        
        return currentTask
    }
    
    /// Clears the current task context.
    /// - Parameter sessionID: The session ID for validation
    public func clearTask(sessionID: UUID) {
        guard currentSessionID == sessionID else {
            return
        }
        
        currentTask = nil
    }
    
    /// Clears all task context (for clear/stop commands).
    public func clearAll() {
        currentTask = nil
    }
    
    /// Checks if there is a current task of a specific kind.
    /// - Parameters:
    ///   - taskKind: The task kind to check
    ///   - sessionID: The session ID for validation
    /// - Returns: True if there is a current task of the specified kind
    public func hasTask(kind taskKind: TaskKind, sessionID: UUID) -> Bool {
        guard currentSessionID == sessionID else {
            return false
        }
        
        return currentTask?.taskKind == taskKind
    }
    
    /// Resolves a follow-up intent against the current task context.
    /// - Parameters:
    ///   - intent: The follow-up intent to resolve
    ///   - sessionID: The session ID for validation
    /// - Returns: Resolution result with the selected entity or appropriate error
    public func resolveFollowUp(_ intent: FollowUpIntent, sessionID: UUID) -> TaskResolutionResult {
        guard currentSessionID == sessionID, let task = currentTask else {
            return .noCurrentTask
        }
        
        switch intent {
        case .newest:
            return resolveNewest(task)
        case .oldest:
            return resolveOldest(task)
        case .positional(let position):
            return resolvePositional(position, in: task)
        case .continuation:
            return resolveContinuation(task)
        }
    }
    
    // MARK: - Resolution Helpers
    
    private func resolveNewest(_ task: DesktopTaskContext) -> TaskResolutionResult {
        guard !task.recentResults.isEmpty else {
            return .noResults
        }
        
        // Filter results with modification dates
        let datedResults = task.recentResults.filter { $0.modificationDate != nil }
        
        guard !datedResults.isEmpty else {
            // No modification dates available - cannot determine newest
            return .metadataUnavailable
        }
        
        // Find the result with the newest modification date
        guard let newest = datedResults.max(by: { a, b in
            guard let dateA = a.modificationDate, let dateB = b.modificationDate else {
                return false
            }
            return dateA < dateB
        }) else {
            return .metadataUnavailable
        }
        
        return .resolved(TaskResultEntity(
            displayName: newest.displayName,
            path: newest.path,
            applicationIdentifier: newest.applicationIdentifier
        ))
    }
    
    private func resolveOldest(_ task: DesktopTaskContext) -> TaskResolutionResult {
        guard !task.recentResults.isEmpty else {
            return .noResults
        }
        
        // Filter results with modification dates
        let datedResults = task.recentResults.filter { $0.modificationDate != nil }
        
        guard !datedResults.isEmpty else {
            // No modification dates available - cannot determine oldest
            return .metadataUnavailable
        }
        
        // Find the result with the oldest modification date
        guard let oldest = datedResults.min(by: { a, b in
            guard let dateA = a.modificationDate, let dateB = b.modificationDate else {
                return false
            }
            return dateA < dateB
        }) else {
            return .metadataUnavailable
        }
        
        return .resolved(TaskResultEntity(
            displayName: oldest.displayName,
            path: oldest.path,
            applicationIdentifier: oldest.applicationIdentifier
        ))
    }
    
    private func resolvePositional(_ position: Int, in task: DesktopTaskContext) -> TaskResolutionResult {
        guard !task.recentResults.isEmpty else {
            return .noResults
        }
        
        guard position >= 1 && position <= task.recentResults.count else {
            return .invalidPosition
        }
        
        let result = task.recentResults[position - 1]
        
        return .resolved(TaskResultEntity(
            displayName: result.displayName,
            path: result.path,
            applicationIdentifier: result.applicationIdentifier
        ))
    }
    
    private func resolveContinuation(_ task: DesktopTaskContext) -> TaskResolutionResult {
        // For continuation, return the most recent result
        guard !task.recentResults.isEmpty else {
            return .noResults
        }
        
        let result = task.recentResults[0]
        
        return .resolved(TaskResultEntity(
            displayName: result.displayName,
            path: result.path,
            applicationIdentifier: result.applicationIdentifier
        ))
    }
}

/// Follow-up intent patterns for task context resolution.
public enum FollowUpIntent: Sendable {
    case newest
    case oldest
    case positional(Int)
    case continuation
}

/// Result of resolving a follow-up intent against task context.
public enum TaskResolutionResult: Sendable {
    case resolved(TaskResultEntity)
    case noCurrentTask
    case noResults
    case metadataUnavailable
    case invalidPosition
}

/// Entity resolved from task context.
public struct TaskResultEntity: Sendable {
    public let displayName: String
    public let path: String?
    public let applicationIdentifier: String?
}
