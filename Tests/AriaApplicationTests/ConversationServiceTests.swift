import XCTest
@testable import AriaApplication
import AriaDomain

final class ConversationServiceTests: XCTestCase {
    func testAppendPreservesOrderAndRoles() async {
        let service = ConversationService()
        await service.append(role: .user, content: "hi")
        await service.append(role: .assistant, content: "hello")

        let history = await service.history()
        XCTAssertEqual(history.count, 2)
        XCTAssertEqual(history[0].role, .user)
        XCTAssertEqual(history[0].content, "hi")
        XCTAssertEqual(history[1].role, .assistant)
        XCTAssertEqual(history[1].content, "hello")
    }

    func testClearEmptiesHistory() async {
        let service = ConversationService()
        await service.append(role: .user, content: "hi")
        await service.clear()
        let history = await service.history()
        XCTAssertTrue(history.isEmpty)
    }

    func testRecentHistoryReturnsEverythingWhenUnderLimit() async {
        let service = ConversationService()
        await service.append(role: .user, content: "hi")
        await service.append(role: .assistant, content: "hello")

        let recent = await service.recentHistory(maxMessages: 10)
        XCTAssertEqual(recent.count, 2)
    }

    func testRecentHistoryTrimsToLastNMessagesInOrder() async {
        let service = ConversationService()
        for i in 1...5 {
            await service.append(role: .user, content: "msg \(i)")
        }

        let recent = await service.recentHistory(maxMessages: 2)
        XCTAssertEqual(recent.map(\.content), ["msg 4", "msg 5"])
    }
}
