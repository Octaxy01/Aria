import XCTest
import AriaDomain
import AriaApplication
import AriaInfrastructure

final class ClarificationFlowTests: XCTestCase {
    
    var clarificationManager: ClarificationManager!
    var clarificationMessageBuilder: ClarificationMessageBuilder!
    var clarificationAnswerParser: ClarificationAnswerParser!
    var entityContext: RuntimeEntityContext!
    var referenceResolver: ReferenceResolver!
    var sessionID: UUID!
    
    override func setUp() async throws {
        clarificationManager = ClarificationManager()
        clarificationMessageBuilder = ClarificationMessageBuilder()
        clarificationAnswerParser = ClarificationAnswerParser()
        
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
        await clarificationManager.setSessionID(sessionID)
    }
    
    override func tearDown() async throws {
        await entityContext.clear()
        await clarificationManager.clearAll()
    }
    
    // MARK: - ClarificationManager Tests
    
    func testClarificationManagerStoresRequest() async {
        let entity1 = RuntimeEntity(kind: .file, displayName: "file1.txt", sessionID: sessionID)
        let entity2 = RuntimeEntity(kind: .file, displayName: "file2.txt", sessionID: sessionID)
        
        let request = ClarificationRequest(
            originalUserMessage: "buka itu",
            candidates: [entity1, entity2],
            sessionID: sessionID,
            pendingToolCall: nil
        )
        
        await clarificationManager.storeClarification(request, sessionID: sessionID)
        
        let retrieved = await clarificationManager.getPendingClarification(sessionID: sessionID)
        XCTAssertNotNil(retrieved)
        XCTAssertEqual(retrieved?.candidates.count, 2)
    }
    
    func testClarificationManagerClearsRequest() async {
        let entity = RuntimeEntity(kind: .file, displayName: "file.txt", sessionID: sessionID)
        let request = ClarificationRequest(
            originalUserMessage: "buka itu",
            candidates: [entity],
            sessionID: sessionID,
            pendingToolCall: nil
        )
        
        await clarificationManager.storeClarification(request, sessionID: sessionID)
        await clarificationManager.clearClarification(sessionID: sessionID)
        
        let retrieved = await clarificationManager.getPendingClarification(sessionID: sessionID)
        XCTAssertNil(retrieved)
    }
    
    func testClarificationManagerSessionSafety() async {
        let session1 = UUID()
        let session2 = UUID()
        
        await clarificationManager.setSessionID(session1)
        
        let entity = RuntimeEntity(kind: .file, displayName: "file.txt", sessionID: session1)
        let request = ClarificationRequest(
            originalUserMessage: "buka itu",
            candidates: [entity],
            sessionID: session1,
            pendingToolCall: nil
        )
        
        await clarificationManager.storeClarification(request, sessionID: session1)
        
        // Try to retrieve with different session ID
        await clarificationManager.setSessionID(session2)
        let retrieved = await clarificationManager.getPendingClarification(sessionID: session2)
        XCTAssertNil(retrieved)
    }
    
    func testClarificationManagerHasPendingClarification() async {
        let entity = RuntimeEntity(kind: .file, displayName: "file.txt", sessionID: sessionID)
        let request = ClarificationRequest(
            originalUserMessage: "buka itu",
            candidates: [entity],
            sessionID: sessionID,
            pendingToolCall: nil
        )
        
        await clarificationManager.storeClarification(request, sessionID: sessionID)
        
        let hasPending = await clarificationManager.hasPendingClarification(sessionID: sessionID)
        XCTAssertTrue(hasPending)
    }
    
    func testClarificationManagerClearAll() async {
        let entity = RuntimeEntity(kind: .file, displayName: "file.txt", sessionID: sessionID)
        let request = ClarificationRequest(
            originalUserMessage: "buka itu",
            candidates: [entity],
            sessionID: sessionID,
            pendingToolCall: nil
        )
        
        await clarificationManager.storeClarification(request, sessionID: sessionID)
        await clarificationManager.clearAll()
        
        let retrieved = await clarificationManager.getPendingClarification(sessionID: sessionID)
        XCTAssertNil(retrieved)
    }
    
    // MARK: - ClarificationMessageBuilder Tests
    
