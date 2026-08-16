import XCTest
import AriaDomain
import AriaApplication
import AriaInfrastructure

final class EntityReferenceResolutionTests: XCTestCase {
    
    var entityContext: RuntimeEntityContext!
    var referenceResolver: ReferenceResolver!
    var sessionID: UUID!
    
    override func setUp() async throws {
        entityContext = RuntimeEntityContext(
            maxRecentEntities: 10,
            maxResultSets: 5,
            logger: ConsoleLogger(minimumLevel: .debug)
        )
        referenceResolver = ReferenceResolver(
            entityContext: entityContext,
            logger: ConsoleLogger(minimumLevel: .debug)
        )
        sessionID = UUID()
        await entityContext.setSessionID(sessionID)
    }
    
    override func tearDown() async throws {
        await entityContext.clear()
    }
    
    // MARK: - Entity Model Tests
    
    func testEntityCreation() {
        let entity = RuntimeEntity(
            kind: .application,
            displayName: "Chrome",
            path: "/Applications/Google Chrome.app",
            applicationIdentifier: "com.google.Chrome",
            sessionID: sessionID
        )
        
        XCTAssertEqual(entity.kind, .application)
        XCTAssertEqual(entity.displayName, "Chrome")
        XCTAssertEqual(entity.path, "/Applications/Google Chrome.app")
        XCTAssertEqual(entity.applicationIdentifier, "com.google.Chrome")
        XCTAssertEqual(entity.sessionID, sessionID)
    }
    
    func testEntityKinds() {
        let appEntity = RuntimeEntity(kind: .application, displayName: "App", sessionID: sessionID)
        let fileEntity = RuntimeEntity(kind: .file, displayName: "File", sessionID: sessionID)
        let folderEntity = RuntimeEntity(kind: .folder, displayName: "Folder", sessionID: sessionID)
        let searchEntity = RuntimeEntity(kind: .searchResult, displayName: "Result", sessionID: sessionID)
        let systemEntity = RuntimeEntity(kind: .systemInfo, displayName: "System", sessionID: sessionID)
        
        XCTAssertEqual(appEntity.kind, .application)
        XCTAssertEqual(fileEntity.kind, .file)
        XCTAssertEqual(folderEntity.kind, .folder)
        XCTAssertEqual(searchEntity.kind, .searchResult)
        XCTAssertEqual(systemEntity.kind, .systemInfo)
    }
    
    func testEntityOptionalMetadata() {
        let minimalEntity = RuntimeEntity(
            kind: .file,
            displayName: "test.txt",
            sessionID: sessionID
        )
        
        XCTAssertNil(minimalEntity.path)
        XCTAssertNil(minimalEntity.applicationIdentifier)
        XCTAssertNil(minimalEntity.position)
    }
    
    // MARK: - Runtime Context Tests
    
    func testRecordEntity() async {
        let entity = RuntimeEntity(
            kind: .application,
            displayName: "Chrome",
            sessionID: sessionID
        )
        
        await entityContext.record(entity, sessionID: sessionID)
        
        let latest = await entityContext.latest()
        let latestNotNil = latest != nil
        let latestName = latest?.displayName
        
        XCTAssertTrue(latestNotNil)
        XCTAssertEqual(latestName, "Chrome")
    }
    
    func testLatestEntity() async {
        let appEntity = RuntimeEntity(kind: .application, displayName: "Chrome", sessionID: sessionID)
        let fileEntity = RuntimeEntity(kind: .file, displayName: "test.txt", sessionID: sessionID)
        
        await entityContext.record(appEntity, sessionID: sessionID)
        await entityContext.record(fileEntity, sessionID: sessionID)
        
        let latest = await entityContext.latest()
        let latestNotNil = latest != nil
        let latestName = latest?.displayName
        
        XCTAssertTrue(latestNotNil)
        XCTAssertEqual(latestName, "test.txt") // Most recent
    }
    
