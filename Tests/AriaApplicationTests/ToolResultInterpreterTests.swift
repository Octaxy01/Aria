import XCTest
import AriaDomain
import AriaApplication

final class ToolResultInterpreterTests: XCTestCase {
    
    var interpreter: ToolResultInterpreter!
    var sessionID: UUID!
    
    override func setUp() async throws {
        interpreter = ToolResultInterpreter()
        sessionID = UUID()
    }
    
    // MARK: - Generic Tests
    
    func testSuccessfulResult() async {
        let result = ToolResult.success([
            "applicationName": "Chrome",
            "bundleIdentifier": "com.google.Chrome",
            "path": "/Applications/Google Chrome.app"
        ])
        let toolCall = ToolCall(
            toolIdentifier: .openApplication,
            arguments: ["applicationName": "Chrome"],
            sessionID: sessionID
        )
        
        let interpretation = await interpreter.interpret(result, for: toolCall, sessionID: sessionID)
        
        XCTAssertTrue(interpretation.success)
        XCTAssertFalse(interpretation.summary.isEmpty)
        XCTAssertTrue(interpretation.displayToUser)
    }
    
    func testFailedResult() async {
        let result = ToolResult.failure("Test error", errorCode: "test_error")
        let toolCall = ToolCall(
            toolIdentifier: .openApplication,
            arguments: [:],
            sessionID: sessionID
        )
        
        let interpretation = await interpreter.interpret(result, for: toolCall, sessionID: sessionID)
        
        XCTAssertFalse(interpretation.success)
        XCTAssertFalse(interpretation.summary.isEmpty)
        XCTAssertTrue(interpretation.displayToUser)
    }
    
    func testCancelledResult() async {
        let result = ToolResult.cancelled()
        let toolCall = ToolCall(
            toolIdentifier: .openApplication,
            arguments: [:],
            sessionID: sessionID
        )
        
        let interpretation = await interpreter.interpret(result, for: toolCall, sessionID: sessionID)
        
        XCTAssertFalse(interpretation.success)
        XCTAssertEqual(interpretation.errorCategory, .cancelled)
        XCTAssertTrue(interpretation.summary.contains("dibatalkan"))
    }
    
    func testMalformedResult() async {
        let result = ToolResult.success([:])
        let toolCall = ToolCall(
            toolIdentifier: .openApplication,
            arguments: ["applicationName": "Chrome"],
            sessionID: sessionID
        )
        
        let interpretation = await interpreter.interpret(result, for: toolCall, sessionID: sessionID)
        
        // Production behavior: missing required data fields result in failure interpretation
        XCTAssertFalse(interpretation.success)
        XCTAssertTrue(interpretation.summary.contains("nggak bisa membuka"))
    }
    
    // MARK: - Application Tools
    
    func testOpenApplicationSuccess() async {
        let result = ToolResult.success([
            "applicationName": "Chrome",
            "bundleIdentifier": "com.google.Chrome",
            "path": "/Applications/Google Chrome.app"
        ])
        
        let toolCall = ToolCall(
            toolIdentifier: .openApplication,
            arguments: ["applicationName": "Chrome"],
            sessionID: sessionID
        )
        
        let interpretation = await interpreter.interpret(result, for: toolCall, sessionID: sessionID)
        
        XCTAssertTrue(interpretation.success)
        XCTAssertTrue(interpretation.summary.contains("Chrome"))
        XCTAssertTrue(interpretation.summary.contains("berhasil dibuka"))
        XCTAssertNotNil(interpretation.entities)
        XCTAssertEqual(interpretation.entities?.count, 1)
        XCTAssertEqual(interpretation.entities?.first?.displayName, "Chrome")
    }
    
    func testOpenApplicationFailure() async {
        let result = ToolResult.failure("Application not found", errorCode: "app_not_found")
        let toolCall = ToolCall(
            toolIdentifier: .openApplication,
            arguments: ["applicationName": "NonExistentApp"],
            sessionID: sessionID
        )
        
        let interpretation = await interpreter.interpret(result, for: toolCall, sessionID: sessionID)
        
        XCTAssertFalse(interpretation.success)
        XCTAssertTrue(interpretation.summary.contains("nggak bisa"))
        XCTAssertEqual(interpretation.errorCategory, .notFound)
    }
    
