import Foundation
import AriaDomain

/// Transforms formal Japanese text into natural conversational speech for Aria.
/// Uses conservative, deterministic transformations to avoid corrupting Japanese text.
public actor JapaneseConversationalTransformer {
    
    // MARK: - Configuration
    
    /// Relationship-aware speech adjustment
    private let relationshipLevel: RelationshipLevel
    
    public init(
        relationshipLevel: RelationshipLevel = .stranger
    ) {
        self.relationshipLevel = relationshipLevel
    }
    
    // MARK: - Main Transformation
    
    /// Transforms formal Japanese text into natural conversational speech.
    /// Uses a deterministic pipeline with conservative transformations only.
    public func transform(_ text: String) -> String {
        var result = text
        
        // Apply transformations in deterministic order:
        // 1. Character-specific phrase transformations (applied first to match original input)
        // 2. Exact phrase transformations (most specific)
        // 3. Supported grammatical patterns
        // 4. Safe sentence-ending transformations
        result = applyCharacterSpecificTransformations(result)
        result = applyExactPhraseTransformations(result)
        result = applyGrammaticalPatternTransformations(result)
        result = applySafeSentenceEndingTransformations(result)
        
        return result
    }
    
    // MARK: - Character-Specific Transformations
    
    /// Applies character-specific phrase transformations first to match original input.
    /// These are applied before generic rules to prevent overwriting character voice.
    private func applyCharacterSpecificTransformations(_ text: String) -> String {
        var result = text
        
        // Aria's character-specific phrases (natural understanding)
        let characterPhrases: [(String, String)] = [
            ("そうですか。", "そっか。"),
            ("そうですか？", "そっか？"),
        ]
        
        for (formal, casual) in characterPhrases {
            result = result.replacingOccurrences(of: formal, with: casual)
        }
        
        return result
    }
    
    // MARK: - Exact Phrase Transformations
    
    /// Applies exact phrase transformations to protect specific patterns.
    /// These are handled before any generic rules to prevent corruption.
    private func applyExactPhraseTransformations(_ text: String) -> String {
        var result = text
        
        // Protected exact phrase transformations (excluding character-specific phrases)
        let exactPhrases: [(String, String)] = [
            // Common polite expressions
            ("ありがとうございます", "ありがとう"),
            ("ありがとうございました", "ありがとう"),
            
            // Understanding verbs
            ("わかりました", "わかった"),
            ("わかりません", "わからない"),
            
            // Knowledge verbs
            ("知りません", "知らない"),
            
            // Ability verbs
            ("できません", "できない"),
            
            // Thinking verbs
            ("思います", "思う"),
            ("思いません", "思わない"),
            ("思いました", "思った"),
            
            // Progressive aspect
            ("しています", "してる"),
            ("疲れています", "疲れてる"),
            
            // Common verbs
            ("しました", "した"),
            ("しません", "しない"),
        ]
        
        for (formal, casual) in exactPhrases {
            result = result.replacingOccurrences(of: formal, with: casual)
        }
        
        return result
    }
    
    // MARK: - Grammatical Pattern Transformations
    
    /// Applies supported grammatical pattern transformations.
    /// These are conservative patterns that won't corrupt Japanese words.
    private func applyGrammaticalPatternTransformations(_ text: String) -> String {
        var result = text
        
        // Safe grammatical patterns with punctuation boundaries
        let grammaticalPatterns: [(String, String)] = [
            // Sentence-ending patterns with punctuation protection
            ("思います。", "思う。"),
            ("思います？", "思う？"),
            ("思います！", "思う！"),
            
            ("思いません。", "思わない。"),
            ("思いません？", "思わない？"),
            ("思いません！", "思わない！"),
            
            ("思いました。", "思った。"),
            ("思いました？", "思った？"),
            ("思いました！", "思った！"),
            
            ("しています。", "してる。"),
            ("しています？", "してる？"),
            ("しています！", "してる！"),
            
            ("しました。", "した。"),
            ("しました？", "した？"),
            ("しました！", "した！"),
            
            ("しません。", "しない。"),
            ("しません？", "しない？"),
            ("しません！", "しない！"),
            
            ("疲れています。", "疲れてる。"),
            ("疲れています？", "疲れてる？"),
            ("疲れています！", "疲れてる！"),
        ]
        
        for (formal, casual) in grammaticalPatterns {
            result = result.replacingOccurrences(of: formal, with: casual)
        }
        
        return result
    }
    
    // MARK: - Safe Sentence Ending Transformations
    
    /// Applies safe sentence-ending transformations only.
    /// These only transform when the pattern is clearly a sentence ending.
    private func applySafeSentenceEndingTransformations(_ text: String) -> String {
        var result = text
        
        // Conversational patterns for natural spoken Japanese
        let conversationalPatterns: [(String, String)] = [
            // Natural agreement/softening
            ("そうですね。", "そうだね。"),
            ("そうですね？", "そうだね？"),
            
            // Natural uncertainty
            ("でしょう。", "かな。"),
            ("でしょう？", "かな？"),
            
            // Natural casual endings
            ("ですね。", "だね。"),
            ("ですね？", "だね？"),
        ]
        
        // Copula transformations - only at clear sentence boundaries
        let copulaPatterns: [(String, String)] = [
            // です as sentence ending (safe cases only)
            ("です。", "だ。"),
            ("です？", "だ？"),
            ("です！", "だ！"),
            
            // でした as sentence ending
            ("でした。", "だった。"),
            ("でした？", "だった？"),
            ("でした！", "だった！"),
        ]
        
        // Apply conversational patterns first
        for (formal, casual) in conversationalPatterns {
            result = result.replacingOccurrences(of: formal, with: casual)
        }
        
        // Then apply general copula patterns
        for (formal, casual) in copulaPatterns {
            result = result.replacingOccurrences(of: formal, with: casual)
        }
        
        return result
    }
    
    // MARK: - Relationship-Aware Adjustment
    
    /// Updates speech style based on relationship level.
    /// Currently reserved for future relationship-based adjustments.
    public func updateRelationshipLevel(_ level: RelationshipLevel) {
        // Reserved for future relationship-based speech adjustments
        // No changes in current conservative implementation
    }
}

