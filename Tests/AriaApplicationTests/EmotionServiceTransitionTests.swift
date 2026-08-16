import XCTest
@testable import AriaApplication
@testable import AriaDomain

final class EmotionServiceTransitionTests: XCTestCase {
    func test_sameEmotionSignal_smoothsTowardNewIntensity_ratherThanSnapping() {
        let service = EmotionService(decayPerTurnWithoutSignal: 0.2, smoothingFactor: 0.5, switchThreshold: 0.35)
        let current = EmotionState(current: .happy, intensity: 0.2)
        let signal = EmotionSignal(emotion: .happy, intensity: 1.0)

        let next = service.nextState(current: current, signal: signal)

        XCTAssertEqual(next.current, .happy)
        XCTAssertEqual(next.intensity, 0.6, accuracy: 0.0001)
    }

    func test_weakDifferentEmotionSignal_isIgnored_currentEmotionHolds() {
        let service = EmotionService(decayPerTurnWithoutSignal: 0.2, smoothingFactor: 0.5, switchThreshold: 0.35)
        let current = EmotionState(current: .happy, intensity: 0.5)
        let weakSignal = EmotionSignal(emotion: .annoyed, intensity: 0.1)

        let next = service.nextState(current: current, signal: weakSignal)

        XCTAssertEqual(next.current, .happy, "a weak signal shouldn't flip the emotion")
        XCTAssertLessThan(next.intensity, current.intensity)
    }

    func test_strongDifferentEmotionSignal_switchesEmotion() {
        let service = EmotionService(decayPerTurnWithoutSignal: 0.2, smoothingFactor: 0.5, switchThreshold: 0.35)
        let current = EmotionState(current: .happy, intensity: 0.5)
        let strongSignal = EmotionSignal(emotion: .angry, intensity: 0.9)

        let next = service.nextState(current: current, signal: strongSignal)

        XCTAssertEqual(next.current, .angry)
        XCTAssertEqual(next.intensity, 0.9, accuracy: 0.0001)
    }

    func test_noSignal_decaysIntensityAndHoldsEmotion() {
        let service = EmotionService(decayPerTurnWithoutSignal: 0.2)
        let current = EmotionState(current: .sad, intensity: 0.5)

        let next = service.nextState(current: current, signal: nil)

        XCTAssertEqual(next.current, .sad)
        XCTAssertEqual(next.intensity, 0.3, accuracy: 0.0001)
    }

    func test_intensityIsAlwaysClampedToUnitRange() {
        let service = EmotionService()
        let current = EmotionState(current: .neutral, intensity: 0.0)
        let outOfRangeSignal = EmotionSignal(emotion: .excited, intensity: 5.0)

        let next = service.nextState(current: current, signal: outOfRangeSignal)

        XCTAssertLessThanOrEqual(next.intensity, 1.0)
        XCTAssertGreaterThanOrEqual(next.intensity, 0.0)
    }
}