    func testQuitApplicationSuccess() async {
        let result = ToolResult.success([
            "applicationName": "Safari"
        ])
        
        let toolCall = ToolCall(
            toolIdentifier: .quitApplication,
            arguments: ["applicationName": "Safari"],
            sessionID: sessionID
        )
        
        let interpretation = await interpreter.interpret(result, for: toolCall, sessionID: sessionID)
        
        XCTAssertTrue(interpretation.success)
        XCTAssertTrue(interpretation.summary.contains("Safari"))
        XCTAssertTrue(interpretation.summary.contains("ditutup"))
    }
    
    func testQuitApplicationFailure() async {
        let result = ToolResult.failure("Application not running", errorCode: "not_found")
        let toolCall = ToolCall(
            toolIdentifier: .quitApplication,
            arguments: ["applicationName": "Safari"],
            sessionID: sessionID
        )
        
        let interpretation = await interpreter.interpret(result, for: toolCall, sessionID: sessionID)
        
        XCTAssertFalse(interpretation.success)
        XCTAssertTrue(interpretation.summary.contains("nggak sedang berjalan"))
        XCTAssertEqual(interpretation.errorCategory, .notFound)
    }
    
    func testFocusApplicationSuccess() async {
        let result = ToolResult.success([
            "applicationName": "Finder"
        ])
        
        let toolCall = ToolCall(
            toolIdentifier: .focusApplication,
            arguments: ["applicationName": "Finder"],
            sessionID: sessionID
        )
        
        let interpretation = await interpreter.interpret(result, for: toolCall, sessionID: sessionID)
        
        XCTAssertTrue(interpretation.success)
        XCTAssertTrue(interpretation.summary.contains("Finder"))
        XCTAssertTrue(interpretation.summary.contains("fokuskan"))
    }
    
    func testFocusApplicationFailure() async {
        let result = ToolResult.failure("Application not running", errorCode: "not_found")
        let toolCall = ToolCall(
            toolIdentifier: .focusApplication,
            arguments: ["applicationName": "Finder"],
            sessionID: sessionID
        )
        
        let interpretation = await interpreter.interpret(result, for: toolCall, sessionID: sessionID)
        
        XCTAssertFalse(interpretation.success)
        XCTAssertTrue(interpretation.summary.contains("nggak menemukan"))
        XCTAssertEqual(interpretation.errorCategory, .notFound)
    }
    
    // MARK: - File Tools
    
    func testOpenFileSuccess() async {
        let result = ToolResult.success([
            "fileName": "tugas.pdf",
            "path": "/Users/test/Documents/tugas.pdf"
        ])
        
        let toolCall = ToolCall(
            toolIdentifier: .openFile,
            arguments: ["path": "/Users/test/Documents/tugas.pdf"],
            sessionID: sessionID
        )
        
        let interpretation = await interpreter.interpret(result, for: toolCall, sessionID: sessionID)
        
        XCTAssertTrue(interpretation.success)
        XCTAssertTrue(interpretation.summary.contains("tugas.pdf"))
        XCTAssertTrue(interpretation.summary.contains("dibuka"))
        XCTAssertNotNil(interpretation.entities)
        XCTAssertEqual(interpretation.entities?.count, 1)
        XCTAssertEqual(interpretation.entities?.first?.displayName, "tugas.pdf")
        // Path should be in entity but not exposed in summary
        XCTAssertFalse(interpretation.summary.contains("/Users/test/Documents"))
    }
    
    func testOpenFileFailure() async {
        let result = ToolResult.failure("File not found", errorCode: "file_not_found")
        let toolCall = ToolCall(
            toolIdentifier: .openFile,
            arguments: ["path": "/nonexistent/file.pdf"],
            sessionID: sessionID
        )
        
        let interpretation = await interpreter.interpret(result, for: toolCall, sessionID: sessionID)
        
        XCTAssertFalse(interpretation.success)
        XCTAssertTrue(interpretation.summary.contains("nggak bisa membuka"))
        XCTAssertEqual(interpretation.errorCategory, .notFound)
    }
    
