import Foundation

/// Parses user answers to clarification requests.
public struct ClarificationAnswerParser {
    
    public init() {}
    
    /// Parses a user's answer to a clarification request.
    /// - Parameters:
    ///   - answer: The user's answer text
    ///   - clarification: The clarification request being answered
    /// - Returns: The parsed answer
    public func parseAnswer(_ answer: String, clarification: ClarificationRequest) -> ClarificationAnswer {
        let trimmedAnswer = answer.trimmingCharacters(in: .whitespacesAndNewlines).lowercased()
        
        // Check for cancellation
        if isCancellation(trimmedAnswer) {
            return .cancelled
        }
        
        // Try to parse as number
        if let position = parsePosition(trimmedAnswer) {
            return .selectedPosition(position)
        }
        
        // Try to match by name
        if let entity = matchByName(trimmedAnswer, candidates: clarification.candidates) {
            return .selectedEntity(entity)
        }
        
        // Try Indonesian positional phrases
        if let position = parseIndonesianPosition(trimmedAnswer) {
            return .selectedPosition(position)
        }
        
        return .invalid
    }
    
    /// Checks if the answer indicates cancellation.
    /// - Parameter answer: The trimmed answer
    /// - Returns: True if cancelled
    private func isCancellation(_ answer: String) -> Bool {
        let cancellationKeywords = ["batal", "cancel", "tidak", "no", "skip", "lewat"]
        return cancellationKeywords.contains(answer)
    }
    
    /// Parses a numeric position from the answer.
    /// - Parameter answer: The trimmed answer
    /// - Returns: The position if valid, nil otherwise
    private func parsePosition(_ answer: String) -> Int? {
        // Extract first number from the answer
        let numbers = answer.filter { $0.isNumber }
        guard !numbers.isEmpty else {
            return nil
        }
        
        guard let position = Int(numbers) else {
            return nil
        }
        
        // Validate position is positive
        guard position > 0 else {
            return nil
        }
        
        return position
    }
    
    /// Matches an entity by name from the candidates.
    /// - Parameters:
    ///   - answer: The trimmed answer
    ///   - candidates: The candidate entities
    /// - Returns: The matched entity if found, nil otherwise
    private func matchByName(_ answer: String, candidates: [RuntimeEntity]) -> RuntimeEntity? {
        for candidate in candidates {
            let displayName = candidate.displayName.lowercased()
            if displayName.contains(answer) || answer.contains(displayName) {
                return candidate
            }
        }
        return nil
    }
    
    /// Parses Indonesian positional phrases.
    /// - Parameter answer: The trimmed answer
    /// - Returns: The position if valid, nil otherwise
    private func parseIndonesianPosition(_ answer: String) -> Int? {
        // Map Indonesian phrases to positions
        let phraseMap: [String: Int] = [
            "yang pertama": 1,
            "yang kedua": 2,
            "yang ketiga": 3,
            "yang keempat": 4,
            "yang kelima": 5,
            "pertama": 1,
            "kedua": 2,
            "ketiga": 3,
            "keempat": 4,
            "kelima": 5,
            "nomor satu": 1,
            "nomor dua": 2,
            "nomor tiga": 3,
            "nomor empat": 4,
            "nomor lima": 5,
            "no 1": 1,
            "no 2": 2,
            "no 3": 3,
            "no 4": 4,
            "no 5": 5
        ]
        
        for (phrase, position) in phraseMap {
            if answer.contains(phrase) {
                return position
            }
        }
        
        return nil
    }
}
