# STEP 5: BEHAVIORAL ARCHITECTURE AUDIT

## 1. EXECUTIVE SUMMARY

Aria has a well-structured behavioral architecture with clear separation of concerns. The system implements a centralized behavioral resolution pattern through `PersonalityBehaviorResolver` and `SpeechStyleResolver`, which successfully integrate emotion, relationship, tone, and personality into runtime behavior. 

The architecture follows the intended conceptual pipeline with minor deviations: emotion and personality behavior are resolved correctly, but there are two instances of `PersonalityBehaviorResolver` being called (in `AssistantCoordinator` and `TextToSpeechService`). The avatar system properly separates lifecycle state from emotional expression. The TTS system correctly preserves native `pitchScale` and applies emotional transformations only through `SpeechStyle` → `VoiceStyle` mapping.

**Overall Assessment**: The architecture is sound with NO major structural issues. Phase 5 requires MINOR changes to eliminate duplicate resolver calls and strengthen emotional/personality integration documentation.

---

## 2. ACTUAL RUNTIME FLOW

Based on analysis of `AssistantCoordinator.swift`, the actual runtime flow is:

```
User Input
    ↓
AssistantCoordinator.handleUserInput()
    ↓
Generate UUID request ID (session invalidation protection)
    ↓
Cancel previous request (prevent overlapping conversations)
    ↓
AvatarStateManager.transitionToThinking()
    ↓
ConversationService.append(role: .user, content: text)
    ↓
LanguageDetector.detect(text) (determine input language)
    ↓
LanguageDetector.detectLanguageOverride(text) (check for explicit language changes)
    ↓
ConversationToneClassifier.classify(text) (determine conversation tone)
    ↓
ConversationService.recentHistory(maxMessages: maxContextMessages)
    ↓
PersonalityBehaviorResolver.resolve(tone, relationship, emotion) ← BEHAVIOR RESOLUTION
    ↓
RelationshipContext(from: relationshipState)
    ↓
SpeechStyleResolver.resolve(tone, relationship, behavior) ← SPEECH STYLE RESOLUTION
    ↓
SystemPromptBuilder.relationshipContext(relationshipState, tone)
    ↓
SystemPromptBuilder.behaviorContext(behavior)
    ↓
SystemPromptBuilder.speechStyleContext(speechStyle)
    ↓
SystemPromptBuilder.relationshipDepthContext(relationshipContext)
    ↓
SystemPromptBuilder.languagePolicyContext(languageSettings, detectedLanguage)
    ↓
MemoryContextBuilder.buildContext(text, relationshipLevel) (if available)
    ↓
SystemPromptBuilder.memoryContext(rawMemoryContext) (if available)
    ↓
Combine: basePrompt + sessionContext + languagePolicyContext + behaviorContext + speechStyleContext + relationshipDepthContext + memoryContext
    ↓
LLMRequest(messages: recentHistory, systemContext: turnContext)
    ↓
LLMResponding.respond(to: request) → LLMResponse(text, emotionSignal?)
    ↓
Validate request ID (stale request protection)
    ↓
validateResponseText(response.text)
    ↓
guardResponseQuality(validatedText)
    ↓
ConversationService.append(role: .assistant, content: qualityGuardedText)
    ↓
EmotionService.nextState(current: emotionState, signal: response.emotionSignal)
    ↓
RelationshipService.nextState(current: relationshipState, tone, emotionSignal)
    ↓
MemoryFormationService.processUserMessage(text) (async, non-blocking)
    ↓
AvatarStateManager.transitionToTalking()
    ↓
Clear request ID
    ↓
Return AssistantTurnResult(reply, emotionState, relationshipState)
    ↓
[Outside Coordinator] TextToSpeechService.synthesizeResponse()
    ↓
PersonalityBehaviorResolver.resolve(tone, relationship, emotion) ← DUPLICATE RESOLUTION
    ↓
SpeechStyleResolver.resolve(tone, relationship, behavior) ← DUPLICATE RESOLUTION
    ↓
mapStyleToVoice(style, language) → VoiceConfiguration
    ↓
VoiceVoxTTSService.synthesize(text, language, voice, style)
    ↓
VoiceVoxTTSService.applySpeechStyle(query, style, voice) → TTS parameters
    ↓
AudioPlaybackService.play(audioFile)
    ↓
AvatarStateManager.transitionToIdle() (after playback completes)
```

**Key Findings**:
1. Behavioral resolution occurs in `AssistantCoordinator` first
2. Behavioral resolution occurs AGAIN in `TextToSpeechService` (duplicate)
3. Session invalidation via UUID protects against stale requests
4. Avatar lifecycle states are properly managed throughout
5. Emotion affects behavior through `PersonalityBehaviorResolver`, not TTS directly

---

## 3. COMPONENT MAP

### Domain Layer (AriaDomain)

