import Foundation

/// Gemini/HTTP-specific failure categories. These stay in Infrastructure
/// — `AssistantCoordinator` never sees this type, it only sees whatever
/// `Error` came out of `LLMResponding.respond(to:)` and maps it to
/// `AriaError.llmProviderFailure(reason:)`. Keeping this enum typed
/// (instead of stringly-matching HTTP status text) is what lets that
/// mapping happen without string inspection anywhere.
public enum GeminiProviderError: Error, Sendable, Equatable {
    case network(URLError)
    case invalidResponse
    case authenticationFailed(statusCode: Int)
    case rateLimited
    case serverError(statusCode: Int)
    case httpError(statusCode: Int, body: String)
    case emptyResponse
    case decodingFailed
}
