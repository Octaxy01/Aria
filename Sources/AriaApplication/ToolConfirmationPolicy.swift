import Foundation
import AriaDomain

/// Policy for determining whether a tool execution requires user confirmation.
/// Uses ToolDefinition risk metadata to make deterministic decisions.
/// Provider-independent and does not depend on LLM output.
public actor ToolConfirmationPolicy {
    
    public init() {}
    
    /// Determines whether a tool requires confirmation before execution.
    /// - Parameters:
    ///   - toolDefinition: The tool definition to evaluate
    ///   - toolCall: The specific tool call being made
    /// - Returns: True if confirmation is required, false otherwise
    public func requiresConfirmation(
        toolDefinition: ToolDefinition,
        toolCall: ToolCall
    ) -> Bool {
        // Explicit confirmation flag in definition takes precedence
        if toolDefinition.requiresConfirmation {
            return true
        }
        
        // Destructive tools always require confirmation
        if toolDefinition.riskLevel == .destructive {
            return true
        }
        
        // Safe tools do not require confirmation
        if toolDefinition.riskLevel == .safe {
            return false
        }
        
        // Sensitive tools: evaluate based on operation type
        // Read/search operations typically don't need confirmation
        // But we defer to the explicit requiresConfirmation flag
        return false
    }
    
    /// Generates a user-friendly confirmation message for a tool call.
    /// - Parameters:
    ///   - toolDefinition: The tool definition
    ///   - toolCall: The tool call being confirmed
    /// - Returns: Natural Indonesian confirmation message
    public func confirmationMessage(
        toolDefinition: ToolDefinition,
        toolCall: ToolCall
    ) -> String {
        // Generate a natural confirmation message without exposing technical details
        return "Aku perlu konfirmasi dulu sebelum melakukan itu. Lanjut?"
    }
}
