import XCTest
@testable import AriaApplication
import AriaDomain

final class RelationshipLevelResolverTests: XCTestCase {
    
    // MARK: - Test: Stranger state
    
    func testStrangerState() {
        let state = RelationshipState(
            warmth: 0.1,
            familiarity: 0.1,
            interactionCount: 1,
            updatedAt: Date()
        )
        
        let context = RelationshipLevelResolver.resolve(from: state)
        
        XCTAssertEqual(context.level, .stranger)
        XCTAssertEqual(context.warmth, 0.1)
        XCTAssertEqual(context.familiarity, 0.1)
        XCTAssertEqual(context.interactionCount, 1)
        XCTAssertTrue(context.behavioralDescription.contains("friendly"))
        XCTAssertTrue(context.behavioralDescription.contains("emotional distance"))
    }
    
    // MARK: - Test: Acquaintance state
    
    func testAcquaintanceState() {
        let state = RelationshipState(
            warmth: 0.3,
            familiarity: 0.2,
            interactionCount: 5,
            updatedAt: Date()
        )
        
        let context = RelationshipLevelResolver.resolve(from: state)
        
        XCTAssertEqual(context.level, .acquaintance)
        XCTAssertEqual(context.warmth, 0.3)
        XCTAssertEqual(context.familiarity, 0.2)
        XCTAssertEqual(context.interactionCount, 5)
        XCTAssertTrue(context.behavioralDescription.contains("familiar"))
        XCTAssertTrue(context.behavioralDescription.contains("warmth"))
    }
    
    // MARK: - Test: Familiar state
    
    func testFamiliarState() {
        let state = RelationshipState(
            warmth: 0.5,
            familiarity: 0.4,
            interactionCount: 15,
            updatedAt: Date()
        )
        
        let context = RelationshipLevelResolver.resolve(from: state)
        
        XCTAssertEqual(context.level, .familiar)
        XCTAssertEqual(context.warmth, 0.5)
        XCTAssertEqual(context.familiarity, 0.4)
        XCTAssertEqual(context.interactionCount, 15)
        XCTAssertTrue(context.behavioralDescription.contains("knows well"))
        XCTAssertTrue(context.behavioralDescription.contains("relaxed"))
    }
    
    // MARK: - Test: Close state
    
    func testCloseState() {
        let state = RelationshipState(
            warmth: 0.7,
            familiarity: 0.65,
            interactionCount: 30,
            updatedAt: Date()
        )
        
        let context = RelationshipLevelResolver.resolve(from: state)
        
        XCTAssertEqual(context.level, .close)
        XCTAssertEqual(context.warmth, 0.7)
        XCTAssertEqual(context.familiarity, 0.65)
        XCTAssertEqual(context.interactionCount, 30)
        XCTAssertTrue(context.behavioralDescription.contains("close companion"))
        XCTAssertTrue(context.behavioralDescription.contains("genuine concern"))
    }
    
    // MARK: - Test: Trusted state
    
    func testTrustedState() {
        let state = RelationshipState(
            warmth: 0.9,
            familiarity: 0.85,
            interactionCount: 50,
            updatedAt: Date()
        )
        
        let context = RelationshipLevelResolver.resolve(from: state)
        
        XCTAssertEqual(context.level, .trusted)
        XCTAssertEqual(context.warmth, 0.9)
        XCTAssertEqual(context.familiarity, 0.85)
        XCTAssertEqual(context.interactionCount, 50)
        XCTAssertTrue(context.behavioralDescription.contains("deeply trusted"))
        XCTAssertTrue(context.behavioralDescription.contains("emotionally warm"))
    }
    
    // MARK: - Test: Milestone detection
    
    func testHasReachedMilestoneWhenLevelChanges() {
        let previousLevel = RelationshipLevel.acquaintance
        let newLevel = RelationshipLevel.familiar
        
        XCTAssertTrue(RelationshipLevelResolver.hasReachedMilestone(from: previousLevel, to: newLevel))
    }
    
    func testHasNotReachedMilestoneWhenLevelSame() {
        let sameLevel = RelationshipLevel.familiar
        
        XCTAssertFalse(RelationshipLevelResolver.hasReachedMilestone(from: sameLevel, to: sameLevel))
    }
    