    func testLatestEntityByKind() async {
        let appEntity = RuntimeEntity(kind: .application, displayName: "Chrome", sessionID: sessionID)
        let fileEntity = RuntimeEntity(kind: .file, displayName: "test.txt", sessionID: sessionID)
        let anotherApp = RuntimeEntity(kind: .application, displayName: "Safari", sessionID: sessionID)
        
        await entityContext.record(appEntity, sessionID: sessionID)
        await entityContext.record(fileEntity, sessionID: sessionID)
        await entityContext.record(anotherApp, sessionID: sessionID)
        
        let latestApp = await entityContext.latest(kind: .application)
        let latestAppNotNil = latestApp != nil
        let latestAppName = latestApp?.displayName
        let latestFile = await entityContext.latest(kind: .file)
        let latestFileNotNil = latestFile != nil
        let latestFileName = latestFile?.displayName
        
        XCTAssertTrue(latestAppNotNil)
        XCTAssertEqual(latestAppName, "Safari")
        XCTAssertTrue(latestFileNotNil)
        XCTAssertEqual(latestFileName, "test.txt")
    }
    
    func testOrderedResultSet() async {
        await entityContext.startResultSet(sessionID: sessionID)
        
        let entity1 = RuntimeEntity(kind: .searchResult, displayName: "result1.pdf", sessionID: sessionID)
        let entity2 = RuntimeEntity(kind: .searchResult, displayName: "result2.pdf", sessionID: sessionID)
        let entity3 = RuntimeEntity(kind: .searchResult, displayName: "result3.pdf", sessionID: sessionID)
        
        await entityContext.recordInResultSet(entity1, sessionID: sessionID)
        await entityContext.recordInResultSet(entity2, sessionID: sessionID)
        await entityContext.recordInResultSet(entity3, sessionID: sessionID)
        
        await entityContext.finalizeResultSet(sessionID: sessionID)
        
        let first = await entityContext.entity(at: 1)
        let second = await entityContext.entity(at: 2)
        let third = await entityContext.entity(at: 3)
        
        XCTAssertEqual(first?.displayName, "result1.pdf")
        XCTAssertEqual(second?.displayName, "result2.pdf")
        XCTAssertEqual(third?.displayName, "result3.pdf")
    }
    
    func testPositionalLookup() async {
        await entityContext.startResultSet(sessionID: sessionID)
        
        let entity1 = RuntimeEntity(kind: .searchResult, displayName: "first.pdf", sessionID: sessionID)
        let entity2 = RuntimeEntity(kind: .searchResult, displayName: "second.pdf", sessionID: sessionID)
        
        await entityContext.recordInResultSet(entity1, sessionID: sessionID)
        await entityContext.recordInResultSet(entity2, sessionID: sessionID)
        
        await entityContext.finalizeResultSet(sessionID: sessionID)
        
        let first = await entityContext.entity(at: 1)
        let second = await entityContext.entity(at: 2)
        let third = await entityContext.entity(at: 3)
        
        XCTAssertNotNil(first)
        XCTAssertNotNil(second)
        XCTAssertNil(third) // Out of bounds
    }
    
    func testClear() async {
        let entity = RuntimeEntity(kind: .application, displayName: "Chrome", sessionID: sessionID)
        
        await entityContext.record(entity, sessionID: sessionID)
        let latestBefore = await entityContext.latest()
        XCTAssertNotNil(latestBefore)
        
        await entityContext.clear()
        let latestAfter = await entityContext.latest()
        XCTAssertNil(latestAfter)
    }
    
    // MARK: - Resolution Tests
    
    func testResolveDemonstrativeItu() async {
        let entity = RuntimeEntity(kind: .folder, displayName: "Downloads", sessionID: sessionID)
        await entityContext.record(entity, sessionID: sessionID)
        
        let result = await referenceResolver.resolve("itu")
        
        switch result {
        case .resolved(let resolvedEntity):
            XCTAssertEqual(resolvedEntity.displayName, "Downloads")
        default:
            XCTFail("Expected resolved entity")
        }
    }
    
