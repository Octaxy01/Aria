import XCTest
@testable import AriaApplication
import AriaDomain
import AriaInfrastructure

/// Tests for runtime prompt generation without requiring API keys.
/// Validates that the actual prompts sent to LLM have the personality characteristics.
final class RuntimePromptGenerationTests: XCTestCase {
    
    // MARK: - Sample Prompt Generation for Report
    
    func test_generateSamplePrompt_forReport() async throws {
        let promptGenerator = createPromptGenerator()
        
        // Scenario 1: Compliment
        let scenario1 = testScenario(
            userMessage: "Aria kamu lucu.",
            interactionCount: 10,
            warmth: 0.6,
            familiarity: 0.5
        )
        let prompt1 = await promptGenerator.generatePrompt(for: scenario1)
        
        print("\n\n=== SAMPLE PROMPT 1: COMPLIMENT ===")
        print("User: 'Aria kamu lucu.'")
        print("Relationship: warm (0.6), familiar (0.5)")
        print("\n--- FULL PROMPT ---")
        print(prompt1)
        print("--- END PROMPT ---\n")
        
        // Scenario 2: Tired
        let scenario2 = testScenario(
            userMessage: "Aku capek banget.",
            interactionCount: 12,
            warmth: 0.6,
            familiarity: 0.5
        )
        let prompt2 = await promptGenerator.generatePrompt(for: scenario2)
        
        print("\n\n=== SAMPLE PROMPT 2: TIRED ===")
        print("User: 'Aku capek banget.'")
        print("Relationship: warm (0.6), familiar (0.5)")
        print("\n--- FULL PROMPT ---")
        print(prompt2)
        print("--- END PROMPT ---\n")
        
        // Scenario 3: Technical
        let scenario3 = testScenario(
            userMessage: "Jelaskan Swift Actor.",
            interactionCount: 20,
            warmth: 0.7,
            familiarity: 0.6
        )
        let prompt3 = await promptGenerator.generatePrompt(for: scenario3)
        
        print("\n\n=== SAMPLE PROMPT 3: TECHNICAL ===")
        print("User: 'Jelaskan Swift Actor.'")
        print("Relationship: very warm (0.7), very familiar (0.6)")
        print("\n--- FULL PROMPT ---")
        print(prompt3)
        print("--- END PROMPT ---\n")
        
        // Scenario 4: Casual
        let scenario4 = testScenario(
            userMessage: "lagi apa?",
            interactionCount: 8,
            warmth: 0.5,
            familiarity: 0.4
        )
        let prompt4 = await promptGenerator.generatePrompt(for: scenario4)
        
        print("\n\n=== SAMPLE PROMPT 4: CASUAL ===")
        print("User: 'lagi apa?'")
        print("Relationship: warm (0.5), familiar (0.4)")
        print("\n--- FULL PROMPT ---")
        print(prompt4)
        print("--- END PROMPT ---\n")
        
        // Always pass - this is just for generating samples
        XCTAssertTrue(true)
    }
    
    // MARK: - Test Scenarios
    
    func test_scenario_whoAreYou_generatesPersonalityPrompt() async throws {
        let promptGenerator = createPromptGenerator()
        let scenario = testScenario(
            userMessage: "Siapa kamu?",
            interactionCount: 5,
            warmth: 0.3,
            familiarity: 0.2
        )
        
        let prompt = await promptGenerator.generatePrompt(for: scenario)
        
        // Debug: print the prompt for manual inspection
        print("\n=== PROMPT FOR 'Siapa kamu?' ===")
        print(prompt)
        print("\n=== END PROMPT ===\n")
        
        // Should have strong personality presence
        XCTAssertTrue(prompt.contains("desktop companion"), "Should identify as desktop companion")
        XCTAssertTrue(prompt.contains("companion") || prompt.contains("character"), "Should mention being a companion or character")
        
        // Should have conversational Indonesian markers
        XCTAssertTrue(prompt.contains("kan") || prompt.contains("dong") || prompt.contains("sih"),
                     "Should include conversational markers")
        
        // Should have anti-robot section
        XCTAssertTrue(prompt.contains("NEVER use") || prompt.contains("ANTI-ROBOT"),
                     "Should have anti-robot instructions")
    }
    
