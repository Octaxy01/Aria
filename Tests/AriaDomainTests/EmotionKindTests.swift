import XCTest
@testable import AriaDomain

final class EmotionKindTests: XCTestCase {
    func testAllExpectedEmotionsExist() {
        let expected: Set<EmotionKind> = [
            .neutral, .happy, .affectionate, .embarrassed, .annoyed,
            .sad, .worried, .excited, .playful, .angry
        ]
        XCTAssertEqual(Set(EmotionKind.allCases), expected)
    }

    func testInitialEmotionStateIsNeutralAndZeroIntensity() {
        XCTAssertEqual(EmotionState.initial.current, .neutral)
        XCTAssertEqual(EmotionState.initial.intensity, 0.0)
    }
}
