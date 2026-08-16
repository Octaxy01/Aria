import XCTest
@testable import AriaApplication
import AriaDomain

final class EmotionServiceTests: XCTestCase {
    func testSignalIsAdoptedWithClampedIntensity() {
        let service = EmotionService()
        let next = service.nextState(
            current: .initial,
            signal: EmotionSignal(emotion: .happy, intensity: 1.5) // out of range on purpose
        )
        XCTAssertEqual(next.current, .happy)
        XCTAssertEqual(next.intensity, 1.0) // clamped
    }

    func testNegativeIntensityIsClampedToZero() {
        let service = EmotionService()
        let next = service.nextState(
            current: .initial,
            signal: EmotionSignal(emotion: .sad, intensity: -0.4)
        )
        // Negative intensity is clamped to 0.0, but since 0.0 < switchThreshold (0.35),
        // the weak signal is ignored and current emotion is held (with decay)
        XCTAssertEqual(next.current, .neutral)
        XCTAssertEqual(next.intensity, 0.0)
    }

    func testNoSignalDecaysIntensityButKeepsEmotion() {
        let service = EmotionService(decayPerTurnWithoutSignal: 0.2)
        let current = EmotionState(current: .playful, intensity: 0.5)
        let next = service.nextState(current: current, signal: nil)
        XCTAssertEqual(next.current, .playful)
        XCTAssertEqual(next.intensity, 0.3, accuracy: 0.0001)
    }

    func testDecayNeverGoesNegative() {
        let service = EmotionService(decayPerTurnWithoutSignal: 0.9)
        let current = EmotionState(current: .angry, intensity: 0.2)
        let next = service.nextState(current: current, signal: nil)
        XCTAssertEqual(next.intensity, 0.0)
    }
}
