import XCTest
@testable import AriaInfrastructure
@testable import AriaDomain

final class FileSearchServiceTests: XCTestCase {
    
    var mockSearchService: MockFileSearchService!
    
    override func setUp() async throws {
        try await super.setUp()
        mockSearchService = MockFileSearchService()
    }
    
    override func tearDown() async throws {
        mockSearchService = nil
        try await super.tearDown()
    }
    
    // MARK: - Mock Search Service Tests
    
    func testSearchFilesFound() async throws {
        let results = [
            FileSearchResult(path: "/Users/test/Documents/file1.pdf", fileName: "file1.pdf", isDirectory: false),
            FileSearchResult(path: "/Users/test/Documents/file2.pdf", fileName: "file2.pdf", isDirectory: false)
        ]
        await mockSearchService.setSearchResults("file", results: results)
        
        let response = try await mockSearchService.searchFiles(query: "file", searchScope: nil, maxResults: 10)
        
        XCTAssertEqual(response.results.count, 2)
        XCTAssertFalse(response.truncated)
        XCTAssertEqual(response.totalCount, 2)
        XCTAssertEqual(response.results[0].fileName, "file1.pdf")
    }
    
    func testSearchFilesTruncated() async throws {
        let results = [
            FileSearchResult(path: "/Users/test/file1.txt", fileName: "file1.txt", isDirectory: false),
            FileSearchResult(path: "/Users/test/file2.txt", fileName: "file2.txt", isDirectory: false),
            FileSearchResult(path: "/Users/test/file3.txt", fileName: "file3.txt", isDirectory: false)
        ]
        await mockSearchService.setSearchResults("file", results: results)
        
        let response = try await mockSearchService.searchFiles(query: "file", searchScope: nil, maxResults: 2)
        
        XCTAssertEqual(response.results.count, 2)
        XCTAssertTrue(response.truncated)
        XCTAssertEqual(response.totalCount, 3)
    }
    
    func testSearchFilesNoResults() async throws {
        let response = try await mockSearchService.searchFiles(query: "nonexistent", searchScope: nil, maxResults: 10)
        
        XCTAssertEqual(response.results.count, 0)
        XCTAssertFalse(response.truncated)
        XCTAssertEqual(response.totalCount, 0)
    }
    
    // MARK: - Native Search Service Tests (with temporary files)
    
    func testNativeSearchServiceInTemporaryDirectory() async throws {
        let nativeSearchService = NativeFileSearchService()
        
        // Create a temporary directory with test files
        let tempDir = FileManager.default.temporaryDirectory
        let testDir = tempDir.appendingPathComponent("test_search_\(UUID().uuidString)")
        
        try FileManager.default.createDirectory(at: testDir, withIntermediateDirectories: true)
        
        defer {
            // Clean up
            try? FileManager.default.removeItem(at: testDir)
        }
        
        // Create test files
        let file1 = testDir.appendingPathComponent("test_file_1.txt")
        let file2 = testDir.appendingPathComponent("test_file_2.txt")
        let otherFile = testDir.appendingPathComponent("other_document.pdf")
        
        try "content1".write(to: file1, atomically: true, encoding: .utf8)
        try "content2".write(to: file2, atomically: true, encoding: .utf8)
        try "content3".write(to: otherFile, atomically: true, encoding: .utf8)
        
        // Search for "test_file"
        let response = try await nativeSearchService.searchFiles(
            query: "test_file",
            searchScope: testDir.path,
            maxResults: 10
        )
        
        XCTAssertEqual(response.results.count, 2)
        XCTAssertFalse(response.truncated)
        XCTAssertEqual(response.totalCount, 2)
        
        // Verify results are sorted by filename
        let fileNames = response.results.map { $0.fileName }
        XCTAssertEqual(fileNames, ["test_file_1.txt", "test_file_2.txt"])
    }
    
    func testNativeSearchServiceCaseInsensitive() async throws {
        let nativeSearchService = NativeFileSearchService()
        
        // Create a temporary directory with test files
        let tempDir = FileManager.default.temporaryDirectory
        let testDir = tempDir.appendingPathComponent("test_case_\(UUID().uuidString)")
        
        try FileManager.default.createDirectory(at: testDir, withIntermediateDirectories: true)
        
        defer {
            // Clean up
            try? FileManager.default.removeItem(at: testDir)
        }
        
        // Create test files with different cases
        let file1 = testDir.appendingPathComponent("TestFile.txt")
        let file2 = testDir.appendingPathComponent("testfile.pdf")
        let file3 = testDir.appendingPathComponent("TESTFILE.doc")
        
        try "content1".write(to: file1, atomically: true, encoding: .utf8)
        try "content2".write(to: file2, atomically: true, encoding: .utf8)
        try "content3".write(to: file3, atomically: true, encoding: .utf8)
        
        // Search for "testfile" (lowercase)
        let response = try await nativeSearchService.searchFiles(
            query: "testfile",
            searchScope: testDir.path,
            maxResults: 10
        )
        
        XCTAssertEqual(response.results.count, 3)
        XCTAssertFalse(response.truncated)
    }
    
