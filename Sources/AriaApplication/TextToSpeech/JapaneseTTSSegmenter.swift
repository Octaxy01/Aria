import Foundation

/// Segments Japanese text into logical spoken utterances for TTS synthesis.
/// This component is responsible only for text segmentation, not for audio processing.
public struct JapaneseTTSSegmenter {
    
    // MARK: - Configuration
    
    /// Maximum length for a single TTS utterance (characters)
    private let maxSegmentLength: Int
    
    /// Sentence boundary punctuation for Japanese
    private static let sentenceBoundaries: Set<Character> = ["。", "？", "！", "?", "!"]
    
    /// Characters that should NOT create new segments (commas, etc.)
    private static let nonBoundaryPunctuation: Set<Character> = ["、", ","]
    
    public init(maxSegmentLength: Int = 100) {
        self.maxSegmentLength = maxSegmentLength
    }
    
    // MARK: - Main Segmentation
    
    /// Segments Japanese text into logical spoken utterances.
    /// Returns an array of text segments, each suitable for separate TTS synthesis.
    public func segment(_ text: String) -> [String] {
        guard !text.isEmpty else { return [] }
        
        let trimmedText = text.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !trimmedText.isEmpty else { return [] }
        
        var segments: [String] = []
        var currentSegment = ""
        var currentIndex = trimmedText.startIndex
        
        while currentIndex < trimmedText.endIndex {
            let character = trimmedText[currentIndex]
            
            // Check if this character is a sentence boundary
            if JapaneseTTSSegmenter.sentenceBoundaries.contains(character) {
                // Add this character to complete the current segment
                currentSegment.append(character)
                
                // Continue consuming consecutive sentence boundaries
                var nextIndex = trimmedText.index(after: currentIndex)
                while nextIndex < trimmedText.endIndex {
                    let nextChar = trimmedText[nextIndex]
                    if JapaneseTTSSegmenter.sentenceBoundaries.contains(nextChar) {
                        currentSegment.append(nextChar)
                        nextIndex = trimmedText.index(after: nextIndex)
                    } else {
                        break
                    }
                }
                
                // Add the segment if it's not empty
                if !currentSegment.isEmpty {
                    segments.append(currentSegment)
                }
                
                currentSegment = ""
                currentIndex = nextIndex
            } else if character.isNewline {
                // Treat newline as a segment boundary
                // Add the current segment if it's not empty
                if !currentSegment.isEmpty {
                    segments.append(currentSegment)
                }
                
                currentSegment = ""
                currentIndex = trimmedText.index(after: currentIndex)
            } else {
                // Add character to current segment
                currentSegment.append(character)
                
                // Check if segment is too long and needs forced splitting
                if currentSegment.count >= maxSegmentLength {
                    // Try to find a natural split point
                    if let splitPoint = findNaturalSplitPoint(in: currentSegment) {
                        let segment = String(currentSegment[..<splitPoint])
                        segments.append(segment)
                        currentSegment = String(currentSegment[splitPoint...])
                    } else {
                        // No natural split, force split at current position
                        segments.append(currentSegment)
                        currentSegment = ""
                    }
                }
                
                currentIndex = trimmedText.index(after: currentIndex)
            }
        }
        
        // Add any remaining text as the last segment
        if !currentSegment.isEmpty {
            segments.append(currentSegment)
        }
        
        return segments
    }
    
    // MARK: - Helper Methods
    
    /// Finds a natural split point within a segment if it exceeds max length.
    /// Prefers splitting at non-boundary punctuation or after a complete phrase.
    private func findNaturalSplitPoint(in segment: String) -> String.Index? {
        // Look for a comma or similar soft punctuation that's safe to split at
        let softPunctuation: Set<Character> = ["、", ","]
        
        for (index, character) in segment.enumerated() {
            if softPunctuation.contains(character) {
                // Split after this character
                let stringIndex = segment.index(segment.startIndex, offsetBy: index + 1)
                if stringIndex < segment.endIndex {
                    return stringIndex
                }
            }
        }
        
        // If no soft punctuation found, don't split mid-segment
        // Let the segment be longer than max rather than corrupt it
        return nil
    }
}