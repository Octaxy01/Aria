import XCTest
@testable import AriaInfrastructure
@testable import AriaDomain

final class ApplicationResolverTests: XCTestCase {
    
    var mockResolver: MockApplicationResolver!
    
    override func setUp() async throws {
        try await super.setUp()
        mockResolver = MockApplicationResolver()
    }
    
    override func tearDown() async throws {
        mockResolver = nil
        try await super.tearDown()
    }
    
    func testResolveApplicationFound() async throws {
        let appURL = URL(fileURLWithPath: "/Applications/TestApp.app")
        await mockResolver.setApplication("TestApp", url: appURL)
        
        let resolved = try await mockResolver.resolveApplication(named: "TestApp")
        
        XCTAssertEqual(resolved, appURL)
    }
    
    func testResolveApplicationNotFound() async throws {
        let resolved = try await mockResolver.resolveApplication(named: "NonExistentApp")
        
        XCTAssertNil(resolved)
    }
    
    func testFindRunningApplicationFound() async {
        await mockResolver.setRunningApplication("TestApp")
        
        let found = await mockResolver.findRunningApplication(named: "TestApp")
        
        // The mock returns a RunningApplicationInfo when set as running
        XCTAssertNotNil(found)
        XCTAssertEqual(found?.bundleIdentifier, "com.test.TestApp")
        let isRunning = await mockResolver.isApplicationRunning(named: "TestApp")
        XCTAssertTrue(isRunning)
    }
    
    func testFindRunningApplicationNotFound() async {
        let found = await mockResolver.findRunningApplication(named: "NonExistentApp")
        
        XCTAssertNil(found)
        let isNotRunning = await mockResolver.isApplicationRunning(named: "NonExistentApp")
        XCTAssertFalse(isNotRunning)
    }
    
    func testApplicationExists() async {
        let appURL = URL(fileURLWithPath: "/Applications/TestApp.app")
        await mockResolver.setApplication("TestApp", url: appURL)
        
        let exists = await mockResolver.applicationExists(named: "TestApp")
        XCTAssertTrue(exists)
        
        let notExists = await mockResolver.applicationExists(named: "NonExistentApp")
        XCTAssertFalse(notExists)
    }
}