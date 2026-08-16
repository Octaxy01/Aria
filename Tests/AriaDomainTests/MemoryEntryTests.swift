import XCTest
@testable import AriaDomain

final class MemoryEntryTests: XCTestCase {
    func testMemoryEntryCreation() {
        let entry = MemoryEntry(
            content: "User prefers dark mode",
            category: .preference,
            importance: .normal
        )

        XCTAssertEqual(entry.content, "User prefers dark mode")
        XCTAssertEqual(entry.category, .preference)
        XCTAssertEqual(entry.importance, .normal)
        XCTAssertNotNil(entry.id)
        XCTAssertNotNil(entry.createdAt)
        XCTAssertNotNil(entry.lastAccessed)
    }

    func testMemoryEntryWithCustomID() {
        let customID = UUID()
        let entry = MemoryEntry(
            id: customID,
            content: "Test content",
            category: .general,
            importance: .low
        )

        XCTAssertEqual(entry.id, customID)
    }

    func testMemoryEntryCategories() {
        XCTAssertEqual(MemoryCategory.general.rawValue, "general")
        XCTAssertEqual(MemoryCategory.preference.rawValue, "preference")
        XCTAssertEqual(MemoryCategory.fact.rawValue, "fact")
        XCTAssertEqual(MemoryCategory.relationship.rawValue, "relationship")
        XCTAssertEqual(MemoryCategory.context.rawValue, "context")
    }

    func testMemoryEntryImportanceLevels() {
        XCTAssertEqual(MemoryImportance.low.rawValue, "low")
        XCTAssertEqual(MemoryImportance.normal.rawValue, "normal")
        XCTAssertEqual(MemoryImportance.high.rawValue, "high")
        XCTAssertEqual(MemoryImportance.critical.rawValue, "critical")
    }

    func testMemoryEntryEquality() {
        let id = UUID()
        let timestamp = Date()
        let entry1 = MemoryEntry(
            id: id,
            content: "Same content",
            category: .general,
            importance: .normal,
            createdAt: timestamp,
            lastAccessed: timestamp
        )
        let entry2 = MemoryEntry(
            id: id,
            content: "Same content",
            category: .general,
            importance: .normal,
            createdAt: timestamp,
            lastAccessed: timestamp
        )

        XCTAssertEqual(entry1, entry2)
    }

    func testMemoryEntryInequality() {
        let entry1 = MemoryEntry(content: "Content 1")
        let entry2 = MemoryEntry(content: "Content 2")

        XCTAssertNotEqual(entry1, entry2)
    }
}