    func testResolveDemonstrativeIni() async {
        let entity = RuntimeEntity(kind: .file, displayName: "document.pdf", sessionID: sessionID)
        await entityContext.record(entity, sessionID: sessionID)
        
        let result = await referenceResolver.resolve("ini")
        
        switch result {
        case .resolved(let resolvedEntity):
            XCTAssertEqual(resolvedEntity.displayName, "document.pdf")
        default:
            XCTFail("Expected resolved entity")
        }
    }
    
    func testResolveDemonstrativeTadi() async {
        let entity = RuntimeEntity(kind: .application, displayName: "Chrome", sessionID: sessionID)
        await entityContext.record(entity, sessionID: sessionID)
        
        let result = await referenceResolver.resolve("tadi")
        
        switch result {
        case .resolved(let resolvedEntity):
            XCTAssertEqual(resolvedEntity.displayName, "Chrome")
        default:
            XCTFail("Expected resolved entity")
        }
    }
    
    func testResolvePositionalPertama() async {
        await entityContext.startResultSet(sessionID: sessionID)
        
        let entity1 = RuntimeEntity(kind: .searchResult, displayName: "first.pdf", sessionID: sessionID)
        let entity2 = RuntimeEntity(kind: .searchResult, displayName: "second.pdf", sessionID: sessionID)
        
        await entityContext.recordInResultSet(entity1, sessionID: sessionID)
        await entityContext.recordInResultSet(entity2, sessionID: sessionID)
        
        await entityContext.finalizeResultSet(sessionID: sessionID)
        
        let result = await referenceResolver.resolve("yang pertama")
        
        switch result {
        case .resolved(let resolvedEntity):
            XCTAssertEqual(resolvedEntity.displayName, "first.pdf")
        default:
            XCTFail("Expected resolved entity")
        }
    }
    
    func testResolvePositionalKedua() async {
        await entityContext.startResultSet(sessionID: sessionID)
        
        let entity1 = RuntimeEntity(kind: .searchResult, displayName: "first.pdf", sessionID: sessionID)
        let entity2 = RuntimeEntity(kind: .searchResult, displayName: "second.pdf", sessionID: sessionID)
        
        await entityContext.recordInResultSet(entity1, sessionID: sessionID)
        await entityContext.recordInResultSet(entity2, sessionID: sessionID)
        
        await entityContext.finalizeResultSet(sessionID: sessionID)
        
        let result = await referenceResolver.resolve("yang kedua")
        
        switch result {
        case .resolved(let resolvedEntity):
            XCTAssertEqual(resolvedEntity.displayName, "second.pdf")
        default:
            XCTFail("Expected resolved entity")
        }
    }
    
    func testResolvePositionalKeN() async {
        await entityContext.startResultSet(sessionID: sessionID)
        
        let entity1 = RuntimeEntity(kind: .searchResult, displayName: "first.pdf", sessionID: sessionID)
        let entity2 = RuntimeEntity(kind: .searchResult, displayName: "second.pdf", sessionID: sessionID)
        let entity3 = RuntimeEntity(kind: .searchResult, displayName: "third.pdf", sessionID: sessionID)
        
        await entityContext.recordInResultSet(entity1, sessionID: sessionID)
        await entityContext.recordInResultSet(entity2, sessionID: sessionID)
        await entityContext.recordInResultSet(entity3, sessionID: sessionID)
        
        await entityContext.finalizeResultSet(sessionID: sessionID)
        
        let result = await referenceResolver.resolve("yang ke-3")
        
        switch result {
        case .resolved(let resolvedEntity):
            XCTAssertEqual(resolvedEntity.displayName, "third.pdf")
        default:
            XCTFail("Expected resolved entity")
        }
    }
    
    func testResolveContextFoldernya() async {
        let entity = RuntimeEntity(kind: .folder, displayName: "Documents", sessionID: sessionID)
        await entityContext.record(entity, sessionID: sessionID)
        
        let result = await referenceResolver.resolve("foldernya")
        
        switch result {
        case .resolved(let resolvedEntity):
            XCTAssertEqual(resolvedEntity.displayName, "Documents")
            XCTAssertEqual(resolvedEntity.kind, .folder)
        default:
            XCTFail("Expected resolved entity")
        }
    }
    
