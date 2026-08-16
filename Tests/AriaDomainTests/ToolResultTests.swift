import XCTest
@testable import AriaDomain

final class ToolResultTests: XCTestCase {
    
    func testSuccessResult() {
        let result = ToolResult.success(["status": "opened"])
        
        XCTAssertTrue(result.success)
        XCTAssertNotNil(result.data)
        XCTAssertEqual(result.data?["status"] as? String, "opened")
        XCTAssertNil(result.error)
        XCTAssertNil(result.errorCode)
    }
    
    func testSuccessResultWithEmptyData() {
        let result = ToolResult.success()
        
        XCTAssertTrue(result.success)
        XCTAssertTrue(result.data?.isEmpty ?? true)
        XCTAssertNil(result.error)
        XCTAssertNil(result.errorCode)
    }
    
    func testFailureResult() {
        let result = ToolResult.failure("File not found", errorCode: "file_not_found")
        
        XCTAssertFalse(result.success)
        XCTAssertNil(result.data)
        XCTAssertEqual(result.error, "File not found")
        XCTAssertEqual(result.errorCode, "file_not_found")
    }
    
    func testFailureResultWithoutErrorCode() {
        let result = ToolResult.failure("Unknown error")
        
        XCTAssertFalse(result.success)
        XCTAssertNil(result.data)
        XCTAssertEqual(result.error, "Unknown error")
        XCTAssertNil(result.errorCode)
    }
    
    func testCancelledResult() {
        let result = ToolResult.cancelled()
        
        XCTAssertFalse(result.success)
        XCTAssertNil(result.data)
        XCTAssertEqual(result.error, "Tool execution was cancelled")
        XCTAssertEqual(result.errorCode, "cancelled")
    }
    
    func testStaleSessionResult() {
        let result = ToolResult.staleSession()
        
        XCTAssertFalse(result.success)
        XCTAssertNil(result.data)
        XCTAssertEqual(result.error, "Tool execution cancelled due to stale session")
        XCTAssertEqual(result.errorCode, "stale_session")
    }
    
    func testEquatable() {
        let result1 = ToolResult.success(["status": "done"])
        let result2 = ToolResult.success(["status": "done"])
        let result3 = ToolResult.failure("Error")
        
        XCTAssertEqual(result1, result2)
        XCTAssertNotEqual(result1, result3)
    }
}