import XCTest
@testable import AriaInfrastructure
import AriaDomain

final class GeminiConfigurationTests: XCTestCase {
    func testMakeThrowsConfigurationMissingWhenAPIKeyIsNil() {
        XCTAssertThrowsError(
            try GeminiConfiguration.make(apiKey: nil, model: "gemini-2.5-flash")
        ) { error in
            guard let ariaError = error as? AriaError,
                  case .configurationMissing(let key) = ariaError else {
                XCTFail("expected AriaError.configurationMissing, got \(error)")
                return
            }
            XCTAssertEqual(key, "GEMINI_API_KEY")
        }
    }

    func testMakeThrowsConfigurationMissingWhenAPIKeyIsBlank() {
        XCTAssertThrowsError(
            try GeminiConfiguration.make(apiKey: "   ", model: "gemini-2.5-flash")
        )
    }

    func testMakeSucceedsWithValidAPIKey() throws {
        let configuration = try GeminiConfiguration.make(apiKey: "test-key", model: "gemini-2.5-flash")
        XCTAssertEqual(configuration.apiKey, "test-key")
        XCTAssertEqual(configuration.model, "gemini-2.5-flash")
    }
}
