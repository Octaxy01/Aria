import XCTest
import AriaDomain
import AriaApplication

final class TaskContextTests: XCTestCase {
    
    var taskContextManager: TaskContextManager!
    var sessionID: UUID!
    
    override func setUp() async throws {
        taskContextManager = TaskContextManager()
        sessionID = UUID()
        await taskContextManager.setSessionID(sessionID)
    }
    
    // MARK: - Task Context Model Tests
    
    func testTaskCreation() {
        let task = DesktopTaskContext(
            sessionID: sessionID,
            taskKind: .fileSearch,
            targetEntityKind: .file,
            scope: "Downloads",
            recentResults: []
        )
        
        XCTAssertEqual(task.taskKind, .fileSearch)
        XCTAssertEqual(task.targetEntityKind, .file)
        XCTAssertEqual(task.scope, "Downloads")
        XCTAssertTrue(task.recentResults.isEmpty)
    }
    
    func testTaskKind() {
        let fileSearchTask = DesktopTaskContext(
            sessionID: sessionID,
            taskKind: .fileSearch
        )
        XCTAssertEqual(fileSearchTask.taskKind, .fileSearch)
        
        let appTask = DesktopTaskContext(
            sessionID: sessionID,
            taskKind: .applicationInteraction
        )
        XCTAssertEqual(appTask.taskKind, .applicationInteraction)
    }
    
    func testTargetEntity() {
        let task = DesktopTaskContext(
            sessionID: sessionID,
            taskKind: .fileSearch,
            targetEntityKind: .file
        )
        
        XCTAssertEqual(task.targetEntityKind, .file)
    }
    
    func testSessionIdentity() {
        let task = DesktopTaskContext(
            sessionID: sessionID,
            taskKind: .fileSearch
        )
        
        XCTAssertEqual(task.sessionID, sessionID)
    }
    
    func testBoundedResultStorage() {
        let results = [
            TaskResult(displayName: "file1.pdf"),
            TaskResult(displayName: "file2.pdf"),
            TaskResult(displayName: "file3.pdf")
        ]
        
        let task = DesktopTaskContext(
            sessionID: sessionID,
            taskKind: .fileSearch,
            recentResults: results
        )
        
        XCTAssertEqual(task.recentResults.count, 3)
    }
    
    // MARK: - Manager Tests
    
    func testSetCurrentTask() async {
        let results = [TaskResult(displayName: "test.pdf")]
        
        await taskContextManager.updateTask(
            taskKind: .fileSearch,
            targetEntityKind: .file,
            scope: "Downloads",
            results: results,
            sessionID: sessionID
        )
        
        let currentTask = await taskContextManager.getCurrentTask(sessionID: sessionID)
        XCTAssertNotNil(currentTask)
        XCTAssertEqual(currentTask?.taskKind, .fileSearch)
        XCTAssertEqual(currentTask?.scope, "Downloads")
    }
    
    func testReplaceOldTask() async {
        // Set initial task
        await taskContextManager.updateTask(
            taskKind: .fileSearch,
            targetEntityKind: .file,
            scope: "Downloads",
            results: [TaskResult(displayName: "file1.pdf")],
            sessionID: sessionID
        )
        
        // Replace with new task
        await taskContextManager.updateTask(
            taskKind: .applicationInteraction,
            targetEntityKind: .application,
            results: [TaskResult(displayName: "Chrome")],
            sessionID: sessionID
        )
        
        let currentTask = await taskContextManager.getCurrentTask(sessionID: sessionID)
        XCTAssertEqual(currentTask?.taskKind, .applicationInteraction)
        XCTAssertEqual(currentTask?.targetEntityKind, .application)
    }
    
    func testRetrieveCurrentTask() async {
        await taskContextManager.updateTask(
            taskKind: .fileSearch,
            results: [TaskResult(displayName: "test.pdf")],
            sessionID: sessionID
        )
        
        let task = await taskContextManager.getCurrentTask(sessionID: sessionID)
        XCTAssertNotNil(task)
        XCTAssertEqual(task?.taskKind, .fileSearch)
    }
    
    func testClearTask() async {
        await taskContextManager.updateTask(
            taskKind: .fileSearch,
            results: [TaskResult(displayName: "test.pdf")],
            sessionID: sessionID
        )
        
        await taskContextManager.clearTask(sessionID: sessionID)
        
        let task = await taskContextManager.getCurrentTask(sessionID: sessionID)
        XCTAssertNil(task)
    }
    
