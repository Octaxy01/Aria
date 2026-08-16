import XCTest
@testable import AriaApplication
@testable import AriaDomain
@testable import AriaInfrastructure
import Foundation

/// Real LLM runtime validation and personality calibration tests.
/// These tests require OPENROUTER_API_KEY environment variable to be set.
/// If the API key is not available, tests will be skipped with a clear diagnostic.
final class RealLLMRuntimeValidationTests: XCTestCase {
    
    private var coordinator: AssistantCoordinator?
    private var config: AppConfiguration?
    
    override func setUp() async throws {
        config = AppConfiguration.load()
        
        // Skip all tests if API key is not available
        guard let apiKey = config?.openRouterAPIKey, !apiKey.isEmpty else {
            throw XCTSkip("RUNTIME VALIDATION BLOCKED: OPENROUTER_API_KEY environment variable not set. Set it to enable real LLM testing.")
        }
        
        // Create real LLM provider
        let openRouterConfig = try OpenRouterConfiguration.make(
            apiKey: apiKey,
            model: config?.openRouterModel ?? "openai/gpt-oss-20b:free",
            baseURL: URL(string: "https://openrouter.ai/api/v1")!,
            temperature: config?.openRouterTemperature ?? 0.8,
            timeout: config?.openRouterRequestTimeoutSeconds ?? 60
        )
        
        let logger = ConsoleLogger(level: config?.logLevel ?? .info)
        let llm = OpenRouterProvider(configuration: openRouterConfig, logger: logger)
        
        // Create services
        let conversation = ConversationService()
        let emotionEngine = EmotionService()
        let relationshipEngine = RelationshipService()
        
        // Note: Memory services omitted for initial validation to isolate personality behavior
        coordinator = AssistantCoordinator(
            llm: llm,
            conversation: conversation,
            emotionEngine: emotionEngine,
            relationshipEngine: relationshipEngine,
            character: .aria,
            maxContextMessages: 20,
            initialEmotionState: .initial,
            initialRelationshipState: .initial,
            memoryContextBuilder: nil,
            memoryFormationService: nil
        )
    }
    
    // MARK: - Test Scenarios
    
    func test_scenario_identity() async throws {
        guard let coordinator = coordinator else { return }
        
        let startTime = Date()
        let result = try await coordinator.handleUserInput("Siapa kamu?")
        let latency = Date().timeIntervalSince(startTime)
        
        print("\n=== IDENTITY SCENARIO ===")
        print("User: Siapa kamu?")
        print("Response: \(result.reply.content)")
        print("Latency: \(String(format: "%.2f", latency))s")
        print("Tone: \(ConversationToneClassifier.classify("Siapa kamu?").rawValue)")
        print("Emotion: \(result.emotionState.current.rawValue)")
        print("=== END IDENTITY ===\n")
        
        // Basic validation
        XCTAssertFalse(result.reply.content.isEmpty, "Response should not be empty")
        XCTAssertFalse(result.reply.content.contains("Sebagai AI"), "Should not contain 'Sebagai AI'")
        XCTAssertFalse(result.reply.content.contains("Saya siap membantu"), "Should not contain assistant phrases")
    }
    
    func test_scenario_casual() async throws {
        guard let coordinator = coordinator else { return }
        
        let startTime = Date()
        let result = try await coordinator.handleUserInput("lagi apa?")
        let latency = Date().timeIntervalSince(startTime)
        
        print("\n=== CASUAL SCENARIO ===")
        print("User: lagi apa?")
        print("Response: \(result.reply.content)")
        print("Latency: \(String(format: "%.2f", latency))s")
        print("Tone: \(ConversationToneClassifier.classify("lagi apa?").rawValue)")
        print("=== END CASUAL ===\n")
        
        XCTAssertFalse(result.reply.content.isEmpty, "Response should not be empty")
    }
    
