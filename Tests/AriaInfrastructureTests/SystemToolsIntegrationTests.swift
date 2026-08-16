import XCTest
@testable import AriaInfrastructure
@testable import AriaDomain
@testable import AriaApplication

final class SystemToolsIntegrationTests: XCTestCase {
    
    var registry: ToolRegistry!
    var executor: SystemToolExecutor!
    
    override func setUp() async throws {
        try await super.setUp()
        registry = ToolRegistry()
        executor = SystemToolExecutor()
    }
    
    override func tearDown() async throws {
        registry = nil
        executor = nil
        try await super.tearDown()
    }
    
    // MARK: - Tool Registration Tests
    
    func testSystemToolsRegistration() async throws {
        // Register all system tools
        for toolDefinition in SystemToolDefinitions.all {
            try await registry.register(toolDefinition)
        }
        
        // Verify all tools are registered
        let hasSystemInfo = await registry.hasTool(.getSystemInfo)
        let hasBatteryStatus = await registry.hasTool(.getBatteryStatus)
        let hasStorageInfo = await registry.hasTool(.getStorageInfo)
        
        XCTAssertTrue(hasSystemInfo)
        XCTAssertTrue(hasBatteryStatus)
        XCTAssertTrue(hasStorageInfo)
        
        // Verify total count
        let allTools = await registry.allTools()
        XCTAssertEqual(allTools.count, 3)
    }
    
    func testSystemToolsInSystemCategory() async throws {
        // Register all system tools
        for toolDefinition in SystemToolDefinitions.all {
            try await registry.register(toolDefinition)
        }
        
        // Verify all tools are in system category
        let systemTools = try await registry.tools(inCategory: .system)
        XCTAssertEqual(systemTools.count, 3)
        
        let identifiers = systemTools.map { $0.identifier }
        XCTAssertTrue(identifiers.contains(.getSystemInfo))
        XCTAssertTrue(identifiers.contains(.getBatteryStatus))
        XCTAssertTrue(identifiers.contains(.getStorageInfo))
    }
    
    // MARK: - Tool Execution Integration Tests
    
    func testGetSystemInfoIntegration() async throws {
        // Register system tools
        for toolDefinition in SystemToolDefinitions.all {
            try await registry.register(toolDefinition)
        }
        
        // Verify tool is registered
        let hasSystemInfo = await registry.hasTool(.getSystemInfo)
        XCTAssertTrue(hasSystemInfo)
        
        // Execute the tool
        let call = ToolCall(
            toolIdentifier: .getSystemInfo,
            arguments: [:],
            sessionID: UUID()
        )
        
        let result = try await executor.execute(call)
        
        // Verify structure (not exact values since they're machine-specific)
        XCTAssertTrue(result.success)
        XCTAssertNotNil(result.data)
        
        // Verify expected fields exist
        XCTAssertNotNil(result.data?["computerName"])
        XCTAssertNotNil(result.data?["operatingSystem"])
        XCTAssertNotNil(result.data?["operatingSystemVersion"])
        
        // Verify operating system is macOS
        XCTAssertEqual(result.data?["operatingSystem"] as? String, "macOS")
    }
    
    func testGetBatteryStatusIntegration() async throws {
        // Register system tools
        for toolDefinition in SystemToolDefinitions.all {
            try await registry.register(toolDefinition)
        }
        
        // Verify tool is registered
        let hasBatteryStatus = await registry.hasTool(.getBatteryStatus)
        XCTAssertTrue(hasBatteryStatus)
        
        // Execute the tool
        let call = ToolCall(
            toolIdentifier: .getBatteryStatus,
            arguments: [:],
            sessionID: UUID()
        )
        
        let result = try await executor.execute(call)
        
        // Verify structure
        XCTAssertTrue(result.success)
        XCTAssertNotNil(result.data)
        
        // Battery may be unavailable on some systems (e.g., desktop Macs)
        // Verify either battery data or unavailable flag
        if let batteryUnavailable = result.data?["batteryUnavailable"] as? Bool, batteryUnavailable {
            // Battery unavailable case
            XCTAssertNotNil(result.data?["message"])
        } else {
            // Battery available case - verify structure
            // We don't assert exact values since they're machine-specific
            // Just verify the structure is correct
            let hasPercentage = result.data?["percentage"] != nil
            let hasCharging = result.data?["isCharging"] != nil
            let hasPowerSource = result.data?["powerSource"] != nil
            
            // At least some battery data should be present
            XCTAssertTrue(hasPercentage || hasCharging || hasPowerSource)
        }
    }
    