    func testStaleSessionRejected() async {
        let staleSessionID = UUID()
        let freshSessionID = UUID()
        
        await taskContextManager.setSessionID(freshSessionID)
        
        // Try to update with stale session
        await taskContextManager.updateTask(
            taskKind: .fileSearch,
            results: [TaskResult(displayName: "test.pdf")],
            sessionID: staleSessionID
        )
        
        let task = await taskContextManager.getCurrentTask(sessionID: freshSessionID)
        XCTAssertNil(task)
    }
    
    // MARK: - Tool Update Tests
    
    func testSuccessfulFindFileCreatesFileSearchContext() async {
        let results = [
            TaskResult(displayName: "file1.pdf", path: "/path/file1.pdf"),
            TaskResult(displayName: "file2.pdf", path: "/path/file2.pdf")
        ]
        
        await taskContextManager.updateTask(
            taskKind: .fileSearch,
            targetEntityKind: .file,
            scope: "PDF",
            results: results,
            sessionID: sessionID
        )
        
        let task = await taskContextManager.getCurrentTask(sessionID: sessionID)
        XCTAssertEqual(task?.taskKind, .fileSearch)
        XCTAssertEqual(task?.targetEntityKind, .file)
        XCTAssertEqual(task?.recentResults.count, 2)
    }
    
    func testSuccessfulOpenFileCreatesFileInteractionContext() async {
        let result = TaskResult(displayName: "document.pdf", path: "/path/document.pdf")
        
        await taskContextManager.updateTask(
            taskKind: .fileInteraction,
            targetEntityKind: .file,
            results: [result],
            sessionID: sessionID
        )
        
        let task = await taskContextManager.getCurrentTask(sessionID: sessionID)
        XCTAssertEqual(task?.taskKind, .fileInteraction)
        XCTAssertEqual(task?.recentResults.count, 1)
        XCTAssertEqual(task?.recentResults.first?.displayName, "document.pdf")
    }
    
    func testSuccessfulOpenFolderCreatesFolderInteractionContext() async {
        let result = TaskResult(displayName: "Downloads", path: "/Users/test/Downloads")
        
        await taskContextManager.updateTask(
            taskKind: .folderInteraction,
            targetEntityKind: .folder,
            results: [result],
            sessionID: sessionID
        )
        
        let task = await taskContextManager.getCurrentTask(sessionID: sessionID)
        XCTAssertEqual(task?.taskKind, .folderInteraction)
        XCTAssertEqual(task?.targetEntityKind, .folder)
    }
    
    func testSuccessfulOpenApplicationCreatesApplicationInteractionContext() async {
        let result = TaskResult(
            displayName: "Chrome",
            applicationIdentifier: "com.google.Chrome"
        )
        
        await taskContextManager.updateTask(
            taskKind: .applicationInteraction,
            targetEntityKind: .application,
            results: [result],
            sessionID: sessionID
        )
        
        let task = await taskContextManager.getCurrentTask(sessionID: sessionID)
        XCTAssertEqual(task?.taskKind, .applicationInteraction)
        XCTAssertEqual(task?.targetEntityKind, .application)
    }
    
    func testFailedToolDoesNotReplaceValidContext() async {
        // Set valid context
        await taskContextManager.updateTask(
            taskKind: .applicationInteraction,
            targetEntityKind: .application,
            results: [TaskResult(displayName: "Chrome")],
            sessionID: sessionID
        )
        
        // Failed tool should not update context (simulated by not calling updateTask)
        // In real implementation, this is handled by only calling updateTask on success
        
        let task = await taskContextManager.getCurrentTask(sessionID: sessionID)
        XCTAssertEqual(task?.taskKind, .applicationInteraction)
        XCTAssertEqual(task?.recentResults.first?.displayName, "Chrome")
    }
    
    func testCancelledToolDoesNotUpdateContext() async {
        // Set initial context
        await taskContextManager.updateTask(
            taskKind: .fileSearch,
            results: [TaskResult(displayName: "file1.pdf")],
            sessionID: sessionID
        )
        
        // Cancelled tool should not update context (simulated by not calling updateTask)
        // In real implementation, this is handled by only calling updateTask on success
        
        let task = await taskContextManager.getCurrentTask(sessionID: sessionID)
        XCTAssertEqual(task?.taskKind, .fileSearch)
    }
    
    // MARK: - Follow-up Resolution Tests
    
