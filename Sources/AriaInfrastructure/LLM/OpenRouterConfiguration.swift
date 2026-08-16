import Foundation

public struct OpenRouterConfiguration: Sendable, Equatable {
    public let apiKey: String
    public let model: String
    public let baseURL: URL
    public let temperature: Double
    public let timeout: TimeInterval

    public init(
        apiKey: String,
        model: String,
        baseURL: URL = URL(string: "https://openrouter.ai/api/v1")!,
        temperature: Double = 0.8,
        timeout: TimeInterval = 60
    ) {
        self.apiKey = apiKey
        self.model = model
        self.baseURL = baseURL
        self.temperature = temperature
        self.timeout = timeout
    }

    public static func make(
        apiKey: String?,
        model: String,
        baseURL: URL = URL(string: "https://openrouter.ai/api/v1")!,
        temperature: Double = 0.8,
        timeout: TimeInterval = 60
    ) throws -> OpenRouterConfiguration {
        guard let apiKey,
              !apiKey.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty
        else {
            throw OpenRouterConfigurationError.apiKeyMissing
        }

        return OpenRouterConfiguration(
            apiKey: apiKey,
            model: model,
            baseURL: baseURL,
            temperature: temperature,
            timeout: timeout
        )
    }
}

public enum OpenRouterConfigurationError: Error, Sendable, Equatable {
    case apiKeyMissing
}