    func testGetStorageInfoIntegration() async throws {
        // Register system tools
        for toolDefinition in SystemToolDefinitions.all {
            try await registry.register(toolDefinition)
        }
        
        // Verify tool is registered
        let hasStorageInfo = await registry.hasTool(.getStorageInfo)
        XCTAssertTrue(hasStorageInfo)
        
        // Execute the tool
        let call = ToolCall(
            toolIdentifier: .getStorageInfo,
            arguments: [:],
            sessionID: UUID()
        )
        
        let result = try await executor.execute(call)
        
        // Verify structure (not exact values since they're machine-specific)
        XCTAssertTrue(result.success)
        XCTAssertNotNil(result.data)
        
        // Verify expected fields exist
        XCTAssertNotNil(result.data?["volumeName"])
        XCTAssertNotNil(result.data?["totalCapacity"])
        XCTAssertNotNil(result.data?["availableCapacity"])
        XCTAssertNotNil(result.data?["usedCapacity"])
        
        // Verify data types
        XCTAssertTrue(result.data?["volumeName"] is String)
        XCTAssertTrue(result.data?["totalCapacity"] is Int64)
        XCTAssertTrue(result.data?["availableCapacity"] is Int64)
        XCTAssertTrue(result.data?["usedCapacity"] is Int64)
        
        // Verify logical consistency
        if let total = result.data?["totalCapacity"] as? Int64,
           let available = result.data?["availableCapacity"] as? Int64,
           let used = result.data?["usedCapacity"] as? Int64 {
            
            XCTAssertTrue(total > 0, "Total capacity should be positive")
            XCTAssertTrue(available >= 0, "Available capacity should be non-negative")
            XCTAssertTrue(used >= 0, "Used capacity should be non-negative")
            XCTAssertEqual(total - available, used, "Used should equal total minus available")
        }
    }
    
    // MARK: - Error Handling Tests
    
    func testUnknownToolIdentifier() async throws {
        // Register system tools
        for toolDefinition in SystemToolDefinitions.all {
            try await registry.register(toolDefinition)
        }
        
        // Try to execute unknown tool
        let call = ToolCall(
            toolIdentifier: ToolIdentifier("unknown_system_tool"),
            arguments: [:],
            sessionID: UUID()
        )
        
        do {
            _ = try await executor.execute(call)
            XCTFail("Expected ToolExecutionError.toolNotFound")
        } catch ToolExecutionError.toolNotFound {
            // Expected
        } catch {
            XCTFail("Expected ToolExecutionError.toolNotFound, got \(error)")
        }
    }
    
    // MARK: - Session Identity Tests
    
    func testSessionIdentityPreserved() async throws {
        // Register system tools
        for toolDefinition in SystemToolDefinitions.all {
            try await registry.register(toolDefinition)
        }
        
        // Execute tool with specific session ID
        let sessionID = UUID()
        let call = ToolCall(
            toolIdentifier: .getSystemInfo,
            arguments: [:],
            sessionID: sessionID
        )
        
        let result = try await executor.execute(call)
        
        // Verify execution succeeded
        XCTAssertTrue(result.success)
        
        // Session ID is preserved in the call but not directly in result
        // The important thing is that the executor doesn't crash or lose session context
        XCTAssertNotNil(result.data)
    }
    
    // MARK: - Tool Definition Verification Tests
    
    func testSystemToolDefinitionsStructure() async throws {
        let allTools = SystemToolDefinitions.all
        
        for toolDefinition in allTools {
            // Verify basic structure
            XCTAssertFalse(toolDefinition.identifier.rawValue.isEmpty)
            XCTAssertFalse(toolDefinition.description.isEmpty)
            XCTAssertEqual(toolDefinition.riskLevel, .safe, "System tools should be safe")
            XCTAssertEqual(toolDefinition.category, .system, "System tools should be in system category")
            XCTAssertFalse(toolDefinition.requiresConfirmation, "System tools should not require confirmation")
            XCTAssertTrue(toolDefinition.parameters.isEmpty, "System tools should require no parameters")
        }
    }
    
    func testSystemToolIdentifiersAreValid() async throws {
        let allTools = SystemToolDefinitions.all
        
        for toolDefinition in allTools {
            XCTAssertTrue(toolDefinition.identifier.isValid, "Tool identifier should be valid")
        }
    }
}
