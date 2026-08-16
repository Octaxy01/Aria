import Foundation

/// Memory relevance scoring system for intelligent memory retrieval.
/// Provides deterministic, weighted scoring for memory candidates based on multiple factors.
public struct MemoryRelevanceScoring {
    
    /// Represents a scored memory with its relevance calculation.
    public struct ScoredMemory {
        public let memory: MemoryEntry
        public let relevanceScore: Double
        public let breakdown: ScoreBreakdown
        
        public init(memory: MemoryEntry, relevanceScore: Double, breakdown: ScoreBreakdown) {
            self.memory = memory
            self.relevanceScore = relevanceScore
            self.breakdown = breakdown
        }
    }
    
    /// Breakdown of how a memory's relevance score was calculated.
    public struct ScoreBreakdown {
        public let keywordScore: Double
        public let categoryScore: Double
        public let importanceScore: Double
        public let recencyScore: Double
        public let exactMatchBonus: Double
        public let contextualScore: Double
        
        public init(
            keywordScore: Double,
            categoryScore: Double,
            importanceScore: Double,
            recencyScore: Double,
            exactMatchBonus: Double,
            contextualScore: Double
        ) {
            self.keywordScore = keywordScore
            self.categoryScore = categoryScore
            self.importanceScore = importanceScore
            self.recencyScore = recencyScore
            self.exactMatchBonus = exactMatchBonus
            self.contextualScore = contextualScore
        }
    }
    
    /// Scoring configuration with weights for each factor.
    public struct Configuration {
        public let keywordWeight: Double
        public let categoryWeight: Double
        public let importanceWeight: Double
        public let recencyWeight: Double
        public let exactMatchBonus: Double
        public let contextualWeight: Double
        
        public init(
            keywordWeight: Double = 0.3,
            categoryWeight: Double = 0.2,
            importanceWeight: Double = 0.15,
            recencyWeight: Double = 0.15,
            exactMatchBonus: Double = 0.2,
            contextualWeight: Double = 0.1
        ) {
            self.keywordWeight = keywordWeight
            self.categoryWeight = categoryWeight
            self.importanceWeight = importanceWeight
            self.recencyWeight = recencyWeight
            self.exactMatchBonus = exactMatchBonus
            self.contextualWeight = contextualWeight
        }
        
        public static let `default` = Configuration()
    }
    
    private let configuration: Configuration
    
    public init(configuration: Configuration = .default) {
        self.configuration = configuration
    }
    
    /// Score a memory against a user message for relevance.
    /// Returns a score between 0.0 and 1.0, where higher is more relevant.
    public func score(memory: MemoryEntry, against userMessage: String) -> ScoredMemory {
        let breakdown = calculateBreakdown(memory: memory, userMessage: userMessage)
        let relevanceScore = calculateTotalScore(breakdown: breakdown)
        
        return ScoredMemory(
            memory: memory,
            relevanceScore: relevanceScore,
            breakdown: breakdown
        )
    }
    
    /// Score multiple memories and return them sorted by relevance.
    public func scoreAndSort(memories: [MemoryEntry], against userMessage: String) -> [ScoredMemory] {
        return memories
            .map { score(memory: $0, against: userMessage) }
            .sorted { $0.relevanceScore > $1.relevanceScore }
    }
    
    // MARK: - Private Scoring Methods
    
    private func calculateBreakdown(memory: MemoryEntry, userMessage: String) -> ScoreBreakdown {
        let keywordScore = calculateKeywordScore(memory: memory, userMessage: userMessage)
        let categoryScore = calculateCategoryScore(memory: memory, userMessage: userMessage)
        let importanceScore = calculateImportanceScore(memory: memory)
        let recencyScore = calculateRecencyScore(memory: memory)
        let exactMatchBonus = calculateExactMatchBonus(memory: memory, userMessage: userMessage)
        let contextualScore = calculateContextualScore(memory: memory, userMessage: userMessage)
        
        return ScoreBreakdown(
            keywordScore: keywordScore,
            categoryScore: categoryScore,
            importanceScore: importanceScore,
            recencyScore: recencyScore,
            exactMatchBonus: exactMatchBonus,
            contextualScore: contextualScore
        )
    }
    
    private func calculateTotalScore(breakdown: ScoreBreakdown) -> Double {
        return breakdown.keywordScore * configuration.keywordWeight
            + breakdown.categoryScore * configuration.categoryWeight
            + breakdown.importanceScore * configuration.importanceWeight
            + breakdown.recencyScore * configuration.recencyWeight
            + breakdown.exactMatchBonus * configuration.exactMatchBonus
            + breakdown.contextualScore * configuration.contextualWeight
    }
    
    private func calculateKeywordScore(memory: MemoryEntry, userMessage: String) -> Double {
        let memoryWords = extractWords(memory.content.lowercased())
        let messageWords = extractWords(userMessage.lowercased())
        
        guard !memoryWords.isEmpty && !messageWords.isEmpty else {
            return 0.0
        }
        
        let overlap = Set(memoryWords).intersection(Set(messageWords))
        let overlapRatio = Double(overlap.count) / Double(max(memoryWords.count, messageWords.count))
        
        return min(1.0, overlapRatio * 2.0) // Boost overlap slightly
    }
    
