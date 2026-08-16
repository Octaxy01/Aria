import Foundation

public enum OpenRouterProviderError: Error, Sendable, Equatable {
    case network
    case invalidResponse
    case authenticationFailed
    case rateLimited
    case serverError
    case decodingFailed
    case emptyResponse
    case httpError(statusCode: Int, body: String)
}