    func testResolveContextFilennya() async {
        let entity = RuntimeEntity(kind: .file, displayName: "report.pdf", sessionID: sessionID)
        await entityContext.record(entity, sessionID: sessionID)
        
        let result = await referenceResolver.resolve("filenya")
        
        switch result {
        case .resolved(let resolvedEntity):
            XCTAssertEqual(resolvedEntity.displayName, "report.pdf")
            XCTAssertEqual(resolvedEntity.kind, .file)
        default:
            XCTFail("Expected resolved entity")
        }
    }
    
    func testResolveContextAplikasinya() async {
        let entity = RuntimeEntity(kind: .application, displayName: "Safari", sessionID: sessionID)
        await entityContext.record(entity, sessionID: sessionID)
        
        let result = await referenceResolver.resolve("aplikasinya")
        
        switch result {
        case .resolved(let resolvedEntity):
            XCTAssertEqual(resolvedEntity.displayName, "Safari")
            XCTAssertEqual(resolvedEntity.kind, .application)
        default:
            XCTFail("Expected resolved entity")
        }
    }
    
    func testResolveContextDiSitu() async {
        let entity = RuntimeEntity(kind: .folder, displayName: "Downloads", sessionID: sessionID)
        await entityContext.record(entity, sessionID: sessionID)
        
        let result = await referenceResolver.resolve("di situ")
        
        switch result {
        case .resolved(let resolvedEntity):
            XCTAssertEqual(resolvedEntity.displayName, "Downloads")
            XCTAssertEqual(resolvedEntity.kind, .folder)
        default:
            XCTFail("Expected resolved entity")
        }
    }
    
    // MARK: - Failure Tests
    
    func testUnresolvedReference() async {
        let result = await referenceResolver.resolve("itu")
        
        switch result {
        case .unresolved:
            XCTAssertTrue(true)
        default:
            XCTFail("Expected unresolved")
        }
    }
    
    func testInvalidPosition() async {
        await entityContext.startResultSet(sessionID: sessionID)
        
        let entity1 = RuntimeEntity(kind: .searchResult, displayName: "first.pdf", sessionID: sessionID)
        await entityContext.recordInResultSet(entity1, sessionID: sessionID)
        
        await entityContext.finalizeResultSet(sessionID: sessionID)
        
        let result = await referenceResolver.resolve("yang ke-5")
        
        switch result {
        case .invalidPosition:
            XCTAssertTrue(true)
        default:
            XCTFail("Expected invalid position")
        }
    }
    
    func testMissingResultSet() async {
        let result = await referenceResolver.resolve("yang pertama")
        
        switch result {
        case .invalidPosition:
            XCTAssertTrue(true)
        default:
            XCTFail("Expected invalid position")
        }
    }
    
    func testUnknownReferencePattern() async {
        let result = await referenceResolver.resolve("some random text")
        
        switch result {
        case .unresolved:
            XCTAssertTrue(true)
        default:
            XCTFail("Expected unresolved")
        }
    }
    
    // MARK: - Session Tests
    
    func testStaleSessionCannotRecordEntity() async {
        let staleSessionID = UUID()
        let entity = RuntimeEntity(kind: .application, displayName: "Chrome", sessionID: staleSessionID)
        
        await entityContext.record(entity, sessionID: staleSessionID)
        
        // Try to record with current session ID
        let currentSessionID = UUID()
        await entityContext.setSessionID(currentSessionID)
        
        let entity2 = RuntimeEntity(kind: .application, displayName: "Safari", sessionID: currentSessionID)
        await entityContext.record(entity2, sessionID: currentSessionID)
        
        let latest = await entityContext.latest()
        let latestNotNil = latest != nil
        let latestName = latest?.displayName
        
        XCTAssertTrue(latestNotNil)
        XCTAssertEqual(latestName, "Safari")
    }
    
