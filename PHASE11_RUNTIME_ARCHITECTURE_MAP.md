# PHASE 11 RUNTIME ARCHITECTURE MAP

## STEP 1 — Runtime Architecture Analysis

### Dependency Injection Architecture

**Entry Point:** AppBootstrap.createCoordinator()

**Parameters:**
- `llm: any LLMResponding` - Dependency injection point for LLM provider
- `logger: any Logging` - Logging infrastructure
- `config: AppConfiguration` - Application configuration

**LLM Provider Interface:**
```swift
public protocol LLMResponding: Sendable {
    func respond(to request: LLMRequest) async throws -> LLMResponse
}
```

**Available Implementations:**
1. **OpenRouterProvider** (Production) - Requires OPENROUTER_API_KEY
2. **MockLLMProvider** (Testing) - Deterministic, no API key required

### Runtime Pipeline Architecture

```
User Input
    ↓
AssistantCoordinator.handleUserInput(_ text: String)
    ↓
ConversationService.append(role: .user, content: text)
    ↓
LLMRequest construction (messages + systemContext + toolDefinitions)
    ↓
LLMResponding.respond(to: LLMRequest)
    ↓
LLMResponse (text + emotionSignal + toolCalls)
    ↓
Tool Detection (if toolCalls present)
    ↓
ToolOrchestrator
    ↓
ClarificationManager / ReferenceResolver (if needed)
    ↓
ConfirmationManager (if needed)
    ↓
ConversationService.append(role: .assistant, content: response)
    ↓
EmotionEngine.nextState()
    ↓
RelationshipEngine.nextState()
    ↓
AvatarStateManager.transitionToIdle()
    ↓
TTS dispatch (TextToSpeechService)
    ↓
Audio playback (AudioPlaybackService)
```

### Component Dependencies

**AssistantCoordinator Dependencies:**
- LLMResponding (injected)
- ConversationService (created locally)
- EmotionEngine (created locally)
- RelationshipEngine (created with persistent store)
- CharacterProfile (uses .aria)
- MemoryContextBuilder (optional)
- MemoryFormationService (optional)
- ToolOrchestrator (optional)
- ToolRegistry (optional)
- RuntimeEntityContext (optional)
- ReferenceResolver (optional)
- ClarificationManager (optional)
- ClarificationAnswerParser (optional)
- ToolResultInterpreter (optional)
- TaskContextManager (optional)
- AvatarStateManager (optional)

**Tool Orchestrator Dependencies:**
- ToolRegistry
- RuntimeEntityContext
- ReferenceResolver
- ClarificationManager
- TaskContextManager

**TTS Service Dependencies:**
- VoiceVoxTTSService (primary for Japanese)
- PiperTTSService (fallback)
- LanguageSettings
- AvatarStateManager (optional)

### Session Safety Mechanisms

**Request Isolation:**
- UUID-based request tracking
- `currentRequestID` validation
- Task cancellation on new input
- Stale response rejection

**Session Validation:**
- Each component has session ID validation
- Stale events rejected
- Session-based state isolation

**Cancellation:**
- Task cancellation support
- Avatar state cleanup
- Request task cancellation
- State rollback on cancellation

### MockLLMProvider Integration Capability

**Current Status:** READY FOR INTEGRATION

**Integration Point:** AppBootstrap.createCoordinator(llm: MockLLMProvider, ...)

**Benefits:**
- Same runtime pipeline as production
- No production code changes required
- Deterministic responses
- Configurable delays
- Error simulation support
- Tool call simulation

**No Changes Required:**
- AssistantCoordinator already uses LLMResponding protocol
- AppBootstrap already has dependency injection
- MockLLMProvider implements LLMResponding protocol
- Same orchestration pipeline used for both production and tests

### Current Test Infrastructure

**Existing Test Coverage:**
- CoreBehaviorTests (18/18 PASS) - Unit tests
- TaskContextTests (39/39 PASS) - Session safety
- ClarificationFlowTests (20/22 PASS) - Clarification flow
- ToolConfirmationPolicyTests (35/35 PASS) - Confirmation logic
- ToolOrchestratorTests (12/12 PASS) - Tool orchestration
- RuntimeAdapterTests (8/8 PASS) - Runtime events
- VoiceVoxTTSServiceTests (15/15 PASS) - TTS integration
- RuntimeStabilityTests (10/10 PASS) - Stress testing

**Missing Integration Tests:**
- End-to-end conversation with MockLLMProvider
- Multi-turn conversation with context preservation
- Stale response protection with real pipeline
- Cancellation with real pipeline
- Tool execution with MockLLMProvider
- Multi-turn reference resolution with real pipeline
- TTS dispatch with real conversation responses
- Audio session safety with real pipeline
- Failure recovery with real pipeline
- Long session stress test with real pipeline

### Conclusion

**Dependency Injection Status:** EXCELLENT
- Clean protocol boundary (LLMResponding)
- Minimal code changes required
- MockLLMProvider can be injected directly
- Same runtime pipeline for production and tests

**Architecture Readiness:** READY
- All components already designed for dependency injection
- Session safety mechanisms in place
- Cancellation infrastructure exists
- Tool orchestration ready for testing
- TTS integration ready for testing

**Next Step:** Create EndToEndRuntimeTests to exercise the full pipeline with MockLLMProvider