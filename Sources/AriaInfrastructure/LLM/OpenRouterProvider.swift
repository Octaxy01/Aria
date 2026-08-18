import Foundation
import AriaDomain

public struct OpenRouterProvider: LLMResponding {
    private let configuration: OpenRouterConfiguration
    private let session: URLSession
    private let logger: any Logging
    private let toolAdapter: OpenRouterToolAdapter

    private let fallbackModels = [
        "openai/gpt-oss-20b:free",
        "google/gemma-4-31b-it:free",
        "google/gemma-4-26b-a4b-it:free",
        "nvidia/nemotron-3-super-120b-a12b:free",
        "nvidia/nemotron-3-nano-30b-a3b-reasoning:free",
        "nvidia/nemotron-3-nano-30b-a3b:free"
    ]

    public init(
        configuration: OpenRouterConfiguration,
        session: URLSession = .shared,
        logger: any Logging
    ) {
        self.configuration = configuration
        self.session = session
        self.logger = logger
        self.toolAdapter = OpenRouterToolAdapter()
    }

    public func respond(to request: LLMRequest) async throws -> LLMResponse {
        var models: [String] = []

        if !configuration.model.isEmpty {
            models.append(configuration.model)
        }

        for model in fallbackModels where !models.contains(model) {
            models.append(model)
        }

        var lastError: Error?

        for model in models {
            do {
                logger.info("OpenRouter trying model: \(model)")

                return try await requestModel(
                    model: model,
                    request: request
                )
            } catch {
                lastError = error

                logger.warning(
                    "OpenRouter model failed: \(model) — \(error)"
                )
            }
        }

        throw lastError ?? OpenRouterProviderError.emptyResponse
    }

    private func requestModel(
        model: String,
        request: LLMRequest
    ) async throws -> LLMResponse {

        let url = configuration.baseURL
            .appendingPathComponent("chat/completions")

        var urlRequest = URLRequest(
            url: url,
            timeoutInterval: configuration.timeout
        )

        urlRequest.httpMethod = "POST"

        urlRequest.setValue(
            "Bearer \(configuration.apiKey)",
            forHTTPHeaderField: "Authorization"
        )

        urlRequest.setValue(
            "application/json",
            forHTTPHeaderField: "Content-Type"
        )

        urlRequest.setValue(
            "https://aria.app",
            forHTTPHeaderField: "HTTP-Referer"
        )

        urlRequest.setValue(
            "Aria",
            forHTTPHeaderField: "X-OpenRouter-Title"
        )

        var messages: [[String: Any]] = []

        if let systemContext = request.systemContext,
           !systemContext.isEmpty {

            messages.append([
                "role": "system",
                "content": systemContext
            ])
        }

        for message in request.messages {
            let role: String

            switch message.role {
            case .user:
                role = "user"

            case .assistant:
                role = "assistant"

            case .system:
                continue
            
            case .toolResult:
                // Tool results are sent as assistant messages with tool result content
                role = "assistant"
            }

            messages.append([
                "role": role,
                "content": message.content
            ])
        }

        var body: [String: Any] = [
            "model": model,
            "messages": messages,
            "temperature": configuration.temperature,
            "max_tokens": 300  // Reduced from 512 to encourage concise responses
        ]
        
        // Add tool definitions if provided
        if let toolDefinitions = request.toolDefinitions, !toolDefinitions.isEmpty {
            body["tools"] = toolAdapter.convertToProviderSchemas(toolDefinitions)
            body["tool_choice"] = "auto"  // Let the model decide when to use tools
        }

        urlRequest.httpBody = try JSONSerialization.data(
            withJSONObject: body
        )

        let data: Data
        let response: URLResponse

        do {
            (data, response) = try await session.data(
                for: urlRequest
            )
        } catch {
            throw OpenRouterProviderError.network
        }

        guard let httpResponse = response as? HTTPURLResponse else {
            throw OpenRouterProviderError.invalidResponse
        }

        let bodyText = String(
            data: data,
            encoding: .utf8
        ) ?? ""

        guard (200...299).contains(httpResponse.statusCode) else {
            logger.warning(
                "OpenRouter HTTP \(httpResponse.statusCode): \(bodyText)"
            )

            switch httpResponse.statusCode {
            case 401, 403:
                throw OpenRouterProviderError.authenticationFailed

            case 429:
                throw OpenRouterProviderError.rateLimited

            case 500...599:
                throw OpenRouterProviderError.serverError

            default:
                throw OpenRouterProviderError.httpError(
                    statusCode: httpResponse.statusCode,
                    body: bodyText
                )
            }
        }

        return try parseResponse(data)
    }

    // MARK: - OpenRouter response

