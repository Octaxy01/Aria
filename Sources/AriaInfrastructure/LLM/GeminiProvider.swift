import Foundation
import AriaDomain

/// Real implementation of `LLMResponding` backed by the Gemini API's
/// `generateContent` REST endpoint, called directly via `URLSession`
/// (no Gemini SDK dependency — keeps this provider replaceable).
///
/// Everything Gemini-specific (endpoint shape, request/response JSON,
/// API key header, model name) lives entirely in this file and
/// `GeminiConfiguration`/`GeminiProviderError`. `AssistantCoordinator`
/// only ever sees `LLMRequest` in, `LLMResponse` out.
public struct GeminiProvider: LLMResponding {
    private let configuration: GeminiConfiguration
    private let session: URLSession
    private let logger: any Logging

    public init(configuration: GeminiConfiguration, session: URLSession = .shared, logger: any Logging) {
        self.configuration = configuration
        self.session = session
        self.logger = logger
    }

    public func respond(to request: LLMRequest) async throws -> LLMResponse {
        let urlRequest = try Self.buildURLRequest(for: request, configuration: configuration)

        let data: Data
        let response: URLResponse
        do {
            (data, response) = try await session.data(for: urlRequest)
        } catch let urlError as URLError {
            logger.error("Gemini network failure: \(urlError.code)")
            throw GeminiProviderError.network(urlError)
        } catch {
            logger.error("Gemini network failure (non-URLError): \(error)")
            throw GeminiProviderError.network(URLError(.unknown))
        }

        guard let httpResponse = response as? HTTPURLResponse else {
            throw GeminiProviderError.invalidResponse
        }

        try Self.validate(statusCode: httpResponse.statusCode, body: data)

        return try Self.parseResponse(data)
    }

    // MARK: - Request building

    /// Internal (not private) so it can be exercised directly by tests
    /// without making a real network call.
    static func buildURLRequest(for request: LLMRequest, configuration: GeminiConfiguration) throws -> URLRequest {
        let url = configuration.baseURL.appendingPathComponent("models/\(configuration.model):generateContent")

        var urlRequest = URLRequest(url: url, timeoutInterval: configuration.timeout)
        urlRequest.httpMethod = "POST"
        urlRequest.setValue("application/json", forHTTPHeaderField: "Content-Type")
        urlRequest.setValue(configuration.apiKey, forHTTPHeaderField: "x-goog-api-key")

        let contents: [[String: Any]] = request.messages.compactMap { message in
            let role: String
            switch message.role {
            case .user: role = "user"
            case .assistant: role = "model"
            case .system: return nil // carried via systemInstruction instead
            }
            return ["role": role, "parts": [["text": message.content]]]
        }

        let generationConfig: [String: Any] = [
            "temperature": configuration.temperature,
            "responseMimeType": "application/json",
            "responseSchema": responseSchema
        ]

        var body: [String: Any] = [
            "contents": contents,
            "generationConfig": generationConfig
        ]

        if let systemContext = request.systemContext, !systemContext.isEmpty {
            body["systemInstruction"] = ["parts": [["text": systemContext]]]
        }

        urlRequest.httpBody = try JSONSerialization.data(withJSONObject: body)
        return urlRequest
    }

    /// JSON schema constraining Gemini's structured output to
    /// `{ "text": string, "emotion": { "kind": <EmotionKind>, "intensity": number } }`.
    /// `emotion` is optional so a valid reply without a mood is still
    /// schema-valid (the app already handles `emotionSignal == nil`).
    private static var responseSchema: [String: Any] {
        let emotionKindProperty: [String: Any] = [
            "type": "string",
            "enum": EmotionKind.allCases.map(\.rawValue)
        ]

        let emotionProperty: [String: Any] = [
            "type": "object",
            "properties": [
                "kind": emotionKindProperty,
                "intensity": ["type": "number"]
            ],
            "required": ["kind", "intensity"]
        ]

        let properties: [String: Any] = [
            "text": ["type": "string"],
            "emotion": emotionProperty
        ]

        return [
            "type": "object",
            "properties": properties,
            "required": ["text"]
        ]
    }

    // MARK: - Response validation & parsing

    static func validate(statusCode: Int, body: Data) throws {
        switch statusCode {
        case 200...299:
            return
        case 401, 403:
            throw GeminiProviderError.authenticationFailed(statusCode: statusCode)
        case 429:
            throw GeminiProviderError.rateLimited
        case 500...599:
            throw GeminiProviderError.serverError(statusCode: statusCode)
        default:
            let bodyText = String(data: body, encoding: .utf8) ?? ""
            throw GeminiProviderError.httpError(statusCode: statusCode, body: bodyText)
        }
    }

    /// Gemini's outer response envelope. Only the fields Stage 2 needs.
    private struct APIResponse: Decodable {
        struct Candidate: Decodable {
            struct Content: Decodable {
                struct Part: Decodable {
                    let text: String?
                }
                let parts: [Part]?
            }
            let content: Content?
        }
        let candidates: [Candidate]?
    }

    /// The JSON *string* Gemini produces inside that envelope, matching
    /// `responseSchema` above.
    private struct StructuredOutput: Decodable {
        struct Emotion: Decodable {
            let kind: String
            let intensity: Double
        }
        let text: String
        let emotion: Emotion?
    }

    /// Never force-unwraps, never crashes, never treats a malformed
    /// payload as valid. Any failure here becomes a typed
    /// `GeminiProviderError` — application state is never touched with
    /// partial/invalid data.
    static func parseResponse(_ data: Data) throws -> LLMResponse {
        let envelope: APIResponse
        do {
            envelope = try JSONDecoder().decode(APIResponse.self, from: data)
        } catch {
            throw GeminiProviderError.decodingFailed
        }

        guard let innerText = envelope.candidates?.first?.content?.parts?.first?.text,
              !innerText.isEmpty else {
            throw GeminiProviderError.emptyResponse
        }

        guard let innerData = innerText.data(using: .utf8) else {
            throw GeminiProviderError.decodingFailed
        }

        let structured: StructuredOutput
        do {
            structured = try JSONDecoder().decode(StructuredOutput.self, from: innerData)
        } catch {
            throw GeminiProviderError.decodingFailed
        }

        let signal: EmotionSignal?
        if let emotion = structured.emotion, let kind = EmotionKind(rawValue: emotion.kind) {
            signal = EmotionSignal(emotion: kind, intensity: emotion.intensity)
        } else {
            signal = nil
        }

        return LLMResponse(text: structured.text, emotionSignal: signal)
    }
}
