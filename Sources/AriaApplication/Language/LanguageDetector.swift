import Foundation
import AriaDomain

/// Detects the language of user input using heuristic patterns.
/// This is a simple, fast detector suitable for conversational input.
public struct LanguageDetector {
    
    /// Detects the language of the given text.
    /// Returns .auto if detection is uncertain.
    public static func detect(_ text: String) -> SupportedLanguage {
        let normalizedText = text.lowercased().trimmingCharacters(in: .whitespacesAndNewlines)
        
        // Check for Japanese characters (Hiragana, Katakana, Kanji)
        if containsJapanese(text) {
            return .japanese
        }
        
        // Check for Russian characters (Cyrillic)
        if containsCyrillic(text) {
            return .russian
        }
        
        // Check for Indonesian markers
        if containsIndonesianMarkers(normalizedText) {
            return .indonesian
        }
        
        // Default to English if no specific language detected
        return .english
    }
    
    // MARK: - Language-specific detection
    
    private static func containsJapanese(_ text: String) -> Bool {
        // Check for Hiragana (3040-309F), Katakana (30A0-30FF), or Kanji (4E00-9FFF)
        for scalar in text.unicodeScalars {
            let value = scalar.value
            if (0x3040...0x309F).contains(value) || // Hiragana
               (0x30A0...0x30FF).contains(value) || // Katakana
               (0x4E00...0x9FFF).contains(value) {  // Kanji
                return true
            }
        }
        return false
    }
    
    private static func containsCyrillic(_ text: String) -> Bool {
        // Check for Cyrillic characters (0400-04FF)
        for scalar in text.unicodeScalars {
            if (0x0400...0x04FF).contains(scalar.value) {
                return true
            }
        }
        return false
    }
    
    private static func containsIndonesianMarkers(_ text: String) -> Bool {
        // Common Indonesian conversational markers
        let indonesianMarkers = [
            "aku", "kamu", "saya", "dia", "mereka", "kita",
            "yang", "dan", "atau", "tapi", "kalau", "jika",
            "tidak", "ya", "tidak", "bisa", "boleh",
            "kan", "dong", "sih", "deh", "lah", "kok",
            "apa", "bagaimana", "kenapa", "mengapa",
            "ini", "itu", "sini", "sana",
            "serius", "banget", "cakap", "bilang",
            "hari", "ini", "besok", "kemarin",
            "mau", "ingin", "perlu", "harus"
        ]
        
        // Split text into words and check for Indonesian markers
        let words = text.components(separatedBy: .whitespacesAndNewlines)
        let matchedCount = words.filter { word in
            indonesianMarkers.contains(word)
        }.count
        
        // If more than 20% of words are Indonesian markers, classify as Indonesian
        let threshold = max(1, Double(words.count) * 0.2)
        return Double(matchedCount) >= threshold
    }
    
    /// Detects if the user is explicitly requesting a language change
    public static func detectLanguageOverride(_ text: String) -> SupportedLanguage? {
        let normalizedText = text.lowercased()
        
        // Indonesian language request patterns
        if normalizedText.contains("bahasa indonesia") ||
           normalizedText.contains("jawab pakai bahasa indonesia") ||
           normalizedText.contains("mulai sekarang jawab pakai bahasa indonesia") ||
           normalizedText.contains("gunakan bahasa indonesia") {
            return .indonesian
        }
        
        // Japanese language request patterns
        if normalizedText.contains("日本語") ||
           normalizedText.contains("japanese please") ||
           normalizedText.contains("jawab pakai bahasa jepang") ||
           normalizedText.contains("gunakan bahasa jepang") {
            return .japanese
        }
        
        // Russian language request patterns
        if normalizedText.contains("русский") ||
           normalizedText.contains("jawab pakai bahasa rusia") ||
           normalizedText.contains("gunakan bahasa rusia") ||
           normalizedText.contains("russian please") ||
           normalizedText.contains("bahasa rusia") ||
           normalizedText.contains("russian language") ||
           normalizedText.contains("speak russian") ||
           normalizedText.contains("говори по-русски") ||
           normalizedText.contains("говорить по-русски") ||
           normalizedText.contains("по-русски") {
            return .russian
        }
        
        // English language request patterns
        if normalizedText.contains("english please") ||
           normalizedText.contains("jawab pakai bahasa inggris") ||
           normalizedText.contains("gunakan bahasa inggris") {
            return .english
        }
        
        return nil
    }
    
    /// Detects if the user is asking for translation or meaning
    public static func detectTranslationRequest(_ text: String) -> Bool {
        let normalizedText = text.lowercased()
        
        let translationKeywords = [
            "apa arti", "apa maksud", "what does", "translate",
            "terjemahkan", "artinya", "meaning", "translation"
        ]
        
        return translationKeywords.contains { normalizedText.contains($0) }
    }
}
