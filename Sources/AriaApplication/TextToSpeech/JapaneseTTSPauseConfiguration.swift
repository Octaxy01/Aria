import Foundation

/// Configuration for pause durations between Japanese TTS segments.
public struct JapaneseTTSPauseConfiguration {
    /// Normal pause duration for sentence boundaries (。)
    public let normalSentencePause: TimeInterval
    
    /// Expressive pause duration for questions and exclamations (？、！)
    public let expressiveSentencePause: TimeInterval
    
    public init(
        normalSentencePause: TimeInterval = 0.25,
        expressiveSentencePause: TimeInterval = 0.30
    ) {
        self.normalSentencePause = normalSentencePause
        self.expressiveSentencePause = expressiveSentencePause
    }
    
    /// Determines the appropriate pause duration based on segment ending punctuation.
    public func pauseForSegment(_ segment: String) -> TimeInterval {
        guard let lastChar = segment.last else {
            return normalSentencePause
        }
        
        // Check for expressive punctuation
        if lastChar == "？" || lastChar == "?" || lastChar == "！" || lastChar == "!" {
            return expressiveSentencePause
        }
        
        return normalSentencePause
    }
}