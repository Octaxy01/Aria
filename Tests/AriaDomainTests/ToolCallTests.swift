import XCTest
@testable import AriaDomain

final class ToolCallTests: XCTestCase {
    
    func testInitialization() {
        let identifier = ToolIdentifier("open_application")
        let sessionID = UUID()
        let call = ToolCall(
            toolIdentifier: identifier,
            arguments: ["applicationName": "Chrome"],
            sessionID: sessionID
        )
        
        XCTAssertEqual(call.toolIdentifier, identifier)
        XCTAssertEqual(call.arguments["applicationName"] as? String, "Chrome")
        XCTAssertEqual(call.sessionID, sessionID)
        XCTAssertNotEqual(call.correlationID, UUID()) // Should be unique
    }
    
    func testInitializationWithEmptyArguments() {
        let identifier = ToolIdentifier("get_system_info")
        let call = ToolCall(
            toolIdentifier: identifier,
            arguments: [:],
            sessionID: UUID()
        )
        
        XCTAssertTrue(call.arguments.isEmpty)
    }
    
    func testValidateAgainstDefinitionWithValidArguments() {
        let identifier = ToolIdentifier("open_file")
        let definition = ToolDefinition(
            identifier: identifier,
            description: "Opens a file",
            riskLevel: .safe,
            parameters: [
                ToolParameter(name: "filePath", description: "Path to file", isRequired: true, type: .string)
            ]
        )
        let call = ToolCall(
            toolIdentifier: identifier,
            arguments: ["filePath": "/Users/test/file.txt"],
            sessionID: UUID()
        )
        
        XCTAssertNil(call.validateAgainst(definition))
    }
    
    func testValidateAgainstDefinitionWithMissingRequiredParameter() {
        let identifier = ToolIdentifier("open_file")
        let definition = ToolDefinition(
            identifier: identifier,
            description: "Opens a file",
            riskLevel: .safe,
            parameters: [
                ToolParameter(name: "filePath", description: "Path to file", isRequired: true, type: .string)
            ]
        )
        let call = ToolCall(
            toolIdentifier: identifier,
            arguments: [:], // Missing required parameter
            sessionID: UUID()
        )
        
        let error = call.validateAgainst(definition)
        XCTAssertNotNil(error)
        if case let .missingRequiredParameter(paramName) = error {
            XCTAssertEqual(paramName, "filePath")
        } else {
            XCTFail("Expected missingRequiredParameter error")
        }
    }
    
    func testValidateAgainstDefinitionWithOptionalParameter() {
        let identifier = ToolIdentifier("open_file")
        let definition = ToolDefinition(
            identifier: identifier,
            description: "Opens a file",
            riskLevel: .safe,
            parameters: [
                ToolParameter(name: "filePath", description: "Path to file", isRequired: true, type: .string),
                ToolParameter(name: "lineNumber", description: "Line number to open at", isRequired: false, type: .integer)
            ]
        )
        let call = ToolCall(
            toolIdentifier: identifier,
            arguments: ["filePath": "/Users/test/file.txt"], // Optional parameter omitted
            sessionID: UUID()
        )
        
        XCTAssertNil(call.validateAgainst(definition))
    }
}