| File | Responsibility |
|------|---------------|
| `Character/CharacterProfile.swift` | Static personality definition (traits, guidelines, speakingStyle, toneGuidelines) |
| `Character/PersonalityBehavior.swift` | Dynamic behavior state (teasingLevel, affectionLevel, formalityLevel, emotionalWarmth, tsundereEnabled) |
| `Character/SpeechStyle.swift` | Speech style state (sentenceLengthPreference, emojiUsageLevel, casualMarkerUsage, emotionalExpressionLevel, reactionBeforeAnswer, avoidFormalLanguage) |
| `Conversation/ConversationTone.swift` | Enum of conversation tones (casual, serious, joking, affectionate, rude, achievement, technical, emotional) |
| `Emotion/EmotionKind.swift` | Enum of emotion types (neutral, happy, affectionate, embarrassed, annoyed, sad, worried, excited, playful, angry) |
| `Emotion/EmotionState.swift` | Current emotion state with intensity and timestamp |
| `Emotion/EmotionSignal.swift` | Advisory emotion suggestion from LLM |
| `Emotion/EmotionEngining.swift` | Protocol for emotion state transition logic |
| `Relationship/RelationshipState.swift` | Relationship metrics (warmth, familiarity, interactionCount) |
| `Relationship/RelationshipContext.swift` | Derived relationship context for prompting |
| `Relationship/RelationshipLevel.swift` | Enum of relationship depth (stranger, acquaintance, familiar, close, trusted) |
| `Relationship/RelationshipEvolving.swift` | Protocol for relationship state evolution |
| `Avatar/AvatarState.swift` | Avatar lifecycle states (idle, thinking, talking, listening) |
| `LLM/LLMRequest.swift` | LLM request structure |
| `LLM/LLMResponding.swift` | Protocol for LLM providers |
| `LLM/LLMResponse.swift` | LLM response with optional emotion signal |

### Application Layer (AriaApplication)

| File | Responsibility |
|------|---------------|
| `AssistantCoordinator.swift` | **MAIN ORCHESTRATOR** - Coordinates all conversation flow, state management, and session invalidation |
| `PersonalityBehaviorResolver.swift` | **CENTRAL BEHAVIOR RESOLVER** - Converts tone/relationship/emotion into PersonalityBehavior |
| `SpeechStyleResolver.swift` | **CENTRAL SPEECH STYLE RESOLVER** - Converts tone/relationship/behavior into SpeechStyle |
| `ConversationToneClassifier.swift` | Classifies user input tone using keyword/heuristic rules |
| `EmotionService.swift` | Implements emotion state transitions with smoothing and decay |
| `RelationshipService.swift` | Implements relationship evolution with persistence |
| `RelationshipLevelResolver.swift` | Converts familiarity metrics to RelationshipLevel |
| `SystemPromptBuilder.swift` | Builds system prompt from character profile and runtime context |
| `ConversationService.swift` | Manages conversation history |
| `MemoryContextBuilder.swift` | Builds memory context for prompting |
| `MemoryFormationService.swift` | Async memory formation from conversations |
| `Avatar/AvatarStateManager.swift` | Manages avatar lifecycle state transitions |
| `TextToSpeech/TextToSpeechService.swift` | Orchestrates TTS synthesis with provider fallback |
| `TextToSpeech/JapaneseConversationalFillerService.swift` | Adds emotion-aware fillers to Japanese speech |
| `TextToSpeech/JapaneseConversationalTransformer.swift` | Transforms Japanese text for natural speech |
| `TextToSpeech/JapaneseTTSSegmenter.swift` | Segments Japanese text for natural pauses |
| `TextToSpeech/JapaneseTTSPauseConfiguration.swift` | Configures pause durations between segments |
| `TextToSpeech/TextSanitizer.swift` | Sanitizes text for TTS compatibility |
| `TextToSpeech/TTSProviderResolver.swift` | Selects TTS provider based on language |
| `TextToSpeech/AudioPlaybackService.swift` | Manages audio playback with avatar integration |
| `Language/LanguageDetector.swift` | Detects input language and language override requests |

### Infrastructure Layer (AriaInfrastructure)

| File | Responsibility |
|------|---------------|
| `TextToSpeech/VoiceVoxTTSService.swift` | VOICEVOX TTS provider with speech style application |
| `TextToSpeech/PiperTTSService.swift` | Piper TTS fallback provider |
| `TextToSpeech/AudioConcatenator.swift` | Concatenates audio segments with pauses |
| `LLM/OpenRouterProvider.swift` | OpenRouter LLM provider implementation |
| `Memory/InMemoryMemoryStore.swift` | In-memory memory storage |
| `Memory/PersistentMemoryStore.swift` | Persistent memory storage |
| `Relationship/InMemoryRelationshipStore.swift` | In-memory relationship storage |
| `Relationship/PersistentRelationshipStore.swift` | Persistent relationship storage |

### Presentation Layer (AriaPresentation)

| File | Responsibility |
|------|---------------|
| `Avatar/AvatarRendering.swift` | Live2D avatar rendering |
| `Live2D/Live2DSwiftBridge.swift` | Live2D SDK bridge |
| `Live2D/Live2DWindow.swift` | Live2D window management |
| `DesktopUI/DesktopUIRendering.swift` | Desktop UI rendering |

---

## 4. STATE OWNERSHIP MATRIX

