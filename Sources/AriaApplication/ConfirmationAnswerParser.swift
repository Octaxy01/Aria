import Foundation

/// Parses user answers to confirmation requests.
/// Supports natural concise Indonesian and English responses.
public struct ConfirmationAnswerParser {
    
    /// Result of parsing a confirmation answer.
    public enum Answer: Sendable, Equatable {
        case confirmed
        case rejected
        case cancelled
        case ambiguous
    }
    
    /// Parses a user message to determine if it's a confirmation answer.
    /// - Parameter message: The user's message
    /// - Returns: The parsed answer
    public func parse(_ message: String) -> Answer {
        let normalized = message.lowercased().trimmingCharacters(in: .whitespaces)
        
        // Positive confirmation patterns (Indonesian, English, Russian, Japanese)
        let positivePatterns = [
            // Indonesian
            "ya", "iya", "boleh", "lanjut", "lakukan",
            // English
            "yes", "ok", "oke", "y", "yup", "okay", "continue",
            // Russian
            "да", "хорошо", "ок", "ладно",
            // Japanese
            "はい", "いいよ", "ok", "ok"
        ]
        for pattern in positivePatterns {
            if normalized == pattern || normalized.hasPrefix(pattern) {
                return .confirmed
            }
        }
        
        // Cancellation patterns (checked before negative patterns)
        let cancelPatterns = [
            // Indonesian
            "batal",
            // English
            "cancel", "stop",
            // Russian
            "отмена", "отменить",
            // Japanese
            "キャンセル"
        ]
        for pattern in cancelPatterns {
            if normalized == pattern || normalized.hasPrefix(pattern) {
                return .cancelled
            }
        }
        
        // Negative rejection patterns (Indonesian, English, Russian, Japanese)
        let negativePatterns = [
            // Indonesian
            "tidak", "jangan", "nggak",
            // English
            "no", "n", "nope",
            // Russian
            "нет", "не",
            // Japanese
            "いいえ", "ダメ"
        ]
        for pattern in negativePatterns {
            if normalized == pattern || normalized.hasPrefix(pattern) {
                return .rejected
            }
        }
        
        // If none match, it's ambiguous - don't execute
        return .ambiguous
    }
    
    /// Determines if a message is likely a confirmation answer.
    /// - Parameter message: The user's message
    /// - Returns: True if the message appears to be a confirmation answer
    public func isConfirmationAnswer(_ message: String) -> Bool {
        let answer = parse(message)
        return answer != .ambiguous
    }
}
