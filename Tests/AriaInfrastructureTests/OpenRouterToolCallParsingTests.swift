import XCTest
@testable import AriaInfrastructure
@testable import AriaDomain

/// Tests for OpenRouter tool call JSON parsing and LLM continuation.
final class OpenRouterToolCallParsingTests: XCTestCase {
    
    var toolAdapter: OpenRouterToolAdapter!
    var sessionID: UUID!
    
    override func setUp() {
        super.setUp()
        toolAdapter = OpenRouterToolAdapter()
        sessionID = UUID()
    }
    
    // MARK: - Tool Call JSON Parsing Tests
    
    func testParseToolCallWithContentNull() throws {
        // Test OpenRouter response with content=null and tool_calls present
        let providerToolCalls: [[String: Any]] = [
            [
                "id": "call_abc123",
                "type": "function",
                "function": [
                    "name": "open_application",
                    "arguments": "{\"applicationName\":\"Safari\"}"
                ]
            ]
        ]
        
        let ariaToolCalls = try toolAdapter.parseToolCalls(providerToolCalls, sessionID: sessionID)
        
        XCTAssertEqual(ariaToolCalls.count, 1)
        XCTAssertEqual(ariaToolCalls[0].toolIdentifier.rawValue, "open_application")
        XCTAssertEqual(ariaToolCalls[0].arguments["applicationName"] as? String, "Safari")
        XCTAssertEqual(ariaToolCalls[0].sessionID, sessionID)
        // Correlation ID should be mapped from provider call ID
        XCTAssertNotNil(ariaToolCalls[0].correlationID)
    }
    
    func testParseToolCallWithMalformedArguments() throws {
        // Test with malformed JSON arguments
        let providerToolCalls: [[String: Any]] = [
            [
                "id": "call_xyz789",
                "type": "function",
                "function": [
                    "name": "open_file",
                    "arguments": "invalid json {"
                ]
            ]
        ]
        
        XCTAssertThrowsError(try toolAdapter.parseToolCalls(providerToolCalls, sessionID: sessionID)) { error in
            XCTAssertTrue(error is ToolCallParseError)
        }
    }
    
    func testParseUnknownTool() throws {
        // Test with unknown tool identifier
        let providerToolCalls: [[String: Any]] = [
            [
                "id": "call_unknown",
                "type": "function",
                "function": [
                    "name": "unknown_tool_that_does_not_exist",
                    "arguments": "{}"
                ]
            ]
        ]
        
        let ariaToolCalls = try toolAdapter.parseToolCalls(providerToolCalls, sessionID: sessionID)
        
        XCTAssertEqual(ariaToolCalls.count, 1)
        XCTAssertEqual(ariaToolCalls[0].toolIdentifier.rawValue, "unknown_tool_that_does_not_exist")
        // The validation should happen later in ToolOrchestrator, not during parsing
    }
    
    func testParseMultipleToolCalls() throws {
        // Test with multiple tool calls in single response
        let providerToolCalls: [[String: Any]] = [
            [
                "id": "call_1",
                "type": "function",
                "function": [
                    "name": "open_application",
                    "arguments": "{\"applicationName\":\"Safari\"}"
                ]
            ],
            [
                "id": "call_2",
                "type": "function",
                "function": [
                    "name": "get_system_info",
                    "arguments": "{}"
                ]
            ]
        ]
        
        let ariaToolCalls = try toolAdapter.parseToolCalls(providerToolCalls, sessionID: sessionID)
        
        XCTAssertEqual(ariaToolCalls.count, 2)
        XCTAssertEqual(ariaToolCalls[0].toolIdentifier.rawValue, "open_application")
        XCTAssertEqual(ariaToolCalls[1].toolIdentifier.rawValue, "get_system_info")
    }
    
    func testParseToolCallWithArgumentsAsObject() throws {
        // Test with arguments as object instead of JSON string
        let providerToolCalls: [[String: Any]] = [
            [
                "id": "call_obj",
                "type": "function",
                "function": [
                    "name": "open_file",
                    "arguments": [
                        "path": "/Users/test/file.txt"
                    ]
                ]
            ]
        ]
        
        let ariaToolCalls = try toolAdapter.parseToolCalls(providerToolCalls, sessionID: sessionID)
        
        XCTAssertEqual(ariaToolCalls.count, 1)
        XCTAssertEqual(ariaToolCalls[0].toolIdentifier.rawValue, "open_file")
        XCTAssertEqual(ariaToolCalls[0].arguments["path"] as? String, "/Users/test/file.txt")
    }
    
    func testParseToolCallWithComplexArguments() throws {
        // Test with complex nested arguments
        let providerToolCalls: [[String: Any]] = [
            [
                "id": "call_complex",
                "type": "function",
                "function": [
                    "name": "find_file",
                    "arguments": "{\"query\":\"test\",\"searchScope\":\"/Users/test\",\"maxResults\":10}"
                ]
            ]
        ]
        
        let ariaToolCalls = try toolAdapter.parseToolCalls(providerToolCalls, sessionID: sessionID)
        
        XCTAssertEqual(ariaToolCalls.count, 1)
        XCTAssertEqual(ariaToolCalls[0].toolIdentifier.rawValue, "find_file")
        XCTAssertEqual(ariaToolCalls[0].arguments["query"] as? String, "test")
        XCTAssertEqual(ariaToolCalls[0].arguments["searchScope"] as? String, "/Users/test")
        XCTAssertEqual(ariaToolCalls[0].arguments["maxResults"] as? Int, 10)
    }
    