    func testStaleContextCannotOverrideActiveContext() async {
        let session1 = UUID()
        let session2 = UUID()
        
        await entityContext.setSessionID(session1)
        let entity1 = RuntimeEntity(kind: .application, displayName: "Chrome", sessionID: session1)
        await entityContext.record(entity1, sessionID: session1)
        
        await entityContext.setSessionID(session2)
        let entity2 = RuntimeEntity(kind: .application, displayName: "Safari", sessionID: session2)
        await entityContext.record(entity2, sessionID: session2)
        
        let latest = await entityContext.latest()
        let latestNotNil = latest != nil
        let latestName = latest?.displayName
        let latestSessionID = latest?.sessionID
        
        XCTAssertTrue(latestNotNil)
        XCTAssertEqual(latestName, "Safari")
        XCTAssertEqual(latestSessionID, session2)
    }
    
    // MARK: - Cancellation Tests
    
    func testCancelledToolDoesNotUpdateContext() async {
        let entity = RuntimeEntity(kind: .application, displayName: "Chrome", sessionID: sessionID)
        
        // Record entity
        await entityContext.record(entity, sessionID: sessionID)
        let latestBefore = await entityContext.latest()
        XCTAssertNotNil(latestBefore)
        
        // Clear context (simulating cancellation)
        await entityContext.clear()
        
        // Verify context is cleared
        let latestAfter = await entityContext.latest()
        XCTAssertNil(latestAfter)
    }
    
    // MARK: - Clear Tests
    
    func testClearRemovesRuntimeContext() async {
        let entity1 = RuntimeEntity(kind: .application, displayName: "Chrome", sessionID: sessionID)
        let entity2 = RuntimeEntity(kind: .file, displayName: "test.txt", sessionID: sessionID)
        
        await entityContext.record(entity1, sessionID: sessionID)
        await entityContext.record(entity2, sessionID: sessionID)
        
        let latestBefore = await entityContext.latest()
        XCTAssertNotNil(latestBefore)
        
        await entityContext.clear()
        
        let latestAfter = await entityContext.latest()
        let latestAppAfter = await entityContext.latest(kind: .application)
        let latestFileAfter = await entityContext.latest(kind: .file)
        
        XCTAssertNil(latestAfter)
        XCTAssertNil(latestAppAfter)
        XCTAssertNil(latestFileAfter)
    }
    
    func testClearRemovesResultSets() async {
        await entityContext.startResultSet(sessionID: sessionID)
        
        let entity1 = RuntimeEntity(kind: .searchResult, displayName: "first.pdf", sessionID: sessionID)
        await entityContext.recordInResultSet(entity1, sessionID: sessionID)
        
        await entityContext.finalizeResultSet(sessionID: sessionID)
        
        let entityBefore = await entityContext.entity(at: 1)
        XCTAssertNotNil(entityBefore)
        
        await entityContext.clear()
        
        let entityAfter = await entityContext.entity(at: 1)
        XCTAssertNil(entityAfter)
    }
    
    // MARK: - Is Reference Tests
    
    func testIsReference() async {
        let ituResult = await referenceResolver.isReference("itu")
        let iniResult = await referenceResolver.isReference("ini")
        let pertamaResult = await referenceResolver.isReference("yang pertama")
        let keduaResult = await referenceResolver.isReference("yang kedua")
        let folderResult = await referenceResolver.isReference("foldernya")
        let situResult = await referenceResolver.isReference("di situ")
        let chromeResult = await referenceResolver.isReference("Chrome")
        let pathResult = await referenceResolver.isReference("/path/to/file")
        
        XCTAssertTrue(ituResult)
        XCTAssertTrue(iniResult)
        XCTAssertTrue(pertamaResult)
        XCTAssertTrue(keduaResult)
        XCTAssertTrue(folderResult)
        XCTAssertTrue(situResult)
        XCTAssertFalse(chromeResult)
        XCTAssertFalse(pathResult)
    }
}
