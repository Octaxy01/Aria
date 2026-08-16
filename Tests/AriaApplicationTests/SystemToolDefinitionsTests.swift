import XCTest
@testable import AriaDomain
@testable import AriaApplication

final class SystemToolDefinitionsTests: XCTestCase {
    
    // MARK: - get_system_info Tests
    
    func testGetSystemInfoDefinition() {
        let definition = SystemToolDefinitions.getSystemInfo
        
        XCTAssertEqual(definition.identifier, .getSystemInfo)
        XCTAssertEqual(definition.description, "Get basic information about the Mac and macOS system")
        XCTAssertEqual(definition.riskLevel, .safe)
        XCTAssertEqual(definition.category, .system)
        XCTAssertTrue(definition.parameters.isEmpty)
        XCTAssertFalse(definition.requiresConfirmation)
    }
    
    // MARK: - get_battery_status Tests
    
    func testGetBatteryStatusDefinition() {
        let definition = SystemToolDefinitions.getBatteryStatus
        
        XCTAssertEqual(definition.identifier, .getBatteryStatus)
        XCTAssertEqual(definition.description, "Get the current Mac battery status")
        XCTAssertEqual(definition.riskLevel, .safe)
        XCTAssertEqual(definition.category, .system)
        XCTAssertTrue(definition.parameters.isEmpty)
        XCTAssertFalse(definition.requiresConfirmation)
    }
    
    // MARK: - get_storage_info Tests
    
    func testGetStorageInfoDefinition() {
        let definition = SystemToolDefinitions.getStorageInfo
        
        XCTAssertEqual(definition.identifier, .getStorageInfo)
        XCTAssertEqual(definition.description, "Get storage information for the Mac")
        XCTAssertEqual(definition.riskLevel, .safe)
        XCTAssertEqual(definition.category, .system)
        XCTAssertTrue(definition.parameters.isEmpty)
        XCTAssertFalse(definition.requiresConfirmation)
    }
    
    // MARK: - All Tools Tests
    
    func testAllSystemTools() {
        let allTools = SystemToolDefinitions.all
        
        XCTAssertEqual(allTools.count, 3)
        
        let identifiers = allTools.map { $0.identifier }
        XCTAssertTrue(identifiers.contains(.getSystemInfo))
        XCTAssertTrue(identifiers.contains(.getBatteryStatus))
        XCTAssertTrue(identifiers.contains(.getStorageInfo))
    }
    
    func testAllSystemToolsAreSafe() {
        let allTools = SystemToolDefinitions.all
        
        for tool in allTools {
            XCTAssertEqual(tool.riskLevel, .safe, "System tools should be safe")
        }
    }
    
    func testAllSystemToolsAreInSystemCategory() {
        let allTools = SystemToolDefinitions.all
        
        for tool in allTools {
            XCTAssertEqual(tool.category, .system, "System tools should be in system category")
        }
    }
    
    func testAllSystemToolsRequireNoParameters() {
        let allTools = SystemToolDefinitions.all
        
        for tool in allTools {
            XCTAssertTrue(tool.parameters.isEmpty, "System tools should require no parameters")
        }
    }
    
    func testAllSystemToolsRequireNoConfirmation() {
        let allTools = SystemToolDefinitions.all
        
        for tool in allTools {
            XCTAssertFalse(tool.requiresConfirmation, "System tools should not require confirmation")
        }
    }
}
