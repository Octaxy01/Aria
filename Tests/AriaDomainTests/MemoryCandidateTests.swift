import XCTest
@testable import AriaDomain

final class MemoryCandidateTests: XCTestCase {
    
    func testValidCandidateCreation() {
        let candidate = MemoryCandidate(
            content: "User prefers coffee over tea",
            category: .preference,
            importance: .normal,
            confidence: 0.8
        )
        
        XCTAssertEqual(candidate.content, "User prefers coffee over tea")
        XCTAssertEqual(candidate.category, .preference)
        XCTAssertEqual(candidate.importance, .normal)
        XCTAssertEqual(candidate.confidence, 0.8)
    }
    
    func testInvalidEmptyCandidate() {
        let emptyCandidate = MemoryCandidate(
            content: "",
            category: .preference,
            importance: .normal,
            confidence: 0.8
        )
        
        XCTAssertFalse(emptyCandidate.isValid, "Empty content should be invalid")
    }
    
    func testInvalidWhitespaceOnlyCandidate() {
        let whitespaceCandidate = MemoryCandidate(
            content: "   ",
            category: .preference,
            importance: .normal,
            confidence: 0.8
        )
        
        XCTAssertFalse(whitespaceCandidate.isValid, "Whitespace-only content should be invalid")
    }
    
    func testInvalidLowConfidenceCandidate() {
        let lowConfidenceCandidate = MemoryCandidate(
            content: "User likes programming",
            category: .preference,
            importance: .normal,
            confidence: 0.3
        )
        
        XCTAssertFalse(lowConfidenceCandidate.isValid, "Low confidence should be invalid")
    }
    
    func testInvalidHighConfidenceCandidate() {
        let highConfidenceCandidate = MemoryCandidate(
            content: "User likes programming",
            category: .preference,
            importance: .normal,
            confidence: 1.5
        )
        
        XCTAssertFalse(highConfidenceCandidate.isValid, "Confidence > 1.0 should be invalid")
    }
    
    func testValidConfidenceBoundary() {
        let boundaryCandidate = MemoryCandidate(
            content: "User likes programming",
            category: .preference,
            importance: .normal,
            confidence: 0.5
        )
        
        XCTAssertTrue(boundaryCandidate.isValid, "Confidence of 0.5 should be valid")
    }
    
    func testCategoryAssignment() {
        let preferenceCandidate = MemoryCandidate(
            content: "I like coffee",
            category: .preference,
            importance: .normal,
            confidence: 0.8
        )
        
        let factCandidate = MemoryCandidate(
            content: "My name is John",
            category: .fact,
            importance: .high,
            confidence: 0.9
        )
        
        XCTAssertEqual(preferenceCandidate.category, .preference)
        XCTAssertEqual(factCandidate.category, .fact)
    }
    
    func testToMemoryEntryConversion() {
        let candidate = MemoryCandidate(
            content: "User prefers coffee",
            category: .preference,
            importance: .normal,
            confidence: 0.8
        )
        
        let memoryEntry = candidate.toMemoryEntry()
        
        XCTAssertEqual(memoryEntry.content, "User prefers coffee")
        XCTAssertEqual(memoryEntry.category, .preference)
        XCTAssertEqual(memoryEntry.importance, .normal)
    }
    
    func testCandidateEquality() {
        let candidate1 = MemoryCandidate(
            content: "User likes coffee",
            category: .preference,
            importance: .normal,
            confidence: 0.8
        )
        
        let candidate2 = MemoryCandidate(
            content: "User likes coffee",
            category: .preference,
            importance: .normal,
            confidence: 0.8
        )
        
        XCTAssertEqual(candidate1, candidate2, "Identical candidates should be equal")
    }
    
    func testCandidateInequality() {
        let candidate1 = MemoryCandidate(
            content: "User likes coffee",
            category: .preference,
            importance: .normal,
            confidence: 0.8
        )
        
        let candidate2 = MemoryCandidate(
            content: "User likes tea",
            category: .preference,
            importance: .normal,
            confidence: 0.8
        )
        
        XCTAssertNotEqual(candidate1, candidate2, "Different candidates should not be equal")
    }
}