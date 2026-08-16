import XCTest
@testable import AriaDomain

final class ToolDefinitionTests: XCTestCase {
    
    func testInitialization() {
        let identifier = ToolIdentifier("open_application")
        let definition = ToolDefinition(
            identifier: identifier,
            description: "Opens an application",
            riskLevel: .safe
        )
        
        XCTAssertEqual(definition.identifier, identifier)
        XCTAssertEqual(definition.description, "Opens an application")
        XCTAssertEqual(definition.riskLevel, .safe)
        XCTAssertTrue(definition.parameters.isEmpty)
        XCTAssertFalse(definition.requiresConfirmation)
        XCTAssertNil(definition.category)
    }
    
    func testInitializationWithParameters() {
        let identifier = ToolIdentifier("open_file")
        let parameters = [
            ToolParameter(name: "filePath", description: "Path to the file", isRequired: true, type: .string)
        ]
        let definition = ToolDefinition(
            identifier: identifier,
            description: "Opens a file",
            riskLevel: .safe,
            parameters: parameters,
            requiresConfirmation: false,
            category: .file
        )
        
        XCTAssertEqual(definition.parameters.count, 1)
        XCTAssertEqual(definition.parameters[0].name, "filePath")
        XCTAssertEqual(definition.category, .file)
    }
    
    func testSafeToolByDefault() {
        let definition = ToolDefinition(
            identifier: ToolIdentifier("get_system_info"),
            description: "Gets system information",
            riskLevel: .safe
        )
        
        XCTAssertFalse(definition.requiresConfirmation)
    }
    
    func testDestructiveToolRequiresConfirmation() {
        let definition = ToolDefinition(
            identifier: ToolIdentifier("delete_file"),
            description: "Deletes a file",
            riskLevel: .destructive,
            requiresConfirmation: true
        )
        
        XCTAssertTrue(definition.requiresConfirmation)
    }
    
    func testEquatable() {
        let identifier = ToolIdentifier("open_application")
        let definition1 = ToolDefinition(
            identifier: identifier,
            description: "Opens an application",
            riskLevel: .safe
        )
        let definition2 = ToolDefinition(
            identifier: identifier,
            description: "Opens an application",
            riskLevel: .safe
        )
        let definition3 = ToolDefinition(
            identifier: identifier,
            description: "Opens an application",
            riskLevel: .sensitive
        )
        
        XCTAssertEqual(definition1, definition2)
        XCTAssertNotEqual(definition1, definition3)
    }
}