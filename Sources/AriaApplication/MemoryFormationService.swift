import Foundation
import AriaDomain

/// Analyzes conversation content to identify and form memory candidates.
/// Uses deterministic pattern matching to detect durable information worth remembering.
/// Now includes quality filtering and improved conflict resolution.
public actor MemoryFormationService {
    private let memoryService: MemoryService
    private let confidenceThreshold: Double
    private let qualityGuard: MemoryQualityGuard
    
    /// Configuration for memory formation behavior.
    public struct Configuration: Sendable {
        public let confidenceThreshold: Double
        public let enableDuplicateDetection: Bool
        public let enableConflictResolution: Bool
        public let enableQualityFiltering: Bool
        
        public init(
            confidenceThreshold: Double = 0.7,
            enableDuplicateDetection: Bool = true,
            enableConflictResolution: Bool = true,
            enableQualityFiltering: Bool = true
        ) {
            self.confidenceThreshold = confidenceThreshold
            self.enableDuplicateDetection = enableDuplicateDetection
            self.enableConflictResolution = enableConflictResolution
            self.enableQualityFiltering = enableQualityFiltering
        }
        
        public static let `default` = Configuration()
    }
    
    public init(
        memoryService: MemoryService,
        configuration: Configuration = .default
    ) {
        self.memoryService = memoryService
        self.confidenceThreshold = configuration.confidenceThreshold
        self.qualityGuard = MemoryQualityGuard()
    }
    
    /// Analyzes a user message and potentially creates a memory.
    /// Returns true if a memory was created/updated, false otherwise.
    /// Never throws - memory formation failures are silently ignored.
    public func processUserMessage(_ message: String) async -> Bool {
        guard let candidate = analyzeMessage(message) else {
            return false
        }
        
        guard candidate.confidence >= confidenceThreshold else {
            return false
        }
        
        // Apply quality filtering
        guard qualityGuard.shouldStore(candidate) else {
            return false
        }
        
        return await storeCandidate(candidate)
    }
    
    // MARK: - Private Analysis Methods
    
    private func analyzeMessage(_ message: String) -> MemoryCandidate? {
        let trimmedMessage = message.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !trimmedMessage.isEmpty else {
            return nil
        }
        
        // Check for memory correction commands first
        if let correctionCandidate = detectMemoryCorrection(trimmedMessage) {
            return correctionCandidate
        }
        
        // Check for explicit memory commands (highest priority)
        if let explicitMemoryCandidate = detectExplicitMemoryCommand(trimmedMessage) {
            return explicitMemoryCandidate
        }
        
        // Check for preference patterns
        if let preferenceCandidate = detectPreference(trimmedMessage) {
            return preferenceCandidate
        }
        
        // Check for personal fact patterns
        if let factCandidate = detectPersonalFact(trimmedMessage) {
            return factCandidate
        }
        
        // Check for project/context patterns
        if let contextCandidate = detectProjectContext(trimmedMessage) {
            return contextCandidate
        }
        
        // Check for relationship-relevant information
        if let relationshipCandidate = detectRelationshipInfo(trimmedMessage) {
            return relationshipCandidate
        }
        
        return nil
    }
    
    private func detectMemoryCorrection(_ message: String) -> MemoryCandidate? {
        let lowerMessage = message.lowercased()
        
        // Indonesian correction markers
        let indonesianMarkers = [
            "itu salah", "bukan begitu", "ubah yang tadi", "jangan ingat itu", "lupakan yang tadi"
        ]
        
        // English correction markers
        let englishMarkers = [
            "that's wrong", "that's incorrect", "forget that", "don't remember that"
        ]
        
        let allMarkers = indonesianMarkers + englishMarkers
        
        for marker in allMarkers {
            if lowerMessage.contains(marker) {
                // For now, we'll return nil to indicate the memory should be invalidated
                // In a full implementation, this would trigger deletion of conflicting memories
                return nil // Placeholder for memory invalidation logic
            }
        }
        
        return nil
    }
    
    private func detectExplicitMemoryCommand(_ message: String) -> MemoryCandidate? {
        let lowerMessage = message.lowercased()
        
        // Indonesian explicit memory markers
        let indonesianMarkers = [
            "ingat ini", "ingat ya", "tolong ingat", "jangan lupa",
            "ingat kalau", "mulai sekarang", "dari sekarang"
        ]
        
        // English explicit memory markers
        let englishMarkers = [
            "remember this", "remember this:", "don't forget", "please remember",
            "remember that", "from now on", "starting now"
        ]
        
        let allMarkers = indonesianMarkers + englishMarkers
        
        for marker in allMarkers {
            if lowerMessage.contains(marker) {
                // Extract the content after the marker
                let content = extractExplicitMemoryContent(message, marker: marker)
                if !content.isEmpty {
                    return MemoryCandidate(
                        content: content,
                        category: .preference,
                        importance: .high,
                        confidence: 0.95 // High confidence for explicit commands
                    )
                }
            }
        }
        
        return nil
    }
    
    private func extractExplicitMemoryContent(_ message: String, marker: String) -> String {
        // Find the marker and extract content after it
        if let markerRange = message.lowercased().range(of: marker.lowercased()) {
            let contentStart = markerRange.upperBound
            let content = String(message[contentStart...])
                .trimmingCharacters(in: .whitespacesAndNewlines)
                .trimmingCharacters(in: .punctuationCharacters)
            return content
        }
        return message.trimmingCharacters(in: .whitespacesAndNewlines)
    }
    
    private func detectPreference(_ message: String) -> MemoryCandidate? {
        let lowerMessage = message.lowercased()
        
        // Indonesian preference markers
        let indonesianMarkers = [
            "saya suka", "aku suka", "saya lebih suka", "aku lebih suka",
            "saya prefer", "aku prefer", "saya senang", "aku senang",
            "saya tidak suka", "aku tidak suka", "saya benci", "aku benci"
        ]
        
        // English preference markers
        let englishMarkers = [
            "i like", "i love", "i prefer", "i enjoy",
            "i don't like", "i hate", "i dislike"
        ]
        
        let allMarkers = indonesianMarkers + englishMarkers
        
        for marker in allMarkers {
            if lowerMessage.contains(marker) {
                // Extract the preference statement
                let content = extractPreferenceContent(message, marker: marker)
                return MemoryCandidate(
                    content: content,
                    category: .preference,
                    importance: .normal,
                    confidence: 0.8
                )
            }
        }
        
        return nil
    }
    
    private func detectPersonalFact(_ message: String) -> MemoryCandidate? {
        let lowerMessage = message.lowercased()
        
        // Indonesian fact markers
        let indonesianMarkers = [
            "nama saya", "namaku", "aku bernama", "saya bernama",
            "saya bekerja", "aku bekerja", "saya kerja", "aku kerja",
            "saya studi", "aku studi", "saya belajar", "aku belajar", "aku sedang belajar", "saya sedang belajar",
            "saya tinggal", "aku tinggal"
        ]
        
        // English fact markers
        let englishMarkers = [
            "my name is", "i'm named", "i work as", "i work at",
            "i study", "i'm studying", "i live in", "i'm from"
        ]
        
        let allMarkers = indonesianMarkers + englishMarkers
        
        for marker in allMarkers {
            if lowerMessage.contains(marker) {
                let content = extractFactContent(message, marker: marker)
                return MemoryCandidate(
                    content: content,
                    category: .fact,
                    importance: .high,
                    confidence: 0.9
                )
            }
        }
        
        return nil
    }
    
    private func detectProjectContext(_ message: String) -> MemoryCandidate? {
        let lowerMessage = message.lowercased()
        
        // Indonesian project markers
        let indonesianMarkers = [
            "saya sedang membuat", "aku sedang membuat", "saya membuat", "aku membuat",
            "project saya", "projectku", "proyek saya", "proyekku",
            "saya sedang bangun", "aku sedang bangun"
        ]
        
        // English project markers
        let englishMarkers = [
            "i'm building", "i am building", "i'm working on", "i am working on",
            "my project", "i'm creating", "i am creating"
        ]
        
        let allMarkers = indonesianMarkers + englishMarkers
        
        for marker in allMarkers {
            if lowerMessage.contains(marker) {
                let content = extractContextContent(message, marker: marker)
                return MemoryCandidate(
                    content: content,
                    category: .context,
                    importance: .normal,
                    confidence: 0.75
                )
            }
        }
        
        return nil
    }
    
    private func detectRelationshipInfo(_ message: String) -> MemoryCandidate? {
        let lowerMessage = message.lowercased()
        
        // Only store clearly relationship-relevant information
        let relationshipMarkers = [
            "kamu adalah teman", "you are my friend",
            "kamu keluarga", "you are family"
        ]
        
        for marker in relationshipMarkers {
            if lowerMessage.contains(marker) {
                let content = message.trimmingCharacters(in: .whitespacesAndNewlines)
                return MemoryCandidate(
                    content: content,
                    category: .relationship,
                    importance: .high,
                    confidence: 0.7
                )
            }
        }
        
        return nil
    }
    
    // MARK: - Content Extraction Methods
    
    private func extractPreferenceContent(_ message: String, marker: String) -> String {
        // Simple extraction: use the message as-is but clean it up
        return message.trimmingCharacters(in: .whitespacesAndNewlines)
    }
    
    private func extractFactContent(_ message: String, marker: String) -> String {
        return message.trimmingCharacters(in: .whitespacesAndNewlines)
    }
    
    private func extractContextContent(_ message: String, marker: String) -> String {
        return message.trimmingCharacters(in: .whitespacesAndNewlines)
    }
    
    // MARK: - Storage Methods
    
    private func storeCandidate(_ candidate: MemoryCandidate) async -> Bool {
        // Check for duplicates
        if await isDuplicate(candidate) {
            return false
        }
        
        // Check for conflicts and update if needed
        if let existingId = await findConflictingMemory(candidate) {
            do {
                try await memoryService.update(id: existingId, content: candidate.content)
                return true
            } catch {
                // Update failed, ignore and continue
                return false
            }
        }
        
        // Store new memory
        do {
            try await memoryService.store(
                content: candidate.content,
                category: candidate.category,
                importance: candidate.importance
            )
            return true
        } catch {
            // Storage failed, ignore and continue
            return false
        }
    }
    
    private func isDuplicate(_ candidate: MemoryCandidate) async -> Bool {
        do {
            let existingMemories = try await memoryService.search(query: candidate.content)
            return existingMemories.contains { $0.content == candidate.content }
        } catch {
            return false
        }
    }
    
    private func findConflictingMemory(_ candidate: MemoryCandidate) async -> UUID? {
        // Simple conflict detection: if memory contains similar keywords in same category
        // This is a basic implementation - could be enhanced with semantic similarity
        do {
            let allMemories = try await memoryService.retrieveAll(category: candidate.category)
            
            for memory in allMemories {
                if areConflicting(memory.content, candidate.content) {
                    return memory.id
                }
            }
        } catch {
            return nil
        }
        
        return nil
    }
    
    private func areConflicting(_ existing: String, _ new: String) -> Bool {
        // Enhanced conflict detection for preferences
        let existingLower = existing.lowercased()
        let newLower = new.lowercased()
        
        // Extract meaningful words (filter out common words)
        let existingWords = extractMeaningfulWords(existingLower)
        let newWords = extractMeaningfulWords(newLower)
        
        // Check for preference conflict indicators
        let preferenceChangeMarkers = ["lebih suka", "more like", "prefer", "daripada", "instead of", "sekarang", "now"]
        let hasPreferenceChange = preferenceChangeMarkers.contains { newLower.contains($0) }
        
        // If new memory explicitly indicates a preference change and shares keywords
        if hasPreferenceChange {
            let commonWords = Set(existingWords).intersection(Set(newWords))
            return commonWords.count >= 1
        }
        
        // For same-category memories with significant word overlap
        let commonWords = Set(existingWords).intersection(Set(newWords))
        if commonWords.count >= 2 {
            // Check if they're about the same topic (both mention the same key nouns)
            return true
        }
        
        return false
    }
    
    private func extractMeaningfulWords(_ text: String) -> [String] {
        let stopWords = Set([
            "aku", "kamu", "saya", "anda", "dia", "kita", "mereka",
            "i", "you", "he", "she", "we", "they",
            "adalah", "is", "are", "was", "were",
            "punya", "have", "has", "had",
            "ini", "itu", "this", "that",
            "dan", "atau", "and", "or",
            "dengan", "with", "untuk", "for",
            "yang", "what", "yang", "which"
        ])
        
        return text.components(separatedBy: .whitespaces)
            .map { $0.trimmingCharacters(in: .punctuationCharacters) }
            .filter { $0.count > 2 && !stopWords.contains($0) }
    }
}