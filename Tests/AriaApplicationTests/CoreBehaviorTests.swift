import XCTest
import AriaDomain
@testable import AriaApplication

/// Minimal deterministic tests for core behavior.
/// These tests avoid network dependencies, GUI, VOICEVOX, and API keys.
final class CoreBehaviorTests: XCTestCase {
    
    // MARK: - ConversationService Tests
    
    func testConversationServiceAppend() async {
        let service = ConversationService()
        
        // Append user message
        let userMsg = await service.append(role: .user, content: "Hello")
        XCTAssertEqual(userMsg.role, .user)
        XCTAssertEqual(userMsg.content, "Hello")
        
        // Append assistant message
        let assistantMsg = await service.append(role: .assistant, content: "Hi there!")
        XCTAssertEqual(assistantMsg.role, .assistant)
        XCTAssertEqual(assistantMsg.content, "Hi there!")
        
        // Verify history
        let history = await service.history()
        let historyCount = history.count
        XCTAssertEqual(historyCount, 2)
        XCTAssertEqual(history[0].content, "Hello")
        XCTAssertEqual(history[1].content, "Hi there!")
    }
    
    func testConversationServiceClear() async {
        let service = ConversationService()
        
        await service.append(role: .user, content: "Test")
        await service.append(role: .assistant, content: "Response")
        
        let historyBefore = await service.history()
        XCTAssertEqual(historyBefore.count, 2)
        
        await service.clear()
        
        let historyAfter = await service.history()
        XCTAssertEqual(historyAfter.count, 0)
    }
    
    func testConversationServiceRecentHistory() async {
        let service = ConversationService()
        
        // Add 5 messages
        for i in 1...5 {
            await service.append(role: .user, content: "Message \(i)")
        }
        
        // Get recent 3
        let recent = await service.recentHistory(maxMessages: 3)
        XCTAssertEqual(recent.count, 3)
        XCTAssertEqual(recent[0].content, "Message 3")
        XCTAssertEqual(recent[1].content, "Message 4")
        XCTAssertEqual(recent[2].content, "Message 5")
    }
    
    func testConversationServiceRemoveLast() async {
        let service = ConversationService()
        
        await service.append(role: .user, content: "First")
        await service.append(role: .assistant, content: "Second")
        
        let removed = await service.removeLast()
        XCTAssertNotNil(removed)
        XCTAssertEqual(removed?.content, "Second")
        
        let history = await service.history()
        XCTAssertEqual(history.count, 1)
        XCTAssertEqual(history.first?.content, "First")
    }
    
    func testConversationServiceRemoveLastEmpty() async {
        let service = ConversationService()
        
        let removed = await service.removeLast()
        XCTAssertNil(removed)
    }
    
    func testConversationServiceIsLastMessageFromUser() async {
        let service = ConversationService()
        
        let result1 = await service.isLastMessageFromUser()
        XCTAssertFalse(result1)
        
        await service.append(role: .user, content: "Hello")
        let result2 = await service.isLastMessageFromUser()
        XCTAssertTrue(result2)
        
        await service.append(role: .assistant, content: "Hi")
        let result3 = await service.isLastMessageFromUser()
        XCTAssertFalse(result3)
    }
    
    // MARK: - ToolConfirmationPolicy Tests
    
    func testToolConfirmationPolicySafeTool() async {
        let policy = ToolConfirmationPolicy()
        
        let safeTool = ToolDefinition(
            identifier: ToolIdentifier("get_system_info"),
            description: "Get system information",
            riskLevel: .safe,
            requiresConfirmation: false
        )
        
        let toolCall = ToolCall(
            toolIdentifier: safeTool.identifier,
            arguments: [:],
            sessionID: UUID()
        )
        
        let result = await policy.requiresConfirmation(
            toolDefinition: safeTool,
            toolCall: toolCall
        )
        XCTAssertFalse(result)
    }
    
    func testToolConfirmationPolicyDestructiveTool() async {
        let policy = ToolConfirmationPolicy()
        
        let destructiveTool = ToolDefinition(
            identifier: ToolIdentifier("delete_file"),
            description: "Delete a file",
            riskLevel: .destructive,
            requiresConfirmation: false
        )
        
        let toolCall = ToolCall(
            toolIdentifier: destructiveTool.identifier,
            arguments: [:],
            sessionID: UUID()
        )
        
        let result = await policy.requiresConfirmation(
            toolDefinition: destructiveTool,
            toolCall: toolCall
        )
        XCTAssertTrue(result)
    }
    
    func testToolConfirmationPolicyExplicitConfirmation() async {
        let policy = ToolConfirmationPolicy()
        
        let explicitTool = ToolDefinition(
            identifier: ToolIdentifier("custom_action"),
            description: "Custom action",
            riskLevel: .safe,
            requiresConfirmation: true
        )
        
        let toolCall = ToolCall(
            toolIdentifier: explicitTool.identifier,
            arguments: [:],
            sessionID: UUID()
        )
        
        let result = await policy.requiresConfirmation(
            toolDefinition: explicitTool,
            toolCall: toolCall
        )
        XCTAssertTrue(result)
    }
    