    func testParseToolCallMissingToolName() throws {
        // Test with missing tool name
        let providerToolCalls: [[String: Any]] = [
            [
                "id": "call_missing",
                "type": "function",
                "function": [
                    "arguments": "{}"
                ]
            ]
        ]
        
        XCTAssertThrowsError(try toolAdapter.parseToolCalls(providerToolCalls, sessionID: sessionID)) { error in
            XCTAssertEqual(error as? ToolCallParseError, .missingToolName)
        }
    }
    
    func testParseToolCallMissingCallID() throws {
        // Test with missing call ID
        let providerToolCalls: [[String: Any]] = [
            [
                "type": "function",
                "function": [
                    "name": "open_application",
                    "arguments": "{\"applicationName\":\"Safari\"}"
                ]
            ]
        ]
        
        XCTAssertThrowsError(try toolAdapter.parseToolCalls(providerToolCalls, sessionID: sessionID)) { error in
            XCTAssertEqual(error as? ToolCallParseError, .missingToolName)
        }
    }
    
    func testParseToolCallEmptyArguments() throws {
        // Test with empty arguments object
        let providerToolCalls: [[String: Any]] = [
            [
                "id": "call_empty",
                "type": "function",
                "function": [
                    "name": "get_system_info",
                    "arguments": "{}"
                ]
            ]
        ]
        
        let ariaToolCalls = try toolAdapter.parseToolCalls(providerToolCalls, sessionID: sessionID)
        
        XCTAssertEqual(ariaToolCalls.count, 1)
        XCTAssertEqual(ariaToolCalls[0].toolIdentifier.rawValue, "get_system_info")
        XCTAssertEqual(ariaToolCalls[0].arguments.count, 0)
    }
    
    // MARK: - Tool Result Conversion Tests
    
    func testConvertToolResultSuccess() {
        let result = ToolResult.success([
            "applicationName": "Safari",
            "path": "/Applications/Safari.app"
        ])
        
        let providerResult = toolAdapter.convertToolResult(result, toolCallID: "call_abc123")
        
        XCTAssertEqual(providerResult["tool_call_id"] as? String, "call_abc123")
        XCTAssertNotNil(providerResult["content"])
        
        if let contentString = providerResult["content"] as? String,
           let contentData = contentString.data(using: .utf8),
           let contentDict = try? JSONSerialization.jsonObject(with: contentData) as? [String: Any] {
            XCTAssertTrue(contentDict["success"] as? Bool ?? false)
            XCTAssertNotNil(contentDict["data"])
        }
    }
    
    func testConvertToolResultFailure() {
        let result = ToolResult.failure("File not found", errorCode: "file_not_found")
        
        let providerResult = toolAdapter.convertToolResult(result, toolCallID: "call_failed")
        
        XCTAssertEqual(providerResult["tool_call_id"] as? String, "call_failed")
        XCTAssertNotNil(providerResult["content"])
        
        if let contentString = providerResult["content"] as? String,
           let contentData = contentString.data(using: .utf8),
           let contentDict = try? JSONSerialization.jsonObject(with: contentData) as? [String: Any] {
            XCTAssertFalse(contentDict["success"] as? Bool ?? true)
            XCTAssertEqual(contentDict["error"] as? String, "File not found")
            XCTAssertEqual(contentDict["errorCode"] as? String, "file_not_found")
        }
    }
    
    func testConvertToolResultEmptyData() {
        let result = ToolResult.success([:])
        
        let providerResult = toolAdapter.convertToolResult(result, toolCallID: "call_empty")
        
        XCTAssertEqual(providerResult["tool_call_id"] as? String, "call_empty")
        XCTAssertNotNil(providerResult["content"])
    }
    
    // MARK: - Correlation ID Mapping Tests
    
    func testCorrelationIDMapping() throws {
        // Test that provider call IDs are mapped to correlation IDs
        let sessionID = UUID()
        let providerToolCalls: [[String: Any]] = [
            [
                "id": "call_unique_12345",
                "type": "function",
                "function": [
                    "name": "open_application",
                    "arguments": "{\"applicationName\":\"Safari\"}"
                ]
            ]
        ]
        
        let ariaToolCalls = try toolAdapter.parseToolCalls(providerToolCalls, sessionID: sessionID)
        
        // The correlation ID should be a valid UUID (randomly generated for non-UUID provider IDs)
        let correlationID = ariaToolCalls[0].correlationID
        
        // Verify correlation ID is a valid UUID by checking it can be reconstructed
        let uuidString = correlationID.uuidString
        let reconstructedUUID = UUID(uuidString: uuidString)
        XCTAssertNotNil(reconstructedUUID, "Correlation ID should be a valid UUID, got: \(uuidString)")
    }
    
    func testCorrelationIDUniqueness() throws {
        // Test that different tool calls get different correlation IDs
        let providerToolCalls: [[String: Any]] = [
            [
                "id": "call_1",
                "type": "function",
                "function": [
                    "name": "open_application",
                    "arguments": "{\"applicationName\":\"Safari\"}"
                ]
            ],
            [
                "id": "call_2",
                "type": "function",
                "function": [
                    "name": "open_application",
                    "arguments": "{\"applicationName\":\"Chrome\"}"
                ]
            ]
        ]
        
        let ariaToolCalls = try toolAdapter.parseToolCalls(providerToolCalls, sessionID: sessionID)
        
        XCTAssertEqual(ariaToolCalls.count, 2)
        XCTAssertNotEqual(ariaToolCalls[0].correlationID, ariaToolCalls[1].correlationID)
    }
}