    func testClarificationMessageBuilderGeneratesMessage() {
        let entity1 = RuntimeEntity(kind: .file, displayName: "file1.txt", sessionID: sessionID)
        let entity2 = RuntimeEntity(kind: .file, displayName: "file2.txt", sessionID: sessionID)
        
        let message = clarificationMessageBuilder.buildClarificationMessage(
            candidates: [entity1, entity2],
            reference: "itu"
        )
        
        XCTAssertTrue(message.contains("Maaf"))
        XCTAssertTrue(message.contains("1. file1.txt"))
        XCTAssertTrue(message.contains("2. file2.txt"))
    }
    
    func testClarificationMessageBuilderEmptyCandidates() {
        let message = clarificationMessageBuilder.buildClarificationMessage(
            candidates: [],
            reference: "itu"
        )
        
        XCTAssertTrue(message.contains("tidak mengerti"))
    }
    
    func testClarificationMessageBuilderSingleCandidate() {
        let entity = RuntimeEntity(kind: .file, displayName: "file.txt", sessionID: sessionID)
        
        let message = clarificationMessageBuilder.buildClarificationMessage(
            candidates: [entity],
            reference: "itu"
        )
        
        XCTAssertTrue(message.contains("1. file.txt"))
    }
    
    // MARK: - ClarificationAnswerParser Tests
    
    func testClarificationAnswerParserParsesNumber() {
        let entity1 = RuntimeEntity(kind: .file, displayName: "file1.txt", sessionID: sessionID)
        let entity2 = RuntimeEntity(kind: .file, displayName: "file2.txt", sessionID: sessionID)
        
        let request = ClarificationRequest(
            originalUserMessage: "buka itu",
            candidates: [entity1, entity2],
            sessionID: sessionID,
            pendingToolCall: nil
        )
        
        let answer = clarificationAnswerParser.parseAnswer("1", clarification: request)
        
        switch answer {
        case .selectedPosition(let position):
            XCTAssertEqual(position, 1)
        default:
            XCTFail("Expected selected position")
        }
    }
    
    func testClarificationAnswerParserParsesName() {
        let entity1 = RuntimeEntity(kind: .file, displayName: "file1.txt", sessionID: sessionID)
        let entity2 = RuntimeEntity(kind: .file, displayName: "file2.txt", sessionID: sessionID)
        
        let request = ClarificationRequest(
            originalUserMessage: "buka itu",
            candidates: [entity1, entity2],
            sessionID: sessionID,
            pendingToolCall: nil
        )
        
        let answer = clarificationAnswerParser.parseAnswer("file1", clarification: request)
        
        switch answer {
        case .selectedEntity(let entity):
            XCTAssertEqual(entity.displayName, "file1.txt")
        default:
            XCTFail("Expected selected entity")
        }
    }
    
    func testClarificationAnswerParserParsesIndonesianPositional() {
        let entity1 = RuntimeEntity(kind: .file, displayName: "file1.txt", sessionID: sessionID)
        let entity2 = RuntimeEntity(kind: .file, displayName: "file2.txt", sessionID: sessionID)
        
        let request = ClarificationRequest(
            originalUserMessage: "buka itu",
            candidates: [entity1, entity2],
            sessionID: sessionID,
            pendingToolCall: nil
        )
        
        let answer = clarificationAnswerParser.parseAnswer("yang pertama", clarification: request)
        
        switch answer {
        case .selectedPosition(let position):
            XCTAssertEqual(position, 1)
        default:
            XCTFail("Expected selected position")
        }
    }
    
    func testClarificationAnswerParserParsesCancellation() {
        let entity = RuntimeEntity(kind: .file, displayName: "file.txt", sessionID: sessionID)
        
        let request = ClarificationRequest(
            originalUserMessage: "buka itu",
            candidates: [entity],
            sessionID: sessionID,
            pendingToolCall: nil
        )
        
        let answer = clarificationAnswerParser.parseAnswer("batal", clarification: request)
        
        switch answer {
        case .cancelled:
            XCTAssertTrue(true)
        default:
            XCTFail("Expected cancelled")
        }
    }
    
    func testClarificationAnswerParserParsesInvalid() {
        let entity = RuntimeEntity(kind: .file, displayName: "file.txt", sessionID: sessionID)
        
        let request = ClarificationRequest(
            originalUserMessage: "buka itu",
            candidates: [entity],
            sessionID: sessionID,
            pendingToolCall: nil
        )
        
        let answer = clarificationAnswerParser.parseAnswer("xyz", clarification: request)
        
        switch answer {
        case .invalid:
            XCTAssertTrue(true)
        default:
            XCTFail("Expected invalid")
        }
    }
    
