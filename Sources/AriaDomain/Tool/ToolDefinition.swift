import Foundation

/// Complete definition for a tool available to Aria.
/// Describes what the tool does, its risk level, required parameters, and permission requirements.
/// This is metadata only - execution logic lives in Infrastructure layer implementations.
public struct ToolDefinition: Sendable, Equatable {
    /// Stable identifier for this tool.
    public let identifier: ToolIdentifier
    
    /// Human-readable description of what this tool does.
    /// This will be used for LLM tool schemas and user-facing explanations.
    public let description: String
    
    /// Risk classification for permission policy and user confirmation requirements.
    public let riskLevel: ToolRiskLevel
    
    /// Parameters required by this tool.
    /// Empty array if the tool requires no parameters.
    public let parameters: [ToolParameter]
    
    /// Whether this tool requires explicit user confirmation before execution.
    /// Typically true for sensitive/destructive tools, false for safe tools.
    public let requiresConfirmation: Bool
    
    /// Optional category for grouping related tools.
    public let category: ToolCategory?
    
    public init(
        identifier: ToolIdentifier,
        description: String,
        riskLevel: ToolRiskLevel,
        parameters: [ToolParameter] = [],
        requiresConfirmation: Bool = false,
        category: ToolCategory? = nil
    ) {
        self.identifier = identifier
        self.description = description
        self.riskLevel = riskLevel
        self.parameters = parameters
        self.requiresConfirmation = requiresConfirmation
        self.category = category
    }
}

/// Definition for a single parameter that a tool accepts.
public struct ToolParameter: Sendable, Equatable {
    /// Parameter name (will be used as key in arguments dictionary).
    public let name: String
    
    /// Human-readable description of this parameter.
    public let description: String
    
    /// Whether this parameter is required for tool execution.
    public let isRequired: Bool
    
    /// Expected type of this parameter.
    public let type: ToolParameterType
    
    public init(name: String, description: String, isRequired: Bool, type: ToolParameterType) {
        self.name = name
        self.description = description
        self.isRequired = isRequired
        self.type = type
    }
}

/// Expected type for a tool parameter.
public enum ToolParameterType: String, Sendable, Equatable {
    case string
    case integer
    case boolean
    case array
    case object
}

/// Category for grouping related tools.
public enum ToolCategory: String, Sendable, Equatable {
    case application
    case file
    case system
    case network
}

/// Legacy permission tier - retained for compatibility with existing AriaError.
/// New code should prefer ToolRiskLevel for more granular classification.
public enum ToolPermission: String, Sendable, Equatable {
    case readOnly
    case requiresConfirmation
}
