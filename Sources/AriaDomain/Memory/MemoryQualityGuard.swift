import Foundation

/// Memory quality guard for filtering memory candidates before storage.
/// Prevents storing low-quality, temporary, or irrelevant information.
public struct MemoryQualityGuard {
    
    /// Configuration for quality filtering rules.
    public struct Configuration {
        public let minConfidence: Double
        public let rejectHypothetical: Bool
        public let rejectQuestions: Bool
        public let rejectJokes: Bool
        public let rejectSarcasm: Bool
        public let rejectTemporaryEmotions: Bool
        public let rejectInstructions: Bool
        
        public init(
            minConfidence: Double = 0.7,
            rejectHypothetical: Bool = true,
            rejectQuestions: Bool = true,
            rejectJokes: Bool = true,
            rejectSarcasm: Bool = true,
            rejectTemporaryEmotions: Bool = true,
            rejectInstructions: Bool = true
        ) {
            self.minConfidence = minConfidence
            self.rejectHypothetical = rejectHypothetical
            self.rejectQuestions = rejectQuestions
            self.rejectJokes = rejectJokes
            self.rejectSarcasm = rejectSarcasm
            self.rejectTemporaryEmotions = rejectTemporaryEmotions
            self.rejectInstructions = rejectInstructions
        }
        
        public static let `default` = Configuration()
    }
    
    private let configuration: Configuration
    
    public init(configuration: Configuration = .default) {
        self.configuration = configuration
    }
    
    /// Evaluate whether a memory candidate should be stored.
    /// Returns true if the candidate passes quality checks.
    public func shouldStore(_ candidate: MemoryCandidate) -> Bool {
        // Check confidence threshold
        guard candidate.confidence >= configuration.minConfidence else {
            return false
        }
        
        let content = candidate.content.lowercased()
        
        // Reject hypothetical statements
        if configuration.rejectHypothetical && isHypothetical(content) {
            return false
        }
        
        // Reject questions
        if configuration.rejectQuestions && isQuestion(content) {
            return false
        }
        
        // Reject jokes
        if configuration.rejectJokes && isJoke(content) {
            return false
        }
        
        // Reject sarcasm markers
        if configuration.rejectSarcasm && isSarcastic(content) {
            return false
        }
        
        // Reject temporary emotional states
        if configuration.rejectTemporaryEmotions && isTemporaryEmotion(content) {
            return false
        }
        
        // Reject instructions directed at Aria
        if configuration.rejectInstructions && isInstruction(content) {
            return false
        }
        
        return true
    }
    
    // MARK: - Private Detection Methods
    
    private func isHypothetical(_ content: String) -> Bool {
        let hypotheticalMarkers = [
            "kalau", "jika", "seandainya", "misalnya", "kayaknya", "kira-kira",
            "if", "suppose", "maybe", "perhaps", "i guess", "probably"
        ]
        
        return hypotheticalMarkers.contains { content.contains($0) }
    }
    
    private func isQuestion(_ content: String) -> Bool {
        return content.hasSuffix("?") ||
               content.starts(with: "apa") ||
               content.starts(with: "siapa") ||
               content.starts(with: "kapan") ||
               content.starts(with: "di mana") ||
               content.starts(with: "bagaimana") ||
               content.starts(with: "what") ||
               content.starts(with: "who") ||
               content.starts(with: "when") ||
               content.starts(with: "where") ||
               content.starts(with: "how")
    }
    
    private func isJoke(_ content: String) -> Bool {
        let jokeMarkers = [
            "bercanda", "kidding", "just kidding", "bukan serius", "not serious",
            "lelucon", "joke", "beneran", "serius tapi", "seriously but"
        ]
        
        return jokeMarkers.contains { content.contains($0) }
    }
    
    private func isSarcastic(_ content: String) -> Bool {
        let sarcasmMarkers = [
            "ya kan", "yeah right", "oh really",
            "tentu saja", "obviously", "of course"
        ]
        
        // "heh", "ha ha", "haha" can be genuine reactions, not always sarcasm
        // "bodoh", "stupid" can be genuine frustration, not sarcasm
        return sarcasmMarkers.contains { content.contains($0) }
    }
    
    private func isTemporaryEmotion(_ content: String) -> Bool {
        let temporaryEmotionMarkers = [
            "lagi capek", "lagi lelah", "lagi marah", "lagi sedih", "lagi bosan",
            "tired right now", "angry right now", "sad right now", "bored right now",
            "hari ini", "today", "sekarang", "right now", "saat ini"
        ]
        
        // Only reject if it's purely emotional without substantive content
        let hasSubstantiveContent = content.contains("suka") ||
                                    content.contains("tidak suka") ||
                                    content.contains("kerja") ||
                                    content.contains("project") ||
                                    content.contains("like") ||
                                    content.contains("work")
        
        let hasTemporaryMarker = temporaryEmotionMarkers.contains { content.contains($0) }
        
        return hasTemporaryMarker && !hasSubstantiveContent
    }
    
    private func isInstruction(_ content: String) -> Bool {
        let instructionMarkers = [
            "lakukan", "do this", "tolong", "please", "jangan", "don't",
            "ingat", "remember", "catat", "note this", "perhatikan", "pay attention"
        ]
        
        return instructionMarkers.contains { content.contains($0) }
    }
}
