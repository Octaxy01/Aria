import XCTest
@testable import AriaApplication
@testable import AriaDomain

final class RelationshipServiceTests: XCTestCase {
    func test_everyTurn_increasesFamiliarityAndInteractionCount() async {
        let service = RelationshipService()
        let current = RelationshipState.initial

        let next = await service.nextState(current: current, tone: .casual, emotionSignal: nil)

        XCTAssertGreaterThan(next.familiarity, current.familiarity)
        XCTAssertEqual(next.interactionCount, current.interactionCount + 1)
    }

    func test_familiarity_isCappedAtOne() async {
        let service = RelationshipService(familiarityStep: 0.5)
        var state = RelationshipState(warmth: 0.3, familiarity: 0.9, interactionCount: 0)

        state = await service.nextState(current: state, tone: .casual, emotionSignal: nil)
        state = await service.nextState(current: state, tone: .casual, emotionSignal: nil)

        XCTAssertLessThanOrEqual(state.familiarity, 1.0)
    }

    func test_affectionateTone_increasesWarmth() async {
        let service = RelationshipService()
        let current = RelationshipState.initial

        let next = await service.nextState(current: current, tone: .affectionate, emotionSignal: nil)

        XCTAssertGreaterThan(next.warmth, current.warmth)
    }

    func test_rudeTone_decreasesWarmth() async {
        let service = RelationshipService()
        let current = RelationshipState(warmth: 0.5, familiarity: 0.2, interactionCount: 3)

        let next = await service.nextState(current: current, tone: .rude, emotionSignal: nil)

        XCTAssertLessThan(next.warmth, current.warmth)
    }

    func test_warmth_isAlwaysClampedToUnitRange() async {
        let service = RelationshipService()
        var state = RelationshipState(warmth: 0.05, familiarity: 0.0, interactionCount: 0)

        for _ in 0..<20 {
            state = await service.nextState(
                current: state,
                tone: .rude,
                emotionSignal: EmotionSignal(emotion: .angry, intensity: 1.0)
            )
        }

        XCTAssertGreaterThanOrEqual(state.warmth, 0.0)
        XCTAssertLessThanOrEqual(state.warmth, 1.0)
    }
    
    func test_serviceWithoutPersistence_startsWithInitialState() async {
        let service = RelationshipService()
        let state = await service.getCurrentState()
        
        XCTAssertEqual(state.warmth, RelationshipState.initial.warmth)
        XCTAssertEqual(state.familiarity, RelationshipState.initial.familiarity)
        XCTAssertEqual(state.interactionCount, RelationshipState.initial.interactionCount)
    }
}