| State | Owner | Lifetime | Source | Consumers | Mutable? | Risk |
|-------|-------|----------|--------|-----------|----------|------|
| **Personality (CharacterProfile)** | AssistantCoordinator (immutable) | Session (static) | Static `.aria` profile | SystemPromptBuilder (base prompt) | No | Low - static, never changes |
| **ConversationTone** | AssistantCoordinator (transient) | Single turn | ConversationToneClassifier.classify(userInput) | PersonalityBehaviorResolver, SpeechStyleResolver, SystemPromptBuilder | No | Low - recalculated each turn |
| **Emotion (EmotionState)** | AssistantCoordinator | Session (with decay) | EmotionService.nextState(current, signal) | PersonalityBehaviorResolver, JapaneseConversationalFillerService, AssistantTurnResult | Yes | Medium - can become stale if session invalidation fails |
| **RelationshipState** | AssistantCoordinator + RelationshipService | Session (with persistence) | RelationshipService.nextState(current, tone, signal) | PersonalityBehaviorResolver, SpeechStyleResolver, SystemPromptBuilder, MemoryContextBuilder | Yes | Low - persistence helps consistency |
| **RelationshipContext** | Derived (computed) | Single turn | RelationshipContext(from: RelationshipState) | SpeechStyleResolver, SystemPromptBuilder | No | Low - always derived from current state |
| **PersonalityBehavior** | Derived (computed) | Single turn | PersonalityBehaviorResolver.resolve(tone, relationship, emotion) | SpeechStyleResolver, SystemPromptBuilder, TextToSpeechService | No | Low - always derived from current inputs |
| **SpeechStyle** | Derived (computed) | Single turn | SpeechStyleResolver.resolve(tone, relationship, behavior) | SystemPromptBuilder, TextToSpeechService | No | Low - always derived from current inputs |
| **AvatarState** | AvatarStateManager | Session (transitions) | AvatarStateManager transitions | Live2D rendering, AudioPlaybackService | Yes | Low - protected by state validation |
| **RuntimeSession (requestID)** | AssistantCoordinator | Single turn | UUID generation per request | Session invalidation checks | No | Low - UUID ensures uniqueness |
| **MuteState** | AudioPlaybackService | Session | User commands | Audio playback | Yes | Low - simple boolean flag |
| **Memory** | MemoryService | Persistent | MemoryFormationService | MemoryContextBuilder | Yes | Low - persistence + quality guards |

**Key Findings**:
- All mutable state is properly owned by specific services
- Derived state (PersonalityBehavior, SpeechStyle, RelationshipContext) is never stored, only computed
- Session invalidation via UUID protects against stale emotional state
- No ambiguous ownership identified

---

## 5. EMOTION FLOW

```
LLM Response (LLMResponse.emotionSignal?)
    ↓
AssistantCoordinator.handleUserInput()
    ↓
EmotionService.nextState(current: emotionState, signal: response.emotionSignal)
    ↓
EmotionState (current, intensity, updatedAt)
    ↓
PersonalityBehaviorResolver.resolve(tone, relationship, emotion) ← EMOTION AFFECTS BEHAVIOR
    ↓
PersonalityBehavior (teasingLevel, affectionLevel, formalityLevel, emotionalWarmth, tsundereEnabled)
    ↓
SpeechStyleResolver.resolve(tone, relationship, behavior) ← BEHAVIOR AFFECTS SPEECH STYLE
    ↓
SpeechStyle (emotionalExpressionLevel, ...)
    ↓
SystemPromptBuilder.behaviorContext(behavior) ← BEHAVIOR AFFECTS PROMPT
    ↓
SystemPromptBuilder.speechStyleContext(style) ← SPEECH STYLE AFFECTS PROMPT
    ↓
LLM (next response influenced by emotion-aware prompt)
    ↓
[For Japanese] JapaneseConversationalFillerService.addFillers(text, tone, emotion, relationship) ← EMOTION AFFECTS FILLERS
    ↓
TextToSpeechService.synthesizeResponse(text, emotion, relationship, tone)
    ↓
PersonalityBehaviorResolver.resolve(tone, relationship, emotion) ← DUPLICATE RESOLUTION
    ↓
SpeechStyleResolver.resolve(tone, relationship, behavior) ← DUPLICATE RESOLUTION
    ↓
mapStyleToVoice(style, language) → VoiceConfiguration
    ↓
VoiceVoxTTSService.applySpeechStyle(query, style, voice) ← SPEECH STYLE AFFECTS TTS
    ↓
TTS audio with emotional prosody (via intonationScale, NOT pitchScale)
```

**Key Findings**:
- Emotion flows through `PersonalityBehaviorResolver` to influence behavior
- Emotion does NOT directly modify TTS parameters
- Emotion affects Japanese fillers directly
- **NO direct emotion → TTS transformation** (prevents previous regression)
- `pitchScale` is preserved as native VOICEVOX value
- Emotional expression in TTS is achieved through `intonationScale` only

---

## 6. PERSONALITY FLOW

```
CharacterProfile (static)
    ↓
SystemPromptBuilder.build(for: character) → basePrompt
    ↓
AssistantCoordinator (stores basePrompt, rendered once at init)
    ↓
[Per Turn] PersonalityBehaviorResolver.resolve(tone, relationship, emotion)
    ↓
PersonalityBehavior (dynamic per-turn behavior)
    ↓
SystemPromptBuilder.behaviorContext(behavior) → behaviorContext
    ↓
Combined prompt: basePrompt + behaviorContext + ...
    ↓
LLM response influenced by personality-aware prompt
    ↓
PersonalityBehavior also affects SpeechStyleResolver
    ↓
SpeechStyle affects TTS voice parameters
```

**Key Findings**:
- Static personality (CharacterProfile) is rendered once at init
- Dynamic personality behavior (PersonalityBehavior) is computed per turn
- Personality influences both LLM prompt and TTS speech style
- **NO duplication of personality logic** - single source of truth in CharacterProfile

---

## 7. TONE FLOW

