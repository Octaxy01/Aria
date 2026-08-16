import Foundation
import AriaDomain

/// In-memory implementation of RelationshipStateStoring for testing and development.
/// Not persistent - data is lost when the app terminates.
/// Can be replaced with persistent implementation in production.
public actor InMemoryRelationshipStore: RelationshipStateStoring {
    private var state: RelationshipState = RelationshipState.initial
    
    public init() {}
    
    public func load() async throws -> RelationshipState {
        return state
    }
    
    public func save(_ state: RelationshipState) async throws {
        self.state = state
    }
    
    public func reset() async throws {
        self.state = RelationshipState.initial
    }
}