    func testToolConfirmationPolicyConfirmationMessage() async {
        let policy = ToolConfirmationPolicy()
        
        let tool = ToolDefinition(
            identifier: ToolIdentifier("test"),
            description: "Test",
            riskLevel: .safe,
            requiresConfirmation: false
        )
        
        let toolCall = ToolCall(
            toolIdentifier: tool.identifier,
            arguments: [:],
            sessionID: UUID()
        )
        
        let message = await policy.confirmationMessage(
            toolDefinition: tool,
            toolCall: toolCall
        )
        
        XCTAssertEqual(message, "Aku perlu konfirmasi dulu sebelum melakukan itu. Lanjut?")
    }
    
    // MARK: - ReferenceResolver Classification Tests
    
    func testReferenceResolverDemonstrativeClassification() {
        let entityContext = RuntimeEntityContext()
        let resolver = ReferenceResolver(entityContext: entityContext)
        
        // Indonesian
        XCTAssertTrue(resolver.isReference("itu"))
        XCTAssertTrue(resolver.isReference("ini"))
        XCTAssertTrue(resolver.isReference("tersebut"))
        XCTAssertTrue(resolver.isReference("tadi"))
        
        // English
        XCTAssertTrue(resolver.isReference("that"))
        XCTAssertTrue(resolver.isReference("this"))
        XCTAssertTrue(resolver.isReference("the one"))
        
        // Not references
        XCTAssertFalse(resolver.isReference("hello"))
        XCTAssertFalse(resolver.isReference("/path/to/file"))
        XCTAssertFalse(resolver.isReference("Chrome"))
    }
    
    func testReferenceResolverPositionalClassification() {
        let entityContext = RuntimeEntityContext()
        let resolver = ReferenceResolver(entityContext: entityContext)
        
        XCTAssertTrue(resolver.isReference("yang pertama"))
        XCTAssertTrue(resolver.isReference("yang kedua"))
        XCTAssertTrue(resolver.isReference("yang ketiga"))
        XCTAssertTrue(resolver.isReference("yang ke-5"))
        XCTAssertTrue(resolver.isReference("yang ke 10"))
    }
    
    func testReferenceResolverContextClassification() {
        let entityContext = RuntimeEntityContext()
        let resolver = ReferenceResolver(entityContext: entityContext)
        
        // Indonesian
        XCTAssertTrue(resolver.isReference("foldernya"))
        XCTAssertTrue(resolver.isReference("filenya"))
        XCTAssertTrue(resolver.isReference("aplikasinya"))
        
        // English
        XCTAssertTrue(resolver.isReference("the folder"))
        XCTAssertTrue(resolver.isReference("the file"))
        XCTAssertTrue(resolver.isReference("the application"))
    }
    
    func testReferenceResolverRecencyClassification() {
        let entityContext = RuntimeEntityContext()
        let resolver = ReferenceResolver(entityContext: entityContext)
        
        XCTAssertTrue(resolver.isReference("yang terbaru"))
        XCTAssertTrue(resolver.isReference("yang paling baru"))
        XCTAssertTrue(resolver.isReference("yang terakhir"))
        XCTAssertTrue(resolver.isReference("yang paling lama"))
    }
    
    // MARK: - ToolDefinition Tests
    
    func testToolDefinitionEquality() {
        let id1 = ToolIdentifier("test_tool")
        let id2 = ToolIdentifier("test_tool")
        let id3 = ToolIdentifier("other_tool")
        
        XCTAssertEqual(id1, id2)
        XCTAssertNotEqual(id1, id3)
    }
    
    func testToolRiskLevelComparison() {
        // ToolRiskLevel is not Comparable, so we just verify they're different
        XCTAssertNotEqual(ToolRiskLevel.safe, ToolRiskLevel.destructive)
    }
    
    // MARK: - ConversationMessage Tests
    
    func testConversationMessageCreation() {
        let message = ConversationMessage(role: .user, content: "Test")
        
        XCTAssertEqual(message.role, .user)
        XCTAssertEqual(message.content, "Test")
        XCTAssertNotNil(message.id)
        XCTAssertNotNil(message.timestamp)
    }
    
    func testConversationMessageEquality() {
        let msg1 = ConversationMessage(role: .user, content: "Test")
        let msg2 = ConversationMessage(role: .user, content: "Test")
        let msg3 = ConversationMessage(role: .assistant, content: "Test")
        
        // Test that same content produces same role and content
        XCTAssertEqual(msg1.role, msg2.role)
        XCTAssertEqual(msg1.content, msg2.content)
        
        // Test that different role produces different results
        XCTAssertNotEqual(msg1.role, msg3.role)
    }
}