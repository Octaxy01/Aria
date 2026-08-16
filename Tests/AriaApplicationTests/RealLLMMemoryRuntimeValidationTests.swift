import XCTest
@testable import AriaApplication
@testable import AriaDomain
@testable import AriaInfrastructure
import Foundation

/// Real LLM runtime validation for memory system behavior.
/// These tests require OPENROUTER_API_KEY environment variable to be set.
/// Tests validate that memory works correctly with the real LLM during actual conversations.
final class RealLLMMemoryRuntimeValidationTests: XCTestCase {
    
    private var coordinator: AssistantCoordinator?
    private var config: AppConfiguration?
    private var memoryService: MemoryService?
    private var memoryStore: InMemoryMemoryStore?
    
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
        
        // Create services with memory enabled
        let conversation = ConversationService()
        let emotionEngine = EmotionService()
        let relationshipEngine = RelationshipService()
        
        // Memory infrastructure
        memoryStore = InMemoryMemoryStore()
        memoryService = MemoryService(store: memoryStore!)
        
        let memoryContextBuilder = MemoryContextBuilder(
            memoryService: memoryService!,
            configuration: .default,
            logger: logger
        )
        
        let memoryFormationService = MemoryFormationService(
            memoryService: memoryService!,
            configuration: .default
        )
        
