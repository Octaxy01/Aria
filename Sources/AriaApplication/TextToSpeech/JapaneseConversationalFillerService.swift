import Foundation
import AriaDomain

/// Adds context-aware conversational fillers and natural hesitation markers to Japanese speech.
/// Uses ConversationTone and personality state to determine when fillers are appropriate.
/// This is separate from the grammar transformer to maintain clear responsibility separation.
public struct JapaneseConversationalFillerService {
    
    // MARK: - Configuration
    
    /// Track filler usage to prevent repetitive patterns
    private var lastFillerUsed: String?
    private var fillerUsageCount: [String: Int] = [:]
    
    public init() {}
    
    // MARK: - Main Filler Addition
    
    /// Adds context-aware conversational fillers to Japanese text based on conversation context.
    /// Returns the text with appropriate fillers added, or unchanged if no filler is appropriate.
    public mutating func addFillers(
        _ text: String,
        tone: ConversationTone,
        emotion: EmotionState,
        relationship: RelationshipState
    ) -> String {
        guard !text.isEmpty else { return text }
        
        // Determine if a filler is appropriate for this context
        guard let filler = appropriateFiller(for: tone, emotion: emotion, in: text) else {
            return text
        }
        
        // Check if we should use this filler (avoid repetition)
        guard shouldUseFiller(filler) else {
            return text
        }
        
        // Add the filler at the beginning of the text
        let filledText = filler + text
        
        // Update tracking
        trackFillerUsage(filler)
        
        return filledText
    }
    
    // MARK: - Filler Selection
    
    /// Determines the appropriate filler based on context, or returns nil if no filler is appropriate.
    private func appropriateFiller(
        for tone: ConversationTone,
        emotion: EmotionState,
        in text: String
    ) -> String? {
        // Check if the text already starts with a conversational marker
        let textLower = text.lowercased()
        if hasConversationalPrefix(textLower) {
            return nil // Don't add filler if text already has one
        }
        
        // Context-based filler selection
        switch emotion.current {
        case .neutral:
            return neutralContextFiller(tone: tone, text: text)
            
        case .worried:
            return thinkingFiller(tone: tone, text: text)
            
        case .happy, .excited, .playful:
            return happinessFiller(tone: tone, text: text)
            
        case .sad, .angry, .annoyed:
            return emotionalFiller(tone: tone, text: text)
            
        case .embarrassed:
            return embarrassmentFiller(tone: tone, text: text)
            
        case .affectionate:
            return affectionateFiller(tone: tone, text: text)
        }
    }
    
    // MARK: - Context-Specific Fillers
    
    /// Fillers for neutral/ordinary context (rarely used)
    private func neutralContextFiller(tone: ConversationTone, text: String) -> String? {
        // Only add fillers in neutral context for specific situations
        switch tone {
        case .technical:
            // No fillers for technical explanations
            return nil
        case .serious:
            // Very rare fillers for serious topics
            return nil
        default:
            // Ordinary conversation rarely needs fillers
            return nil
        }
    }
    
    /// Fillers for thinking/deliberation context
    private func thinkingFiller(tone: ConversationTone, text: String) -> String? {
        switch tone {
        case .casual:
            return "んー……"
        case .serious:
            return "うーん……"
        case .technical:
            return nil // No fillers for technical thinking
        default:
            return "んー……"
        }
    }
    
    /// Fillers for happiness context
    private func happinessFiller(tone: ConversationTone, text: String) -> String? {
        // Only add happiness filler for genuinely happy contexts
        // Check if the text is clearly expressing happiness
        let happyIndicators = ["嬉しい", "楽しい", "ありがとう", "すごい", "やったー"]
        let hasHappyIndicator = happyIndicators.contains { text.contains($0) }
        
        guard hasHappyIndicator else { return nil }
        
        switch tone {
        case .casual:
            return "ふふ"
        case .affectionate:
            return "ふふ"
        case .achievement:
            return nil // Achievement joy is different
        default:
            return "ふふ"
        }
    }
    
    /// Fillers for emotional context (sad, angry, worried)
    private func emotionalFiller(tone: ConversationTone, text: String) -> String? {
        switch tone {
        case .casual:
            return "んー……"
        case .emotional:
            return "そっか……" // Gentle acknowledgment
        case .serious:
            return nil
        default:
            return "んー……"
        }
    }
    
    /// Fillers for embarrassment context
    private func embarrassmentFiller(tone: ConversationTone, text: String) -> String? {
        switch tone {
        case .casual:
            return "えっと……"
        case .affectionate:
            return "えっと……"
        default:
            return "えっと……"
        }
    }
    
    /// Fillers for affectionate context
    private func affectionateFiller(tone: ConversationTone, text: String) -> String? {
        // Affectionate context rarely needs fillers
        return nil
    }
    
    // MARK: - Helper Functions
    
    /// Checks if text already starts with a conversational marker
    private func hasConversationalPrefix(_ text: String) -> Bool {
        let conversationalPrefixes = [
            "うん", "えっ", "あっ", "あー", "えっと", "んー", "ふふ", "そっか", "なるほど",
            "ん", "え", "あ", "えと", "そ", "な"
        ]
        
        return conversationalPrefixes.contains { text.hasPrefix($0) }
    }
    
    /// Determines if a filler should be used based on usage patterns
    private func shouldUseFiller(_ filler: String) -> Bool {
        // Prevent using the same filler repeatedly
        if let lastUsed = lastFillerUsed, lastUsed == filler {
            // Allow some repetition but not immediate
            let count = fillerUsageCount[filler] ?? 0
            return count < 2 // Allow same filler up to 2 times in a row
        }
        
        return true
    }
    
    /// Tracks filler usage to prevent repetitive patterns
    private mutating func trackFillerUsage(_ filler: String) {
        lastFillerUsed = filler
        fillerUsageCount[filler, default: 0] = (fillerUsageCount[filler] ?? 0) + 1
        
        // Decay counter for other fillers
        for key in fillerUsageCount.keys where key != filler {
            fillerUsageCount[key] = max(0, fillerUsageCount[key]! - 1)
        }
    }
    
    /// Resets filler tracking (call between conversations or when appropriate)
    public mutating func resetFillerTracking() {
        lastFillerUsed = nil
        fillerUsageCount.removeAll()
    }
}