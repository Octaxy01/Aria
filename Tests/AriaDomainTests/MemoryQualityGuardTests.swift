import XCTest
@testable import AriaDomain

final class MemoryQualityGuardTests: XCTestCase {
    
    var qualityGuard: MemoryQualityGuard!
    
    override func setUp() {
        super.setUp()
        qualityGuard = MemoryQualityGuard()
    }
    
    // MARK: - Quality Filtering Tests
    
    func test_hypotheticalStatementIsRejected() {
        let hypotheticalCandidate = MemoryCandidate(
            content: "If I lived in Japan, I would eat sushi every day",
            category: .preference,
            importance: .normal,
            confidence: 0.8
        )
        
        XCTAssertFalse(qualityGuard.shouldStore(hypotheticalCandidate),
                      "Hypothetical statements should be rejected")
    }
    
    func test_questionIsRejected() {
        let questionCandidate = MemoryCandidate(
            content: "Do you think I'm a good programmer?",
            category: .general,
            importance: .normal,
            confidence: 0.8
        )
        
        XCTAssertFalse(qualityGuard.shouldStore(questionCandidate),
                      "Questions should be rejected")
    }
    
    func test_jokeIsRejected() {
        let jokeCandidate = MemoryCandidate(
            content: "I'm just kidding, I actually hate coffee",
            category: .preference,
            importance: .normal,
            confidence: 0.8
        )
        
        XCTAssertFalse(qualityGuard.shouldStore(jokeCandidate),
                      "Jokes should be rejected")
    }
    
    func test_sarcasmIsRejected() {
        let sarcasticCandidate = MemoryCandidate(
            content: "Yeah right, I just love debugging all day",
            category: .general,
            importance: .normal,
            confidence: 0.8
        )
        
        XCTAssertFalse(qualityGuard.shouldStore(sarcasticCandidate),
                      "Sarcastic statements should be rejected")
    }
    
    func test_temporaryEmotionIsRejected() {
        let temporaryEmotionCandidate = MemoryCandidate(
            content: "I'm tired right now",
            category: .general,
            importance: .normal,
            confidence: 0.8
        )
        
        XCTAssertFalse(qualityGuard.shouldStore(temporaryEmotionCandidate),
                      "Temporary emotions should be rejected")
    }
    
    func test_instructionIsRejected() {
        let instructionCandidate = MemoryCandidate(
            content: "Remember that I prefer coffee",
            category: .preference,
            importance: .normal,
            confidence: 0.8
        )
        
        XCTAssertFalse(qualityGuard.shouldStore(instructionCandidate),
                      "Instructions should be rejected")
    }
    
    func test_lowConfidenceIsRejected() {
        let lowConfidenceCandidate = MemoryCandidate(
            content: "User likes coffee",
            category: .preference,
            importance: .normal,
            confidence: 0.5
        )
        
        XCTAssertFalse(qualityGuard.shouldStore(lowConfidenceCandidate),
                      "Low confidence candidates should be rejected")
    }
    
    func test_definitePreferenceIsAccepted() {
        let definitePreferenceCandidate = MemoryCandidate(
            content: "I actually prefer coffee over tea",
            category: .preference,
            importance: .normal,
            confidence: 0.8
        )
        
        XCTAssertTrue(qualityGuard.shouldStore(definitePreferenceCandidate),
                     "Definite preferences should be accepted")
    }
    
    func test_personalFactIsAccepted() {
        let personalFactCandidate = MemoryCandidate(
            content: "My name is John",
            category: .fact,
            importance: .high,
            confidence: 0.9
        )
        
        XCTAssertTrue(qualityGuard.shouldStore(personalFactCandidate),
                     "Personal facts should be accepted")
    }
    
    func test_highConfidenceLowImportanceAccepted() {
        let candidate = MemoryCandidate(
            content: "I mentioned this once",
            category: .general,
            importance: .low,
            confidence: 0.9
        )
        
        XCTAssertTrue(qualityGuard.shouldStore(candidate),
                     "High confidence should compensate for low importance")
    }
    
    func test_lowConfidenceHighImportanceRejected() {
        let candidate = MemoryCandidate(
            content: "My name is John",
            category: .fact,
            importance: .critical,
            confidence: 0.5
        )
        
        XCTAssertFalse(qualityGuard.shouldStore(candidate),
                      "Low confidence should reject even high importance")
    }
    
    func test_mediumConfidenceNormalImportanceAccepted() {
        let candidate = MemoryCandidate(
            content: "I work as a developer",
            category: .fact,
            importance: .normal,
            confidence: 0.75
        )
        
        XCTAssertTrue(qualityGuard.shouldStore(candidate),
                     "Medium confidence with normal importance should be accepted")
    }
}