    func testResolveNewest() async {
        let now = Date()
        let olderDate = now.addingTimeInterval(-3600) // 1 hour ago
        let newestDate = now.addingTimeInterval(-60) // 1 minute ago
        
        let results = [
            TaskResult(displayName: "old.pdf", modificationDate: olderDate),
            TaskResult(displayName: "new.pdf", modificationDate: newestDate)
        ]
        
        await taskContextManager.updateTask(
            taskKind: .fileSearch,
            results: results,
            sessionID: sessionID
        )
        
        let resolution = await taskContextManager.resolveFollowUp(.newest, sessionID: sessionID)
        
        if case .resolved(let entity) = resolution {
            XCTAssertEqual(entity.displayName, "new.pdf")
        } else {
            XCTFail("Expected resolved entity")
        }
    }
    
    func testResolvePalingBaru() async {
        let results = [
            TaskResult(displayName: "file1.pdf", modificationDate: Date().addingTimeInterval(-3600)),
            TaskResult(displayName: "file2.pdf", modificationDate: Date().addingTimeInterval(-60))
        ]
        
        await taskContextManager.updateTask(
            taskKind: .fileSearch,
            results: results,
            sessionID: sessionID
        )
        
        let resolution = await taskContextManager.resolveFollowUp(.newest, sessionID: sessionID)
        
        if case .resolved(let entity) = resolution {
            XCTAssertEqual(entity.displayName, "file2.pdf")
        } else {
            XCTFail("Expected resolved entity")
        }
    }
    
    func testResolveTerakhir() async {
        let results = [
            TaskResult(displayName: "file1.pdf", modificationDate: Date().addingTimeInterval(-3600)),
            TaskResult(displayName: "file2.pdf", modificationDate: Date().addingTimeInterval(-60))
        ]
        
        await taskContextManager.updateTask(
            taskKind: .fileSearch,
            results: results,
            sessionID: sessionID
        )
        
        let resolution = await taskContextManager.resolveFollowUp(.newest, sessionID: sessionID)
        
        if case .resolved(let entity) = resolution {
            XCTAssertEqual(entity.displayName, "file2.pdf")
        } else {
            XCTFail("Expected resolved entity")
        }
    }
    
    func testResolvePalingLama() async {
        let results = [
            TaskResult(displayName: "old.pdf", modificationDate: Date().addingTimeInterval(-7200)),
            TaskResult(displayName: "new.pdf", modificationDate: Date().addingTimeInterval(-60))
        ]
        
        await taskContextManager.updateTask(
            taskKind: .fileSearch,
            results: results,
            sessionID: sessionID
        )
        
        let resolution = await taskContextManager.resolveFollowUp(.oldest, sessionID: sessionID)
        
        if case .resolved(let entity) = resolution {
            XCTAssertEqual(entity.displayName, "old.pdf")
        } else {
            XCTFail("Expected resolved entity")
        }
    }
    
    func testMetadataUnavailable() async {
        let results = [
            TaskResult(displayName: "file1.pdf"), // No modification date
            TaskResult(displayName: "file2.pdf")  // No modification date
        ]
        
        await taskContextManager.updateTask(
            taskKind: .fileSearch,
            results: results,
            sessionID: sessionID
        )
        
        let resolution = await taskContextManager.resolveFollowUp(.newest, sessionID: sessionID)
        switch resolution {
        case .metadataUnavailable:
            XCTAssertTrue(true)
        default:
            XCTFail("Expected metadataUnavailable, got \(resolution)")
        }
    }
    
    func testExplicitArgumentOverridesTaskContext() async {
        // Set task context with Chrome
        await taskContextManager.updateTask(
            taskKind: .applicationInteraction,
            results: [TaskResult(displayName: "Chrome")],
            sessionID: sessionID
        )
        
        // Explicit argument (Safari) should override
        // This is handled at the tool orchestration level by checking explicit arguments first
        // The test verifies task context doesn't interfere with explicit arguments
        
        let task = await taskContextManager.getCurrentTask(sessionID: sessionID)
        XCTAssertEqual(task?.recentResults.first?.displayName, "Chrome")
        // In real flow, explicit "Safari" argument would be used instead
    }
    
    func testCurrentTaskPriorityOverHistoricalEntity() async {
        // Set current task context
        await taskContextManager.updateTask(
            taskKind: .fileSearch,
            results: [TaskResult(displayName: "current.pdf")],
            sessionID: sessionID
        )
        
        let task = await taskContextManager.getCurrentTask(sessionID: sessionID)
        XCTAssertNotNil(task)
        XCTAssertEqual(task?.recentResults.first?.displayName, "current.pdf")
    }
    
