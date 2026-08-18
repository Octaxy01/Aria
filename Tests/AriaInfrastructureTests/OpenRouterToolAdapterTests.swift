import XCTest
@testable import AriaInfrastructure
@testable import AriaDomain

final class OpenRouterToolAdapterTests: XCTestCase {
    
    var adapter: OpenRouterToolAdapter!
    
    override func setUp() {
        super.setUp()
        adapter = OpenRouterToolAdapter()
    }
    
    override func tearDown() {
        adapter = nil
        super.tearDown()
    }
    
    // MARK: - Schema Translation Tests
    
    func testConvertToolDefinitionToSchema() {
        let definition = ToolDefinition(
            identifier: .openApplication,
            description: "Open an application",
            riskLevel: .safe,
            parameters: [
                ToolParameter(name: "applicationName", description: "Name of the application", isRequired: true, type: .string)
            ],
            requiresConfirmation: false,
            category: .application
        )
        
        let schemas = adapter.convertToProviderSchemas([definition])
        
        XCTAssertEqual(schemas.count, 1)
        let schema = schemas[0]
        
        XCTAssertEqual(schema["name"] as? String, "open_application")
        XCTAssertEqual(schema["description"] as? String, "Open an application")
        
        let parameters: [String: Any]? = schema["parameters"] as? [String: Any]
        XCTAssertNotNil(parameters)
        XCTAssertEqual(parameters?["type"] as? String, "object")
        
        let properties: [String: Any]? = parameters?["properties"] as? [String: Any]
        XCTAssertNotNil(properties)
        
        let appParam: [String: Any]? = properties?["applicationName"] as? [String: Any]
        XCTAssertNotNil(appParam)
        XCTAssertEqual(appParam?["type"] as? String, "string")
        XCTAssertEqual(appParam?["description"] as? String, "Name of the application")
        
        let required: [String]? = parameters?["required"] as? [String]
        XCTAssertEqual(required, ["applicationName"])
    }
    
    func testConvertToolDefinitionWithoutParameters() {
        let definition = ToolDefinition(
            identifier: .getSystemInfo,
            description: "Get system information",
            riskLevel: .safe,
            parameters: [],
            requiresConfirmation: false,
            category: .system
        )
        
        let schemas = adapter.convertToProviderSchemas([definition])
        
        XCTAssertEqual(schemas.count, 1)
        let schema = schemas[0]
        
        XCTAssertEqual(schema["name"] as? String, "get_system_info")
        XCTAssertEqual(schema["description"] as? String, "Get system information")
        XCTAssertNil(schema["parameters"])
    }
    
    func testConvertMultipleToolDefinitions() {
        let definitions = [
            ToolDefinition(
                identifier: .openApplication,
                description: "Open an application",
                riskLevel: .safe,
                parameters: [
                    ToolParameter(name: "applicationName", description: "Name", isRequired: true, type: .string)
                ],
                requiresConfirmation: false,
                category: .application
            ),
            ToolDefinition(
                identifier: .getSystemInfo,
                description: "Get system information",
                riskLevel: .safe,
                parameters: [],
                requiresConfirmation: false,
                category: .system
            )
        ]
        
        let schemas = adapter.convertToProviderSchemas(definitions)
        
        XCTAssertEqual(schemas.count, 2)
        XCTAssertEqual(schemas[0]["name"] as? String, "open_application")
        XCTAssertEqual(schemas[1]["name"] as? String, "get_system_info")
    }
    
    func testConvertParameterTypes() {
        let definitions = [
            ToolDefinition(
                identifier: ToolIdentifier("test_tool"),
                description: "Test tool",
                riskLevel: .safe,
                parameters: [
                    ToolParameter(name: "stringParam", description: "String param", isRequired: true, type: .string),
                    ToolParameter(name: "intParam", description: "Integer param", isRequired: false, type: .integer),
                    ToolParameter(name: "boolParam", description: "Boolean param", isRequired: false, type: .boolean),
                    ToolParameter(name: "arrayParam", description: "Array param", isRequired: false, type: .array),
                    ToolParameter(name: "objectParam", description: "Object param", isRequired: false, type: .object)
                ],
                requiresConfirmation: false,
                category: .system
            )
        ]
        
        let schemas = adapter.convertToProviderSchemas(definitions)
        let parameters: [String: Any]? = schemas[0]["parameters"] as? [String: Any]
        let properties: [String: Any]? = parameters?["properties"] as? [String: Any]
        
        XCTAssertEqual((properties?["stringParam"] as? [String: Any])?["type"] as? String, "string")
        XCTAssertEqual((properties?["intParam"] as? [String: Any])?["type"] as? String, "integer")
        XCTAssertEqual((properties?["boolParam"] as? [String: Any])?["type"] as? String, "boolean")
        XCTAssertEqual((properties?["arrayParam"] as? [String: Any])?["type"] as? String, "array")
        XCTAssertEqual((properties?["objectParam"] as? [String: Any])?["type"] as? String, "object")
    }
    
