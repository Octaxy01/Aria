import Foundation
import AriaDomain

/// Policy for handling tool execution failures and determining recovery actions.
/// Implements deterministic recovery behavior based on error category.
public actor ToolFailureRecoveryPolicy {
    
    public init() {}
    
    /// Maximum number of automatic retries allowed.
    private let maxRetries: Int = 1
    
    /// Determines whether a tool execution should be retried after a failure.
    /// - Parameters:
    ///   - errorCategory: The category of the error that occurred
    ///   - currentRetryCount: How many times this operation has already been retried
    ///   - toolCall: The tool call that failed
    ///   - sessionID: The current session ID
    /// - Returns: True if a retry should be attempted, false otherwise
    public func shouldRetry(
        errorCategory: ToolErrorCategory,
        currentRetryCount: Int,
        toolCall: ToolCall,
        sessionID: UUID
    ) -> Bool {
        // Never exceed max retries
        guard currentRetryCount < maxRetries else {
            return false
        }
        
        // Stale session: never retry
        if errorCategory == .staleSession {
            return false
        }
        
        // Cancelled: never retry
        if errorCategory == .cancelled {
            return false
        }
        
        // Permission denied: never retry (macOS won't change its mind)
        if errorCategory == .permissionDenied {
            return false
        }
        
        // Not found: don't blindly retry
        if errorCategory == .notFound {
            return false
        }
        
        // Unavailable: don't repeatedly execute
        if errorCategory == .unavailable {
            return false
        }
        
        // Invalid arguments: bounded recovery only if obvious from context
        if errorCategory == .invalidArguments {
            // For now, don't automatically retry - ask user for correct info
            return false
        }
        
        // Execution failed: allow one bounded retry if conditions are met
        if errorCategory == .executionFailed {
            return true
        }
        
        return false
    }
    
    /// Generates a user-friendly failure message for a given error category.
    /// - Parameters:
    ///   - errorCategory: The category of the error
    ///   - toolCall: The tool call that failed
    /// - Returns: Natural Indonesian failure message
    public func failureMessage(
        errorCategory: ToolErrorCategory,
        toolCall: ToolCall
    ) -> String {
        switch errorCategory {
        case .notFound:
            return "Maaf, itu nggak ditemukan."
        case .unavailable:
            return "Maaf, operasi itu nggak tersedia sekarang."
        case .permissionDenied:
            return "Maaf, macOS nggak mengizinkan akses ke itu."
        case .invalidArguments:
            return "Maaf, ada yang salah dengan informasi yang diberikan."
        case .cancelled:
            return "Oke, dibatalkan."
        case .executionFailed:
            return "Maaf, ada kesalahan saat menjalankan itu."
        case .staleSession:
            return "Maaf, sesi sudah kadaluarsa."
        }
    }
    
    /// Determines whether a failure should suggest an alternative action to the user.
    /// - Parameters:
    ///   - errorCategory: The category of the error
    ///   - toolCall: The tool call that failed
    /// - Returns: Suggestion message if appropriate, nil otherwise
    public func suggestion(
        errorCategory: ToolErrorCategory,
        toolCall: ToolCall
    ) -> String? {
        switch errorCategory {
        case .notFound:
            if toolCall.toolIdentifier == ToolIdentifier.openApplication {
                return "Mau aku cari aplikasi lain?"
            }
            return nil
        default:
            return nil
        }
    }
}