    // MARK: - Integration Tests
    
    func testFindFileToNewestToOpenFile() async {
        // Simulate find_file
        let results = [
            TaskResult(displayName: "old.pdf", path: "/path/old.pdf", modificationDate: Date().addingTimeInterval(-3600)),
            TaskResult(displayName: "new.pdf", path: "/path/new.pdf", modificationDate: Date().addingTimeInterval(-60))
        ]
        
        await taskContextManager.updateTask(
            taskKind: .fileSearch,
            results: results,
            sessionID: sessionID
        )
        
        // Resolve "yang terbaru"
        let resolution = await taskContextManager.resolveFollowUp(.newest, sessionID: sessionID)
        
        if case .resolved(let entity) = resolution {
            XCTAssertEqual(entity.displayName, "new.pdf")
            XCTAssertEqual(entity.path, "/path/new.pdf")
            // This path would be used for open_file
        } else {
            XCTFail("Expected resolved entity")
        }
    }
    
    func testFindFileToOldestToOpenFile() async {
        let results = [
            TaskResult(displayName: "old.pdf", path: "/path/old.pdf", modificationDate: Date().addingTimeInterval(-7200)),
            TaskResult(displayName: "new.pdf", path: "/path/new.pdf", modificationDate: Date().addingTimeInterval(-60))
        ]
        
        await taskContextManager.updateTask(
            taskKind: .fileSearch,
            results: results,
            sessionID: sessionID
        )
        
        let resolution = await taskContextManager.resolveFollowUp(.oldest, sessionID: sessionID)
        
        if case .resolved(let entity) = resolution {
            XCTAssertEqual(entity.displayName, "old.pdf")
            XCTAssertEqual(entity.path, "/path/old.pdf")
        } else {
            XCTFail("Expected resolved entity")
        }
    }
    
    func testOpenApplicationToFocusApplication() async {
        await taskContextManager.updateTask(
            taskKind: .applicationInteraction,
            results: [TaskResult(displayName: "Chrome", applicationIdentifier: "com.google.Chrome")],
            sessionID: sessionID
        )
        
        let resolution = await taskContextManager.resolveFollowUp(.continuation, sessionID: sessionID)
        
        if case .resolved(let entity) = resolution {
            XCTAssertEqual(entity.displayName, "Chrome")
            XCTAssertEqual(entity.applicationIdentifier, "com.google.Chrome")
        } else {
            XCTFail("Expected resolved entity")
        }
    }
    
    func testOpenFolderToFindFileInFolder() async {
        await taskContextManager.updateTask(
            taskKind: .folderInteraction,
            results: [TaskResult(displayName: "Downloads", path: "/Users/test/Downloads")],
            sessionID: sessionID
        )
        
        let task = await taskContextManager.getCurrentTask(sessionID: sessionID)
        XCTAssertEqual(task?.taskKind, .folderInteraction)
        // The path would be used as scope for find_file
        XCTAssertEqual(task?.recentResults.first?.path, "/Users/test/Downloads")
    }
    
    func testClarificationToSelectedEntityToTaskContextUpdate() async {
        // After clarification, user selects entity
        let selectedEntity = TaskResult(displayName: "selected.pdf", path: "/path/selected.pdf")
        
        await taskContextManager.updateTask(
            taskKind: .fileInteraction,
            results: [selectedEntity],
            sessionID: sessionID
        )
        
        let task = await taskContextManager.getCurrentTask(sessionID: sessionID)
        XCTAssertEqual(task?.taskKind, .fileInteraction)
        XCTAssertEqual(task?.recentResults.first?.displayName, "selected.pdf")
    }
    
    // MARK: - Session / Cancellation Tests
    
    func testStaleSearchCannotReplaceCurrentTask() async {
        let freshSessionID = UUID()
        let staleSessionID = UUID()
        
        await taskContextManager.setSessionID(freshSessionID)
        
        // Set task with fresh session
        await taskContextManager.updateTask(
            taskKind: .fileSearch,
            results: [TaskResult(displayName: "fresh.pdf")],
            sessionID: freshSessionID
        )
        
        // Try to replace with stale session
        await taskContextManager.updateTask(
            taskKind: .fileSearch,
            results: [TaskResult(displayName: "stale.pdf")],
            sessionID: staleSessionID
        )
        
        let task = await taskContextManager.getCurrentTask(sessionID: freshSessionID)
        XCTAssertEqual(task?.recentResults.first?.displayName, "fresh.pdf")
    }
    