    func testClarificationAnswerParserParsesCancelKeywords() {
        let entity = RuntimeEntity(kind: .file, displayName: "file.txt", sessionID: sessionID)
        
        let request = ClarificationRequest(
            originalUserMessage: "buka itu",
            candidates: [entity],
            sessionID: sessionID,
            pendingToolCall: nil
        )
        
        let cancelKeywords = ["batal", "cancel", "tidak", "no", "skip", "lewat"]
        
        for keyword in cancelKeywords {
            let answer = clarificationAnswerParser.parseAnswer(keyword, clarification: request)
            switch answer {
            case .cancelled:
                XCTAssertTrue(true)
            default:
                XCTFail("Expected cancelled for keyword: \(keyword)")
            }
        }
    }
    
    // MARK: - Ambiguity Detection Tests
    
    func testAmbiguityDetectionMultipleSameName() async {
        let entity1 = RuntimeEntity(kind: .file, displayName: "document.pdf", path: "/path1/document.pdf", sessionID: sessionID)
        let entity2 = RuntimeEntity(kind: .file, displayName: "document.pdf", path: "/path2/document.pdf", sessionID: sessionID)
        
        await entityContext.record(entity1, sessionID: sessionID)
        await entityContext.record(entity2, sessionID: sessionID)
        
        let result = await referenceResolver.resolve("itu")
        
        switch result {
        case .ambiguous(let candidates):
            XCTAssertEqual(candidates.count, 2)
        default:
            XCTFail("Expected ambiguous result")
        }
    }
    
    func testAmbiguityDetectionResultSet() async {
        await entityContext.startResultSet(sessionID: sessionID)
        
        let entity1 = RuntimeEntity(kind: .searchResult, displayName: "result1.pdf", sessionID: sessionID)
        let entity2 = RuntimeEntity(kind: .searchResult, displayName: "result2.pdf", sessionID: sessionID)
        
        await entityContext.recordInResultSet(entity1, sessionID: sessionID)
        await entityContext.recordInResultSet(entity2, sessionID: sessionID)
        
        await entityContext.finalizeResultSet(sessionID: sessionID)
        
        let result = await referenceResolver.resolve("itu")
        
        switch result {
        case .ambiguous(let candidates):
            XCTAssertEqual(candidates.count, 2)
        default:
            XCTFail("Expected ambiguous result for result set")
        }
    }
    
    func testNoAmbiguitySingleEntity() async {
        let entity = RuntimeEntity(kind: .file, displayName: "document.pdf", sessionID: sessionID)
        await entityContext.record(entity, sessionID: sessionID)
        
        let result = await referenceResolver.resolve("itu")
        
        switch result {
        case .resolved(let resolvedEntity):
            XCTAssertEqual(resolvedEntity.displayName, "document.pdf")
        default:
            XCTFail("Expected resolved result for single entity")
        }
    }
    
    // MARK: - Session Safety Tests
    
    func testClarificationSessionIsolation() async {
        let session1 = UUID()
        let session2 = UUID()
        
        await clarificationManager.setSessionID(session1)
        
        let entity1 = RuntimeEntity(kind: .file, displayName: "file1.txt", sessionID: session1)
        let request1 = ClarificationRequest(
            originalUserMessage: "buka itu",
            candidates: [entity1],
            sessionID: session1,
            pendingToolCall: nil
        )
        
        await clarificationManager.storeClarification(request1, sessionID: session1)
        
        // Switch to session 2
        await clarificationManager.setSessionID(session2)
        
        let entity2 = RuntimeEntity(kind: .file, displayName: "file2.txt", sessionID: session2)
        let request2 = ClarificationRequest(
            originalUserMessage: "buka itu",
            candidates: [entity2],
            sessionID: session2,
            pendingToolCall: nil
        )
        
        await clarificationManager.storeClarification(request2, sessionID: session2)
        
        // Verify session 1 request is not accessible from session 2
        let retrievedFromSession2 = await clarificationManager.getPendingClarification(sessionID: session2)
        XCTAssertEqual(retrievedFromSession2?.candidates.first?.displayName, "file2.txt")
        
        // Switch back to session 1
        await clarificationManager.setSessionID(session1)
        let retrievedFromSession1 = await clarificationManager.getPendingClarification(sessionID: session1)
        XCTAssertEqual(retrievedFromSession1?.candidates.first?.displayName, "file1.txt")
    }
    
    // MARK: - Cancellation Tests
    