    func test_scenario_compliment() async throws {
        guard let coordinator = coordinator else { return }
        
        let startTime = Date()
        let result = try await coordinator.handleUserInput("Aria kamu lucu.")
        let latency = Date().timeIntervalSince(startTime)
        
        print("\n=== COMPLIMENT SCENARIO ===")
        print("User: Aria kamu lucu.")
        print("Response: \(result.reply.content)")
        print("Latency: \(String(format: "%.2f", latency))s")
        print("Tone: \(ConversationToneClassifier.classify("Aria kamu lucu.").rawValue)")
        print("=== END COMPLIMENT ===\n")
        
        XCTAssertFalse(result.reply.content.isEmpty, "Response should not be empty")
    }
    
    func test_scenario_affection() async throws {
        guard let coordinator = coordinator else { return }
        
        let startTime = Date()
        let result = try await coordinator.handleUserInput("Aku sayang kamu.")
        let latency = Date().timeIntervalSince(startTime)
        
        print("\n=== AFFECTION SCENARIO ===")
        print("User: Aku sayang kamu.")
        print("Response: \(result.reply.content)")
        print("Latency: \(String(format: "%.2f", latency))s")
        print("Tone: \(ConversationToneClassifier.classify("Aku sayang kamu.").rawValue)")
        print("=== END AFFECTION ===\n")
        
        XCTAssertFalse(result.reply.content.isEmpty, "Response should not be empty")
    }
    
    func test_scenario_achievement() async throws {
        guard let coordinator = coordinator else { return }
        
        let startTime = Date()
        let result = try await coordinator.handleUserInput("Aku akhirnya berhasil menyelesaikan project ini.")
        let latency = Date().timeIntervalSince(startTime)
        
        print("\n=== ACHIEVEMENT SCENARIO ===")
        print("User: Aku akhirnya berhasil menyelesaikan project ini.")
        print("Response: \(result.reply.content)")
        print("Latency: \(String(format: "%.2f", latency))s")
        print("Tone: \(ConversationToneClassifier.classify("Aku akhirnya berhasil menyelesaikan project ini.").rawValue)")
        print("=== END ACHIEVEMENT ===\n")
        
        XCTAssertFalse(result.reply.content.isEmpty, "Response should not be empty")
    }
    
    func test_scenario_emotional() async throws {
        guard let coordinator = coordinator else { return }
        
        let startTime = Date()
        let result = try await coordinator.handleUserInput("Aku capek banget hari ini.")
        let latency = Date().timeIntervalSince(startTime)
        
        print("\n=== EMOTIONAL SCENARIO ===")
        print("User: Aku capek banget hari ini.")
        print("Response: \(result.reply.content)")
        print("Latency: \(String(format: "%.2f", latency))s")
        print("Tone: \(ConversationToneClassifier.classify("Aku capek banget hari ini.").rawValue)")
        print("=== END EMOTIONAL ===\n")
        
        XCTAssertFalse(result.reply.content.isEmpty, "Response should not be empty")
    }
    
    func test_scenario_sad() async throws {
        guard let coordinator = coordinator else { return }
        
        let startTime = Date()
        let result = try await coordinator.handleUserInput("Aku lagi sedih.")
        let latency = Date().timeIntervalSince(startTime)
        
        print("\n=== SAD SCENARIO ===")
        print("User: Aku lagi sedih.")
        print("Response: \(result.reply.content)")
        print("Latency: \(String(format: "%.2f", latency))s")
        print("Tone: \(ConversationToneClassifier.classify("Aku lagi sedih.").rawValue)")
        print("=== END SAD ===\n")
        
        XCTAssertFalse(result.reply.content.isEmpty, "Response should not be empty")
    }
    