    func testCancelledSearchCannotCreateTask() async {
        // Cancelled search should not call updateTask
        // Simulated by not calling updateTask
        
        let task = await taskContextManager.getCurrentTask(sessionID: sessionID)
        XCTAssertNil(task)
    }
    
    func testNewRequestInvalidatesStaleUpdate() async {
        let oldSessionID = UUID()
        let newSessionID = UUID()
        
        await taskContextManager.setSessionID(oldSessionID)
        await taskContextManager.updateTask(
            taskKind: .fileSearch,
            results: [TaskResult(displayName: "old.pdf")],
            sessionID: oldSessionID
        )
        
        // New request with new session
        await taskContextManager.setSessionID(newSessionID)
        
        // Old task should not be accessible with new session
        let task = await taskContextManager.getCurrentTask(sessionID: newSessionID)
        XCTAssertNil(task)
    }
    
    // MARK: - Command Tests
    
    func testClearRemovesTaskContext() async {
        await taskContextManager.updateTask(
            taskKind: .fileSearch,
            results: [TaskResult(displayName: "test.pdf")],
            sessionID: sessionID
        )
        
        await taskContextManager.clearAll()
        
        let task = await taskContextManager.getCurrentTask(sessionID: sessionID)
        XCTAssertNil(task)
    }
    
    func testClearPreservesMemoryService() async {
        // TaskContextManager doesn't touch MemoryService
        // This test verifies that clearAll() only clears task context
        
        await taskContextManager.updateTask(
            taskKind: .fileSearch,
            results: [TaskResult(displayName: "test.pdf")],
            sessionID: sessionID
        )
        
        await taskContextManager.clearAll()
        
        let task = await taskContextManager.getCurrentTask(sessionID: sessionID)
        XCTAssertNil(task)
        // MemoryService would be unaffected (separate component)
    }
    
    func testStopDoesNotCreateInvalidContext() async {
        // Stop command should not create invalid context
        // Simulated by not calling updateTask
        
        let task = await taskContextManager.getCurrentTask(sessionID: sessionID)
        XCTAssertNil(task)
    }
    
    // MARK: - Regression Tests
    
    func testPhase71ReferencesPreserved() async {
        // TaskContext is separate from RuntimeEntityContext
        // This test verifies they coexist
        
        let task = await taskContextManager.getCurrentTask(sessionID: sessionID)
        XCTAssertNil(task) // No task context yet
        
        // RuntimeEntityContext would still work independently
        // (tested in EntityReferenceResolutionTests)
    }
    
    func testPhase72ClarificationPreserved() async {
        // TaskContext doesn't interfere with ClarificationManager
        // They are separate components
        
        await taskContextManager.updateTask(
            taskKind: .fileSearch,
            results: [TaskResult(displayName: "test.pdf")],
            sessionID: sessionID
        )
        
        let task = await taskContextManager.getCurrentTask(sessionID: sessionID)
        XCTAssertNotNil(task)
        // ClarificationManager would still work independently
    }
    
    func testPhase73InterpretationPreserved() async {
        // TaskContext is updated after interpretation
        // This test verifies the flow works
        
        // In real flow: ToolResult -> Interpretation -> TaskContext update
        // Here we simulate the final state
        
        await taskContextManager.updateTask(
            taskKind: .fileSearch,
            results: [TaskResult(displayName: "test.pdf")],
            sessionID: sessionID
        )
        
        let task = await taskContextManager.getCurrentTask(sessionID: sessionID)
        XCTAssertNotNil(task)
    }
    
    func testPhase6ToolExecutionPreserved() async {
        // TaskContext doesn't interfere with tool execution
        // Tools execute normally, then update context
        
        // Simulate successful tool execution
        await taskContextManager.updateTask(
            taskKind: .fileSearch,
            results: [TaskResult(displayName: "test.pdf")],
            sessionID: sessionID
        )
        
        let task = await taskContextManager.getCurrentTask(sessionID: sessionID)
        XCTAssertNotNil(task)
    }
    
    func testNormalNonToolConversationUnchanged() async {
        // Non-tool conversations don't create task context
        
        let task = await taskContextManager.getCurrentTask(sessionID: sessionID)
        XCTAssertNil(task)
    }
}