```
User Input
    ↓
ConversationToneClassifier.classify(text) → ConversationTone
    ↓
PersonalityBehaviorResolver.resolve(tone, relationship, emotion)
    ↓
SpeechStyleResolver.resolve(tone, relationship, behavior)
    ↓
SystemPromptBuilder.relationshipContext(relationshipState, tone)
    ↓
LLM response influenced by tone-aware prompt
    ↓
TTS speech style influenced by tone
```

**Key Findings**:
- Tone is transient (recalculated each turn from user input)
- Tone is NOT treated as emotion (separate concepts)
- Tone influences behavior, speech style, and prompt
- **NO duplication of tone classification** - single classifier

---

## 8. RELATIONSHIP FLOW

```
RelationshipState (warmth, familiarity, interactionCount)
    ↓
RelationshipContext(from: relationshipState)
    ↓
PersonalityBehaviorResolver.resolve(tone, relationship, emotion)
    ↓
SpeechStyleResolver.resolve(tone, relationship, behavior)
    ↓
SystemPromptBuilder.relationshipContext(relationshipState, tone)
    ↓
SystemPromptBuilder.relationshipDepthContext(relationshipContext)
    ↓
LLM response influenced by relationship-aware prompt
    ↓
TTS speech style influenced by relationship level
```

**Key Findings**:
- Relationship state is persistent (via RelationshipService)
- Relationship affects behavior, speech style, and prompt
- Relationship is NOT mixed with temporary emotion
- **NO duplication of relationship logic** - single evolution path

---

## 9. SPEECH STYLE FLOW

```
ConversationTone
    ↓
RelationshipContext
    ↓
PersonalityBehavior
    ↓
SpeechStyleResolver.resolve(tone, relationship, behavior) → SpeechStyle
    ↓
SystemPromptBuilder.speechStyleContext(style) → prompt influence
    ↓
TextToSpeechService.mapStyleToVoice(style, language) → VoiceConfiguration
    ↓
VoiceVoxTTSService.applySpeechStyle(query, style, voice) → TTS parameters
    ↓
TTS audio with style-aware prosody
```

**Transformation Map**:

| SpeechStyle Field | System Prompt Effect | TTS Effect |
|------------------|---------------------|------------|
| `sentenceLengthPreference` | "Prefer shorter/longer sentences" | None |
| `emojiUsageLevel` | Emoji usage guidance | None |
| `casualMarkerUsage` | "Use conversational markers frequently/sparingly" | None |
| `emotionalExpressionLevel` | "Be emotionally expressive/subtle" | `intonationScale` (1.2 high, 0.8 low, 1.0 normal) |
| `reactionBeforeAnswer` | "React before answering" | None |
| `avoidFormalLanguage` | "Avoid/formal language acceptable" | `VoiceStyle` selection (casual/natural/energetic/warm) |

**TTS Parameter Mapping** (from `VoiceVoxTTSService.mapStyleToVoiceVoxParameters`):

```swift
// SpeechStyle → VoiceStyle mapping
if style.emotionalExpressionLevel > 0.7 {
    voiceStyle = .warm
} else if style.reactionBeforeAnswer {
    voiceStyle = .energetic
} else if style.avoidFormalLanguage {
    voiceStyle = .casual
} else {
    voiceStyle = .natural
}

// SpeechStyle → intonationScale mapping
if style.emotionalExpressionLevel > 0.7 {
    parameters["intonationScale"] = 1.2 // More expressive
} else if style.emotionalExpressionLevel < 0.4 {
    parameters["intonationScale"] = 0.8 // Less expressive
} else {
    parameters["intonationScale"] = 1.0 // Normal
}

// CRITICAL: pitchScale is NEVER modified
// Native VOICEVOX value from /audio_query is preserved
```

**Key Findings**:
- **ONE FINAL SpeechStyle** produced by SpeechStyleResolver
- **NO multiple independent emotional transformations**
- **pitchScale preservation is guaranteed** (critical fix from previous regression)
- Emotional expression achieved through `intonationScale` only
- SpeechStyle affects both prompt and TTS consistently

---

## 10. AVATAR FLOW

### Lifecycle State Management

```
idle (default)
    ↓
User input received
    ↓
AvatarStateManager.transitionToThinking()
    ↓
LLM processing
    ↓
AvatarStateManager.transitionToTalking()
    ↓
TTS playback
    ↓
AvatarStateManager.transitionToIdle()
```

### Emotional Expression

**Emotional expression is NOT handled through AvatarState lifecycle.**

Current emotional expression mechanisms:
1. **Through TTS**: Emotional prosody via `intonationScale`
2. **Through prompt**: Emotion-aware behavior instructions
3. **Through Japanese fillers**: Emotion-specific hesitation markers
4. **Future**: Live2D expressions/animations (not yet implemented in current code)

**AvatarState remains purely lifecycle-based**:
- `.idle` - Waiting for input
- `.thinking` - Processing LLM request
- `.talking` - Speaking TTS audio
- `.listening` - Waiting for user input during conversation

**Key Findings**:
- AvatarState is properly separated from emotional state
- NO emotion fields in AvatarState enum
- Emotional expression is handled through other channels (TTS, prompt)
- Avatar lifecycle transitions are protected by validation
- Cancellation/errors return avatar to idle (guaranteed cleanup)

---

## 11. DUPLICATE RESPONSIBILITY FINDINGS

### Finding 1: Duplicate PersonalityBehaviorResolver Calls

**File**: `AssistantCoordinator.swift` (line 144) and `TextToSpeechService.swift` (lines 100, 159)

**Function/Type**: `PersonalityBehaviorResolver.resolve()`

