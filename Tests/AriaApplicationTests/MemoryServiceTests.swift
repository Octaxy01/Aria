import XCTest
@testable import AriaApplication
@testable import AriaDomain
@testable import AriaInfrastructure

final class MemoryServiceTests: XCTestCase {
    var memoryService: MemoryService!
    var inMemoryStore: InMemoryMemoryStore!

    override func setUp() async throws {
        inMemoryStore = InMemoryMemoryStore()
        memoryService = MemoryService(store: inMemoryStore)
    }

    override func tearDown() async throws {
        try await inMemoryStore.deleteAll()
    }

    // MARK: - Store Tests

    func testStoreMemory() async throws {
        try await memoryService.store(
            content: "User likes coffee",
            category: .preference,
            importance: .normal
        )

        let memories = try await memoryService.retrieveAll()
        XCTAssertEqual(memories.count, 1)
        XCTAssertEqual(memories.first?.content, "User likes coffee")
    }

    func testStoreEmptyContentThrowsError() async {
        do {
            try await memoryService.store(content: "   ")
            XCTFail("Expected error for empty content")
        } catch let error as AriaError {
            switch error {
            case .invalidState:
                break // Expected
            default:
                XCTFail("Expected invalidState error, got \(error)")
            }
        } catch {
            XCTFail("Expected AriaError, got \(error)")
        }
    }

    func testStoreTrimsWhitespace() async throws {
        try await memoryService.store(content: "  User likes tea  ")

        let memories = try await memoryService.retrieveAll()
        XCTAssertEqual(memories.first?.content, "User likes tea")
    }

    // MARK: - Retrieve Tests

    func testRetrieveById() async throws {
        try await memoryService.store(content: "Test memory")
        let memories = try await memoryService.retrieveAll()
        let id = memories.first?.id

        let retrieved = try await memoryService.retrieve(id: id!)
        XCTAssertNotNil(retrieved)
        XCTAssertEqual(retrieved?.content, "Test memory")
    }

    func testRetrieveNonExistentReturnsNil() async throws {
        let retrieved = try await memoryService.retrieve(id: UUID())
        XCTAssertNil(retrieved)
    }

    func testRetrieveAllWithCategoryFilter() async throws {
        try await memoryService.store(content: "Preference 1", category: .preference)
        try await memoryService.store(content: "Fact 1", category: .fact)
        try await memoryService.store(content: "Preference 2", category: .preference)

        let preferences = try await memoryService.retrieveAll(category: .preference)
        XCTAssertEqual(preferences.count, 2)

        let facts = try await memoryService.retrieveAll(category: .fact)
        XCTAssertEqual(facts.count, 1)
    }

    // MARK: - Search Tests

    func testSearchFindsMatchingContent() async throws {
        try await memoryService.store(content: "User loves programming")
        try await memoryService.store(content: "User hates bugs")
        try await memoryService.store(content: "User enjoys coffee")

        let results = try await memoryService.search(query: "programming")
        XCTAssertEqual(results.count, 1)
        XCTAssertEqual(results.first?.content, "User loves programming")
    }

    func testSearchCaseInsensitive() async throws {
        try await memoryService.store(content: "User loves Programming")

        let results = try await memoryService.search(query: "programming")
        XCTAssertEqual(results.count, 1)
    }

    func testSearchEmptyQueryReturnsEmpty() async throws {
        try await memoryService.store(content: "Test content")

        let results = try await memoryService.search(query: "   ")
        XCTAssertEqual(results.count, 0)
    }

    // MARK: - Update Tests

    func testUpdateMemory() async throws {
        try await memoryService.store(content: "Original content")
        let memories = try await memoryService.retrieveAll()
        let id = memories.first?.id

        try await memoryService.update(id: id!, content: "Updated content")

        let updated = try await memoryService.retrieve(id: id!)
        XCTAssertEqual(updated?.content, "Updated content")
    }

    func testUpdateNonExistentThrowsError() async throws {
        do {
            try await memoryService.update(id: UUID(), content: "Test")
            XCTFail("Expected error for non-existent entry")
        } catch let error as AriaError {
            switch error {
            case .invalidState:
                break // Expected
            default:
                XCTFail("Expected invalidState error, got \(error)")
            }
        } catch {
            XCTFail("Expected AriaError, got \(error)")
        }
    }

    func testUpdateEmptyContentThrowsError() async throws {
        try await memoryService.store(content: "Test")
        let memories = try await memoryService.retrieveAll()
        let id = memories.first?.id

        do {
            try await memoryService.update(id: id!, content: "   ")
            XCTFail("Expected error for empty content")
        } catch let error as AriaError {
            switch error {
            case .invalidState:
                break // Expected
            default:
                XCTFail("Expected invalidState error, got \(error)")
            }
        } catch {
            XCTFail("Expected AriaError, got \(error)")
        }
    }

    // MARK: - Delete Tests

    func testDeleteMemory() async throws {
        try await memoryService.store(content: "To be deleted")
        let memories = try await memoryService.retrieveAll()
        let id = memories.first?.id

        try await memoryService.delete(id: id!)

        let retrieved = try await memoryService.retrieve(id: id!)
        XCTAssertNil(retrieved)
    }

    func testDeleteAll() async throws {
        try await memoryService.store(content: "Memory 1")
        try await memoryService.store(content: "Memory 2")

        try await memoryService.deleteAll()

        let memories = try await memoryService.retrieveAll()
        XCTAssertEqual(memories.count, 0)
    }

    func testDeleteAllWithCategoryFilter() async throws {
        try await memoryService.store(content: "Pref 1", category: .preference)
        try await memoryService.store(content: "Fact 1", category: .fact)
        try await memoryService.store(content: "Pref 2", category: .preference)

        try await memoryService.deleteAll(category: .preference)

        let memories = try await memoryService.retrieveAll()
        XCTAssertEqual(memories.count, 1)
        XCTAssertEqual(memories.first?.category, .fact)
    }
}
