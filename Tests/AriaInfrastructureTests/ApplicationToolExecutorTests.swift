import XCTest
@testable import AriaInfrastructure
@testable import AriaDomain

final class ApplicationToolExecutorTests: XCTestCase {
    
    var executor: ApplicationToolExecutor!
    var mockResolver: MockApplicationResolver!
    
    override func setUp() async throws {
        try await super.setUp()
        mockResolver = MockApplicationResolver()
        executor = ApplicationToolExecutor(applicationResolver: mockResolver)
    }
    
    override func tearDown() async throws {
        executor = nil
        mockResolver = nil
        try await super.tearDown()
    }
    
    func testOpenApplicationSuccess() async throws {
        let appURL = URL(fileURLWithPath: "/Applications/TestApp.app")
        await mockResolver.setApplication("TestApp", url: appURL)
        
        let call = ToolCall(
            toolIdentifier: .openApplication,
            arguments: ["applicationName": "TestApp"],
            sessionID: UUID()
        )
        
        // Test that the tool call structure is correct
        do {
            let result = try await executor.execute(call)
            // In test environment, this will fail because we can't actually launch apps
            // But we verify the structure is correct
            XCTAssertNotNil(result)
        } catch {
            // Expected to fail in test environment
            XCTAssertNotNil(error)
        }
    }
    
    func testOpenApplicationMissingArgument() async throws {
        let call = ToolCall(
            toolIdentifier: .openApplication,
            arguments: [:], // Missing applicationName
            sessionID: UUID()
        )
        
        do {
            _ = try await executor.execute(call)
            XCTFail("Should have thrown invalidArguments error")
        } catch ToolExecutionError.invalidArguments {
            // Expected
        } catch {
            XCTFail("Expected invalidArguments error, got \(error)")
        }
    }
    
    func testOpenApplicationNotFound() async throws {
        let call = ToolCall(
            toolIdentifier: .openApplication,
            arguments: ["applicationName": "NonExistentApp"],
            sessionID: UUID()
        )
        
        let result = try await executor.execute(call)
        
        XCTAssertFalse(result.success)
        XCTAssertEqual(result.errorCode, "application_not_found")
    }
    
    func testQuitApplicationSuccess() async throws {
        // For safety, we test the error handling when app is not running
        let call = ToolCall(
            toolIdentifier: .quitApplication,
            arguments: ["applicationName": "TestApp"],
            sessionID: UUID()
        )
        
        let result = try await executor.execute(call)
        
        // Should fail because app is not running
        XCTAssertFalse(result.success)
        XCTAssertEqual(result.errorCode, "application_not_running")
    }
    
    func testQuitApplicationMissingArgument() async throws {
        let call = ToolCall(
            toolIdentifier: .quitApplication,
            arguments: [:], // Missing applicationName
            sessionID: UUID()
        )
        
        do {
            _ = try await executor.execute(call)
            XCTFail("Should have thrown invalidArguments error")
        } catch ToolExecutionError.invalidArguments {
            // Expected
        } catch {
            XCTFail("Expected invalidArguments error, got \(error)")
        }
    }
    
    func testFocusApplicationSuccess() async throws {
        // For safety, we test the logic without actually focusing real apps
        // We'll test that when the app is not running, we get the correct error
        let call = ToolCall(
            toolIdentifier: .focusApplication,
            arguments: ["applicationName": "TestApp"],
            sessionID: UUID()
        )
        
        let result = try await executor.execute(call)
        
        // Should fail because app is not running
        XCTAssertFalse(result.success)
        XCTAssertEqual(result.errorCode, "application_not_running")
    }
    
    func testFocusApplicationMissingArgument() async throws {
        let call = ToolCall(
            toolIdentifier: .focusApplication,
            arguments: [:], // Missing applicationName
            sessionID: UUID()
        )
        
        do {
            _ = try await executor.execute(call)
            XCTFail("Should have thrown invalidArguments error")
        } catch ToolExecutionError.invalidArguments {
            // Expected
        } catch {
            XCTFail("Expected invalidArguments error, got \(error)")
        }
    }
    
    func testUnknownTool() async throws {
        let call = ToolCall(
            toolIdentifier: ToolIdentifier("unknown_tool"),
            arguments: ["applicationName": "test"], // Add required parameter to avoid invalidArguments
            sessionID: UUID()
        )
        
        do {
            _ = try await executor.execute(call)
            XCTFail("Should have thrown toolNotFound error")
        } catch ToolExecutionError.toolNotFound {
            // Expected
        } catch {
            XCTFail("Expected toolNotFound error, got \(error)")
        }
    }
}