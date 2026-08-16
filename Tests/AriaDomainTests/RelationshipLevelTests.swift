import XCTest
@testable import AriaDomain

final class RelationshipLevelTests: XCTestCase {
    
    // MARK: - Test: Correct level for each familiarity range
    
    func testStrangerLevelForLowFamiliarity() {
        let level = RelationshipLevel.from(familiarity: 0.0)
        XCTAssertEqual(level, .stranger)
        
        let levelNearBoundary = RelationshipLevel.from(familiarity: 0.14)
        XCTAssertEqual(levelNearBoundary, .stranger)
    }
    
    func testAcquaintanceLevelForMediumLowFamiliarity() {
        let level = RelationshipLevel.from(familiarity: 0.15)
        XCTAssertEqual(level, .acquaintance)
        
        let levelMiddle = RelationshipLevel.from(familiarity: 0.25)
        XCTAssertEqual(levelMiddle, .acquaintance)
        
        let levelNearBoundary = RelationshipLevel.from(familiarity: 0.34)
        XCTAssertEqual(levelNearBoundary, .acquaintance)
    }
    
    func testFamiliarLevelForMediumFamiliarity() {
        let level = RelationshipLevel.from(familiarity: 0.35)
        XCTAssertEqual(level, .familiar)
        
        let levelMiddle = RelationshipLevel.from(familiarity: 0.5)
        XCTAssertEqual(levelMiddle, .familiar)
        
        let levelNearBoundary = RelationshipLevel.from(familiarity: 0.59)
        XCTAssertEqual(levelNearBoundary, .familiar)
    }
    
    func testCloseLevelForHighFamiliarity() {
        let level = RelationshipLevel.from(familiarity: 0.60)
        XCTAssertEqual(level, .close)
        
        let levelMiddle = RelationshipLevel.from(familiarity: 0.7)
        XCTAssertEqual(levelMiddle, .close)
        
        let levelNearBoundary = RelationshipLevel.from(familiarity: 0.79)
        XCTAssertEqual(levelNearBoundary, .close)
    }
    
    func testTrustedLevelForVeryHighFamiliarity() {
        let level = RelationshipLevel.from(familiarity: 0.80)
        XCTAssertEqual(level, .trusted)
        
        let levelHigh = RelationshipLevel.from(familiarity: 0.9)
        XCTAssertEqual(levelHigh, .trusted)
        
        let levelMax = RelationshipLevel.from(familiarity: 1.0)
        XCTAssertEqual(levelMax, .trusted)
    }
    
    // MARK: - Test: Boundary values
    
    func testStrangerBoundary() {
        // Just below stranger threshold
        XCTAssertEqual(RelationshipLevel.from(familiarity: 0.149), .stranger)
        
        // At stranger threshold (should be acquaintance)
        XCTAssertEqual(RelationshipLevel.from(familiarity: 0.15), .acquaintance)
    }
    
    func testAcquaintanceBoundary() {
        // Just below acquaintance threshold
        XCTAssertEqual(RelationshipLevel.from(familiarity: 0.349), .acquaintance)
        
        // At acquaintance threshold (should be familiar)
        XCTAssertEqual(RelationshipLevel.from(familiarity: 0.35), .familiar)
    }
    
    func testFamiliarBoundary() {
        // Just below familiar threshold
        XCTAssertEqual(RelationshipLevel.from(familiarity: 0.599), .familiar)
        
        // At familiar threshold (should be close)
        XCTAssertEqual(RelationshipLevel.from(familiarity: 0.60), .close)
    }
    
    func testCloseBoundary() {
        // Just below close threshold
        XCTAssertEqual(RelationshipLevel.from(familiarity: 0.799), .close)
        
        // At close threshold (should be trusted)
        XCTAssertEqual(RelationshipLevel.from(familiarity: 0.80), .trusted)
    }
    
    // MARK: - Test: All levels exist
    
    func testAllLevelsExist() {
        let allLevels = RelationshipLevel.allCases
        XCTAssertEqual(allLevels.count, 5)
        
        XCTAssertTrue(allLevels.contains(.stranger))
        XCTAssertTrue(allLevels.contains(.acquaintance))
        XCTAssertTrue(allLevels.contains(.familiar))
        XCTAssertTrue(allLevels.contains(.close))
        XCTAssertTrue(allLevels.contains(.trusted))
    }
    
    // MARK: - Test: Behavioral descriptions
    
    func testStrangerBehavioralDescription() {
        let description = RelationshipLevel.stranger.behavioralDescription
        XCTAssertTrue(description.contains("friendly"))
        XCTAssertTrue(description.contains("emotional distance"))
    }
    
    func testAcquaintanceBehavioralDescription() {
        let description = RelationshipLevel.acquaintance.behavioralDescription
        XCTAssertTrue(description.contains("familiar"))
        XCTAssertTrue(description.contains("warmth"))
    }
    
    func testFamiliarBehavioralDescription() {
        let description = RelationshipLevel.familiar.behavioralDescription
        XCTAssertTrue(description.contains("knows well"))
        XCTAssertTrue(description.contains("relaxed"))
    }
    
    func testCloseBehavioralDescription() {
        let description = RelationshipLevel.close.behavioralDescription
        XCTAssertTrue(description.contains("close companion"))
        XCTAssertTrue(description.contains("genuine concern"))
    }
    
    func testTrustedBehavioralDescription() {
        let description = RelationshipLevel.trusted.behavioralDescription
        XCTAssertTrue(description.contains("deeply trusted"))
        XCTAssertTrue(description.contains("emotionally warm"))
    }
    
    // MARK: - Test: Edge cases
    
    func testNegativeFamiliarity() {
        let level = RelationshipLevel.from(familiarity: -0.1)
        XCTAssertEqual(level, .stranger, "Negative familiarity should default to stranger")
    }
    
    func testFamiliarityAboveOne() {
        let level = RelationshipLevel.from(familiarity: 1.5)
        XCTAssertEqual(level, .trusted, "Familiarity above 1.0 should default to trusted")
    }
}
