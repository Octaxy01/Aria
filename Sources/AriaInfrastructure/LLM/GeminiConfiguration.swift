import Foundation
import AriaDomain

/// Gemini-specific settings, resolved once from `AppConfiguration` at
/// startup. Model name, base URL, temperature, and timeout are grouped
/// here — deliberately not more than that — so no other file needs to
/// know Gemini's endpoint shape or hardcode a model name.
public struct GeminiConfiguration: Sendable, Equatable {
    public let apiKey: String
    public let model: String
    public let baseURL: URL
    public let temperature: Double
    public let timeout: TimeInterval

    public init(apiKey: String, model: String, baseURL: URL, temperature: Double, timeout: TimeInterval) {
        self.apiKey = apiKey
        self.model = model
        self.baseURL = baseURL
        self.temperature = temperature
        self.timeout = timeout
    }

    /// The only entry point that should construct a `GeminiConfiguration`.
    /// Fails clearly and immediately (no network call needed) if the API
    /// key is missing/blank — this is what satisfies "GeminiProvider
    /// fails clearly if the API key isn't available" without needing
    /// network access to prove it in a test.
    public static func make(
        apiKey: String?,
        model: String,
        baseURL: URL = URL(string: "https://generativelanguage.googleapis.com/v1beta")!,
        temperature: Double = 0.8,
        timeout: TimeInterval = 30
    ) throws -> GeminiConfiguration {
        guard let apiKey, !apiKey.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty else {
            throw AriaError.configurationMissing(key: "GEMINI_API_KEY")
        }
        return GeminiConfiguration(apiKey: apiKey, model: model, baseURL: baseURL, temperature: temperature, timeout: timeout)
    }
}