    func testOpenFolderSuccess() async {
        let result = ToolResult.success([
            "folderName": "Downloads",
            "path": "/Users/test/Downloads"
        ])
        
        let toolCall = ToolCall(
            toolIdentifier: .openFolder,
            arguments: ["path": "/Users/test/Downloads"],
            sessionID: sessionID
        )
        
        let interpretation = await interpreter.interpret(result, for: toolCall, sessionID: sessionID)
        
        XCTAssertTrue(interpretation.success)
        XCTAssertTrue(interpretation.summary.contains("Downloads"))
        XCTAssertTrue(interpretation.summary.contains("dibuka"))
        XCTAssertNotNil(interpretation.entities)
        XCTAssertEqual(interpretation.entities?.count, 1)
        XCTAssertEqual(interpretation.entities?.first?.displayName, "Downloads")
    }
    
    func testOpenFolderFailure() async {
        let result = ToolResult.failure("Folder not found", errorCode: "not_found")
        let toolCall = ToolCall(
            toolIdentifier: .openFolder,
            arguments: ["path": "/nonexistent/folder"],
            sessionID: sessionID
        )
        
        let interpretation = await interpreter.interpret(result, for: toolCall, sessionID: sessionID)
        
        XCTAssertFalse(interpretation.success)
        XCTAssertTrue(interpretation.summary.contains("nggak bisa membuka"))
        XCTAssertEqual(interpretation.errorCategory, .notFound)
    }
    
    func testFindFileZeroResults() async {
        let result = ToolResult.success([
            "results": []
        ])
        
        let toolCall = ToolCall(
            toolIdentifier: .findFile,
            arguments: ["query": "nonexistent"],
            sessionID: sessionID
        )
        
        let interpretation = await interpreter.interpret(result, for: toolCall, sessionID: sessionID)
        
        // Production behavior: zero results return success with nil entities
        XCTAssertTrue(interpretation.success)
        XCTAssertTrue(interpretation.summary.contains("belum menemukan"))
        XCTAssertNil(interpretation.entities) // Zero results produce nil entities
    }
    
    func testFindFileOneResult() async {
        let result = ToolResult.success([
            "results": [
                ["fileName": "tugas.pdf", "path": "/Users/test/tugas.pdf"]
            ]
        ])
        
        let toolCall = ToolCall(
            toolIdentifier: .findFile,
            arguments: ["query": "tugas"],
            sessionID: sessionID
        )
        
        let interpretation = await interpreter.interpret(result, for: toolCall, sessionID: sessionID)
        
        XCTAssertTrue(interpretation.success)
        XCTAssertTrue(interpretation.summary.contains("tugas.pdf"))
        XCTAssertTrue(interpretation.summary.contains("menemukan"))
        XCTAssertNotNil(interpretation.entities)
        XCTAssertEqual(interpretation.entities?.count, 1)
        XCTAssertEqual(interpretation.entities?.first?.displayName, "tugas.pdf")
        // Path should be in entity but not exposed in summary
        XCTAssertFalse(interpretation.summary.contains("/Users/test"))
    }
    
    func testFindFileMultipleResults() async {
        let result = ToolResult.success([
            "results": [
                ["fileName": "tugas.pdf", "path": "/Users/test/tugas.pdf"],
                ["fileName": "laporan.pdf", "path": "/Users/test/laporan.pdf"],
                ["fileName": "gambar.png", "path": "/Users/test/gambar.png"]
            ]
        ])
        
        let toolCall = ToolCall(
            toolIdentifier: .findFile,
            arguments: ["query": "test"],
            sessionID: sessionID
        )
        
        let interpretation = await interpreter.interpret(result, for: toolCall, sessionID: sessionID)
        
        XCTAssertTrue(interpretation.success)
        XCTAssertTrue(interpretation.summary.contains("3 file"))
        XCTAssertTrue(interpretation.summary.contains("tugas.pdf"))
        XCTAssertTrue(interpretation.summary.contains("laporan.pdf"))
        XCTAssertNotNil(interpretation.entities)
        XCTAssertEqual(interpretation.entities?.count, 3)
    }
    