**Responsibility**: Convert tone/relationship/emotion into PersonalityBehavior

**Why It Is Duplicated**: 
- `AssistantCoordinator` resolves behavior for prompt generation
- `TextToSpeechService` resolves behavior again for TTS voice mapping

**Severity**: MEDIUM

**Impact**: 
- Unnecessary computation (same inputs produce same output)
- Potential for inconsistency if inputs differ between calls
- Violates single-computation principle

**Recommendation**: Pass resolved `PersonalityBehavior` from `AssistantCoordinator` to `TextToSpeechService` instead of re-resolving.

---

### Finding 2: Duplicate SpeechStyleResolver Calls

**File**: `AssistantCoordinator.swift` (line 160) and `TextToSpeechService.swift` (lines 102, 161)

**Function/Type**: `SpeechStyleResolver.resolve()`

**Responsibility**: Convert tone/relationship/behavior into SpeechStyle

**Why It Is Duplicated**: 
- `AssistantCoordinator` resolves speech style for prompt generation
- `TextToSpeechService` resolves speech style again for TTS voice mapping

**Severity**: MEDIUM

**Impact**: 
- Unnecessary computation
- Potential for inconsistency if inputs differ between calls
- Violates single-computation principle

**Recommendation**: Pass resolved `SpeechStyle` from `AssistantCoordinator` to `TextToSpeechService` instead of re-resolving.

---

### Finding 3: RelationshipContext Computation

**File**: `AssistantCoordinator.swift` (lines 151-157) and `TextToSpeechService.swift` (line 101)

**Function/Type**: `RelationshipContext(from: relationshipState)`

**Responsibility**: Derive relationship context from relationship state

**Why It Is Duplicated**: 
- Computed in both `AssistantCoordinator` and `TextToSpeechService`

**Severity**: LOW

**Impact**: 
- Minimal (computation is trivial)
- Could be avoided by passing derived context

**Recommendation**: Minor optimization - pass `RelationshipContext` instead of re-computing.

---

**Summary**: 3 duplicate responsibility findings, all MEDIUM/LOW severity. No CRITICAL or HIGH severity duplications found. The architecture is fundamentally sound with minor optimization opportunities.

---

## 12. STALE STATE / RACE CONDITION FINDINGS

### Scenario A: Late Request A Overwriting Request B's State

**Question**: Can Request A overwrite Request B's emotion/behavior/avatar/speech state?

**Answer**: NO

**Protection Mechanism**:
```swift
// AssistantCoordinator.swift lines 95-97
let requestID = UUID()
currentRequestID = requestID

// AssistantCoordinator.swift lines 115-122
guard currentRequestID == requestID else {
    print("[Conversation] Request \(requestID) was invalidated by newer request")
    if let manager = avatarStateManager {
        try? await manager.transitionToIdle()
    }
    throw AriaError.invalidState(reason: "Request was superseded by newer input")
}
```

**Analysis**:
- Each request gets a unique UUID
- `currentRequestID` is updated to the latest request
- Stale requests are rejected via guard check
- Avatar is returned to idle on stale request detection
- Emotion/relationship state updates only occur after successful validation

**Status**: PROTECTED

---

### Scenario B: Request A's Cleanup Incorrectly Resetting Request B

**Question**: Can Request A's eventual cleanup incorrectly reset Request B?

**Answer**: NO

**Protection Mechanism**:
```swift
// AssistantCoordinator.swift lines 260-285
guard currentRequestID == requestID else {
    print("[Conversation] Request \(requestID) was invalidated during LLM processing")
    if let manager = avatarStateManager {
        try? await manager.transitionToIdle()
    }
    // Return graceful response, don't modify state
    return AssistantTurnResult(...)
}
```

**Analysis**:
- Stale requests return early without modifying state
- Avatar cleanup only occurs for the stale request itself
- Active request (Request B) continues with its own `requestID`
- No shared mutable state between requests

**Status**: PROTECTED

---

### Scenario C: Stale Speech State or Emotional State Surviving

**Question**: Can stale speech state or emotional state survive?

**Answer**: NO

**Protection Mechanism**:
```swift
// AssistantCoordinator.swift lines 358-359
currentRequestID = nil
```

**Analysis**:
- `currentRequestID` is cleared after successful completion
- New requests get new UUIDs
- Emotion/relationship state is updated atomically per valid request
- Audio playback has its own session tracking via `AudioPlaybackService`
- TTS cancellation is handled independently

**Status**: PROTECTED

---

### Additional Protections

1. **Avatar State Validation**: `AvatarStateManager.isValidTransition()` prevents invalid state transitions
2. **Cancellation Safety**: All async operations check `Task.isCancelled`
3. **Error Recovery**: LLM/TTS failures return avatar to idle
4. **Memory Formation**: Async and non-blocking, doesn't affect conversation flow

**Summary**: Phase 4 session invalidation fully protects emotional/personality/avatar state from stale requests. All scenarios are protected by UUID-based validation.

---

## 13. MULTILINGUAL FINDINGS

### Language Detection and Selection

**Location**: `LanguageDetector.swift`

**Process**:
```swift
let detectedLanguage = LanguageDetector.detect(text)
let overrideLanguage = LanguageDetector.detectLanguageOverride(text)
if let overrideLanguage = overrideLanguage {
    languageSettings.setConversationOverride(overrideLanguage)
}
```

**Supported Languages**:
- Indonesian (default)
- Japanese
- English
- Russian

---

### Language Effects on Personality

