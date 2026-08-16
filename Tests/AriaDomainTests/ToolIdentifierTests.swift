import XCTest
@testable import AriaDomain

final class ToolIdentifierTests: XCTestCase {
    
    func testInitialization() {
        let identifier = ToolIdentifier("open_application")
        XCTAssertEqual(identifier.rawValue, "open_application")
    }
    
    func testValidIdentifier() {
        let validIdentifier = ToolIdentifier("open_application")
        XCTAssertTrue(validIdentifier.isValid)
    }
    
    func testInvalidIdentifierWithUppercase() {
        let invalidIdentifier = ToolIdentifier("Open_Application")
        XCTAssertFalse(invalidIdentifier.isValid)
    }
    
    func testInvalidIdentifierWithSpaces() {
        let invalidIdentifier = ToolIdentifier("open application")
        XCTAssertFalse(invalidIdentifier.isValid)
    }
    
    func testInvalidIdentifierWithSpecialCharacters() {
        let invalidIdentifier = ToolIdentifier("open-application")
        XCTAssertFalse(invalidIdentifier.isValid)
    }
    
    func testValidIdentifierWithNumbers() {
        let validIdentifier = ToolIdentifier("tool_123")
        XCTAssertTrue(validIdentifier.isValid)
    }
    
    func testHashableAndEquatable() {
        let identifier1 = ToolIdentifier("open_application")
        let identifier2 = ToolIdentifier("open_application")
        let identifier3 = ToolIdentifier("open_file")
        
        XCTAssertEqual(identifier1, identifier2)
        XCTAssertNotEqual(identifier1, identifier3)
        XCTAssertEqual(identifier1.hashValue, identifier2.hashValue)
    }
    
    func testCommonIdentifiers() {
        XCTAssertEqual(ToolIdentifier.openApplication.rawValue, "open_application")
        XCTAssertEqual(ToolIdentifier.openFile.rawValue, "open_file")
        XCTAssertEqual(ToolIdentifier.openFolder.rawValue, "open_folder")
        XCTAssertEqual(ToolIdentifier.getSystemInfo.rawValue, "get_system_info")
        XCTAssertEqual(ToolIdentifier.getBatteryStatus.rawValue, "get_battery_status")
        XCTAssertEqual(ToolIdentifier.getStorageInfo.rawValue, "get_storage_info")
    }
}