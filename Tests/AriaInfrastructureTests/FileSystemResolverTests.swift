import XCTest
@testable import AriaInfrastructure
@testable import AriaDomain

final class FileSystemResolverTests: XCTestCase {
    
    var mockResolver: MockFileSystemResolver!
    
    override func setUp() async throws {
        try await super.setUp()
        mockResolver = MockFileSystemResolver()
    }
    
    override func tearDown() async throws {
        mockResolver = nil
        try await super.tearDown()
    }
    
    // MARK: - Mock Resolver Tests
    
    func testResolvePathFound() async throws {
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
        
        let resolved = try await mockResolver.resolvePath("/Users/test/Documents/file.pdf")
        
        XCTAssertNotNil(resolved)
        XCTAssertEqual(resolved?.path, "/Users/test/Documents/file.pdf")
        XCTAssertEqual(resolved?.fileName, "file.pdf")
        XCTAssertEqual(resolved?.fileExtension, "pdf")
        XCTAssertFalse(resolved?.isDirectory ?? true)
        XCTAssertTrue(resolved?.exists ?? false)
    }
    
    func testResolvePathNotFound() async throws {
        let resolved = try await mockResolver.resolvePath("/nonexistent/path")
        
        XCTAssertNil(resolved)
    }
    
    func testResolveDirectoryPath() async throws {
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
        
        let resolved = try await mockResolver.resolvePath("/Users/test/Documents")
        
        XCTAssertNotNil(resolved)
        XCTAssertEqual(resolved?.path, "/Users/test/Documents")
        XCTAssertEqual(resolved?.fileName, "Documents")
        XCTAssertNil(resolved?.fileExtension)
        XCTAssertTrue(resolved?.isDirectory ?? false)
        XCTAssertTrue(resolved?.exists ?? false)
    }
    
    func testPathExists() async {
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
        
        let exists = await mockResolver.pathExists("/Users/test/file.txt")
        XCTAssertTrue(exists)
        
        let notExists = await mockResolver.pathExists("/nonexistent/path")
        XCTAssertFalse(notExists)
    }
    
    func testIsDirectory() async {
        let dirURL = URL(fileURLWithPath: "/Users/test/Documents")
        let dirTarget = FileSystemTarget(
            url: dirURL,
            path: "/Users/test/Documents",
            fileName: "Documents",
            fileExtension: nil,
            isDirectory: true,
            exists: true
        )
        await mockResolver.setPath("/Users/test/Documents", target: dirTarget)
        
        let isDir = await mockResolver.isDirectory("/Users/test/Documents")
        XCTAssertTrue(isDir)
        
        let fileURL = URL(fileURLWithPath: "/Users/test/file.txt")
        let fileTarget = FileSystemTarget(
            url: fileURL,
            path: "/Users/test/file.txt",
            fileName: "file.txt",
            fileExtension: "txt",
            isDirectory: false,
            exists: true
        )
        await mockResolver.setPath("/Users/test/file.txt", target: fileTarget)
        
        let isNotDir = await mockResolver.isDirectory("/Users/test/file.txt")
        XCTAssertFalse(isNotDir)
    }
    
    func testIsFile() async {
        let fileURL = URL(fileURLWithPath: "/Users/test/file.txt")
        let fileTarget = FileSystemTarget(
            url: fileURL,
            path: "/Users/test/file.txt",
            fileName: "file.txt",
            fileExtension: "txt",
            isDirectory: false,
            exists: true
        )
        await mockResolver.setPath("/Users/test/file.txt", target: fileTarget)
        
        let isFile = await mockResolver.isFile("/Users/test/file.txt")
        XCTAssertTrue(isFile)
        
        let dirURL = URL(fileURLWithPath: "/Users/test/Documents")
        let dirTarget = FileSystemTarget(
            url: dirURL,
            path: "/Users/test/Documents",
            fileName: "Documents",
            fileExtension: nil,
            isDirectory: true,
            exists: true
        )
        await mockResolver.setPath("/Users/test/Documents", target: dirTarget)
        
        let isNotFile = await mockResolver.isFile("/Users/test/Documents")
        XCTAssertFalse(isNotFile)
    }
    
    // MARK: - Native Resolver Tests (with temporary files)
    
    func testNativeResolverResolveTemporaryFile() async throws {
        let nativeResolver = NativeFileSystemResolver()
        
        // Create a temporary file
        let tempDir = FileManager.default.temporaryDirectory
        let tempFile = tempDir.appendingPathComponent("test_file_\(UUID().uuidString).txt")
        
        try "test content".write(to: tempFile, atomically: true, encoding: .utf8)
        
        defer {
            // Clean up
            try? FileManager.default.removeItem(at: tempFile)
        }
        
        let resolved = try await nativeResolver.resolvePath(tempFile.path)
        
        XCTAssertNotNil(resolved)
        XCTAssertEqual(resolved?.path, tempFile.path)
        XCTAssertEqual(resolved?.fileName, tempFile.lastPathComponent)
        XCTAssertEqual(resolved?.fileExtension, "txt")
        XCTAssertFalse(resolved?.isDirectory ?? true)
        XCTAssertTrue(resolved?.exists ?? false)
    }
    
    func testNativeResolverResolveTemporaryDirectory() async throws {
        let nativeResolver = NativeFileSystemResolver()
        
        // Create a temporary directory
        let tempDir = FileManager.default.temporaryDirectory
        let tempSubDir = tempDir.appendingPathComponent("test_dir_\(UUID().uuidString)")
        
        try FileManager.default.createDirectory(at: tempSubDir, withIntermediateDirectories: true)
        
        defer {
            // Clean up
            try? FileManager.default.removeItem(at: tempSubDir)
        }
        
        let resolved = try await nativeResolver.resolvePath(tempSubDir.path)
        
        XCTAssertNotNil(resolved)
        XCTAssertEqual(resolved?.path, tempSubDir.path)
        XCTAssertEqual(resolved?.fileName, tempSubDir.lastPathComponent)
        XCTAssertTrue(resolved?.isDirectory ?? false)
        XCTAssertTrue(resolved?.exists ?? false)
    }
    
    func testNativeResolverTildeExpansion() async throws {
        let nativeResolver = NativeFileSystemResolver()
        
        // Test tilde expansion
        let homePath = "~"
        let resolved = try await nativeResolver.resolvePath(homePath)
        
        XCTAssertNotNil(resolved)
        let path = resolved?.path ?? ""
        XCTAssertTrue(path.hasPrefix("/Users/") || path.hasPrefix("/var/folders/"))
        XCTAssertTrue(resolved?.isDirectory ?? false)
        XCTAssertTrue(resolved?.exists ?? false)
    }
    
    func testNativeResolverNonExistentPath() async throws {
        let nativeResolver = NativeFileSystemResolver()
        
        let resolved = try await nativeResolver.resolvePath("/nonexistent/path/that/does/not/exist")
        
        XCTAssertNil(resolved)
    }
    
    func testNativeResolverEmptyPath() async throws {
        let nativeResolver = NativeFileSystemResolver()
        
        let resolved = try await nativeResolver.resolvePath("")
        
        XCTAssertNil(resolved)
    }
}