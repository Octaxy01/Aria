import XCTest
import AriaDomain
import AriaApplication
import AriaInfrastructure

final class EntityReferenceIntegrationTests: XCTestCase {
    
    var toolRegistry: ToolRegistry!
    var entityContext: RuntimeEntityContext!
    var referenceResolver: ReferenceResolver!
    var toolOrchestrator: ToolOrchestrator!
    var conversation: ConversationService!
    var sessionID: UUID!
    
    override func setUp() async throws {
        toolRegistry = ToolRegistry()
        entityContext = RuntimeEntityContext(
            maxRecentEntities: 10,
            maxResultSets: 5,
            logger: ConsoleLogger(minimumLevel: .debug)
        )
        referenceResolver = ReferenceResolver(
            entityContext: entityContext,
            logger: ConsoleLogger(minimumLevel: .debug)
        )
        conversation = ConversationService()
        sessionID = UUID()
        
        await entityContext.setSessionID(sessionID)
        
        // Register test tools
        try await toolRegistry.register(ToolDefinition(
            identifier: .openFile,
            description: "Open a file",
            riskLevel: .safe,
            parameters: [
                ToolParameter(name: "path", description: "File path", isRequired: true, type: .string)
            ],
            requiresConfirmation: false,
            category: .file
        ))
        
        try await toolRegistry.register(ToolDefinition(
            identifier: .findFile,
            description: "Find files",
            riskLevel: .sensitive,
            parameters: [
                ToolParameter(name: "query", description: "Search query", isRequired: true, type: .string)
            ],
            requiresConfirmation: false,
            category: .file
        ))
    }
    
    override func tearDown() async throws {
        await entityContext.clear()
        await conversation.clear()
    }
    
    // MARK: - Integration Tests
    
    func testEntityRecordingFromToolResult() async {
        // Simulate a successful file open tool result
        _ = ToolResult.success([
            "path": "/Users/test/Documents/report.pdf",
            "fileName": "report.pdf"
        ])
        
        _ = ToolCall(
            toolIdentifier: .openFile,
            arguments: ["path": "/Users/test/Documents/report.pdf"],
            sessionID: sessionID,
            correlationID: UUID()
        )
        
        // Record entity from tool result
        let entity = RuntimeEntity(
            kind: .file,
            displayName: "report.pdf",
            path: "/Users/test/Documents/report.pdf",
            sessionID: sessionID
        )
        
        await entityContext.record(entity, sessionID: sessionID)
        
        // Verify entity was recorded
        let latest = await entityContext.latest()
        XCTAssertNotNil(latest)
        XCTAssertEqual(latest?.displayName, "report.pdf")
        XCTAssertEqual(latest?.path, "/Users/test/Documents/report.pdf")
    }
    
    func testSearchResultRecordingAsResultSet() async {
        // Simulate a search result with multiple files
        await entityContext.startResultSet(sessionID: sessionID)
        
        let result1 = RuntimeEntity(
            kind: .searchResult,
            displayName: "document1.pdf",
            path: "/Users/test/Documents/document1.pdf",
            position: 1,
            sessionID: sessionID
        )
        
        let result2 = RuntimeEntity(
            kind: .searchResult,
            displayName: "document2.pdf",
            path: "/Users/test/Documents/document2.pdf",
            position: 2,
            sessionID: sessionID
        )
        
        let result3 = RuntimeEntity(
            kind: .searchResult,
            displayName: "document3.pdf",
            path: "/Users/test/Documents/document3.pdf",
            position: 3,
            sessionID: sessionID
        )
        
        await entityContext.recordInResultSet(result1, sessionID: sessionID)
        await entityContext.recordInResultSet(result2, sessionID: sessionID)
        await entityContext.recordInResultSet(result3, sessionID: sessionID)
        
        await entityContext.finalizeResultSet(sessionID: sessionID)
        
        // Verify positional access
        let first = await entityContext.entity(at: 1)
        let second = await entityContext.entity(at: 2)
        let third = await entityContext.entity(at: 3)
        
        XCTAssertEqual(first?.displayName, "document1.pdf")
        XCTAssertEqual(second?.displayName, "document2.pdf")
        XCTAssertEqual(third?.displayName, "document3.pdf")
    }
    
