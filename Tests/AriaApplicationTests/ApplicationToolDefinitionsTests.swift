import XCTest
@testable import AriaDomain
@testable import AriaApplication

final class ApplicationToolDefinitionsTests: XCTestCase {
    
    func testOpenApplicationDefinition() {
        let definition = ApplicationToolDefinitions.openApplication
        
        XCTAssertEqual(definition.identifier, .openApplication)
        XCTAssertEqual(definition.description, "Open an installed macOS application by name")
        XCTAssertEqual(definition.riskLevel, .safe)
        XCTAssertEqual(definition.category, .application)
        XCTAssertFalse(definition.requiresConfirmation)
        
        XCTAssertEqual(definition.parameters.count, 1)
        let parameter = definition.parameters[0]
        XCTAssertEqual(parameter.name, "applicationName")
        XCTAssertEqual(parameter.type, .string)
        XCTAssertTrue(parameter.isRequired)
    }
    
    func testQuitApplicationDefinition() {
        let definition = ApplicationToolDefinitions.quitApplication
        
        XCTAssertEqual(definition.identifier, .quitApplication)
        XCTAssertEqual(definition.description, "Quit a running macOS application by name")
        XCTAssertEqual(definition.riskLevel, .safe)
        XCTAssertEqual(definition.category, .application)
        XCTAssertFalse(definition.requiresConfirmation)
        
        XCTAssertEqual(definition.parameters.count, 1)
        let parameter = definition.parameters[0]
        XCTAssertEqual(parameter.name, "applicationName")
        XCTAssertEqual(parameter.type, .string)
        XCTAssertTrue(parameter.isRequired)
    }
    
    func testFocusApplicationDefinition() {
        let definition = ApplicationToolDefinitions.focusApplication
        
        XCTAssertEqual(definition.identifier, .focusApplication)
        XCTAssertEqual(definition.description, "Bring a running macOS application to the foreground by name")
        XCTAssertEqual(definition.riskLevel, .safe)
        XCTAssertEqual(definition.category, .application)
        XCTAssertFalse(definition.requiresConfirmation)
        
        XCTAssertEqual(definition.parameters.count, 1)
        let parameter = definition.parameters[0]
        XCTAssertEqual(parameter.name, "applicationName")
        XCTAssertEqual(parameter.type, .string)
        XCTAssertTrue(parameter.isRequired)
    }
    
    func testAllApplicationTools() {
        let allTools = ApplicationToolDefinitions.all
        
        XCTAssertEqual(allTools.count, 3)
        
        let identifiers = allTools.map { $0.identifier }
        XCTAssertTrue(identifiers.contains(.openApplication))
        XCTAssertTrue(identifiers.contains(.quitApplication))
        XCTAssertTrue(identifiers.contains(.focusApplication))
    }
}