import Foundation

/// Builds natural clarification messages for ambiguous references.
public struct ClarificationMessageBuilder {
    
    public init() {}
    
    /// Builds a natural clarification message for ambiguous candidates.
    /// - Parameters:
    ///   - candidates: The ambiguous candidate entities
    ///   - reference: The reference that was ambiguous (e.g., "itu", "yang pertama")
    /// - Returns: A natural language clarification message
    public func buildClarificationMessage(candidates: [RuntimeEntity], reference: String) -> String {
        guard !candidates.isEmpty else {
            return "Maaf, saya tidak mengerti yang kamu maksud."
        }
        
        // Build candidate list with redacted sensitive paths
        let candidateList = candidates.enumerated().map { index, entity in
            let displayName = entity.displayName
            let position = index + 1
            return "\(position). \(displayName)"
        }.joined(separator: "\n")
        
        // Build natural message
        var message = "Maaf, yang kamu maksud apa? "
        message += "Pilih salah satu:\n\n"
        message += candidateList
        message += "\n\nKetik nomor atau nama untuk memilih."
        
        return message
    }
}