    func testClarificationCancellationClearsState() async {
        let entity = RuntimeEntity(kind: .file, displayName: "file.txt", sessionID: sessionID)
        let request = ClarificationRequest(
            originalUserMessage: "buka itu",
            candidates: [entity],
            sessionID: sessionID,
            pendingToolCall: nil
        )
        
        await clarificationManager.storeClarification(request, sessionID: sessionID)
        
        let beforeCancel = await clarificationManager.hasPendingClarification(sessionID: sessionID)
        XCTAssertTrue(beforeCancel)
        
        await clarificationManager.clearClarification(sessionID: sessionID)
        
        let afterCancel = await clarificationManager.hasPendingClarification(sessionID: sessionID)
        XCTAssertFalse(afterCancel)
    }
    
    // MARK: - Integration Tests
    
    func testFullClarificationFlow() async {
        // Setup: Create ambiguous entities
        let entity1 = RuntimeEntity(kind: .file, displayName: "document.pdf", path: "/path1/document.pdf", sessionID: sessionID)
        let entity2 = RuntimeEntity(kind: .file, displayName: "document.pdf", path: "/path2/document.pdf", sessionID: sessionID)
        
        await entityContext.record(entity1, sessionID: sessionID)
        await entityContext.record(entity2, sessionID: sessionID)
        
        // Step 1: Detect ambiguity
        let resolutionResult = await referenceResolver.resolve("itu")
        
        switch resolutionResult {
        case .ambiguous(let candidates):
            XCTAssertEqual(candidates.count, 2)
            
            // Step 2: Create clarification request
            let clarificationRequest = ClarificationRequest(
                originalUserMessage: "buka itu",
                candidates: candidates,
                sessionID: sessionID,
                pendingToolCall: nil
            )
            
            await clarificationManager.storeClarification(clarificationRequest, sessionID: sessionID)
            
            // Step 3: Generate clarification message
            let clarificationMessage = clarificationMessageBuilder.buildClarificationMessage(
                candidates: candidates,
                reference: "itu"
            )
            
            XCTAssertTrue(clarificationMessage.contains("Maaf"))
            XCTAssertTrue(clarificationMessage.contains("1."))
            XCTAssertTrue(clarificationMessage.contains("2."))
            
            // Step 4: Parse user answer
            let userAnswer = "1"
            let parsedAnswer = clarificationAnswerParser.parseAnswer(userAnswer, clarification: clarificationRequest)
            
            switch parsedAnswer {
            case .selectedPosition(let position):
                XCTAssertEqual(position, 1)
                
                // Step 5: Clear clarification after selection
                await clarificationManager.clearClarification(sessionID: sessionID)
                
                let afterClear = await clarificationManager.hasPendingClarification(sessionID: sessionID)
                XCTAssertFalse(afterClear)
                
            default:
                XCTFail("Expected selected position")
            }
            
        default:
            XCTFail("Expected ambiguous result")
        }
    }
    
    func testClarificationFlowWithCancellation() async {
        let entity1 = RuntimeEntity(kind: .file, displayName: "file1.txt", sessionID: sessionID)
        let entity2 = RuntimeEntity(kind: .file, displayName: "file2.txt", sessionID: sessionID)
        
        let request = ClarificationRequest(
            originalUserMessage: "buka itu",
            candidates: [entity1, entity2],
            sessionID: sessionID,
            pendingToolCall: nil
        )
        
        await clarificationManager.storeClarification(request, sessionID: sessionID)
        
        let answer = clarificationAnswerParser.parseAnswer("batal", clarification: request)
        
        switch answer {
        case .cancelled:
            await clarificationManager.clearClarification(sessionID: sessionID)
            
            let afterCancel = await clarificationManager.hasPendingClarification(sessionID: sessionID)
            XCTAssertFalse(afterCancel)
            
        default:
            XCTFail("Expected cancelled")
        }
    }
    
    func testClarificationFlowWithInvalidAnswer() async {
        let entity = RuntimeEntity(kind: .file, displayName: "file.txt", sessionID: sessionID)
        
        let request = ClarificationRequest(
            originalUserMessage: "buka itu",
            candidates: [entity],
            sessionID: sessionID,
            pendingToolCall: nil
        )
        
        await clarificationManager.storeClarification(request, sessionID: sessionID)
        
        let answer = clarificationAnswerParser.parseAnswer("invalid", clarification: request)
        
        switch answer {
        case .invalid:
            // Clarification should remain pending for retry
            let stillPending = await clarificationManager.hasPendingClarification(sessionID: sessionID)
            XCTAssertTrue(stillPending)
            
        default:
            XCTFail("Expected invalid")
        }
    }
}