    private func calculateCategoryScore(memory: MemoryEntry, userMessage: String) -> Double {
        let categoryKeywords = categoryKeywordsFor(memory.category)
        let messageLower = userMessage.lowercased()
        
        let keywordMatches = categoryKeywords.filter { messageLower.contains($0) }
        let matchRatio = Double(keywordMatches.count) / Double(max(1, categoryKeywords.count))
        
        return matchRatio
    }
    
    private func calculateImportanceScore(memory: MemoryEntry) -> Double {
        switch memory.importance {
        case .low: return 0.25
        case .normal: return 0.5
        case .high: return 0.75
        case .critical: return 1.0
        }
    }
    
    private func calculateRecencyScore(memory: MemoryEntry) -> Double {
        let daysSinceAccess = Date().timeIntervalSince(memory.lastAccessed) / 86400.0
        
        // Importance-based decay: high importance memories decay slower
        let decayRate: Double
        switch memory.importance {
        case .critical:
            decayRate = 90.0 // Very slow decay (90 days for 0.5 score)
        case .high:
            decayRate = 60.0 // Slow decay (60 days for 0.5 score)
        case .normal:
            decayRate = 30.0 // Normal decay (30 days for 0.5 score)
        case .low:
            decayRate = 14.0 // Fast decay (14 days for 0.5 score)
        }
        
        // Decay function: 1.0 for fresh, approaches 0.0 for old
        let decayFactor = 1.0 / (1.0 + daysSinceAccess / decayRate)
        
        return decayFactor
    }
    
    private func calculateExactMatchBonus(memory: MemoryEntry, userMessage: String) -> Double {
        let memoryLower = memory.content.lowercased()
        let messageLower = userMessage.lowercased()
        
        // Check for exact phrase matches of 3+ words
        let memoryPhrases = extractPhrases(memoryLower, minWords: 3)
        let messagePhrases = extractPhrases(messageLower, minWords: 3)
        
        let exactMatches = Set(memoryPhrases).intersection(Set(messagePhrases))
        
        return exactMatches.isEmpty ? 0.0 : 1.0
    }
    
    private func calculateContextualScore(memory: MemoryEntry, userMessage: String) -> Double {
        // Check if memory's semantic category matches the conversation context
        let messageLower = userMessage.lowercased()
        
        switch memory.category {
        case .preference:
            // Relevance if user discusses preferences/opinions
            let preferenceKeywords = ["suka", "tidak suka", "benci", "prefer", "like", "love", "hate", "don't like"]
            let hasPreferenceContext = preferenceKeywords.contains { messageLower.contains($0) }
            return hasPreferenceContext ? 1.0 : 0.3
            
        case .fact:
            // Relevance if user discusses identity/personal info
            let factKeywords = ["nama", "name", "kerja", "work", "belajar", "study", "tinggal", "live"]
            let hasFactContext = factKeywords.contains { messageLower.contains($0) }
            return hasFactContext ? 1.0 : 0.3
            
        case .context:
            // Relevance if user discusses projects/activities
            let contextKeywords = ["project", "kerja", "kerjaan", "buat", "membuat", "sedang", "doing", "working"]
            let hasContextContext = contextKeywords.contains { messageLower.contains($0) }
            return hasContextContext ? 1.0 : 0.3
            
        case .relationship:
            // Only relevant if explicitly about relationship
            let relationshipKeywords = ["teman", "friend", "kamu", "you", "kita", "us", "relationship"]
            let hasRelationshipContext = relationshipKeywords.contains { messageLower.contains($0) }
            return hasRelationshipContext ? 1.0 : 0.0
            
        case .general:
            return 0.5 // Neutral relevance
        }
    }
    
    // MARK: - Helper Methods
    
    private func extractWords(_ text: String) -> [String] {
        return text.components(separatedBy: .whitespacesAndNewlines)
            .map { $0.trimmingCharacters(in: .punctuationCharacters) }
            .filter { $0.count >= 2 }
    }
    
    private func extractPhrases(_ text: String, minWords: Int) -> Set<String> {
        let words = extractWords(text)
        guard words.count >= minWords else { return Set() }
        
        var phrases = Set<String>()
        for i in 0...(words.count - minWords) {
            let phrase = words[i..<(i + minWords)].joined(separator: " ")
            phrases.insert(phrase)
        }
        
        return phrases
    }
    
    private func categoryKeywordsFor(_ category: MemoryCategory) -> [String] {
        switch category {
        case .preference:
            return ["suka", "tidak suka", "benci", "like", "love", "hate", "prefer", "kopi", "teh", "makan", "minuman", "makanan", "prefer"]
        case .fact:
            return ["nama", "name", "kerja", "work", "belajar", "study", "tinggal", "live", "umur", "age", "pekerjaan", "studi"]
        case .context:
            return ["project", "kerja", "kerjaan", "buat", "membuat", "sedang", "doing", "working", "aria", "aplikasi", "ngoding", "coding"]
        case .relationship:
            return ["teman", "friend", "kamu", "you", "kita", "us", "relationship", "hubungan", "keluarga", "family"]
        case .general:
            return []
        }
    }
}