    func testReferenceResolutionInToolArguments() async {
        // Record an entity first
        let entity = RuntimeEntity(
            kind: .file,
            displayName: "report.pdf",
            path: "/Users/test/Documents/report.pdf",
            sessionID: sessionID
        )
        
        await entityContext.record(entity, sessionID: sessionID)
        
        // Resolve reference
        let result = await referenceResolver.resolve("itu")
        
        switch result {
        case .resolved(let resolvedEntity):
            XCTAssertEqual(resolvedEntity.path, "/Users/test/Documents/report.pdf")
        default:
            XCTFail("Expected resolved entity")
        }
    }
    
    func testPositionalReferenceInSearchResults() async {
        // Set up search results
        await entityContext.startResultSet(sessionID: sessionID)
        
        let result1 = RuntimeEntity(
            kind: .searchResult,
            displayName: "first.pdf",
            path: "/Users/test/first.pdf",
            position: 1,
            sessionID: sessionID
        )
        
        let result2 = RuntimeEntity(
            kind: .searchResult,
            displayName: "second.pdf",
            path: "/Users/test/second.pdf",
            position: 2,
            sessionID: sessionID
        )
        
        await entityContext.recordInResultSet(result1, sessionID: sessionID)
        await entityContext.recordInResultSet(result2, sessionID: sessionID)
        
        await entityContext.finalizeResultSet(sessionID: sessionID)
        
        // Resolve "yang kedua"
        let result = await referenceResolver.resolve("yang kedua")
        
        switch result {
        case .resolved(let resolvedEntity):
            XCTAssertEqual(resolvedEntity.displayName, "second.pdf")
            XCTAssertEqual(resolvedEntity.path, "/Users/test/second.pdf")
        default:
            XCTFail("Expected resolved entity")
        }
    }
    
    func testContextReferenceByKind() async {
        // Record multiple entities of different kinds
        let appEntity = RuntimeEntity(
            kind: .application,
            displayName: "Chrome",
            path: "/Applications/Google Chrome.app",
            applicationIdentifier: "com.google.Chrome",
            sessionID: sessionID
        )
        
        let fileEntity = RuntimeEntity(
            kind: .file,
            displayName: "report.pdf",
            path: "/Users/test/report.pdf",
            sessionID: sessionID
        )
        
        let folderEntity = RuntimeEntity(
            kind: .folder,
            displayName: "Documents",
            path: "/Users/test/Documents",
            sessionID: sessionID
        )
        
        await entityContext.record(appEntity, sessionID: sessionID)
        await entityContext.record(fileEntity, sessionID: sessionID)
        await entityContext.record(folderEntity, sessionID: sessionID)
        
        // Resolve "filenya" (should get the file entity)
        let fileResult = await referenceResolver.resolve("filenya")
        
        switch fileResult {
        case .resolved(let resolvedEntity):
            XCTAssertEqual(resolvedEntity.kind, .file)
            XCTAssertEqual(resolvedEntity.displayName, "report.pdf")
        default:
            XCTFail("Expected resolved file entity")
        }
        
        // Resolve "aplikasinya" (should get the app entity)
        let appResult = await referenceResolver.resolve("aplikasinya")
        
        switch appResult {
        case .resolved(let resolvedEntity):
            XCTAssertEqual(resolvedEntity.kind, .application)
            XCTAssertEqual(resolvedEntity.displayName, "Chrome")
        default:
            XCTFail("Expected resolved app entity")
        }
    }
    
