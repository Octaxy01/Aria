import XCTest
@testable import AriaInfrastructure
import AriaDomain

final class GeminiProviderParsingTests: XCTestCase {
    private func envelopeData(innerJSONText: String?) throws -> Data {
        var candidate: [String: Any] = [:]
        if let innerJSONText {
            candidate = ["content": ["parts": [["text": innerJSONText]]]]
        }
        let envelope: [String: Any] = innerJSONText == nil ? ["candidates": []] : ["candidates": [candidate]]
        return try JSONSerialization.data(withJSONObject: envelope)
    }

    func testParseResponseExtractsTextAndEmotion() throws {
        let inner = #"{"text":"Hmph... fine.","emotion":{"kind":"affectionate","intensity":0.65}}"#
        let data = try envelopeData(innerJSONText: inner)

        let response = try GeminiProvider.parseResponse(data)

        XCTAssertEqual(response.text, "Hmph... fine.")
        XCTAssertEqual(response.emotionSignal?.emotion, .affectionate)
        XCTAssertEqual(response.emotionSignal?.intensity ?? -1, 0.65, accuracy: 0.0001)
    }

    func testParseResponseWithoutEmotionFieldYieldsNilSignal() throws {
        let inner = #"{"text":"just text, no mood"}"#
        let data = try envelopeData(innerJSONText: inner)

        let response = try GeminiProvider.parseResponse(data)

        XCTAssertEqual(response.text, "just text, no mood")
        XCTAssertNil(response.emotionSignal)
    }

    func testParseResponseWithUnknownEmotionKindYieldsNilSignalNotCrash() throws {
        let inner = #"{"text":"ok","emotion":{"kind":"totally_made_up","intensity":0.5}}"#
        let data = try envelopeData(innerJSONText: inner)

        let response = try GeminiProvider.parseResponse(data)

        XCTAssertEqual(response.text, "ok")
        XCTAssertNil(response.emotionSignal)
    }

    func testParseResponseWithMalformedInnerJSONThrowsDecodingFailed() throws {
        let data = try envelopeData(innerJSONText: "{not valid json at all")

        XCTAssertThrowsError(try GeminiProvider.parseResponse(data)) { error in
            XCTAssertEqual(error as? GeminiProviderError, .decodingFailed)
        }
    }

    func testParseResponseWithNoCandidatesThrowsEmptyResponse() throws {
        let data = try envelopeData(innerJSONText: nil)

        XCTAssertThrowsError(try GeminiProvider.parseResponse(data)) { error in
            XCTAssertEqual(error as? GeminiProviderError, .emptyResponse)
        }
    }

    func testParseResponseWithGarbageEnvelopeThrowsDecodingFailed() {
        let data = Data("not even json".utf8)

        XCTAssertThrowsError(try GeminiProvider.parseResponse(data)) { error in
            XCTAssertEqual(error as? GeminiProviderError, .decodingFailed)
        }
    }
}

final class GeminiProviderValidationTests: XCTestCase {
    func testSuccessStatusCodesDoNotThrow() throws {
        try GeminiProvider.validate(statusCode: 200, body: Data())
        try GeminiProvider.validate(statusCode: 204, body: Data())
    }

    func testAuthFailureStatusCodesThrowAuthenticationFailed() {
        for code in [401, 403] {
            XCTAssertThrowsError(try GeminiProvider.validate(statusCode: code, body: Data())) { error in
                XCTAssertEqual(error as? GeminiProviderError, .authenticationFailed(statusCode: code))
            }
        }
    }

    func testRateLimitStatusCodeThrowsRateLimited() {
        XCTAssertThrowsError(try GeminiProvider.validate(statusCode: 429, body: Data())) { error in
            XCTAssertEqual(error as? GeminiProviderError, .rateLimited)
        }
    }

    func testServerErrorStatusCodesThrowServerError() {
        XCTAssertThrowsError(try GeminiProvider.validate(statusCode: 503, body: Data())) { error in
            XCTAssertEqual(error as? GeminiProviderError, .serverError(statusCode: 503))
        }
    }

    func testOtherErrorStatusCodesThrowHTTPError() {
        let body = Data(#"{"error":"teapot"}"#.utf8)
        XCTAssertThrowsError(try GeminiProvider.validate(statusCode: 418, body: body)) { error in
            XCTAssertEqual(error as? GeminiProviderError, .httpError(statusCode: 418, body: #"{"error":"teapot"}"#))
        }
    }
}

final class GeminiProviderRequestBuildingTests: XCTestCase {
    func testBuildURLRequestIncludesModelAndAPIKeyHeader() throws {
        let configuration = try GeminiConfiguration.make(apiKey: "secret-key", model: "gemini-2.5-flash")
        let request = LLMRequest(
            messages: [ConversationMessage(role: .user, content: "hi")],
            systemContext: "You are Aria."
        )

        let urlRequest = try GeminiProvider.buildURLRequest(for: request, configuration: configuration)

        XCTAssertEqual(urlRequest.httpMethod, "POST")
        XCTAssertEqual(urlRequest.value(forHTTPHeaderField: "x-goog-api-key"), "secret-key")
        XCTAssertTrue(urlRequest.url?.absoluteString.contains("gemini-2.5-flash:generateContent") ?? false)

        let bodyData = try XCTUnwrap(urlRequest.httpBody)
        let body = try XCTUnwrap(JSONSerialization.jsonObject(with: bodyData) as? [String: Any])

        XCTAssertNotNil(body["systemInstruction"])
        let generationConfig = try XCTUnwrap(body["generationConfig"] as? [String: Any])
        XCTAssertEqual(generationConfig["responseMimeType"] as? String, "application/json")

        let contents = try XCTUnwrap(body["contents"] as? [[String: Any]])
        XCTAssertEqual(contents.count, 1)
        XCTAssertEqual(contents[0]["role"] as? String, "user")
    }

    func testBuildURLRequestOmitsSystemInstructionWhenNil() throws {
        let configuration = try GeminiConfiguration.make(apiKey: "secret-key", model: "gemini-2.5-flash")
        let request = LLMRequest(messages: [], systemContext: nil)

        let urlRequest = try GeminiProvider.buildURLRequest(for: request, configuration: configuration)
        let bodyData = try XCTUnwrap(urlRequest.httpBody)
        let body = try XCTUnwrap(JSONSerialization.jsonObject(with: bodyData) as? [String: Any])

        XCTAssertNil(body["systemInstruction"])
    }

    func testBuildURLRequestMapsAssistantRoleToModel() throws {
        let configuration = try GeminiConfiguration.make(apiKey: "secret-key", model: "gemini-2.5-flash")
        let request = LLMRequest(
            messages: [ConversationMessage(role: .assistant, content: "hello")],
            systemContext: nil
        )

        let urlRequest = try GeminiProvider.buildURLRequest(for: request, configuration: configuration)
        let bodyData = try XCTUnwrap(urlRequest.httpBody)
        let body = try XCTUnwrap(JSONSerialization.jsonObject(with: bodyData) as? [String: Any])
        let contents = try XCTUnwrap(body["contents"] as? [[String: Any]])

        XCTAssertEqual(contents[0]["role"] as? String, "model")
    }
}