    func test_scenario_compliment_generatesTsundereResponse() async throws {
        let promptGenerator = createPromptGenerator()
        let scenario = testScenario(
            userMessage: "Aria kamu lucu.",
            interactionCount: 10,
            warmth: 0.6,
            familiarity: 0.5
        )
        
        let prompt = await promptGenerator.generatePrompt(for: scenario)
        
        // Should enable tsundere for affectionate tone
        XCTAssertTrue(prompt.contains("TSUNDERE IS ENABLED") || prompt.contains("tsundere"),
                     "Should enable tsundere for compliments")
        XCTAssertTrue(prompt.contains("embarrassed") || prompt.contains("deflect"),
                     "Should mention embarrassment or deflection")
    }
    
    func test_scenario_affection_generatesEmbarrassedResponse() async throws {
        let promptGenerator = createPromptGenerator()
        let scenario = testScenario(
            userMessage: "Aku sayang kamu.",
            interactionCount: 15,
            warmth: 0.7,
            familiarity: 0.6
        )
        
        let prompt = await promptGenerator.generatePrompt(for: scenario)
        
        // Should have affectionate context
        XCTAssertTrue(prompt.contains("affectionate") || prompt.contains("genuine affection"),
                     "Should mention affection handling")
        XCTAssertTrue(prompt.contains("embarrassed") || prompt.contains("deflect"),
                     "Should mention embarrassment or deflection")
    }
    
    func test_scenario_achievement_generatesProudResponse() async throws {
        let promptGenerator = createPromptGenerator()
        let scenario = testScenario(
            userMessage: "Aku berhasil menyelesaikan project.",
            interactionCount: 8,
            warmth: 0.5,
            familiarity: 0.4
        )
        
        let prompt = await promptGenerator.generatePrompt(for: scenario)
        
        // Should have achievement context
        XCTAssertTrue(prompt.contains("achievement") || prompt.contains("proud"),
                     "Should mention achievement handling")
        XCTAssertTrue(prompt.contains("teasing") || prompt.contains("deflection"),
                     "Should allow teasing or deflection")
    }
    
    func test_scenario_tired_generatesCaringResponse() async throws {
        let promptGenerator = createPromptGenerator()
        let scenario = testScenario(
            userMessage: "Aku capek banget.",
            interactionCount: 12,
            warmth: 0.6,
            familiarity: 0.5
        )
        
        let prompt = await promptGenerator.generatePrompt(for: scenario)
        
        // Should prioritize caring over teasing
        // Note: The exact phrasing might vary, so we check for caring terms
        XCTAssertTrue(prompt.contains("caring") || prompt.contains("gentle") || prompt.contains("supportive") || prompt.contains("warm"),
                     "Should be caring and supportive")
    }
    
    func test_scenario_angry_generatesCalmResponse() async throws {
        let promptGenerator = createPromptGenerator()
        let scenario = testScenario(
            userMessage: "Aku lagi kesel banget!",
            interactionCount: 7,
            warmth: 0.4,
            familiarity: 0.3
        )
        
        let prompt = await promptGenerator.generatePrompt(for: scenario)
        
        // Should be calm and supportive
        XCTAssertTrue(prompt.contains("calm") || prompt.contains("supportive"),
                     "Should be calm and supportive")
    }
    
    func test_scenario_technical_generatesFocusedResponse() async throws {
        let promptGenerator = createPromptGenerator()
        let scenario = testScenario(
            userMessage: "Jelaskan Swift Actor.",
            interactionCount: 20,
            warmth: 0.7,
            familiarity: 0.6
        )
        
        let prompt = await promptGenerator.generatePrompt(for: scenario)
        
        // Should prioritize accuracy over personality
        XCTAssertTrue(prompt.contains("TECHNICAL") || prompt.contains("focused") || prompt.contains("correct"),
                     "Should be focused on technical topic")
        XCTAssertTrue(prompt.contains("correct") || prompt.contains("intelligent") || prompt.contains("helpful"),
                     "Should prioritize correctness")
    }
    