    func testSessionSafetyInEntityRecording() async {
        let session1 = UUID()
        let session2 = UUID()
        
        // Set session 1 and record entity
        await entityContext.setSessionID(session1)
        let entity1 = RuntimeEntity(
            kind: .application,
            displayName: "Chrome",
            sessionID: session1
        )
        await entityContext.record(entity1, sessionID: session1)
        
        // Set session 2 and record entity
        await entityContext.setSessionID(session2)
        let entity2 = RuntimeEntity(
            kind: .application,
            displayName: "Safari",
            sessionID: session2
        )
        await entityContext.record(entity2, sessionID: session2)
        
        // Verify only session 2 entity is accessible
        let latest = await entityContext.latest()
        XCTAssertEqual(latest?.displayName, "Safari")
        XCTAssertEqual(latest?.sessionID, session2)
    }
    
    func testClearConversationClearsEntityContext() async {
        // Record some entities
        let entity = RuntimeEntity(
            kind: .application,
            displayName: "Chrome",
            sessionID: sessionID
        )
        
        await entityContext.record(entity, sessionID: sessionID)
        let latestBefore = await entityContext.latest()
        XCTAssertNotNil(latestBefore)
        
        // Clear context
        await entityContext.clear()
        
        // Verify context is cleared
        let latest = await entityContext.latest()
        XCTAssertNil(latest)
    }
    
    func testUnresolvedReferenceFailsGracefully() async {
        // Try to resolve reference with no entities
        let result = await referenceResolver.resolve("itu")
        
        switch result {
        case .unresolved:
            XCTAssertTrue(true)
        default:
            XCTFail("Expected unresolved")
        }
    }
    
    func testInvalidPositionFailsGracefully() async {
        // Set up search results with only 2 items
        await entityContext.startResultSet(sessionID: sessionID)
        
        let result1 = RuntimeEntity(
            kind: .searchResult,
            displayName: "first.pdf",
            sessionID: sessionID
        )
        
        await entityContext.recordInResultSet(result1, sessionID: sessionID)
        await entityContext.finalizeResultSet(sessionID: sessionID)
        
        // Try to resolve "yang ke-5" (out of bounds)
        let result = await referenceResolver.resolve("yang ke-5")
        
        switch result {
        case .invalidPosition:
            XCTAssertTrue(true)
        default:
            XCTFail("Expected invalid position")
        }
    }
    
    func testMultipleResultSets() async {
        // Create first result set
        await entityContext.startResultSet(sessionID: sessionID)
        
        let result1 = RuntimeEntity(
            kind: .searchResult,
            displayName: "search1.pdf",
            sessionID: sessionID
        )
        
        await entityContext.recordInResultSet(result1, sessionID: sessionID)
        await entityContext.finalizeResultSet(sessionID: sessionID)
        
        // Create second result set
        await entityContext.startResultSet(sessionID: sessionID)
        
        let result2 = RuntimeEntity(
            kind: .searchResult,
            displayName: "search2.pdf",
            sessionID: sessionID
        )
        
        await entityContext.recordInResultSet(result2, sessionID: sessionID)
        await entityContext.finalizeResultSet(sessionID: sessionID)
        
        // Verify second result set is accessible
        let latest = await entityContext.entity(at: 1)
        XCTAssertEqual(latest?.displayName, "search2.pdf")
    }
    
    func testEntityKindFiltering() async {
        // Record entities of different kinds
        let appEntity = RuntimeEntity(kind: .application, displayName: "Chrome", sessionID: sessionID)
        let fileEntity = RuntimeEntity(kind: .file, displayName: "report.pdf", sessionID: sessionID)
        let anotherApp = RuntimeEntity(kind: .application, displayName: "Safari", sessionID: sessionID)
        
        await entityContext.record(appEntity, sessionID: sessionID)
        await entityContext.record(fileEntity, sessionID: sessionID)
        await entityContext.record(anotherApp, sessionID: sessionID)
        
        // Get latest application
        let latestApp = await entityContext.latest(kind: .application)
        XCTAssertEqual(latestApp?.displayName, "Safari")
        
        // Get latest file
        let latestFile = await entityContext.latest(kind: .file)
        XCTAssertEqual(latestFile?.displayName, "report.pdf")
    }
}
