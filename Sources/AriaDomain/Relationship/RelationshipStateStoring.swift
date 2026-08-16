import Foundation

/// Protocol for relationship state persistence operations.
/// Infrastructure layer provides concrete implementations (in-memory, file-based, etc.).
/// Application layer uses this protocol without knowing storage details.
public protocol RelationshipStateStoring: Sendable {
    /// Load the current relationship state.
    func load() async throws -> RelationshipState
    
    /// Save the relationship state.
    func save(_ state: RelationshipState) async throws
    
    /// Reset the relationship state to initial values.
    func reset() async throws
}