**Finding**: Language does NOT affect personality behavior resolution

**Evidence**:
- `PersonalityBehaviorResolver.resolve()` does not take language as input
- Personality behavior depends only on tone, relationship, and emotion
- `CharacterProfile` is language-agnostic

**Status**: CORRECT - Language should not change personality

---

### Language Effects on Tone

**Finding**: Language does NOT affect tone classification

**Evidence**:
- `ConversationToneClassifier` has language-agnostic keyword lists
- Includes Indonesian, English, and Japanese markers
- Tone classification is independent of output language setting

**Status**: CORRECT - Tone detection is language-aware but personality-independent

---

### Language Effects on Emotion

**Finding**: Language does NOT affect emotion processing

**Evidence**:
- `EmotionService.nextState()` does not take language as input
- Emotion transition logic is language-agnostic
- Emotion depends only on current state and LLM signal

**Status**: CORRECT - Emotion processing is language-independent

---

### Language Effects on Speech Style

**Finding**: Language affects speech style through TTS voice selection only

**Evidence**:
```swift
// TextToSpeechService.swift lines 199-213
if language == .japanese {
    baseVoice = VoiceConfiguration.ariaJapanese
} else if language == .indonesian {
    baseVoice = useFallback ? VoiceConfiguration.indonesianFallback : VoiceConfiguration.ariaIndonesian
} else if language == .english {
    baseVoice = VoiceConfiguration.englishDefault
} else if language == .russian {
    baseVoice = VoiceConfiguration.russianDefault
}
```

**Status**: CORRECT - Language affects voice selection, not behavioral logic

---

### Japanese-Specific Processing

**Additional Components**:
1. `JapaneseConversationalTransformer` - Transforms text for natural spoken Japanese
2. `JapaneseConversationalFillerService` - Adds emotion-aware fillers
3. `JapaneseTTSSegmenter` - Segments text for natural pauses
4. `JapaneseTTSPauseConfiguration` - Configures pause durations

**Key Finding**: Japanese-specific processing is ADDITIVE, not a different behavioral system

**Evidence**:
- Japanese fillers use the SAME emotion state as other languages
- Personality behavior resolution is identical across languages
- Only text realization and TTS voice selection differ

**Status**: CORRECT - Emotion → Behavior pipeline is language-independent

---

### System Prompt Language Instructions

**Location**: `SystemPromptBuilder.languagePolicyContext()`

**Content**:
- Input/output language independence
- Language-specific conversational markers
- Japanese-specific spoken structure guidelines
- Personality consistency instruction: "Maintain Aria's personality... regardless of language"

**Status**: CORRECT - Language affects text realization, not core personality

---

**Summary**: Multilingual architecture is correctly implemented. Language affects only text realization and TTS voice selection, NOT the fundamental emotion → behavior pipeline. No language-specific emotion logic duplication found.

---

## 14. TEST COVERAGE

### Existing Test Coverage

| Component | Test File | Coverage |
|-----------|-----------|----------|
| **PersonalityBehaviorResolver** | `PersonalityBehaviorResolverTests.swift` | COMPREHENSIVE - Tests tone/relationship/emotion combinations, technical overrides, emotional overrides |
| **SpeechStyleResolver** | `SpeechStyleResolverTests.swift` | COMPREHENSIVE - Tests tone/relationship/behavior combinations, formality, emotion adjustments |
| **EmotionService** | `EmotionServiceTests.swift`, `EmotionServiceTransitionTests.swift` | COMPREHENSIVE - Tests signal adoption, decay, smoothing, transitions |
| **ConversationToneClassifier** | `ConversationToneClassifierTests.swift` | COMPREHENSIVE - Tests all tone classifications with keyword matching |
| **RelationshipService** | `RelationshipServiceTests.swift`, `RelationshipPersistenceIntegrationTests.swift` | COMPREHENSIVE - Tests warmth/familiarity evolution, persistence |
| **CharacterProfile** | `CharacterProfileTests.swift` | BASIC - Tests profile structure and defaults |
| **SpeechStyle** | `SpeechStyleTests.swift` | BASIC - Tests style presets and parameters |
| **AvatarStateManager** | `AvatarStateManagerTests.swift` | COMPREHENSIVE - Tests state transitions, validation, animation parameters |
| **AssistantCoordinator** | `AssistantCoordinatorTests.swift`, `AssistantCoordinatorMemoryIntegrationTests.swift`, `AssistantCoordinatorMemoryFormationTests.swift` | COMPREHENSIVE - Tests full conversation flow, memory integration, cancellation |
| **TextToSpeechService** | `TextToSpeechServiceTests.swift` | COMPREHENSIVE - Tests synthesis, fallback, error handling |
| **VoiceVoxTTSService** | `VoiceVoxTTSServiceTests.swift` | COMPREHENSIVE - Tests API integration, speech style application, WAV validation |
| **PiperTTSService** | `PiperTTSServiceTests.swift` | BASIC - Tests basic synthesis |
| **JapaneseConversationalFillerService** | `JapaneseConversationalFillerServiceTests.swift` | COMPREHENSIVE - Tests emotion-aware filler selection, repetition prevention |
| **JapaneseConversationalTransformer** | `JapaneseConversationalTransformerTests.swift` | COMPREHENSIVE - Tests text transformation for natural speech |
| **JapaneseTTSSegmenter** | `JapaneseTTSSegmenterTests.swift` | COMPREHENSIVE - Tests segmentation logic |
| **MemoryContextBuilder** | `MemoryContextBuilderTests.swift` | COMPREHENSIVE - Tests memory context construction |
| **MemoryFormationService** | `MemoryFormationServiceTests.swift` | COMPREHENSIVE - Tests async memory formation |
| **RuntimePromptGeneration** | `RuntimePromptGenerationTests.swift` | COMPREHENSIVE - Tests full prompt assembly with all context sections |

