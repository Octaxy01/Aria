import Foundation
import AriaDomain
import AriaInfrastructure

/// Builds memory context for conversation turns.
/// Handles retrieval, filtering, and formatting of relevant memories for LLM context.
/// Now uses intelligent relevance scoring for better memory selection.
public actor MemoryContextBuilder {
    private let memoryService: MemoryService
    private let maxMemoriesPerTurn: Int
    private let minImportanceThreshold: MemoryImportance
    private let minRelevanceScore: Double
    private let scoring: MemoryRelevanceScoring
    private let logger: (any Logging)?
    private let enableDebugLogging: Bool
    
    /// Configuration for memory retrieval behavior.
    public struct Configuration: Sendable {
        public let maxMemoriesPerTurn: Int
        public let minImportanceThreshold: MemoryImportance
        public let minRelevanceScore: Double
        public let enableDebugLogging: Bool
        
        public init(
            maxMemoriesPerTurn: Int = 3,
            minImportanceThreshold: MemoryImportance = .normal,
            minRelevanceScore: Double = 0.3,
            enableDebugLogging: Bool = false
        ) {
            self.maxMemoriesPerTurn = maxMemoriesPerTurn
            self.minImportanceThreshold = minImportanceThreshold
            self.minRelevanceScore = minRelevanceScore
            self.enableDebugLogging = enableDebugLogging
        }
        
        public static let `default` = Configuration()
    }
    
    public init(
        memoryService: MemoryService,
        configuration: Configuration = .default,
        logger: (any Logging)? = nil
    ) {
        self.memoryService = memoryService
        self.maxMemoriesPerTurn = configuration.maxMemoriesPerTurn
        self.minImportanceThreshold = configuration.minImportanceThreshold
        self.minRelevanceScore = configuration.minRelevanceScore
        self.enableDebugLogging = configuration.enableDebugLogging
        self.logger = logger
        self.scoring = MemoryRelevanceScoring()
    }
    
    /// Retrieves and formats relevant memories for the given user message.
    /// Returns empty string if no relevant memories are found or on failure.
    public func buildContext(for userMessage: String, relationshipLevel: RelationshipLevel? = nil) async -> String {
        if enableDebugLogging {
            logger?.debug("[MEMORY] Building context for message: \(userMessage.prefix(50))...")
        }
        
        // Extract search terms from user message
        let searchTerms = extractSearchTerms(from: userMessage)
        guard !searchTerms.isEmpty else {
            if enableDebugLogging {
                logger?.debug("[MEMORY] No search terms extracted")
            }
            return ""
        }
        
        if enableDebugLogging {
            logger?.debug("[MEMORY] Search terms: \(searchTerms)")
        }
        
        // Search for memories using each term
        var allMatches: [MemoryEntry] = []
        for term in searchTerms {
            do {
                let matches = try await memoryService.search(query: term)
                allMatches.append(contentsOf: matches)
                if enableDebugLogging {
                    logger?.debug("[MEMORY] Found \(matches.count) matches for term: \(term)")
                }
            } catch {
                // Memory retrieval failure should not break conversation
                if enableDebugLogging {
                    logger?.warning("[MEMORY] Search failed for term: \(term)")
                }
                continue
            }
        }
        
        // Remove duplicates while preserving order
        var seenIds = Set<UUID>()
        let uniqueMatches = allMatches.filter { entry in
            seenIds.insert(entry.id).inserted
        }
        
        if enableDebugLogging {
            logger?.debug("[MEMORY] Total unique matches: \(uniqueMatches.count)")
        }
        
        // Score and rank memories
        let scoredMemories = scoring.scoreAndSort(memories: uniqueMatches, against: userMessage)
        
        if enableDebugLogging {
            logger?.debug("[MEMORY] Scored memories: \(scoredMemories.map { "\($0.relevanceScore): \($0.memory.content.prefix(30))" }.joined(separator: ", "))")
        }
        
        // Apply relationship-aware filtering
        let relationshipFilteredMemories = applyRelationshipFilter(
            scoredMemories: scoredMemories,
            relationshipLevel: relationshipLevel
        )
        
        // Filter by importance threshold and minimum relevance score
        let filteredMemories = relationshipFilteredMemories.filter { scored in
            meetsImportanceThreshold(scored.memory.importance) &&
            scored.relevanceScore >= minRelevanceScore
        }
        
        if enableDebugLogging {
            logger?.debug("[MEMORY] After filtering: \(filteredMemories.count) memories")
        }
        
        // Sort by relevance score (highest first)
        let sortedMemories = filteredMemories.sorted { $0.relevanceScore > $1.relevanceScore }
        
        // Limit to max memories per turn
        let selectedMemories = Array(sortedMemories.prefix(maxMemoriesPerTurn)).map { $0.memory }
        
        guard !selectedMemories.isEmpty else {
            if enableDebugLogging {
                logger?.debug("[MEMORY] No memories selected after filtering")
            }
            return ""
        }
        
        if enableDebugLogging {
            logger?.debug("[MEMORY] Selected \(selectedMemories.count) memories for context")
        }
        
        // Update lastAccessed for selected memories
        for memory in selectedMemories {
            try? await memoryService.updateLastAccessed(id: memory.id)
        }
        
        // Format memories for prompt
        return formatMemories(selectedMemories)
    }
    
    // MARK: - Relationship-Aware Filtering
    
    private func applyRelationshipFilter(
        scoredMemories: [MemoryRelevanceScoring.ScoredMemory],
        relationshipLevel: RelationshipLevel?
    ) -> [MemoryRelevanceScoring.ScoredMemory] {
        guard let level = relationshipLevel else {
            return scoredMemories
        }
        
        // Relationship level modifies memory selection but doesn't override relevance
        // MEMORY RELEVANCE > RELATIONSHIP DEPTH is the core rule
        return scoredMemories.map { scored in
            var adjustedScore = scored.relevanceScore
            
            // Relationship depth only boosts relevant memories, doesn't make irrelevant ones relevant
            if scored.relevanceScore > 0.5 {
                switch level {
                case .trusted:
                    // Very close relationship: slightly boost personal memories
                    if scored.memory.category == .relationship || scored.memory.category == .context {
                        adjustedScore *= 1.1
                    }
                case .close:
                    // Close relationship: moderate boost to personal memories
                    if scored.memory.category == .relationship || scored.memory.category == .context {
                        adjustedScore *= 1.08
                    }
                case .familiar:
                    // Familiar relationship: small boost to context memories
                    if scored.memory.category == .context {
                        adjustedScore *= 1.05
                    }
                case .acquaintance:
                    // Acquaintance relationship: minimal boost
                    if scored.memory.category == .context {
                        adjustedScore *= 1.02
                    }
                case .stranger:
                    // Stranger relationship: no boost, keep as-is
                    break
                }
            }
            
            return MemoryRelevanceScoring.ScoredMemory(
                memory: scored.memory,
                relevanceScore: min(1.0, adjustedScore),
                breakdown: scored.breakdown
            )
        }
    }
    
    // MARK: - Private Helper Methods
    
    private func extractSearchTerms(from message: String) -> [String] {
        // Simple term extraction: split by whitespace and filter common words
        let words = message.components(separatedBy: .whitespacesAndNewlines)
            .map { $0.lowercased().trimmingCharacters(in: .punctuationCharacters) }
            .filter { $0.count >= 3 } // Ignore very short words
        
        // Filter out common Indonesian/English stop words
        let stopWords = Set([
            "aku", "kamu", "dia", "kita", "mereka", "ini", "itu", "ada", "tidak",
            "ya", "tidak", "bisa", "akan", "sudah", "belum", "yang", "dengan",
            "untuk", "dari", "ke", "di", "pada", "dan", "atau", "tapi", "karena",
            "the", "a", "an", "is", "are", "was", "were", "be", "been", "being",
            "have", "has", "had", "do", "does", "did", "will", "would", "could",
            "should", "may", "might", "must", "shall", "can", "need", "dare"
        ])
        
        return words.filter { !stopWords.contains($0) }
    }
    
    private func meetsImportanceThreshold(_ importance: MemoryImportance) -> Bool {
        return importanceRank(importance) >= importanceRank(minImportanceThreshold)
    }
    
    private func importanceRank(_ importance: MemoryImportance) -> Int {
        switch importance {
        case .low: return 0
        case .normal: return 1
        case .high: return 2
        case .critical: return 3
        }
    }
    
    private func formatMemories(_ memories: [MemoryEntry]) -> String {
        let memoryTexts = memories.map { entry in
            "- \(entry.content)"
        }.joined(separator: "\n")
        
        return memoryTexts
    }
}