    func testFindFileVisibleResultBounding() async {
        var results: [[String: Sendable]] = []
        for i in 1...10 {
            results.append(["fileName": "file\(i).pdf", "path": "/Users/test/file\(i).pdf"])
        }
        
        let result = ToolResult.success(["results": results])
        
        let toolCall = ToolCall(
            toolIdentifier: .findFile,
            arguments: ["query": "file"],
            sessionID: sessionID
        )
        
        let interpretation = await interpreter.interpret(result, for: toolCall, sessionID: sessionID)
        
        XCTAssertTrue(interpretation.success)
        XCTAssertTrue(interpretation.summary.contains("10 file"))
        XCTAssertTrue(interpretation.summary.contains("5 lainnya"))
        // Should not list all 10 files
        XCTAssertFalse(interpretation.summary.contains("file6.pdf"))
        XCTAssertFalse(interpretation.summary.contains("file7.pdf"))
        // But all entities should be preserved
        XCTAssertNotNil(interpretation.entities)
        XCTAssertEqual(interpretation.entities?.count, 10)
    }
    
    func testFindFileFullRuntimeResultPreservation() async {
        var results: [[String: Sendable]] = []
        for i in 1...20 {
            results.append(["fileName": "file\(i).pdf", "path": "/Users/test/file\(i).pdf"])
        }
        
        let result = ToolResult.success(["results": results])
        
        let toolCall = ToolCall(
            toolIdentifier: .findFile,
            arguments: ["query": "file"],
            sessionID: sessionID
        )
        
        let interpretation = await interpreter.interpret(result, for: toolCall, sessionID: sessionID)
        
        // All 20 entities should be preserved for reference resolution
        XCTAssertNotNil(interpretation.entities)
        XCTAssertEqual(interpretation.entities?.count, 20)
        
        // Verify entities have correct positions
        for (index, entity) in (interpretation.entities ?? []).enumerated() {
            XCTAssertEqual(entity.displayName, "file\(index + 1).pdf")
            XCTAssertEqual(entity.path, "/Users/test/file\(index + 1).pdf")
        }
    }
    
    // MARK: - System Tools
    
    func testSystemInfo() async {
        let result = ToolResult.success([
            "osVersion": "14.0",
            "architecture": "arm64",
            "computerName": "TestMac"
        ])
        
        let toolCall = ToolCall(
            toolIdentifier: .getSystemInfo,
            arguments: [:],
            sessionID: sessionID
        )
        
        let interpretation = await interpreter.interpret(result, for: toolCall, sessionID: sessionID)
        
        XCTAssertTrue(interpretation.success)
        XCTAssertTrue(interpretation.summary.contains("macOS"))
        XCTAssertTrue(interpretation.summary.contains("14.0"))
        XCTAssertTrue(interpretation.summary.contains("arm64"))
    }
    
    func testBatteryCharging() async {
        let result = ToolResult.success([
            "percentage": 62,
            "isCharging": true
        ])
        
        let toolCall = ToolCall(
            toolIdentifier: .getBatteryStatus,
            arguments: [:],
            sessionID: sessionID
        )
        
        let interpretation = await interpreter.interpret(result, for: toolCall, sessionID: sessionID)
        
        XCTAssertTrue(interpretation.success)
        XCTAssertTrue(interpretation.summary.contains("62%"))
        XCTAssertTrue(interpretation.summary.contains("mengisi daya"))
    }
    
