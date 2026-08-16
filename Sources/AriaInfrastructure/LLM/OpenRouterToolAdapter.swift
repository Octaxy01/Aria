import Foundation
import AriaDomain

/// Adapter for translating between Aria's tool system and OpenRouter's function calling format.
/// This isolates provider-specific details from the core architecture.
public struct OpenRouterToolAdapter: Sendable {
    
    public init() {}
    
    /// Converts Aria ToolDefinition to OpenRouter function schema format.
    /// - Parameter definitions: Aria tool definitions to convert
    /// - Returns: Array of OpenRouter-compatible function schemas
    public func convertToProviderSchemas(_ definitions: [ToolDefinition]) -> [[String: Any]] {
        return definitions.map { definition in
            var function: [String: Any] = [
                "name": definition.identifier.rawValue,
                "description": definition.description
            ]
            
            // Add parameters if any exist
            if !definition.parameters.isEmpty {
                function["parameters"] = buildParametersSchema(definition.parameters)
            }
            
            return function
        }
    }
    
    /// Builds the parameters schema for a tool definition.
    /// - Parameter parameters: Tool parameters to convert
    /// - Returns: OpenAI-compatible parameters schema
    private func buildParametersSchema(_ parameters: [ToolParameter]) -> [String: Any] {
        var properties: [String: Any] = [:]
        var required: [String] = []
        
        for parameter in parameters {
            properties[parameter.name] = [
                "type": convertParameterType(parameter.type),
                "description": parameter.description
            ]
            
            if parameter.isRequired {
                required.append(parameter.name)
            }
        }
        
        return [
            "type": "object",
            "properties": properties,
            "required": required
        ]
    }
    
    /// Converts Aria ToolParameterType to OpenAI JSON schema type.
    /// - Parameter type: Aria parameter type
    /// - Returns: OpenAI-compatible type string
    private func convertParameterType(_ type: ToolParameterType) -> String {
        switch type {
        case .string:
            return "string"
        case .integer:
            return "integer"
        case .boolean:
            return "boolean"
        case .array:
            return "array"
        case .object:
            return "object"
        }
    }
    
    /// Parses OpenRouter tool calls from API response.
    /// - Parameter toolCalls: OpenRouter tool call objects
    /// - Parameter sessionID: Current session ID for validation
    /// - Returns: Array of Aria ToolCall objects
    /// - Throws: ToolCallParseError if parsing fails
    public func parseToolCalls(_ toolCalls: [[String: Any]], sessionID: UUID) throws -> [ToolCall] {
        return try toolCalls.map { toolCall in
            guard let functionName = toolCall["function"] as? [String: Any],
                  let name = functionName["name"] as? String else {
                throw ToolCallParseError.missingToolName
            }
            
            let identifier = ToolIdentifier(name)
            
            var arguments: [String: Sendable] = [:]
            if let argumentsString = functionName["arguments"] as? String {
                // Parse JSON arguments string
                if let argumentsData = argumentsString.data(using: .utf8),
                   let parsedArguments = try? JSONSerialization.jsonObject(with: argumentsData) as? [String: Any] {
                    arguments = parsedArguments
                } else {
                    throw ToolCallParseError.invalidArguments
                }
            } else if let argumentsDict = functionName["arguments"] as? [String: Any] {
                arguments = argumentsDict
            }
            
            return ToolCall(
                toolIdentifier: identifier,
                arguments: arguments,
                sessionID: sessionID
            )
        }
    }
    
    /// Converts Aria ToolResult to OpenRouter tool result format.
    /// - Parameter result: Aria tool result to convert
    /// - Parameter toolCallID: Original tool call ID for correlation
    /// - Returns: OpenRouter-compatible tool result message
    public func convertToolResult(_ result: ToolResult, toolCallID: String) -> [String: Any] {
        let toolResult: [String: Any] = [
            "tool_call_id": toolCallID,
            "content": resultToContent(result)
        ]
        
        return toolResult
    }
    
    /// Converts ToolResult to content string.
    /// - Parameter result: Tool result to convert
    /// - Returns: JSON string representation
    private func resultToContent(_ result: ToolResult) -> String {
        var content: [String: Any] = [:]
        
        if result.success {
            content["success"] = true
            if let data = result.data {
                content["data"] = data
            }
        } else {
            content["success"] = false
            if let error = result.error {
                content["error"] = error
            }
            if let errorCode = result.errorCode {
                content["errorCode"] = errorCode
            }
        }
        
        if let jsonData = try? JSONSerialization.data(withJSONObject: content),
           let jsonString = String(data: jsonData, encoding: .utf8) {
            return jsonString
        }
        
        return "{}"
    }
}

/// Errors that can occur during tool call parsing.
public enum ToolCallParseError: Error, Equatable {
    case missingToolName
    case invalidArguments
    case invalidToolIdentifier(String)
}