    func testHasNotReachedMilestoneWhenLevelDecreases() {
        let previousLevel = RelationshipLevel.close
        let newLevel = RelationshipLevel.familiar
        
        // Should return false since it's a decrease, not an upward milestone
        XCTAssertFalse(RelationshipLevelResolver.hasReachedMilestone(from: previousLevel, to: newLevel), "Decreasing level should not be considered a milestone")
    }
    
    func testHasReachedMilestoneWhenLevelIncreases() {
        let previousLevel = RelationshipLevel.familiar
        let newLevel = RelationshipLevel.close
        
        // Should return true since it's an upward progression
        XCTAssertTrue(RelationshipLevelResolver.hasReachedMilestone(from: previousLevel, to: newLevel), "Increasing level should be considered a milestone")
    }
    
    // MARK: - Test: Milestone messages
    
    func testMilestoneMessageForAcquaintance() {
        let message = RelationshipLevelResolver.milestoneMessage(
            from: .stranger,
            to: .acquaintance
        )
        
        XCTAssertNotNil(message)
        XCTAssertTrue(message!.contains("starting to get to know"))
    }
    
    func testMilestoneMessageForFamiliar() {
        let message = RelationshipLevelResolver.milestoneMessage(
            from: .acquaintance,
            to: .familiar
        )
        
        XCTAssertNotNil(message)
        XCTAssertTrue(message!.contains("know this user well"))
    }
    
    func testMilestoneMessageForClose() {
        let message = RelationshipLevelResolver.milestoneMessage(
            from: .familiar,
            to: .close
        )
        
        XCTAssertNotNil(message)
        XCTAssertTrue(message!.contains("close companion"))
    }
    
    func testMilestoneMessageForTrusted() {
        let message = RelationshipLevelResolver.milestoneMessage(
            from: .close,
            to: .trusted
        )
        
        XCTAssertNotNil(message)
        XCTAssertTrue(message!.contains("deeply trust"))
    }
    
    func testMilestoneMessageNilWhenNoMilestone() {
        let message = RelationshipLevelResolver.milestoneMessage(
            from: .familiar,
            to: .familiar
        )
        
        XCTAssertNil(message)
    }
    
    func testMilestoneMessageNilWhenLevelDecreases() {
        let message = RelationshipLevelResolver.milestoneMessage(
            from: .close,
            to: .familiar
        )
        
        XCTAssertNil(message)
    }
    
    // MARK: - Test: Edge cases
    
    func testContextPreservesAllStateValues() {
        let state = RelationshipState(
            warmth: 0.42,
            familiarity: 0.58,
            interactionCount: 23,
            updatedAt: Date()
        )
        
        let context = RelationshipLevelResolver.resolve(from: state)
        
        XCTAssertEqual(context.warmth, state.warmth)
        XCTAssertEqual(context.familiarity, state.familiarity)
        XCTAssertEqual(context.interactionCount, state.interactionCount)
    }
    
    func testBoundaryConditions() {
        // Test exact boundary values
        let atAcquaintanceBoundary = RelationshipState(
            warmth: 0.3,
            familiarity: 0.15,
            interactionCount: 5,
            updatedAt: Date()
        )
        
        let context1 = RelationshipLevelResolver.resolve(from: atAcquaintanceBoundary)
        XCTAssertEqual(context1.level, .acquaintance)
        
        let atFamiliarBoundary = RelationshipState(
            warmth: 0.5,
            familiarity: 0.35,
            interactionCount: 15,
            updatedAt: Date()
        )
        
        let context2 = RelationshipLevelResolver.resolve(from: atFamiliarBoundary)
        XCTAssertEqual(context2.level, .familiar)
        
        let atCloseBoundary = RelationshipState(
            warmth: 0.7,
            familiarity: 0.60,
            interactionCount: 30,
            updatedAt: Date()
        )
        
        let context3 = RelationshipLevelResolver.resolve(from: atCloseBoundary)
        XCTAssertEqual(context3.level, .close)
        
        let atTrustedBoundary = RelationshipState(
            warmth: 0.9,
            familiarity: 0.80,
            interactionCount: 50,
            updatedAt: Date()
        )
        
        let context4 = RelationshipLevelResolver.resolve(from: atTrustedBoundary)
        XCTAssertEqual(context4.level, .trusted)
    }
}