    func test_scenario_angry() async throws {
        guard let coordinator = coordinator else { return }
        
        let startTime = Date()
        let result = try await coordinator.handleUserInput("Aku kesel banget sama project ini.")
        let latency = Date().timeIntervalSince(startTime)
        
        print("\n=== ANGRY SCENARIO ===")
        print("User: Aku kesel banget sama project ini.")
        print("Response: \(result.reply.content)")
        print("Latency: \(String(format: "%.2f", latency))s")
        print("Tone: \(ConversationToneClassifier.classify("Aku kesel banget sama project ini.").rawValue)")
        print("=== END ANGRY ===\n")
        
        XCTAssertFalse(result.reply.content.isEmpty, "Response should not be empty")
    }
    
    func test_scenario_technical() async throws {
        guard let coordinator = coordinator else { return }
        
        let startTime = Date()
        let result = try await coordinator.handleUserInput("Jelaskan Swift Actor.")
        let latency = Date().timeIntervalSince(startTime)
        
        print("\n=== TECHNICAL SCENARIO ===")
        print("User: Jelaskan Swift Actor.")
        print("Response: \(result.reply.content)")
        print("Latency: \(String(format: "%.2f", latency))s")
        print("Tone: \(ConversationToneClassifier.classify("Jelaskan Swift Actor.").rawValue)")
        print("=== END TECHNICAL ===\n")
        
        XCTAssertFalse(result.reply.content.isEmpty, "Response should not be empty")
    }
    
    func test_scenario_technicalDebugging() async throws {
        guard let coordinator = coordinator else { return }
        
        let startTime = Date()
        let result = try await coordinator.handleUserInput("Kenapa Swift-ku error actor isolation?")
        let latency = Date().timeIntervalSince(startTime)
        
        print("\n=== TECHNICAL DEBUGGING SCENARIO ===")
        print("User: Kenapa Swift-ku error actor isolation?")
        print("Response: \(result.reply.content)")
        print("Latency: \(String(format: "%.2f", latency))s")
        print("Tone: \(ConversationToneClassifier.classify("Kenapa Swift-ku error actor isolation?").rawValue)")
        print("=== END TECHNICAL DEBUGGING ===\n")
        
        XCTAssertFalse(result.reply.content.isEmpty, "Response should not be empty")
    }
    
    func test_scenario_multiTurnConsistency() async throws {
        guard let coordinator = coordinator else { return }
        
        print("\n=== MULTI-TURN CONSISTENCY ===")
        
        let messages = [
            "lagi apa?",
            "Aku sedang bikin project desktop AI companion.",
            "Serius? Project apa tuh?",
            "Namanya Aria, kayak kamu.",
            "Aku akhirnya berhasil menyelesaikan project ini.",
            "Aria kamu lucu.",
            "Aku capek banget hari ini.",
            "Jelaskan Swift Actor.",
        ]
        
        for (index, message) in messages.enumerated() {
            let startTime = Date()
            let result = try await coordinator.handleUserInput(message)
            let latency = Date().timeIntervalSince(startTime)
            
            print("\n--- Turn \(index + 1) ---")
            print("User: \(message)")
            print("Response: \(result.reply.content)")
            print("Latency: \(String(format: "%.2f", latency))s")
            print("Tone: \(ConversationToneClassifier.classify(message).rawValue)")
            print("Emotion: \(result.emotionState.current.rawValue)")
            print("Relationship warmth: \(String(format: "%.2f", result.relationshipState.warmth))")
            print("Relationship familiarity: \(String(format: "%.2f", result.relationshipState.familiarity))")
        }
        
        print("\n=== END MULTI-TURN CONSISTENCY ===\n")
    }
}

// MARK: - Simple Console Logger

private struct ConsoleLogger: Logging {
    let minimumLevel: LogLevel
    
    init(level: LogLevel) {
        self.minimumLevel = level
    }
    
    func log(_ level: LogLevel, _ message: String, file: String, line: Int) {
        guard level >= minimumLevel else { return }
        let tag: String
        switch level {
        case .debug: tag = "DEBUG"
        case .info: tag = "INFO"
        case .warning: tag = "WARN"
        case .error: tag = "ERROR"
        }
        print("[\(tag)] \(message)")
    }
}
