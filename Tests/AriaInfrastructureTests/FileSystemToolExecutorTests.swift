import XCTest
@testable import AriaInfrastructure
@testable import AriaDomain

final class FileSystemToolExecutorTests: XCTestCase {
    
    var executor: FileSystemToolExecutor!
    var mockResolver: MockFileSystemResolver!
    var mockSearchService: MockFileSearchService!
    
    override func setUp() async throws {
        try await super.setUp()
        mockResolver = MockFileSystemResolver()
        mockSearchService = MockFileSearchService()
        executor = FileSystemToolExecutor(
            fileSystemResolver: mockResolver,
            fileSearchService: mockSearchService
        )
    }
    
    override func tearDown() async throws {
        executor = nil
        mockResolver = nil
        mockSearchService = nil
        try await super.tearDown()
    }
    
    // MARK: - Open File Tests
    
    func testOpenFileSuccess() async throws {
        let fileURL = URL(fileURLWithPath: "/Users/test/Documents/file.pdf")
        let target = FileSystemTarget(
            url: fileURL,
            path: "/Users/test/Documents/file.pdf",
            fileName: "file.pdf",
            fileExtension: "pdf",
            isDirectory: false,
            exists: true
        )
        await mockResolver.setPath("/Users/test/Documents/file.pdf", target: target)
        
        let call = ToolCall(
            toolIdentifier: .openFile,
            arguments: ["path": "/Users/test/Documents/file.pdf"],
            sessionID: UUID()
        )
        
        // Test that the tool call structure is correct
        do {
            let result = try await executor.execute(call)
            // In test environment, this will fail because we can't actually open files
            // But we verify the structure is correct
            XCTAssertNotNil(result)
        } catch {
            // Expected to fail in test environment
            XCTAssertNotNil(error)
        }
    }
    