---

### Missing Coverage

| Area | Missing Tests | Risk |
|------|---------------|------|
| **Emotion → TTS Integration** | Tests verifying emotion flows correctly through behavior → speech style → TTS parameters | LOW - Individual components are tested, integration is implicit |
| **Avatar Emotional Expression** | Tests for future Live2D emotional expression system | N/A - Not yet implemented |
| **Cross-Language Behavior Consistency** | Tests verifying personality behavior is identical across languages | LOW - Logic is language-independent by design |
| **Stale State Scenarios** | Specific tests for the 3 stale state scenarios analyzed in this audit | MEDIUM - Should add explicit tests for session invalidation edge cases |
| **Duplicate Resolution Prevention** | Tests verifying PersonalityBehavior/SpeechStyle are not re-resolved unnecessarily | LOW - Optimization issue, not correctness issue |

---

### Risky Untested Behavior

| Behavior | Risk | Severity |
|----------|------|----------|
| **Session invalidation during concurrent requests** | Race conditions if user sends multiple inputs rapidly | MEDIUM |
| **Emotion state consistency across TTS re-resolution** | Potential inconsistency if duplicate resolution produces different results | LOW |
| **Avatar state cleanup on all error paths** | Avatar might not return to idle on unanticipated errors | LOW |
| **Memory formation failure handling** | Async memory formation failures are silently ignored | LOW |

---

**Summary**: Test coverage is COMPREHENSIVE for core behavioral components. Missing coverage is primarily for integration scenarios and edge cases. No critical untested behavior identified.

---

## 15. RECOMMENDED PHASE 5 CHANGES

### Must Fix

**None identified** - The architecture is fundamentally sound. No critical issues require immediate fixes.

---

### Should Fix

#### 1. Eliminate Duplicate PersonalityBehaviorResolver Calls

**File**: `TextToSpeechService.swift`

**Change**: Modify `synthesizeResponse()` to accept `PersonalityBehavior` as parameter instead of re-resolving.

**Rationale**: 
- Eliminates unnecessary computation
- Ensures consistency between prompt and TTS behavior
- Follows single-computation principle

**Implementation**:
```swift
// AssistantCoordinator.swift
let behavior = PersonalityBehaviorResolver.resolve(...)
let speechStyle = SpeechStyleResolver.resolve(...)
let result = AssistantTurnResult(reply, emotionState, relationshipState, behavior, speechStyle)

// TextToSpeechService.swift
public func synthesizeResponse(_ text: String, emotion: EmotionState, relationship: RelationshipState, tone: ConversationTone, behavior: PersonalityBehavior, speechStyle: SpeechStyle) async throws -> URL?
```

---

#### 2. Eliminate Duplicate SpeechStyleResolver Calls

**File**: `TextToSpeechService.swift`

**Change**: Modify `synthesizeResponse()` to accept `SpeechStyle` as parameter instead of re-resolving.

**Rationale**: Same as above - consistency and efficiency.

**Implementation**: Combined with #1 above.

---

#### 3. Add Stale State Scenario Tests

**File**: New test file `AssistantCoordinatorStaleStateTests.swift`

**Change**: Add explicit tests for the 3 stale state scenarios analyzed in this audit.

**Rationale**: 
- Ensures session invalidation works correctly
- Documents protection mechanisms
- Prevents regressions

**Implementation**:
```swift
func testLateRequestCannotOverwriteNewerRequestState()
func testStaleRequestCleanupDoesNotAffectActiveRequest()
func testStaleSpeechStateCannotSurviveNewRequest()
```

---

### Optional

#### 1. Pass RelationshipContext Instead of Re-computing

**File**: `TextToSpeechService.swift`

**Change**: Accept `RelationshipContext` as parameter instead of `RelationshipState`.

**Rationale**: Minor optimization - avoids trivial computation.

**Implementation**:
```swift
public func synthesizeResponse(_ text: String, emotion: EmotionState, relationshipContext: RelationshipContext, tone: ConversationTone, behavior: PersonalityBehavior, speechStyle: SpeechStyle) async throws -> URL?
```

---

#### 2. Add Cross-Language Behavior Consistency Tests

**File**: New test file `MultilingualBehaviorConsistencyTests.swift`

**Change**: Verify personality behavior is identical across different languages.

**Rationale**: Documents language-independence of behavioral logic.

**Implementation**:
```swift
func testPersonalityBehaviorIsLanguageIndependent()
func testSpeechStyleResolutionIsLanguageIndependent()
```

---

#### 3. Add Emotion-to-TTS Integration Tests

**File**: New test file `EmotionTTSIntegrationTests.swift`

**Change**: Verify emotion flows correctly through behavior → speech style → TTS parameters.

**Rationale**: Documents end-to-end emotional expression in TTS.

**Implementation**:
```swift
func testEmotionAffectsSpeechStyle()
func testSpeechStyleAffectsTTSParameters()
func testPitchScalePreservationAcrossEmotions()
```

---

## 16. PHASE 5 IMPLEMENTATION PLAN

