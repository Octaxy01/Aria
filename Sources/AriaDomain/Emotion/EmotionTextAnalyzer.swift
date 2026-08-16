import Foundation

/// Simple heuristic-based emotion detection from text content.
/// Used as fallback when structured LLM output is not available.
/// Not meant to replace structured emotion signals from the LLM,
/// but to provide reasonable defaults when models return plain text.
public enum EmotionTextAnalyzer {
    /// Analyzes text and returns a suggested emotion signal.
    /// Returns nil if no clear emotion is detected.
    public static func analyze(_ text: String) -> EmotionSignal? {
        let lowercased = text.lowercased()
        
        // Check for playful indicators
        if hasPlayfulIndicators(lowercased) {
            return EmotionSignal(emotion: .playful, intensity: 0.6)
        }
        
        // Check for happy/excited indicators
        if hasHappyIndicators(lowercased) {
            return EmotionSignal(emotion: .excited, intensity: 0.7)
        }
        
        // Check for affectionate indicators
        if hasAffectionateIndicators(lowercased) {
            return EmotionSignal(emotion: .affectionate, intensity: 0.5)
        }
        
        // Check for worried/sad indicators
        if hasWorriedIndicators(lowercased) {
            return EmotionSignal(emotion: .worried, intensity: 0.4)
        }
        
        // Check for annoyed/angry indicators
        if hasAnnoyedIndicators(lowercased) {
            return EmotionSignal(emotion: .annoyed, intensity: 0.5)
        }
        
        // Check for embarrassed indicators
        if hasEmbarrassedIndicators(lowercased) {
            return EmotionSignal(emotion: .embarrassed, intensity: 0.4)
        }
        
        // No clear emotion detected
        return nil
    }
    
    private static func hasPlayfulIndicators(_ text: String) -> Bool {
        let playfulMarkers = [
            "haha", "hehe", "lol", "lmao", "😂", "🤣", "😄", "😆",
            "just kidding", "jk", "teasing", "playful", "wkwk", "hihi",
            "*giggles", "*laughs", "*smirks", "*grins", "*winks",
            // Indonesian playful markers
            "tertawa", "kidding", "guyon", "bercanda", "ketawa"
        ]
        return playfulMarkers.contains(where: text.contains)
    }
    
    private static func hasHappyIndicators(_ text: String) -> Bool {
        let happyMarkers = [
            "yay", "woo", "amazing", "awesome", "great", "fantastic",
            "love it", "so happy", "excited", "finally", "success",
            "😊", "😃", "🎉", "✨", "🌟", "😍",
            // Indonesian happy markers
            "bagus", "keren", "hebat", "mantap", "senang", "senyum",
            "terima kasih", "makasih", "terimakasih"
        ]
        return happyMarkers.contains(where: text.contains)
    }
    
    private static func hasAffectionateIndicators(_ text: String) -> Bool {
        let affectionateMarkers = [
            "love you", "care about", "miss you", "so sweet", "darling",
            "honey", "dear", "❤", "💕", "💗", "care for", "fond of"
        ]
        return affectionateMarkers.contains(where: text.contains)
    }
    
    private static func hasWorriedIndicators(_ text: String) -> Bool {
        let worriedMarkers = [
            "worried", "concerned", "not sure", "uncertain", "nervous",
            "anxious", "scared", "afraid", "hope", "hopefully", "fingers crossed"
        ]
        return worriedMarkers.contains(where: text.contains)
    }
    
    private static func hasAnnoyedIndicators(_ text: String) -> Bool {
        let annoyedMarkers = [
            "ugh", "seriously", "seriously?", "come on", "ughh",
            "annoying", "frustrating", "hmpf", "*sighs",
            "*frowns", "*rolls eyes",
            // Indonesian annoyed markers
            "kesal", "marah", "kesel", "muak", "sebel"
        ]
        return annoyedMarkers.contains(where: text.contains)
    }
    
    private static func hasEmbarrassedIndicators(_ text: String) -> Bool {
        let embarrassedMarkers = [
            "blush", "embarrassed", "shy", "um", "uh", "well, um",
            "*blushes", "*looks away", "*fidgets", "kind of"
        ]
        return embarrassedMarkers.contains(where: text.contains)
    }
}