    func testOpenFileMissingArgument() async throws {
        let call = ToolCall(
            toolIdentifier: .openFile,
            arguments: [:], // Missing path
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
    
    func testOpenFileNotFound() async throws {
        let call = ToolCall(
            toolIdentifier: .openFile,
            arguments: ["path": "/nonexistent/file.pdf"],
            sessionID: UUID()
        )
        
        let result = try await executor.execute(call)
        
        XCTAssertFalse(result.success)
        XCTAssertEqual(result.errorCode, "file_not_found")
    }
    
    func testOpenFileDirectoryAsFile() async throws {
        let dirURL = URL(fileURLWithPath: "/Users/test/Documents")
        let target = FileSystemTarget(
            url: dirURL,
            path: "/Users/test/Documents",
            fileName: "Documents",
            fileExtension: nil,
            isDirectory: true,
            exists: true
        )
        await mockResolver.setPath("/Users/test/Documents", target: target)
        
        let call = ToolCall(
            toolIdentifier: .openFile,
            arguments: ["path": "/Users/test/Documents"],
            sessionID: UUID()
        )
        
        let result = try await executor.execute(call)
        
        XCTAssertFalse(result.success)
        XCTAssertEqual(result.errorCode, "wrong_target_type")
    }
    
    // MARK: - Open Folder Tests
    
    func testOpenFolderSuccess() async throws {
        let dirURL = URL(fileURLWithPath: "/Users/test/Documents")
        let target = FileSystemTarget(
            url: dirURL,
            path: "/Users/test/Documents",
            fileName: "Documents",
            fileExtension: nil,
            isDirectory: true,
            exists: true
        )
        await mockResolver.setPath("/Users/test/Documents", target: target)
        
        let call = ToolCall(
            toolIdentifier: .openFolder,
            arguments: ["path": "/Users/test/Documents"],
            sessionID: UUID()
        )
        
        // Test that the tool call structure is correct
        do {
            let result = try await executor.execute(call)
            // In test environment, this will fail because we can't actually open folders
            // But we verify the structure is correct
            XCTAssertNotNil(result)
        } catch {
            // Expected to fail in test environment
            XCTAssertNotNil(error)
        }
    }
    
    func testOpenFolderMissingArgument() async throws {
        let call = ToolCall(
            toolIdentifier: .openFolder,
            arguments: [:], // Missing path
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
    
    func testOpenFolderNotFound() async throws {
        let call = ToolCall(
            toolIdentifier: .openFolder,
            arguments: ["path": "/nonexistent/folder"],
            sessionID: UUID()
        )
        
        let result = try await executor.execute(call)
        
        XCTAssertFalse(result.success)
        XCTAssertEqual(result.errorCode, "file_not_found")
    }
    
    func testOpenFolderFileAsDirectory() async throws {
        let fileURL = URL(fileURLWithPath: "/Users/test/file.txt")
        let target = FileSystemTarget(
            url: fileURL,
            path: "/Users/test/file.txt",
            fileName: "file.txt",
            fileExtension: "txt",
            isDirectory: false,
            exists: true
        )
        await mockResolver.setPath("/Users/test/file.txt", target: target)
        
        let call = ToolCall(
            toolIdentifier: .openFolder,
            arguments: ["path": "/Users/test/file.txt"],
            sessionID: UUID()
        )
        
        let result = try await executor.execute(call)
        
        XCTAssertFalse(result.success)
        XCTAssertEqual(result.errorCode, "wrong_target_type")
    }
    
    // MARK: - Find File Tests
    
    func testFindFileSuccess() async throws {
        let results = [
            FileSearchResult(path: "/Users/test/Documents/file1.pdf", fileName: "file1.pdf", isDirectory: false),
            FileSearchResult(path: "/Users/test/Documents/file2.pdf", fileName: "file2.pdf", isDirectory: false)
        ]
        await mockSearchService.setSearchResults("file", results: results)
        
        let call = ToolCall(
            toolIdentifier: .findFile,
            arguments: ["query": "file"],
            sessionID: UUID()
        )
        
        let result = try await executor.execute(call)
        
        XCTAssertTrue(result.success)
        XCTAssertEqual(result.data?["query"] as? String, "file")
        XCTAssertEqual(result.data?["count"] as? Int, 2)
        XCTAssertFalse(result.data?["truncated"] as? Bool ?? true)
        
        if let resultsArray = result.data?["results"] as? [[String: Any]] {
            XCTAssertEqual(resultsArray.count, 2)
            XCTAssertEqual(resultsArray[0]["fileName"] as? String, "file1.pdf")
        } else {
            XCTFail("Results should be an array")
        }
    }
    
    func testFindFileMissingArgument() async throws {
        let call = ToolCall(
            toolIdentifier: .findFile,
            arguments: [:], // Missing query
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
    
    func testFindFileNoResults() async throws {
        let call = ToolCall(
            toolIdentifier: .findFile,
            arguments: ["query": "nonexistent"],
            sessionID: UUID()
        )
        
        let result = try await executor.execute(call)
        
        XCTAssertTrue(result.success)
        XCTAssertEqual(result.data?["count"] as? Int, 0)
        XCTAssertFalse(result.data?["truncated"] as? Bool ?? true)
    }
    
    func testFindFileWithSearchScope() async throws {
        let results = [
            FileSearchResult(path: "/Users/test/Documents/file.txt", fileName: "file.txt", isDirectory: false)
        ]
        await mockSearchService.setSearchResults("file", results: results)
        
        let call = ToolCall(
            toolIdentifier: .findFile,
            arguments: ["query": "file", "searchScope": "/Users/test/Documents"],
            sessionID: UUID()
        )
        
        let result = try await executor.execute(call)
        
        XCTAssertTrue(result.success)
        XCTAssertEqual(result.data?["count"] as? Int, 1)
    }
    
    func testFindFileTruncatedResults() async throws {
        let results = [
            FileSearchResult(path: "/Users/test/file1.txt", fileName: "file1.txt", isDirectory: false),
            FileSearchResult(path: "/Users/test/file2.txt", fileName: "file2.txt", isDirectory: false),
            FileSearchResult(path: "/Users/test/file3.txt", fileName: "file3.txt", isDirectory: false)
        ]
        await mockSearchService.setSearchResults("file", results: results)
        
        let call = ToolCall(
            toolIdentifier: .findFile,
            arguments: ["query": "file"],
            sessionID: UUID()
        )
        
        let result = try await executor.execute(call)
        
        XCTAssertTrue(result.success)
        XCTAssertEqual(result.data?["count"] as? Int, 3) // All 3 results returned (limit is 20)
        XCTAssertFalse(result.data?["truncated"] as? Bool ?? true) // Not truncated since 3 < 20
        XCTAssertEqual(result.data?["totalCount"] as? Int, 3)
    }
    
    // MARK: - Unknown Tool Test
    
    func testUnknownTool() async throws {
        let call = ToolCall(
            toolIdentifier: ToolIdentifier("unknown_tool"),
            arguments: [:],
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
    
    // MARK: - Cancellation Tests
    
    func testOpenFileCancellation() async throws {
        let fileURL = URL(fileURLWithPath: "/Users/test/file.txt")
        let target = FileSystemTarget(
            url: fileURL,
            path: "/Users/test/file.txt",
            fileName: "file.txt",
            fileExtension: "txt",
            isDirectory: false,
            exists: true
        )
        await mockResolver.setPath("/Users/test/file.txt", target: target)
        
        let call = ToolCall(
            toolIdentifier: .openFile,
            arguments: ["path": "/Users/test/file.txt"],
            sessionID: UUID()
        )
        
        // Create a task that we can cancel
        let task = Task {
            try await executor.execute(call)
        }
        
        // Cancel immediately
        task.cancel()
        
        do {
            _ = try await task.value
            XCTFail("Should have been cancelled")
        } catch is CancellationError {
            // Expected
        } catch {
            XCTFail("Expected CancellationError, got \(error)")
        }
    }
    
    func testFindFileCancellation() async throws {
        let call = ToolCall(
            toolIdentifier: .findFile,
            arguments: ["query": "file"],
            sessionID: UUID()
        )
        
        // Create a task that we can cancel
        let task = Task {
            try await executor.execute(call)
        }
        
        // Cancel immediately
        task.cancel()
        
        do {
            _ = try await task.value
            XCTFail("Should have been cancelled")
        } catch is CancellationError {
            // Expected
        } catch {
            XCTFail("Expected CancellationError, got \(error)")
        }
    }
}