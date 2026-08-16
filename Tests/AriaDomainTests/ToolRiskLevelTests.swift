import XCTest
@testable import AriaDomain

final class ToolRiskLevelTests: XCTestCase {
    
    func testEquatable() {
        XCTAssertEqual(ToolRiskLevel.safe, ToolRiskLevel.safe)
        XCTAssertNotEqual(ToolRiskLevel.safe, ToolRiskLevel.sensitive)
        XCTAssertNotEqual(ToolRiskLevel.safe, ToolRiskLevel.destructive)
    }
    
    func testRawValue() {
        XCTAssertEqual(ToolRiskLevel.safe.rawValue, "safe")
        XCTAssertEqual(ToolRiskLevel.sensitive.rawValue, "sensitive")
        XCTAssertEqual(ToolRiskLevel.destructive.rawValue, "destructive")
    }
}