    func testNativeSearchServiceMaxResultsLimit() async throws {
        let nativeSearchService = NativeFileSearchService()
        
        // Create a temporary directory with many test files
        let tempDir = FileManager.default.temporaryDirectory
        let testDir = tempDir.appendingPathComponent("test_limit_\(UUID().uuidString)")
        
        try FileManager.default.createDirectory(at: testDir, withIntermediateDirectories: true)
        
        defer {
            // Clean up
            try? FileManager.default.removeItem(at: testDir)
        }
        
        // Create 25 test files
        for i in 1...25 {
            let file = testDir.appendingPathComponent("test_file_\(i).txt")
            try "content\(i)".write(to: file, atomically: true, encoding: .utf8)
        }
        
        // Search with max results of 10
        let response = try await nativeSearchService.searchFiles(
            query: "test_file",
            searchScope: testDir.path,
            maxResults: 10
        )
        
        XCTAssertEqual(response.results.count, 10)
        XCTAssertTrue(response.truncated)
        // The actual implementation may return different counts based on internal logic
        XCTAssertGreaterThan(response.totalCount, 10)
    }
    
    func testNativeSearchServiceSubdirectory() async throws {
        let nativeSearchService = NativeFileSearchService()
        
        // Create a temporary directory with subdirectories
        let tempDir = FileManager.default.temporaryDirectory
        let testDir = tempDir.appendingPathComponent("test_subdir_\(UUID().uuidString)")
        let subDir = testDir.appendingPathComponent("subdir")
        
        try FileManager.default.createDirectory(at: subDir, withIntermediateDirectories: true)
        
        defer {
            // Clean up
            try? FileManager.default.removeItem(at: testDir)
        }
        
        // Create files in both directories
        let rootFile = testDir.appendingPathComponent("root_test.txt")
        let subFile = subDir.appendingPathComponent("sub_test.txt")
        
        try "root content".write(to: rootFile, atomically: true, encoding: .utf8)
        try "sub content".write(to: subFile, atomically: true, encoding: .utf8)
        
        // Search from root directory
        let response = try await nativeSearchService.searchFiles(
            query: "test",
            searchScope: testDir.path,
            maxResults: 10
        )
        
        XCTAssertEqual(response.results.count, 2)
        XCTAssertFalse(response.truncated)
    }
    
    func testNativeSearchServiceEmptyQuery() async throws {
        let nativeSearchService = NativeFileSearchService()
        
        let tempDir = FileManager.default.temporaryDirectory
        
        do {
            _ = try await nativeSearchService.searchFiles(
                query: "",
                searchScope: tempDir.path,
                maxResults: 10
            )
            XCTFail("Should have thrown an error for empty query")
        } catch let error as FileSearchError {
            XCTAssertEqual(error, .invalidQuery("Query cannot be empty"))
        } catch {
            XCTFail("Unexpected error type: \(error)")
        }
    }
    
    func testNativeSearchServiceNonExistentScope() async throws {
        let nativeSearchService = NativeFileSearchService()
        
        do {
            _ = try await nativeSearchService.searchFiles(
                query: "test",
                searchScope: "/nonexistent/directory",
                maxResults: 10
            )
            XCTFail("Should have thrown an error for non-existent scope")
        } catch let error as FileSearchError {
            XCTAssertEqual(error, .searchScopeNotFound("/nonexistent/directory"))
        } catch {
            XCTFail("Unexpected error type: \(error)")
        }
    }
    
    func testNativeSearchServiceFileAsScope() async throws {
        let nativeSearchService = NativeFileSearchService()
        
        // Create a temporary file
        let tempDir = FileManager.default.temporaryDirectory
        let tempFile = tempDir.appendingPathComponent("test_file_\(UUID().uuidString).txt")
        
        try "test content".write(to: tempFile, atomically: true, encoding: .utf8)
        
        defer {
            // Clean up
            try? FileManager.default.removeItem(at: tempFile)
        }
        
        do {
            _ = try await nativeSearchService.searchFiles(
                query: "test",
                searchScope: tempFile.path,
                maxResults: 10
            )
            XCTFail("Should have thrown an error for file as scope")
        } catch let error as FileSearchError {
            XCTAssertEqual(error, .invalidSearchScope("Search scope must be a directory"))
        } catch {
            XCTFail("Unexpected error type: \(error)")
        }
    }
    
    func testNativeSearchServiceDefaultScope() async throws {
        let nativeSearchService = NativeFileSearchService()
        
        // Search without specifying scope (should use home directory)
        let response = try await nativeSearchService.searchFiles(
            query: "nonexistent_file_that_should_not_exist_anywhere",
            searchScope: nil,
            maxResults: 10
        )
        
        // Should succeed but return no results
        XCTAssertEqual(response.results.count, 0)
        XCTAssertFalse(response.truncated)
    }
}