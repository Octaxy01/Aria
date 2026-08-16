import XCTest
@testable import AriaApplication
@testable import AriaDomain

final class ToolRegistryTests: XCTestCase {
    
    var registry: ToolRegistry!
    
    override func setUp() async throws {
        try await super.setUp()
        registry = ToolRegistry()
    }
    
    override func tearDown() async throws {
        registry = nil
        try await super.tearDown()
    }
    
    func testRegisterTool() async throws {
        let identifier = ToolIdentifier("test_tool")
        let definition = ToolDefinition(
            identifier: identifier,
            description: "Test tool",
            riskLevel: .safe
        )
        
        try await registry.register(definition)
        
        let retrieved = await registry.tool(for: identifier)
        XCTAssertNotNil(retrieved)
        XCTAssertEqual(retrieved?.identifier, identifier)
    }
    
    func testRegisterDuplicateIdentifier() async throws {
        let identifier = ToolIdentifier("test_tool")
        let definition1 = ToolDefinition(
            identifier: identifier,
            description: "First tool",
            riskLevel: .safe
        )
        let definition2 = ToolDefinition(
            identifier: identifier,
            description: "Second tool",
            riskLevel: .safe
        )
        
        try await registry.register(definition1)
        
        do {
            try await registry.register(definition2)
            XCTFail("Should have thrown duplicate identifier error")
        } catch RegistrationError.duplicateIdentifier(let id) {
            XCTAssertEqual(id, identifier.rawValue)
        } catch {
            XCTFail("Expected RegistrationError.duplicateIdentifier, got \(error)")
        }
    }
    
    func testRetrieveNonExistentTool() async {
        let identifier = ToolIdentifier("nonexistent_tool")
        
        let retrieved = await registry.tool(for: identifier)
        XCTAssertNil(retrieved)
    }
    
    func testHasTool() async throws {
        let identifier = ToolIdentifier("test_tool")
        let definition = ToolDefinition(
            identifier: identifier,
            description: "Test tool",
            riskLevel: .safe
        )
        
        let hasToolBefore = await registry.hasTool(identifier)
        XCTAssertFalse(hasToolBefore)
        
        try await registry.register(definition)
        
        let hasToolAfter = await registry.hasTool(identifier)
        XCTAssertTrue(hasToolAfter)
    }
    
    func testAllTools() async throws {
        let identifier1 = ToolIdentifier("tool_1")
        let identifier2 = ToolIdentifier("tool_2")
        let definition1 = ToolDefinition(
            identifier: identifier1,
            description: "Tool 1",
            riskLevel: .safe
        )
        let definition2 = ToolDefinition(
            identifier: identifier2,
            description: "Tool 2",
            riskLevel: .safe
        )
        
        try await registry.register(definition1)
        try await registry.register(definition2)
        
        let allTools = await registry.allTools()
        XCTAssertEqual(allTools.count, 2)
        
        let identifiers = allTools.map { $0.identifier }
        XCTAssertTrue(identifiers.contains(identifier1))
        XCTAssertTrue(identifiers.contains(identifier2))
    }
    
    func testAllIdentifiers() async throws {
        let identifier1 = ToolIdentifier("tool_1")
        let identifier2 = ToolIdentifier("tool_2")
        let definition1 = ToolDefinition(
            identifier: identifier1,
            description: "Tool 1",
            riskLevel: .safe
        )
        let definition2 = ToolDefinition(
            identifier: identifier2,
            description: "Tool 2",
            riskLevel: .safe
        )
        
        try await registry.register(definition1)
        try await registry.register(definition2)
        
        let identifiers = await registry.allIdentifiers()
        XCTAssertEqual(identifiers.count, 2)
        XCTAssertTrue(identifiers.contains(identifier1))
        XCTAssertTrue(identifiers.contains(identifier2))
    }
    
    func testFilterByCategory() async throws {
        let identifier1 = ToolIdentifier("app_tool")
        let identifier2 = ToolIdentifier("file_tool")
        let definition1 = ToolDefinition(
            identifier: identifier1,
            description: "App tool",
            riskLevel: .safe,
            category: .application
        )
        let definition2 = ToolDefinition(
            identifier: identifier2,
            description: "File tool",
            riskLevel: .safe,
            category: .file
        )
        
        try await registry.register(definition1)
        try await registry.register(definition2)
        
        let appTools = await registry.tools(inCategory: .application)
        XCTAssertEqual(appTools.count, 1)
        XCTAssertEqual(appTools[0].identifier, identifier1)
        
        let fileTools = await registry.tools(inCategory: .file)
        XCTAssertEqual(fileTools.count, 1)
        XCTAssertEqual(fileTools[0].identifier, identifier2)
    }
    
    func testFilterByRiskLevel() async throws {
        let identifier1 = ToolIdentifier("safe_tool")
        let identifier2 = ToolIdentifier("destructive_tool")
        let definition1 = ToolDefinition(
            identifier: identifier1,
            description: "Safe tool",
            riskLevel: .safe
        )
        let definition2 = ToolDefinition(
            identifier: identifier2,
            description: "Destructive tool",
            riskLevel: .destructive,
            requiresConfirmation: true
        )
        
        try await registry.register(definition1)
        try await registry.register(definition2)
        
        let safeTools = await registry.tools(withRiskLevel: .safe)
        XCTAssertEqual(safeTools.count, 1)
        XCTAssertEqual(safeTools[0].identifier, identifier1)
        
        let destructiveTools = await registry.tools(withRiskLevel: .destructive)
        XCTAssertEqual(destructiveTools.count, 1)
        XCTAssertEqual(destructiveTools[0].identifier, identifier2)
    }
    
    func testUnregisterTool() async throws {
        let identifier = ToolIdentifier("test_tool")
        let definition = ToolDefinition(
            identifier: identifier,
            description: "Test tool",
            riskLevel: .safe
        )
        
        try await registry.register(definition)
        let hasToolBefore = await registry.hasTool(identifier)
        XCTAssertTrue(hasToolBefore)
        
        let removed = await registry.unregister(identifier)
        XCTAssertNotNil(removed)
        XCTAssertEqual(removed?.identifier, identifier)
        
        let hasToolAfter = await registry.hasTool(identifier)
        XCTAssertFalse(hasToolAfter)
    }
    
    func testUnregisterNonExistentTool() async {
        let identifier = ToolIdentifier("nonexistent_tool")
        
        let removed = await registry.unregister(identifier)
        XCTAssertNil(removed)
    }
    
    func testClear() async throws {
        let identifier1 = ToolIdentifier("tool_1")
        let identifier2 = ToolIdentifier("tool_2")
        let definition1 = ToolDefinition(
            identifier: identifier1,
            description: "Tool 1",
            riskLevel: .safe
        )
        let definition2 = ToolDefinition(
            identifier: identifier2,
            description: "Tool 2",
            riskLevel: .safe
        )
        
        try await registry.register(definition1)
        try await registry.register(definition2)
        
        let toolsBeforeClear = await registry.allTools()
        XCTAssertEqual(toolsBeforeClear.count, 2)
        
        await registry.clear()
        
        let toolsAfterClear = await registry.allTools()
        XCTAssertEqual(toolsAfterClear.count, 0)
    }
}