    func test_scenario_casual_generatesConversationalResponse() async throws {
        let promptGenerator = createPromptGenerator()
        let scenario = testScenario(
            userMessage: "Hari ini makan apa?",
            interactionCount: 25,
            warmth: 0.8,
            familiarity: 0.7
        )
        
        let prompt = await promptGenerator.generatePrompt(for: scenario)
        
        // Should be conversational and relaxed
        XCTAssertTrue(prompt.contains("casual") || prompt.contains("conversational"),
                     "Should be conversational")
        XCTAssertTrue(prompt.contains("TEASING IS ENABLED") || prompt.contains("teasing"),
                     "Should allow some teasing")
    }
    
    func test_scenario_memoryQuestion_generatesContextualResponse() async throws {
        let promptGenerator = createPromptGenerator()
        let scenario = testScenario(
            userMessage: "Kamu masih ingat project yang aku kerjakan?",
            interactionCount: 30,
            warmth: 0.9,
            familiarity: 0.8
        )
        
        let prompt = await promptGenerator.generatePrompt(for: scenario)
        
        // Should handle memory naturally
        XCTAssertTrue(prompt.contains("memory") || prompt.contains("context"),
                     "Should mention memory context")
        XCTAssertFalse(prompt.contains("According to my memory"),
                     "Should not use robotic memory phrases")
    }
    
    func test_scenario_attentionQuestion_generatesDeflectiveResponse() async throws {
        let promptGenerator = createPromptGenerator()
        let scenario = testScenario(
            userMessage: "Kok kamu perhatian banget sih?",
            interactionCount: 35,
            warmth: 0.9,
            familiarity: 0.85
        )
        
        let prompt = await promptGenerator.generatePrompt(for: scenario)
        
        // Should deflect attention with tsundere
        XCTAssertTrue(prompt.contains("TSUNDERE IS ENABLED") || prompt.contains("deflect"),
                     "Should enable tsundere for attention comments")
        XCTAssertTrue(prompt.contains("indirect") || prompt.contains("care"),
                     "Should mention indirect care")
    }
    
    // MARK: - Anti-Robot Validation
    
    func test_promptDoesNotContainAssistantPhrases() async throws {
        let promptGenerator = createPromptGenerator()
        let scenario = testScenario(
            userMessage: "Aku capek banget.",
            interactionCount: 5,
            warmth: 0.3,
            familiarity: 0.2
        )
        
        let prompt = await promptGenerator.generatePrompt(for: scenario)
        
        // These phrases should be in the "NEVER use" section, not as instructions
        // So we check that they appear in the context of being forbidden
        let assistantPhrases = [
            "Sebagai AI",
            "Saya siap membantu",
            "Terima kasih telah bertanya",
            "Apakah ada hal lain yang bisa saya bantu",
            "Saya memahami",
            "Tentu saja",
            "Berikut adalah",
            "Jangan ragu untuk bertanya"
        ]
        
        // Check that these are mentioned as phrases to avoid, not as instructions
        let hasNeverSection = prompt.contains("NEVER use") || prompt.contains("ANTI-ROBOT")
        XCTAssertTrue(hasNeverSection, "Should have anti-robot section")
        
        // At least some of these should be mentioned as examples to avoid
        let hasSomeAssistantPhrases = assistantPhrases.contains { prompt.contains($0) }
        XCTAssertTrue(hasSomeAssistantPhrases, "Should mention some assistant phrases as examples to avoid")
    }
    