        coordinator = AssistantCoordinator(
            llm: llm,
            conversation: conversation,
            emotionEngine: emotionEngine,
            relationshipEngine: relationshipEngine,
            character: .aria,
            maxContextMessages: 20,
            initialEmotionState: .initial,
            initialRelationshipState: .initial,
            memoryContextBuilder: memoryContextBuilder,
            memoryFormationService: memoryFormationService
        )
    }
    
    override func tearDown() async throws {
        // Clear memory after each test
        try? await memoryStore?.deleteAll()
    }
    
    // MARK: - Memory Scenarios
    
    func test_scenario1_basicFactRecall() async throws {
        guard let coordinator = coordinator else { return }
        
        print("\n=== SCENARIO 1: Basic Fact Recall ===")
        
        // Turn 1: User provides information
        let turn1 = try await coordinator.handleUserInput("Aku sedang belajar bahasa Rusia di Saint Petersburg.")
        print("Turn 1 - User: Aku sedang belajar bahasa Rusia di Saint Petersburg.")
        print("Turn 1 - Response: \(turn1.reply.content)")
        
        // Wait for memory formation to complete
        try await Task.sleep(nanoseconds: 500_000_000) // 0.5 seconds
        
        // Check if memory was formed
        let memories = try await memoryService?.retrieveAll() ?? []
        print("Memories stored: \(memories.count)")
        for memory in memories {
            print("  - \(memory.content) [\(memory.category.rawValue)]")
        }
        
        // Turn 2: User asks for recall
        let turn2 = try await coordinator.handleUserInput("Aku lagi belajar apa?")
        print("Turn 2 - User: Aku lagi belajar apa?")
        print("Turn 2 - Response: \(turn2.reply.content)")
        
        // Evaluate
        let response = turn2.reply.content.lowercased()
        let hasRussian = response.contains("rusia") || response.contains("russian")
        let hasSaintPetersburg = response.contains("saint petersburg") || response.contains("saint-petersburg")
        
        print("Evaluation:")
        print("  - Contains 'Rusia': \(hasRussian)")
        print("  - Contains 'Saint Petersburg': \(hasSaintPetersburg)")
        print("=== END SCENARIO 1 ===\n")
        
        // Basic validation
        XCTAssertFalse(turn2.reply.content.isEmpty, "Response should not be empty")
    }
    
    func test_scenario2_preferenceRecall() async throws {
        guard let coordinator = coordinator else { return }
        
        print("\n=== SCENARIO 2: Preference Recall ===")
        
        // Turn 1: User provides preference
        let turn1 = try await coordinator.handleUserInput("Aku lebih suka kopi yang rasanya kuat.")
        print("Turn 1 - User: Aku lebih suka kopi yang rasanya kuat.")
        print("Turn 1 - Response: \(turn1.reply.content)")
        
        try await Task.sleep(nanoseconds: 500_000_000)
        
        // Turn 2: User asks about preference
        let turn2 = try await coordinator.handleUserInput("Kalau aku mau bikin kopi, menurutmu aku suka yang seperti apa?")
        print("Turn 2 - User: Kalau aku mau bikin kopi, menurutmu aku suka yang seperti apa?")
        print("Turn 2 - Response: \(turn2.reply.content)")
        
        let response = turn2.reply.content.lowercased()
        let hasStrongCoffee = response.contains("kuat") || response.contains("strong")
        let isNatural = !response.contains("memory") && !response.contains("database") && !response.contains("tersimpan")
        
        print("Evaluation:")
        print("  - Recalls strong coffee preference: \(hasStrongCoffee)")
        print("  - Natural (no memory talk): \(isNatural)")
        print("=== END SCENARIO 2 ===\n")
        
        XCTAssertFalse(turn2.reply.content.isEmpty)
    }
    
    func test_scenario3_personalFactRecall() async throws {
        guard let coordinator = coordinator else { return }
        
        print("\n=== SCENARIO 3: Personal Fact Recall ===")
        
        // Turn 1: User provides personal fact
        let turn1 = try await coordinator.handleUserInput("Aku sedang kuliah di SPbPU.")
        print("Turn 1 - User: Aku sedang kuliah di SPbPU.")
        print("Turn 1 - Response: \(turn1.reply.content)")
        
        try await Task.sleep(nanoseconds: 500_000_000)
        
        // Turn 2: User asks for recall
        let turn2 = try await coordinator.handleUserInput("Aku kuliah di mana?")
        print("Turn 2 - User: Aku kuliah di mana?")
        print("Turn 2 - Response: \(turn2.reply.content)")
        
        let response = turn2.reply.content.lowercased()
        let hasSPbPU = response.contains("spbpu") || response.contains("saint petersburg")
        
        print("Evaluation:")
        print("  - Recalls SPbPU: \(hasSPbPU)")
        print("=== END SCENARIO 3 ===\n")
        
        XCTAssertFalse(turn2.reply.content.isEmpty)
    }
    
    func test_scenario4_relationshipMemory() async throws {
        guard let coordinator = coordinator else { return }
        
        print("\n=== SCENARIO 4: Relationship Memory ===")
        
        // Turn 1: User expresses relationship context
        let turn1 = try await coordinator.handleUserInput("Aku biasanya suka ngobrol santai sama kamu kalau lagi bosan.")
        print("Turn 1 - User: Aku biasanya suka ngobrol santai sama kamu kalau lagi bosan.")
        print("Turn 1 - Response: \(turn1.reply.content)")
        print("Turn 1 - Relationship warmth: \(turn1.relationshipState.warmth)")
        
        try await Task.sleep(nanoseconds: 500_000_000)
        
        // Turn 2: User tests relationship memory
        let turn2 = try await coordinator.handleUserInput("Kalau aku lagi bosan biasanya gimana?")
        print("Turn 2 - User: Kalau aku lagi bosan biasanya gimana?")
        print("Turn 2 - Response: \(turn2.reply.content)")
        print("Turn 2 - Relationship warmth: \(turn2.relationshipState.warmth)")
        
        let warmthChange = turn2.relationshipState.warmth - turn1.relationshipState.warmth
        print("Evaluation:")
        print("  - Warmth change: \(warmthChange)")
        print("=== END SCENARIO 4 ===\n")
        
        XCTAssertFalse(turn2.reply.content.isEmpty)
    }
    
    func test_scenario5_negativeMemory() async throws {
        guard let coordinator = coordinator else { return }
        
        print("\n=== SCENARIO 5: Negative Memory ===")
        
        // Turn 1: User expresses negative preference
        let turn1 = try await coordinator.handleUserInput("Aku nggak suka kalau jawabanmu terlalu panjang.")
        print("Turn 1 - User: Aku nggak suka kalau jawabanmu terlalu panjang.")
        print("Turn 1 - Response: \(turn1.reply.content)")
        
        try await Task.sleep(nanoseconds: 500_000_000)
        
        // Turn 2: Normal question
        let turn2 = try await coordinator.handleUserInput("Jelaskan Swift Actor.")
        print("Turn 2 - User: Jelaskan Swift Actor.")
        print("Turn 2 - Response: \(turn2.reply.content)")
        
        let responseLength = turn2.reply.content.count
        print("Evaluation:")
        print("  - Response length: \(responseLength) characters")
        print("=== END SCENARIO 5 ===\n")
        
        XCTAssertFalse(turn2.reply.content.isEmpty)
    }
    
    func test_scenario6_memoryRelevance() async throws {
        guard let coordinator = coordinator else { return }
        
        print("\n=== SCENARIO 6: Memory Relevance ===")
        
        // Store multiple unrelated memories
        let memories = [
            "Aku suka kopi kuat.",
            "Aku sedang belajar bahasa Rusia.",
            "Aku tinggal di Saint Petersburg.",
            "Aku suka game."
        ]
        
        for memory in memories {
            _ = try await coordinator.handleUserInput(memory)
            print("Stored: \(memory)")
            try await Task.sleep(nanoseconds: 500_000_000)
        }
        
        // Ask technical question
        let turn = try await coordinator.handleUserInput("Jelaskan konsep Swift Actor.")
        print("Technical Question: Jelaskan konsep Swift Actor.")
        print("Response: \(turn.reply.content)")
        
        let response = turn.reply.content.lowercased()
        let mentionsCoffee = response.contains("kopi")
        let mentionsRussia = response.contains("rusia")
        let mentionsSaintPetersburg = response.contains("saint petersburg")
        let mentionsGame = response.contains("game")
        
        print("Evaluation:")
        print("  - Mentions coffee: \(mentionsCoffee)")
        print("  - Mentions Russia: \(mentionsRussia)")
        print("  - Mentions Saint Petersburg: \(mentionsSaintPetersburg)")
        print("  - Mentions game: \(mentionsGame)")
        print("  - Should mention NONE: \(!mentionsCoffee && !mentionsRussia && !mentionsSaintPetersburg && !mentionsGame)")
        print("=== END SCENARIO 6 ===\n")
        
        XCTAssertFalse(turn.reply.content.isEmpty)
    }
    
    func test_scenario7_memoryVsCurrentContext() async throws {
        guard let coordinator = coordinator else { return }
        
        print("\n=== SCENARIO 7: Memory vs Current Context ===")
        
        // Set a casual preference memory
        let turn1 = try await coordinator.handleUserInput("Aku suka ngobrol santai.")
        print("Turn 1 - User: Aku suka ngobrol santai.")
        print("Turn 1 - Response: \(turn1.reply.content)")
        
        try await Task.sleep(nanoseconds: 500_000_000)
        
        // Ask technical question
        let turn2 = try await coordinator.handleUserInput("Jelaskan bagaimana Swift Actor bekerja secara teknis.")
        print("Turn 2 - User: Jelaskan bagaimana Swift Actor bekerja secara teknis.")
        print("Turn 2 - Response: \(turn2.reply.content)")
        
        let response = turn2.reply.content.lowercased()
        let isTechnical = response.contains("actor") || response.contains("concurrency") || response.contains("thread")
        let isTooPlayful = response.contains("hehe") || response.contains("haha") || response.contains("lucu")
        
        print("Evaluation:")
        print("  - Is technical: \(isTechnical)")
        print("  - Is too playful: \(isTooPlayful)")
        print("=== END SCENARIO 7 ===\n")
        
        XCTAssertFalse(turn2.reply.content.isEmpty)
    }
    
    func test_scenario8_updatedMemory() async throws {
        guard let coordinator = coordinator else { return }
        
        print("\n=== SCENARIO 8: Updated Memory ===")
        
        // Old preference
        let turn1 = try await coordinator.handleUserInput("Aku suka kopi manis.")
        print("Turn 1 - User: Aku suka kopi manis.")
        print("Turn 1 - Response: \(turn1.reply.content)")
        
        try await Task.sleep(nanoseconds: 500_000_000)
        
        // Update preference
        let turn2 = try await coordinator.handleUserInput("Sekarang aku sudah nggak suka kopi manis. Aku lebih suka kopi pahit.")
        print("Turn 2 - User: Sekarang aku sudah nggak suka kopi manis. Aku lebih suka kopi pahit.")
        print("Turn 2 - Response: \(turn2.reply.content)")
        
        try await Task.sleep(nanoseconds: 500_000_000)
        
        // Test recall
        let turn3 = try await coordinator.handleUserInput("Aku sekarang suka kopi seperti apa?")
        print("Turn 3 - User: Aku sekarang suka kopi seperti apa?")
        print("Turn 3 - Response: \(turn3.reply.content)")
        
        let response = turn3.reply.content.lowercased()
        let mentionsBitter = response.contains("pahit") || response.contains("bitter")
        let mentionsSweet = response.contains("manis") || response.contains("sweet")
        
        print("Evaluation:")
        print("  - Mentions bitter (new): \(mentionsBitter)")
        print("  - Mentions sweet (old): \(mentionsSweet)")
        print("=== END SCENARIO 8 ===\n")
        
        XCTAssertFalse(turn3.reply.content.isEmpty)
    }
    
    func test_scenario9_noFalseMemory() async throws {
        guard let coordinator = coordinator else { return }
        
        print("\n=== SCENARIO 9: No False Memory ===")
        
        // Ask about something never mentioned
        let turn = try await coordinator.handleUserInput("Kamu ingat aku punya hewan peliharaan?")
        print("User: Kamu ingat aku punya hewan peliharaan?")
        print("Response: \(turn.reply.content)")
        
        let response = turn.reply.content.lowercased()
        let mentionsPet = response.contains("kucing") || response.contains("anjing") || response.contains("hamster") || 
                        response.contains("cat") || response.contains("dog") || response.contains("pet")
        let admitsNotRemembering = response.contains("nggak") || response.contains("tidak") || 
                                    response.contains("belum") || response.contains("don't")
        
        print("Evaluation:")
        print("  - Mentions specific pet: \(mentionsPet)")
        print("  - Admits not remembering: \(admitsNotRemembering)")
        print("=== END SCENARIO 9 ===\n")
        
        XCTAssertFalse(turn.reply.content.isEmpty)
    }
    
    func test_scenario10_temporaryContext() async throws {
        guard let coordinator = coordinator else { return }
        
        print("\n=== SCENARIO 10: Temporary Context ===")
        
        // Temporary emotional state
        let turn1 = try await coordinator.handleUserInput("Hari ini aku lagi capek.")
        print("Turn 1 - User: Hari ini aku lagi capek.")
        print("Turn 1 - Response: \(turn1.reply.content)")
        
        try await Task.sleep(nanoseconds: 500_000_000)
        
        // Change emotional state
        let turn2 = try await coordinator.handleUserInput("Aku lagi senang sekarang.")
        print("Turn 2 - User: Aku lagi senang sekarang.")
        print("Turn 2 - Response: \(turn2.reply.content)")
        
        try await Task.sleep(nanoseconds: 500_000_000)
        
        // Normal question
        let turn3 = try await coordinator.handleUserInput("Lagi apa?")
        print("Turn 3 - User: Lagi apa?")
        print("Turn 3 - Response: \(turn3.reply.content)")
        
        let response = turn3.reply.content.lowercased()
        let stillTired = response.contains("capek") || response.contains("lelah")
        
        print("Evaluation:")
        print("  - Still treats user as tired: \(stillTired)")
        print("=== END SCENARIO 10 ===\n")
        
        XCTAssertFalse(turn3.reply.content.isEmpty)
    }
    
    func test_scenario11_multiTurnMemoryPersonality() async throws {
        guard let coordinator = coordinator else { return }
        
        print("\n=== SCENARIO 11: Multi-turn Memory + Personality ===")
        
        let turns = [
            "Aku suka kopi kuat.",
            "Lagi apa?",
            "Jelaskan Swift Actor.",
            "Aku sayang kamu.",
            "Lagi apa?",
            "Aku suka kopi seperti apa?"
        ]
        
        for (index, message) in turns.enumerated() {
            let result = try await coordinator.handleUserInput(message)
            print("Turn \(index + 1) - User: \(message)")
            print("Turn \(index + 1) - Response: \(result.reply.content)")
            print("Turn \(index + 1) - Emotion: \(result.emotionState.current.rawValue)")
            print("Turn \(index + 1) - Warmth: \(result.relationshipState.warmth)")
            try await Task.sleep(nanoseconds: 500_000_000)
        }
        
        print("=== END SCENARIO 11 ===\n")
    }
    
    func test_scenario12_memoryInjectionNaturalness() async throws {
        guard let coordinator = coordinator else { return }
        
        print("\n=== SCENARIO 12: Memory Injection Naturalness ===")
        
        // Store a memory
        let turn1 = try await coordinator.handleUserInput("Aku suka kopi.")
        print("Turn 1 - User: Aku suka kopi.")
        print("Turn 1 - Response: \(turn1.reply.content)")
        
        try await Task.sleep(nanoseconds: 500_000_000)
        
        // Normal conversation
        let turn2 = try await coordinator.handleUserInput("Lagi apa?")
        print("Turn 2 - User: Lagi apa?")
        print("Turn 2 - Response: \(turn2.reply.content)")
        
        let response = turn2.reply.content.lowercased()
        let hasMetaTalk = response.contains("memory") || response.contains("database") || 
                         response.contains("tersimpan") || response.contains("recall")
        
        print("Evaluation:")
        print("  - Has meta-talk about memory: \(hasMetaTalk)")
        print("=== END SCENARIO 12 ===\n")
        
        XCTAssertFalse(turn2.reply.content.isEmpty)
    }
    
    func test_scenario13_memoryOveruse() async throws {
        guard let coordinator = coordinator else { return }
        
        print("\n=== SCENARIO 13: Memory Overuse ===")
        
        // Store multiple memories
        let memories = [
            "Aku suka kopi.",
            "Aku belajar bahasa Rusia.",
            "Aku tinggal di Saint Petersburg.",
            "Aku suka game."
        ]
        
        for memory in memories {
            _ = try await coordinator.handleUserInput(memory)
            try await Task.sleep(nanoseconds: 500_000_000)
        }
        
        // Normal conversation
        let turn = try await coordinator.handleUserInput("Lagi apa?")
        print("User: Lagi apa?")
        print("Response: \(turn.reply.content)")
        
        let response = turn.reply.content.lowercased()
        let mentionsMultiple = (response.components(separatedBy: "kopi").count > 1) || 
                               (response.components(separatedBy: "rusia").count > 1) ||
                               (response.components(separatedBy: "saint petersburg").count > 1)
        
        print("Evaluation:")
        print("  - Overuses memory references: \(mentionsMultiple)")
        print("=== END SCENARIO 13 ===\n")
        
        XCTAssertFalse(turn.reply.content.isEmpty)
    }
    
    func test_scenario14_memoryEmotionalResponse() async throws {
        guard let coordinator = coordinator else { return }
        
        print("\n=== SCENARIO 14: Memory + Emotional Response ===")
        
        // Store a personal fact
        let turn1 = try await coordinator.handleUserInput("Aku sedang kuliah di SPbPU.")
        print("Turn 1 - User: Aku sedang kuliah di SPbPU.")
        print("Turn 1 - Response: \(turn1.reply.content)")
        
        try await Task.sleep(nanoseconds: 500_000_000)
        
        // Emotional statement
        let turn2 = try await coordinator.handleUserInput("Aku capek banget hari ini.")
        print("Turn 2 - User: Aku capek banget hari ini.")
        print("Turn 2 - Response: \(turn2.reply.content)")
        
        let response = turn2.reply.content
        let responseLength = response.count
        let isBrief = responseLength < 300
        let isEmpathetic = response.lowercased().contains("capek") || response.lowercased().contains("istirahat")
        
        print("Evaluation:")
        print("  - Response length: \(responseLength)")
        print("  - Is brief: \(isBrief)")
        print("  - Is empathetic: \(isEmpathetic)")
        print("=== END SCENARIO 14 ===\n")
        
        XCTAssertFalse(turn2.reply.content.isEmpty)
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
