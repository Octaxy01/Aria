import Foundation
import AriaDomain

/// Registry for managing available tool definitions.
/// Responsible for tool discovery, registration, and lookup - not execution.
/// Thread-safe through actor isolation.
public actor ToolRegistry {
    private var tools: [ToolIdentifier: ToolDefinition] = [:]
    
    public init() {}
    
    /// Registers a tool definition in the registry.
    /// - Parameter definition: The tool definition to register
    /// - Throws: RegistrationError if a tool with the same identifier already exists
    public func register(_ definition: ToolDefinition) throws {
        if tools[definition.identifier] != nil {
            throw RegistrationError.duplicateIdentifier(definition.identifier.rawValue)
        }
        tools[definition.identifier] = definition
    }
    
    /// Retrieves a tool definition by identifier.
    /// - Parameter identifier: The tool identifier to look up
    /// - Returns: The tool definition if found, nil otherwise
    public func tool(for identifier: ToolIdentifier) -> ToolDefinition? {
        tools[identifier]
    }
    
    /// Checks whether a tool with the given identifier exists.
    /// - Parameter identifier: The tool identifier to check
    /// - Returns: True if the tool exists, false otherwise
    public func hasTool(_ identifier: ToolIdentifier) -> Bool {
        tools[identifier] != nil
    }
    
    /// Returns all registered tool definitions.
    /// - Returns: Array of all registered tool definitions
    public func allTools() -> [ToolDefinition] {
        Array(tools.values)
    }
    
    /// Returns all tool identifiers.
    /// - Returns: Array of all registered tool identifiers
    public func allIdentifiers() -> [ToolIdentifier] {
        Array(tools.keys)
    }
    
    /// Returns tools filtered by category.
    /// - Parameter category: The category to filter by
    /// - Returns: Array of tool definitions in the specified category
    public func tools(inCategory category: ToolCategory) -> [ToolDefinition] {
        tools.values.filter { $0.category == category }
    }
    
    /// Returns tools filtered by risk level.
    /// - Parameter riskLevel: The risk level to filter by
    /// - Returns: Array of tool definitions with the specified risk level
    public func tools(withRiskLevel riskLevel: ToolRiskLevel) -> [ToolDefinition] {
        tools.values.filter { $0.riskLevel == riskLevel }
    }
    
    /// Removes a tool from the registry.
    /// - Parameter identifier: The tool identifier to remove
    /// - Returns: The removed tool definition if found, nil otherwise
    @discardableResult
    public func unregister(_ identifier: ToolIdentifier) -> ToolDefinition? {
        tools.removeValue(forKey: identifier)
    }
    
    /// Clears all tools from the registry.
    public func clear() {
        tools.removeAll()
    }
}

/// Errors that can occur during tool registration.
public enum RegistrationError: Error, Equatable {
    case duplicateIdentifier(String)
}