    private struct APIResponse: Decodable {
        struct Choice: Decodable {
            struct Message: Decodable {
                let role: String?
                let content: String?
                let tool_calls: [ProviderToolCall]?
            }

            let message: Message?
            let finish_reason: String?
        }

        let choices: [Choice]?
    }
    
    /// OpenRouter/OpenAI-compatible tool call structure
    private struct ProviderToolCall: Decodable {
        let id: String
        let type: String
        let function: FunctionCall
        
        struct FunctionCall: Decodable {
            let name: String
            let arguments: String
        }
    }

    // MARK: - Aria structured response

    private struct AriaStructuredResponse: Decodable {
        struct Emotion: Decodable {
            let kind: String
            let intensity: Double
        }

        let text: String
        let emotion: Emotion?
    }

    // MARK: - JSON extraction helpers

    private func extractJSON(from text: String) -> Data? {
        // Try direct JSON first
        if let data = text.data(using: .utf8),
           (try? JSONSerialization.jsonObject(with: data)) != nil {
            return data
        }

        // Try markdown code blocks
        if text.hasPrefix("```") {
            var stripped = text
            stripped = stripped.replacingOccurrences(of: "```json", with: "")
            stripped = stripped.replacingOccurrences(of: "```JSON", with: "")
            stripped = stripped.replacingOccurrences(of: "```", with: "")
            stripped = stripped.trimmingCharacters(in: .whitespacesAndNewlines)
            
            if let data = stripped.data(using: .utf8),
               (try? JSONSerialization.jsonObject(with: data)) != nil {
                return data
            }
        }

        // Try to find JSON object patterns in mixed content (simple bracket matching)
        if let startIndex = text.firstIndex(of: "{"),
           let endIndex = text.lastIndex(of: "}") {
            let possibleJSON = String(text[startIndex...endIndex])
            if let data = possibleJSON.data(using: .utf8),
               (try? JSONSerialization.jsonObject(with: data)) != nil {
                return data
            }
        }

        return nil
    }

    private func parseResponse(_ data: Data) throws -> LLMResponse {
        let envelope: APIResponse

        do {
            envelope = try JSONDecoder().decode(
                APIResponse.self,
                from: data
            )
        } catch {
            throw OpenRouterProviderError.decodingFailed
        }

        guard let choice = envelope.choices?.first else {
            throw OpenRouterProviderError.emptyResponse
        }
        
        let message = choice.message
        
        // Check for tool calls first
        if let toolCalls = message?.tool_calls, !toolCalls.isEmpty {
            // Parse tool calls using the adapter
            let providerToolCalls = toolCalls.map { toolCall in
                [
                    "id": toolCall.id,
                    "type": toolCall.type,
                    "function": [
                        "name": toolCall.function.name,
                        "arguments": toolCall.function.arguments
                    ]
                ]
            }
            
            // Generate a session ID for this request (will be replaced by AssistantCoordinator)
            let sessionID = UUID()
            
            do {
                let ariaToolCalls = try toolAdapter.parseToolCalls(providerToolCalls, sessionID: sessionID)
                
                // Return response with tool calls
                // Content may be null or empty when tool calls are present
                let content = message?.content ?? ""
                return LLMResponse(
                    text: content,
                    emotionSignal: nil,
                    toolCalls: ariaToolCalls
                )
            } catch {
                logger.warning("Failed to parse tool calls: \(error)")
                // Fall through to treat as normal response
            }
        }

        // Normal text response
        guard let content = message?.content,
              !content.trimmingCharacters(
                in: .whitespacesAndNewlines
              ).isEmpty
        else {
            throw OpenRouterProviderError.emptyResponse
        }

        let cleanedContent = content.trimmingCharacters(
            in: .whitespacesAndNewlines
        )

        // Try to extract JSON from various formats
        let extractedJSON = extractJSON(from: cleanedContent)
        
        if let jsonData = extractedJSON {
            do {
                let structured = try JSONDecoder().decode(
                    AriaStructuredResponse.self,
                    from: jsonData
                )

                let signal: EmotionSignal?

                if let emotion = structured.emotion,
                   let kind = EmotionKind(
                    rawValue: emotion.kind
                   ) {

                    signal = EmotionSignal(
                        emotion: kind,
                        intensity: emotion.intensity
                    )
                } else {
                    signal = nil
                }

                return LLMResponse(
                    text: structured.text.trimmingCharacters(
                        in: .whitespacesAndNewlines
                    ),
                    emotionSignal: signal
                )
            } catch {
                // JSON parsing failed, fall through to plain text
            }
        }

        // Fallback: normal plain-text response with heuristic emotion detection.
        let detectedEmotion = EmotionTextAnalyzer.analyze(cleanedContent)
        return LLMResponse(
            text: cleanedContent,
            emotionSignal: detectedEmotion
        )
    }
}