    func testBatteryUnavailable() async {
        let result = ToolResult.failure("Battery info unavailable", errorCode: "unavailable")
        let toolCall = ToolCall(
            toolIdentifier: .getBatteryStatus,
            arguments: [:],
            sessionID: sessionID
        )
        
        let interpretation = await interpreter.interpret(result, for: toolCall, sessionID: sessionID)
        
        XCTAssertFalse(interpretation.success)
        XCTAssertTrue(interpretation.summary.contains("tidak melaporkan"))
        XCTAssertEqual(interpretation.errorCategory, .unavailable)
    }
    
    func testStorageFormatting() async {
        let result = ToolResult.success([
            "availableGB": 120.5,
            "totalGB": 500.0
        ])
        
        let toolCall = ToolCall(
            toolIdentifier: .getStorageInfo,
            arguments: [:],
            sessionID: sessionID
        )
        
        let interpretation = await interpreter.interpret(result, for: toolCall, sessionID: sessionID)
        
        XCTAssertTrue(interpretation.success)
        XCTAssertTrue(interpretation.summary.contains("120"))
        XCTAssertTrue(interpretation.summary.contains("500"))
        XCTAssertTrue(interpretation.summary.contains("GB"))
    }
    
    // MARK: - Safety Tests
    
    func testFailedToolCannotBecomeSuccessResponse() async {
        let result = ToolResult.failure("Test failure", errorCode: "test_error")
        let toolCall = ToolCall(
            toolIdentifier: .openApplication,
            arguments: [:],
            sessionID: sessionID
        )
        
        let interpretation = await interpreter.interpret(result, for: toolCall, sessionID: sessionID)
        
        XCTAssertFalse(interpretation.success)
        // Summary should not claim success
        XCTAssertFalse(interpretation.summary.lowercased().contains("berhasil"))
        XCTAssertFalse(interpretation.summary.lowercased().contains("success"))
    }
    
    func testInternalIDsHidden() async {
        let result = ToolResult.success([
            "applicationName": "Chrome",
            "bundleIdentifier": "com.google.Chrome",
            "internalID": "12345",
            "sessionToken": "abc-xyz"
        ])
        
        let toolCall = ToolCall(
            toolIdentifier: .openApplication,
            arguments: ["applicationName": "Chrome"],
            sessionID: sessionID
        )
        
        let interpretation = await interpreter.interpret(result, for: toolCall, sessionID: sessionID)
        
        // Internal IDs should not appear in summary
        XCTAssertFalse(interpretation.summary.contains("12345"))
        XCTAssertFalse(interpretation.summary.contains("abc-xyz"))
        XCTAssertFalse(interpretation.summary.contains("internalID"))
        XCTAssertFalse(interpretation.summary.contains("sessionToken"))
    }
    
    func testSessionIDsHidden() async {
        let result = ToolResult.success([
            "fileName": "test.pdf",
            "path": "/Users/test/test.pdf",
            "sessionID": "550e8400-e29b-41d4-a716-446655440000"
        ])
        
        let toolCall = ToolCall(
            toolIdentifier: .openFile,
            arguments: ["path": "/Users/test/test.pdf"],
            sessionID: sessionID
        )
        
        let interpretation = await interpreter.interpret(result, for: toolCall, sessionID: sessionID)
        
        // Session ID should not appear in summary
        XCTAssertFalse(interpretation.summary.contains("550e8400"))
        XCTAssertFalse(interpretation.summary.contains("sessionID"))
    }
    
    func testAbsolutePathHiddenByDefault() async {
        let result = ToolResult.success([
            "fileName": "tugas.pdf",
            "path": "/Users/test/Documents/University/Semester1/tugas.pdf"
        ])
        
        let toolCall = ToolCall(
            toolIdentifier: .openFile,
            arguments: ["path": "/Users/test/Documents/University/Semester1/tugas.pdf"],
            sessionID: sessionID
        )
        
        let interpretation = await interpreter.interpret(result, for: toolCall, sessionID: sessionID)
        
        // Full path should not appear in summary
        XCTAssertFalse(interpretation.summary.contains("/Users/test/Documents"))
        XCTAssertFalse(interpretation.summary.contains("University"))
        // But filename should appear
        XCTAssertTrue(interpretation.summary.contains("tugas.pdf"))
    }
}