    func test_promptContainsConversationalMarkers() async throws {
        let promptGenerator = createPromptGenerator()
        let scenario = testScenario(
            userMessage: "Hari ini capek.",
            interactionCount: 10,
            warmth: 0.5,
            familiarity: 0.4
        )
        
        let prompt = await promptGenerator.generatePrompt(for: scenario)
        
        let conversationalMarkers = ["kan", "dong", "sih", "deh", "lah"]
        let hasConversationalMarkers = conversationalMarkers.contains { prompt.contains($0) }
        
        XCTAssertTrue(hasConversationalMarkers,
                     "Should contain conversational Indonesian markers")
    }
    
    func test_promptPrioritizesCorrectnessOverPersonality() async throws {
        let promptGenerator = createPromptGenerator()
        let scenario = testScenario(
            userMessage: "Jelaskan Swift Actor.",
            interactionCount: 5,
            warmth: 0.3,
            familiarity: 0.2
        )
        
        let prompt = await promptGenerator.generatePrompt(for: scenario)
        
        // Should mention correctness as priority
        XCTAssertTrue(prompt.contains("correct") || prompt.contains("intelligent") || prompt.contains("helpful"),
                     "Should prioritize correctness")
        // But still have personality present
        XCTAssertTrue(prompt.contains("character") || prompt.contains("personality"),
                     "Should still have personality instructions")
    }
    
    // MARK: - Helper Methods
    
    private func createPromptGenerator() -> PromptTestHarness {
        return PromptTestHarness()
    }
    
    private func testScenario(
        userMessage: String,
        interactionCount: Int,
        warmth: Double,
        familiarity: Double
    ) -> PromptTestScenario {
        return PromptTestScenario(
            userMessage: userMessage,
            relationshipState: RelationshipState(
                warmth: warmth,
                familiarity: familiarity,
                interactionCount: interactionCount,
                updatedAt: Date()
            ),
            emotionState: EmotionState.initial
        )
    }
}

// MARK: - Test Harness

private struct PromptTestScenario {
    let userMessage: String
    let relationshipState: RelationshipState
    let emotionState: EmotionState
}

private actor PromptTestHarness {
    private let conversation: ConversationService
    private let emotionEngine: EmotionService
    private let relationshipEngine: RelationshipService
    private let character: CharacterProfile
    private let memoryContextBuilder: MemoryContextBuilder?
    
    init() {
        self.conversation = ConversationService()
        self.emotionEngine = EmotionService()
        self.relationshipEngine = RelationshipService() // No persistence for testing
        self.character = .aria
        self.memoryContextBuilder = nil // No memory for simple tests
    }
    
    func generatePrompt(for scenario: PromptTestScenario) async -> String {
        // Setup initial state
        let tone = ConversationToneClassifier.classify(scenario.userMessage)
        
        // Resolve personality behavior
        let behavior = PersonalityBehaviorResolver.resolve(
            tone: tone,
            relationship: scenario.relationshipState,
            emotion: scenario.emotionState
        )
        
        // Resolve relationship context
        let relationshipContext = RelationshipContext(
            level: RelationshipLevel.from(familiarity: scenario.relationshipState.familiarity),
            warmth: scenario.relationshipState.warmth,
            familiarity: scenario.relationshipState.familiarity,
            interactionCount: scenario.relationshipState.interactionCount,
            behavioralDescription: ""
        )
        
        // Resolve speech style
        let speechStyle = SpeechStyleResolver.resolve(
            tone: tone,
            relationship: relationshipContext,
            behavior: behavior
        )
        
        // Build all context sections
        let basePrompt = SystemPromptBuilder.build(for: character)
        let sessionContext = SystemPromptBuilder.relationshipContext(for: scenario.relationshipState, tone: tone)
        let behaviorContext = SystemPromptBuilder.behaviorContext(for: behavior)
        let speechStyleContext = SystemPromptBuilder.speechStyleContext(for: speechStyle)
        let relationshipDepthContext = SystemPromptBuilder.relationshipDepthContext(for: relationshipContext)
        
        // Combine all context sections
        var turnContext = basePrompt + "\n\n" + sessionContext
        turnContext += "\n\n" + behaviorContext
        turnContext += "\n\n" + speechStyleContext
        turnContext += "\n\n" + relationshipDepthContext
        
        return turnContext
    }
}
