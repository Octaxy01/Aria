import XCTest
@testable import AriaDomain

final class CharacterProfileTests: XCTestCase {
    func testDefaultAriaProfileHasNameAndNonEmptyTraits() {
        let profile = CharacterProfile.aria
        XCTAssertEqual(profile.name, "Aria")
        XCTAssertFalse(profile.traits.isEmpty)
        XCTAssertFalse(profile.guidelines.isEmpty)
        XCTAssertFalse(profile.speakingStyle.isEmpty)
        XCTAssertFalse(profile.toneGuidelines.isEmpty)
    }
    
    func testProfileContainsPersonalityGuidance() {
        let profile = CharacterProfile.aria
        
        // Check for key personality elements
        let allGuidelines = profile.guidelines.joined(separator: " ").lowercased()
        XCTAssertTrue(allGuidelines.contains("priorit") || allGuidelines.contains("priority"))
        XCTAssertTrue(allGuidelines.contains("correct"))
        XCTAssertTrue(allGuidelines.contains("tsundere"))
    }
    
    func testProfileContainsSituationalBehavior() {
        let profile = CharacterProfile.aria
        
        // Check for situational tone guidelines
        let allToneGuidelines = profile.toneGuidelines.joined(separator: " ").lowercased()
        XCTAssertTrue(allToneGuidelines.contains("casual"))
        XCTAssertTrue(allToneGuidelines.contains("serious"))
        XCTAssertTrue(allToneGuidelines.contains("achievement"))
    }
}
