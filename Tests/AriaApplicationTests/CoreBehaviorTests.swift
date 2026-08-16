import XCTest
import AriaDomain
@testable import AriaApplication

/// Minimal deterministic tests for core behavior.
/// These tests avoid network dependencies, GUI, VOICEVOX, and API keys.
final class CoreBehaviorTests: XCTestCase {
    
    // MARK: - ConversationService Tests
    
    func testConversationServiceAppend() {
        let service = ConversationService()
        
        // Append user message
        let userMsg = service.append(role: .user, content: "Hello")
        XCTAssertEqual(userMsg.role, .user)
        XCTAssertEqual(userMsg.content, "Hello")
        
        // Append assistant message
        let assistantMsg = service.append(role: .assistant, content: "Hi there!")
        XCTAssertEqual(assistantMsg.role, .assistant)
        XCTAssertEqual(assistantMsg.content, "Hi there!")
        
        // Verify history
        let history = service.history()
        XCTAssertEqual(history.count, 2)
        XCTAssertEqual(history[0].content, "Hello")
        XCTAssertEqual(history[1].content, "Hi there!")
    }
    
    func testConversationServiceClear() {
        let service = ConversationService()
        
        service.append(role: .user, content: "Test")
        service.append(role: .assistant, content: "Response")
        
        XCTAssertEqual(service.history().count, 2)
        
        service.clear()
        
        XCTAssertEqual(service.history().count, 0)
    }
    
    func testConversationServiceRecentHistory() {
        let service = ConversationService()
        
        // Add 5 messages
        for i in 1...5 {
            service.append(role: .user, content: "Message \(i)")
        }
        
        // Get recent 3
        let recent = service.recentHistory(maxMessages: 3)
        XCTAssertEqual(recent.count, 3)
        XCTAssertEqual(recent[0].content, "Message 3")
        XCTAssertEqual(recent[1].content, "Message 4")
        XCTAssertEqual(recent[2].content, "Message 5")
    }
    
    func testConversationServiceRemoveLast() {
        let service = ConversationService()
        
        service.append(role: .user, content: "First")
        service.append(role: .assistant, content: "Second")
        
        let removed = service.removeLast()
        XCTAssertNotNil(removed)
        XCTAssertEqual(removed?.content, "Second")
        
        XCTAssertEqual(service.history().count, 1)
        XCTAssertEqual(service.history().first?.content, "First")
    }
    
    func testConversationServiceRemoveLastEmpty() {
        let service = ConversationService()
        
        let removed = service.removeLast()
        XCTAssertNil(removed)
    }
    
    func testConversationServiceIsLastMessageFromUser() {
        let service = ConversationService()
        
        XCTAssertFalse(service.isLastMessageFromUser())
        
        service.append(role: .user, content: "Hello")
        XCTAssertTrue(service.isLastMessageFromUser())
        
        service.append(role: .assistant, content: "Hi")
        XCTAssertFalse(service.isLastMessageFromUser())
    }
    
    // MARK: - ToolConfirmationPolicy Tests
    
    func testToolConfirmationPolicySafeTool() {
        let policy = ToolConfirmationPolicy()
        
        let safeTool = ToolDefinition(
            identifier: ToolIdentifier(name: "get_system_info"),
            displayName: "Get System Info",
            description: "Get system information",
            riskLevel: .safe,
            requiresConfirmation: false
        )
        
        let toolCall = ToolCall(
            id: "test-id",
            identifier: safeTool.identifier,
            arguments: [:]
        )
        
        XCTAssertFalse(policy.requiresConfirmation(
            toolDefinition: safeTool,
            toolCall: toolCall
        ))
    }
    
    func testToolConfirmationPolicyDestructiveTool() {
        let policy = ToolConfirmationPolicy()
        
        let destructiveTool = ToolDefinition(
            identifier: ToolIdentifier(name: "delete_file"),
            displayName: "Delete File",
            description: "Delete a file",
            riskLevel: .destructive,
            requiresConfirmation: false
        )
        
        let toolCall = ToolCall(
            id: "test-id",
            identifier: destructiveTool.identifier,
            arguments: [:]
        )
        
        XCTAssertTrue(policy.requiresConfirmation(
            toolDefinition: destructiveTool,
            toolCall: toolCall
        ))
    }
    
    func testToolConfirmationPolicyExplicitConfirmation() {
        let policy = ToolConfirmationPolicy()
        
        let explicitTool = ToolDefinition(
            identifier: ToolIdentifier(name: "custom_action"),
            displayName: "Custom Action",
            description: "Custom action",
            riskLevel: .safe,
            requiresConfirmation: true
        )
        
        let toolCall = ToolCall(
            id: "test-id",
            identifier: explicitTool.identifier,
            arguments: [:]
        )
        
        XCTAssertTrue(policy.requiresConfirmation(
            toolDefinition: explicitTool,
            toolCall: toolCall
        ))
    }
    
    func testToolConfirmationPolicyConfirmationMessage() {
        let policy = ToolConfirmationPolicy()
        
        let tool = ToolDefinition(
            identifier: ToolIdentifier(name: "test"),
            displayName: "Test",
            description: "Test",
            riskLevel: .safe,
            requiresConfirmation: false
        )
        
        let toolCall = ToolCall(
            id: "test-id",
            identifier: tool.identifier,
            arguments: [:]
        )
        
        let message = policy.confirmationMessage(
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
        let id1 = ToolIdentifier(name: "test_tool")
        let id2 = ToolIdentifier(name: "test_tool")
        let id3 = ToolIdentifier(name: "other_tool")
        
        XCTAssertEqual(id1, id2)
        XCTAssertNotEqual(id1, id3)
    }
    
    func testToolRiskLevelComparison() {
        XCTAssertLessThan(ToolRiskLevel.safe, ToolRiskLevel.destructive)
    }
    
    // MARK: - ConversationMessage Tests
    
    func testConversationMessageCreation() {
        let message = ConversationMessage(role: .user, content: "Test")
        
        XCTAssertEqual(message.role, .user)
        XCTAssertEqual(message.content, "Test")
    }
    
    func testConversationMessageEquality() {
        let msg1 = ConversationMessage(role: .user, content: "Test")
        let msg2 = ConversationMessage(role: .user, content: "Test")
        let msg3 = ConversationMessage(role: .assistant, content: "Test")
        
        XCTAssertEqual(msg1, msg2)
        XCTAssertNotEqual(msg1, msg3)
    }
}
}<arg_value><arg_key>limit</arg_key><arg_value>50