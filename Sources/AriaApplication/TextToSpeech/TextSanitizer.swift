import Foundation
import AriaDomain

/// Sanitizes LLM responses for TTS synthesis.
/// Removes non-spoken markers while preserving natural speech patterns.
public struct TextSanitizer {
    
    /// Patterns to remove from TTS text.
    private static let removePatterns: [String] = [
        // Action/emotion markers
        "\\*tertawa\\*",
        "\\*laughs\\*",
        "\\*senyum\\*",
        "\\*tersenyum\\*",
        "\\*tersenyum\\*",
        "\\*tersenyun\\*",
        "\\*ketawa\\*",
        "\\*tawa\\*",
        
        // Stage directions
        "\\[smiles\\]",
        "\\[frowns\\]",
        "\\[nods\\]",
        "\\[shrugs\\]",
        "\\[winks\\]",
        "\\[looks at you\\]",
        "\\[thinks\\]",
        
        // TTS command-like patterns
        "Voice:",
        "Speaker:",
        "TTS:",
        "Speech:",
    ]
    
    /// Patterns to remove entirely (including surrounding context)
    private static let removeEntirePatterns: [String] = [
        // JSON/emotion metadata
        "\\{\\s*\"text\"\\s*:\\s*\"[^\"]*\"\\s*,\\s*\"emotion\"\\s*:\\s*\\{[^}]*\\}\\s*\\}",
        "\\{\\s*\"emotion\"\\s*:\\s*\\{[^}]*\\}\\s*\\}",
    ]
    
    /// Characters/patterns to replace with spoken alternatives.
    private static let replacements: [(pattern: String, replacement: String)] = [
        // Emoji descriptions to remove
        ("😊", ""),
        ("😂", ""),
        ("🤣", ""),
        ("😍", ""),
        ("❤", ""),
        ("💕", ""),
        ("😊", ""),
        ("🙏", ""),
        ("😔", ""),
        ("😢", ""),
        ("😡", ""),
        ("🤔", ""),
        ("😎", ""),
        ("🎉", ""),
        ("⭐", ""),
        
        // Common markdown for TTS
        ("\\*\\*([^*]+)\\*\\*", "$1"), // Bold -> plain
        ("\\*([^*]+)\\*", "$1"),       // Italic -> plain
        ("_([^_]+)_", "$1"),           // Underline -> plain
        ("~~([^~]+)~~", "$1"),        // Strikethrough -> plain
        ("`([^`]+)`", "$1")            // Inline code -> plain
    ]
    
    /// Code block patterns to remove.
    private static let codeBlockPatterns: [String] = [
        "```[\\s\\S]*?```",
        "`[^`]+`",
    ]
    
    /// Removes non-spoken markers from LLM responses.
    public func sanitize(_ text: String) -> String {
        var sanitized = text
        
        // Remove action/emotion markers
        for pattern in TextSanitizer.removePatterns {
            sanitized = sanitized.replacingOccurrences(of: pattern, with: "", options: .regularExpression)
        }
        
        // Remove stage directions
        for pattern in TextSanitizer.removePatterns {
            sanitized = sanitized.replacingOccurrences(of: pattern, with: "", options: .regularExpression)
        }
        
        // Remove JSON/emotion metadata blocks
        for pattern in TextSanitizer.removeEntirePatterns {
            sanitized = sanitized.replacingOccurrences(of: pattern, with: "", options: .regularExpression)
        }
        
        // Remove code blocks
        for pattern in TextSanitizer.codeBlockPatterns {
            sanitized = sanitized.replacingOccurrences(of: pattern, with: "", options: .regularExpression)
        }
        
        // Apply replacements (emoji, markdown)
        for (pattern, replacement) in TextSanitizer.replacements {
            sanitized = sanitized.replacingOccurrences(of: pattern, with: replacement, options: .regularExpression)
        }
        
        // Clean up multiple spaces and line breaks
        sanitized = sanitized.replacingOccurrences(of: "  +", with: " ", options: .regularExpression)
        sanitized = sanitized.replacingOccurrences(of: "\\n\\n+", with: "\\n\\n", options: .regularExpression)
        
        // Trim whitespace
        sanitized = sanitized.trimmingCharacters(in: .whitespacesAndNewlines)
        
        return sanitized
    }
    
    /// Checks if text is too long for comfortable TTS.
    public func isTooLong(_ text: String, maxLength: Int = 500) -> Bool {
        return text.count > maxLength
    }
    
    /// Truncates text to appropriate length for TTS.
    public func truncate(_ text: String, maxLength: Int = 500) -> String {
        guard text.count > maxLength else { return text }
        
        let truncated = String(text.prefix(maxLength))
        // Try to end at a sentence boundary
        if let lastSentenceEnd = truncated.range(of: ". ", options: .backwards)?.upperBound {
            return String(truncated[..<lastSentenceEnd])
        }
        
        return truncated + "..."
    }
    
    /// Extracts spoken text from potentially mixed content.
    public func extractSpokenText(_ text: String) -> String {
        // Remove JSON metadata if present
        let withoutJson = text.replacingOccurrences(of: "\\{[^}]*\"text\"\\s*:\\s*\"[^\"]*\"\\s*\\}", with: "", options: .regularExpression)
        
        // Remove JSON blocks entirely
        let withoutJsonBlocks = withoutJson.replacingOccurrences(of: "\\{\\s*\"[^\"]*\"\\s*:\\s*\\{[^}]*\\}\\s*\\}", with: "", options: .regularExpression)
        
        return withoutJsonBlocks.trimmingCharacters(in: .whitespacesAndNewlines)
    }
}