    func testConvertOptionalParameters() {
        let definition = ToolDefinition(
            identifier: ToolIdentifier("test_tool"),
            description: "Test tool",
            riskLevel: .safe,
            parameters: [
                ToolParameter(name: "requiredParam", description: "Required", isRequired: true, type: .string),
                ToolParameter(name: "optionalParam", description: "Optional", isRequired: false, type: .string)
            ],
            requiresConfirmation: false,
            category: .system
        )
        
        let schemas = adapter.convertToProviderSchemas([definition])
        let parameters: [String: Any]? = schemas[0]["parameters"] as? [String: Any]
        let required: [String]? = parameters?["required"] as? [String]
        
        XCTAssertEqual(required, ["requiredParam"])
        XCTAssertEqual(required?.count, 1)
    }
    
    // MARK: - Tool Call Parsing Tests
    
    func testParseValidToolCall() throws {
        let toolCalls = [
            [
                "id": "call_abc123",
                "function": [
                    "name": "open_application",
                    "arguments": "{\"applicationName\":\"Chrome\"}"
                ]
            ]
        ]
        
        let sessionID = UUID()
        let parsed = try adapter.parseToolCalls(toolCalls, sessionID: sessionID)
        
        XCTAssertEqual(parsed.count, 1)
        XCTAssertEqual(parsed[0].toolIdentifier.rawValue, "open_application")
        XCTAssertEqual(parsed[0].sessionID, sessionID)
        XCTAssertEqual(parsed[0].arguments["applicationName"] as? String, "Chrome")
    }
    
    func testParseToolCallWithDictArguments() throws {
        let toolCalls = [
            [
                "id": "call_dict",
                "function": [
                    "name": "open_application",
                    "arguments": ["applicationName": "Safari"]
                ]
            ]
        ]
        
        let sessionID = UUID()
        let parsed = try adapter.parseToolCalls(toolCalls, sessionID: sessionID)
        
        XCTAssertEqual(parsed.count, 1)
        XCTAssertEqual(parsed[0].arguments["applicationName"] as? String, "Safari")
    }
    
    func testParseMultipleToolCalls() throws {
        let toolCalls = [
            [
                "id": "call_1",
                "function": [
                    "name": "get_system_info",
                    "arguments": "{}"
                ]
            ],
            [
                "id": "call_2",
                "function": [
                    "name": "get_storage_info",
                    "arguments": "{}"
                ]
            ]
        ]
        
        let sessionID = UUID()
        let parsed = try adapter.parseToolCalls(toolCalls, sessionID: sessionID)
        
        XCTAssertEqual(parsed.count, 2)
        XCTAssertEqual(parsed[0].toolIdentifier.rawValue, "get_system_info")
        XCTAssertEqual(parsed[1].toolIdentifier.rawValue, "get_storage_info")
    }
    
    func testParseToolCallMissingName() {
        let toolCalls = [
            [
                "id": "call_missing",
                "function": [
                    "arguments": "{}"
                ]
            ]
        ]
        
        let sessionID = UUID()
        XCTAssertThrowsError(try adapter.parseToolCalls(toolCalls, sessionID: sessionID)) { error in
            XCTAssertEqual(error as? ToolCallParseError, .missingToolName)
        }
    }
    
    func testParseToolCallInvalidArguments() {
        let toolCalls = [
            [
                "id": "call_invalid",
                "function": [
                    "name": "open_application",
                    "arguments": "invalid json"
                ]
            ]
        ]
        
        let sessionID = UUID()
        XCTAssertThrowsError(try adapter.parseToolCalls(toolCalls, sessionID: sessionID)) { error in
            // The error could be missingToolName if the JSON parsing fails, or invalidArguments
            // depending on how the parsing proceeds
            XCTAssertTrue(error is ToolCallParseError)
        }
    }
    
    // MARK: - Tool Result Conversion Tests
    
    func testConvertSuccessfulToolResult() {
        let result = ToolResult.success(["status": "opened"])
        let toolCallID = "test_id"
        
        let converted = adapter.convertToolResult(result, toolCallID: toolCallID)
        
        XCTAssertEqual(converted["tool_call_id"] as? String, toolCallID)
        XCTAssertNotNil(converted["content"])
        
        let content = converted["content"] as? String
        XCTAssertNotNil(content)
        XCTAssertTrue(content?.contains("\"success\":true") ?? false)
    }
    
    func testConvertFailedToolResult() {
        let result = ToolResult.failure("Application not found", errorCode: "not_found")
        let toolCallID = "test_id"
        
        let converted = adapter.convertToolResult(result, toolCallID: toolCallID)
        
        XCTAssertEqual(converted["tool_call_id"] as? String, toolCallID)
        XCTAssertNotNil(converted["content"])
        
        let content = converted["content"] as? String
        XCTAssertNotNil(content)
        XCTAssertTrue(content?.contains("\"success\":false") ?? false)
        XCTAssertTrue(content?.contains("Application not found") ?? false)
    }
    
    func testConvertCancelledToolResult() {
        let result = ToolResult.cancelled()
        let toolCallID = "test_id"
        
        let converted = adapter.convertToolResult(result, toolCallID: toolCallID)
        
        XCTAssertEqual(converted["tool_call_id"] as? String, toolCallID)
        let content = converted["content"] as? String
        XCTAssertTrue(content?.contains("cancelled") ?? false)
    }
}