### Step 1: Eliminate Duplicate Resolution Calls (Should Fix #1, #2)

1. Modify `AssistantTurnResult` to include `behavior` and `speechStyle`
2. Update `AssistantCoordinator.handleUserInput()` to pass resolved behavior/speech style
3. Update `TextToSpeechService.synthesizeResponse()` signature to accept behavior/speech style
4. Remove duplicate `PersonalityBehaviorResolver.resolve()` calls from `TextToSpeechService`
5. Remove duplicate `SpeechStyleResolver.resolve()` calls from `TextToSpeechService`
6. Update all callers of `TextToSpeechService.synthesizeResponse()`
7. Run existing tests to ensure no regressions

**Estimated Effort**: 2-3 hours

**Risk**: LOW - Changes are parameter additions, removals are safe re-factoring

---

### Step 2: Add Stale State Scenario Tests (Should Fix #3)

1. Create `AssistantCoordinatorStaleStateTests.swift`
2. Implement test for Scenario A (late request overwriting)
3. Implement test for Scenario B (cleanup affecting active request)
4. Implement test for Scenario C (stale speech state survival)
5. Run tests to verify session invalidation protections
6. Document test coverage

**Estimated Effort**: 2-3 hours

**Risk**: LOW - Tests document existing behavior, no code changes required

---

### Step 3: Optional Enhancements (Optional #1, #2, #3)

1. Implement `RelationshipContext` parameter passing (if desired)
2. Implement cross-language consistency tests (if desired)
3. Implement emotion-to-TTS integration tests (if desired)

**Estimated Effort**: 4-6 hours (all optional)

**Risk**: LOW - All are additive tests or minor optimizations

---

### Total Estimated Effort

**Must Fix**: 0 hours
**Should Fix**: 4-6 hours
**Optional**: 4-6 hours

**Total**: 4-12 hours depending on optional enhancements

---

## 17. IMPORTANT DECISION RULE ANSWERS

### A. Does Aria already have a centralized behavioral resolution layer?

**Answer**: YES

**Explanation**: 
- `PersonalityBehaviorResolver` is the single authoritative behavioral resolution point
- `SpeechStyleResolver` is the single authoritative speech style resolution point
- Both resolvers follow a clear pipeline: tone → relationship → emotion → behavior → speech style
- All behavioral decisions flow through these centralized resolvers
- The only issue is duplicate calls to these resolvers, not duplicate logic

---

### B. Is emotion currently being applied to TTS in more than one place?

**Answer**: NO

**Explanation**:
- Emotion affects TTS ONLY through the `PersonalityBehaviorResolver` → `SpeechStyleResolver` → `VoiceStyle` pipeline
- Emotion does NOT directly modify TTS parameters
- The previous regression (multiple emotional transformations) has been fixed
- `pitchScale` is explicitly preserved as native VOICEVOX value
- Emotional expression in TTS is achieved through `intonationScale` only
- No other emotion → TTS transformation paths exist

---

### C. Can stale requests modify emotional/personality/avatar state?

**Answer**: NO

**Explanation**:
- UUID-based session invalidation protects all state modifications
- Stale requests are rejected before any state updates occur
- Avatar cleanup only affects the stale request itself
- Active requests continue with their own UUIDs
- All three stale state scenarios analyzed are protected

---

### D. Is AvatarState properly separated from emotional state?

**Answer**: YES

**Explanation**:
- `AvatarState` enum contains only lifecycle states: idle, thinking, talking, listening
- NO emotion fields exist in `AvatarState`
- Emotional expression is handled through TTS (intonationScale), prompt (behavior instructions), and Japanese fillers
- Avatar lifecycle transitions are independent of emotional state
- Future Live2D emotional expressions will be separate from lifecycle state

---

### E. Does Phase 5 require architectural changes?

**Answer**: MINOR

**Explanation**:
- The fundamental architecture is sound and requires no structural changes
- The only changes needed are:
  1. Eliminate duplicate resolver calls (parameter passing optimization)
  2. Add tests for stale state scenarios (documentation)
  3. Optional enhancements (minor optimizations and additional tests)
- No new abstractions are needed
- No existing systems need replacement
- The emotion → behavior → speech style pipeline is already correctly implemented
- Phase 5 is about strengthening integration, not rebuilding architecture

---

## 18. CONCLUSION

The Phase 5 behavioral architecture audit reveals that Aria has a well-designed, properly integrated emotional and personality system. The architecture successfully implements the desired conceptual pipeline with clear separation of concerns and centralized behavioral resolution.

**Key Strengths**:
1. Centralized behavioral resolution through `PersonalityBehaviorResolver` and `SpeechStyleResolver`
2. Proper separation of avatar lifecycle state from emotional expression
3. Effective session invalidation protecting against stale requests
4. Language-independent emotion → behavior pipeline
5. Comprehensive test coverage for core components
6. Correct TTS emotional expression (previous regression fixed)

**Areas for Improvement**:
1. Eliminate duplicate resolver calls (efficiency and consistency)
2. Add explicit stale state scenario tests (documentation)
3. Optional: Add integration tests for emotion-to-TTS flow

**Overall Assessment**: The architecture is production-ready with MINOR improvements recommended. Phase 5 implementation should focus on optimization and documentation rather than structural changes.

---

**Audit Completed**: 2026-08-14
**Auditor**: Devin (AI Assistant)
**Scope**: Phase 5 - Emotional & Personality Runtime Integration
**Status**: READY FOR IMPLEMENTATION (Step 2)
