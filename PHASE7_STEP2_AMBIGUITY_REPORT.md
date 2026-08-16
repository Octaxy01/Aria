# PHASE 7 STEP 2: Ambiguity Clarification Implementation Report

## Overview

This report documents the implementation of the ambiguity clarification flow for the Aria assistant system. The feature enables Aria to detect ambiguous entity references in tool calls and prompt the user for clarification before executing tools.

## Objectives

1. Detect ambiguous entity references in tool calls
2. Generate natural clarification messages in Indonesian
3. Parse user answers (numbers, names, Indonesian positional phrases)
4. Integrate clarification flow into ToolOrchestrator and AssistantCoordinator
5. Ensure session safety and proper state management
6. Prevent clarification interactions from creating memories
7. Preserve personality and TTS during clarification

## Architecture

### Components

#### 1. ClarificationManager (Actor)
- **Location**: `Sources/AriaDomain/Entity/ClarificationManager.swift`
- **Purpose**: Manages clarification state with session safety
- **Key Methods**:
  - `setSessionID(_:)` - Sets active session ID
  - `storeClarification(_:sessionID:)` - Stores pending clarification request
  - `getPendingClarification(sessionID:)` - Retrieves pending clarification for session
  - `clearClarification(sessionID:)` - Clears clarification for specific session
  - `clearAll()` - Clears all clarification state
  - `hasPendingClarification(sessionID:)` - Checks if session has pending clarification

#### 2. ClarificationMessageBuilder (Struct)
- **Location**: `Sources/AriaDomain/Entity/ClarificationMessageBuilder.swift`
- **Purpose**: Generates natural Indonesian clarification messages
- **Key Methods**:
  - `buildClarificationMessage(candidates:reference:)` - Builds clarification message with numbered candidates

#### 3. ClarificationAnswerParser (Struct)
- **Location**: `Sources/AriaDomain/Entity/ClarificationAnswerParser.swift`
- **Purpose**: Parses user answers to clarification requests
- **Supported Answer Types**:
  - Numeric positions (1, 2, 3, etc.)
  - Entity names (partial matching)
  - Indonesian positional phrases ("yang pertama", "yang kedua", etc.)
  - Cancellation keywords ("batal", "cancel", "tidak", "no", "skip", "lewat")
- **Key Methods**:
  - `parseAnswer(_:clarification:)` - Parses user answer and returns `ClarificationAnswer`

#### 4. ClarificationRequest (Struct)
- **Location**: `Sources/AriaDomain/Entity/ClarificationRequest.swift`
- **Purpose**: Model for storing clarification state
- **Properties**:
  - `originalUserMessage` - The original user message that triggered ambiguity
  - `candidates` - Array of ambiguous candidate entities
  - `sessionID` - Session identifier for safety
  - `pendingToolCall` - The tool call waiting for clarification

#### 5. ClarificationAnswer (Enum)
- **Location**: `Sources/AriaDomain/Entity/ClarificationAnswer.swift`
- **Purpose**: Represents parsed user answer
- **Cases**:
  - `selectedPosition(Int)` - User selected by number
  - `selectedEntity(RuntimeEntity)` - User selected by name
  - `cancelled` - User cancelled the clarification
  - `invalid` - Answer could not be parsed

### Integration Points

#### ToolOrchestrator Integration
- **Location**: `Sources/AriaApplication/ToolOrchestrator.swift`
- **Changes**:
  - Added `clarificationManager` and `clarificationMessageBuilder` as optional dependencies
  - Updated initializer to accept clarification components
  - Added `checkForAmbiguity(in:)` method to detect ambiguous references
  - Added `handleAmbiguity(_:originalToolCall:resolvedToolCall:sessionID:conversation:)` method to handle ambiguity
  - Modified `resolveReferences(in:)` to defer ambiguity handling instead of throwing
  - Integrated ambiguity check in `executeToolLoop` before tool execution

#### AssistantCoordinator Integration
- **Location**: `Sources/AriaApplication/AssistantCoordinator.swift`
- **Changes**:
  - Added `clarificationManager` and `clarificationAnswerParser` as optional dependencies
  - Updated initializer to accept clarification components
  - Added clarification answer handling in `handleUserInput(_:)` before normal processing
  - Added `continueWithResolvedEntity(_:pendingClarification:requestID:text:)` method to continue tool execution after clarification
  - Updated `clearConversation()` to clear clarification state
  - Implemented memory prevention for clarification interactions

## Implementation Details

### Ambiguity Detection

Ambiguity is detected in the `ReferenceResolver` when:
1. Multiple entities with the same name exist in recent context
2. A result set contains multiple entities and the reference is "itu" (that)
3. Positional references cannot be uniquely resolved

The `ResolutionResult` enum includes an `ambiguous([RuntimeEntity])` case to return candidate entities.

### Clarification Flow

1. **Detection Phase**:
   - ToolOrchestrator detects ambiguous reference in tool call
   - Calls `checkForAmbiguity(in:)` to verify ambiguity
   - Returns `ResolutionResult.ambiguous` with candidates

2. **Clarification Phase**:
   - ToolOrchestrator calls `handleAmbiguity(...)`
   - Generates clarification message using `ClarificationMessageBuilder`
   - Creates `ClarificationRequest` with candidates and pending tool call
   - Stores request in `ClarificationManager` with session ID
   - Returns clarification message as LLM response

3. **Answer Phase**:
   - AssistantCoordinator checks for pending clarification on next user input
   - Parses user answer using `ClarificationAnswerParser`
   - Handles different answer types:
     - **Cancelled**: Clears clarification, returns cancellation message
     - **Invalid**: Returns error message, keeps clarification pending
     - **Selected Position/Entity**: Clears clarification, continues with resolved entity

4. **Continuation Phase**:
   - AssistantCoordinator calls `continueWithResolvedEntity(...)`
   - Reconstructs tool call with resolved entity path/identifier
   - Executes tool via ToolOrchestrator
   - Processes response normally
   - Skips memory formation for clarification interactions

### Session Safety

All clarification operations are session-scoped:
- `ClarificationManager` maintains current session ID
- Storage and retrieval require matching session ID
- Session switching automatically invalidates pending clarifications
- `clearConversation()` clears clarification state along with other session state

### Cancellation Handling

Users can cancel clarification using:
- "batal" (Indonesian)
- "cancel" (English)
- "tidak" (Indonesian - no)
- "no" (English)
- "skip"
- "lewat" (Indonesian - pass)

Cancellation clears the clarification state and returns a neutral acknowledgment message.

### Memory Prevention

Clarification interactions do not create memories:
- Memory formation is skipped in `continueWithResolvedEntity(...)`
- This prevents clarification Q&A from polluting the memory system
- Only actual tool execution results are remembered

### Personality and TTS Preservation

During clarification:
- Avatar transitions to thinking state during ambiguity detection
- Avatar transitions to idle after clarification message
- Avatar transitions to talking after tool execution
- Emotion signals are preserved throughout the flow
- TTS is handled normally for all messages

## Testing

### Test Coverage

Created comprehensive test suite in `Tests/AriaApplicationTests/ClarificationFlowTests.swift`:

1. **ClarificationManager Tests**:
   - `testClarificationManagerStoresRequest` - Verifies request storage
   - `testClarificationManagerClearsRequest` - Verifies request clearing
   - `testClarificationManagerSessionSafety` - Verifies session isolation
   - `testClarificationManagerHasPendingClarification` - Verifies pending check
   - `testClarificationManagerClearAll` - Verifies bulk clearing

2. **ClarificationMessageBuilder Tests**:
   - `testClarificationMessageBuilderGeneratesMessage` - Verifies message generation
   - `testClarificationMessageBuilderEmptyCandidates` - Verifies empty candidate handling
   - `testClarificationMessageBuilderSingleCandidate` - Verifies single candidate handling

3. **ClarificationAnswerParser Tests**:
   - `testClarificationAnswerParserParsesNumber` - Verifies numeric parsing
   - `testClarificationAnswerParserParsesName` - Verifies name parsing
   - `testClarificationAnswerParserParsesIndonesianPositional` - Verifies Indonesian phrases
   - `testClarificationAnswerParserParsesCancellation` - Verifies cancellation parsing
   - `testClarificationAnswerParserParsesInvalid` - Verifies invalid answer handling
   - `testClarificationAnswerParserParsesCancelKeywords` - Verifies all cancel keywords

4. **Ambiguity Detection Tests**:
   - `testAmbiguityDetectionMultipleSameName` - Verifies same-name ambiguity
   - `testAmbiguityDetectionResultSet` - Verifies result set ambiguity
   - `testNoAmbiguitySingleEntity` - Verifies single entity resolution

5. **Session Safety Tests**:
   - `testClarificationSessionIsolation` - Verifies multi-session isolation

6. **Cancellation Tests**:
   - `testClarificationCancellationClearsState` - Verifies cancellation clears state

7. **Integration Tests**:
   - `testFullClarificationFlow` - Verifies end-to-end flow
   - `testClarificationFlowWithCancellation` - Verifies cancellation flow
   - `testClarificationFlowWithInvalidAnswer` - Verifies invalid answer retry

## Build Status

- **Main Build**: ✅ Passing
- **Module Dependencies**: ✅ Resolved
- **Compilation Errors**: ✅ Fixed

## Known Issues

None at this time.

## Future Enhancements

1. **Multi-language Support**: Extend clarification messages to Japanese and Russian
2. **Smart Candidate Ordering**: Rank candidates by relevance/recency
3. **Contextual Hints**: Include context in clarification messages (e.g., "the file from yesterday")
4. **Batch Clarification**: Handle multiple ambiguities in a single tool call
5. **Learning**: Remember user preferences for similar ambiguities

## Files Modified

### Core Implementation
- `Sources/AriaDomain/Entity/ClarificationManager.swift` - Created
- `Sources/AriaDomain/Entity/ClarificationMessageBuilder.swift` - Created
- `Sources/AriaDomain/Entity/ClarificationAnswerParser.swift` - Created
- `Sources/AriaDomain/Entity/ClarificationRequest.swift` - Created
- `Sources/AriaDomain/Entity/ClarificationAnswer.swift` - Created

### Integration
- `Sources/AriaApplication/ToolOrchestrator.swift` - Modified
- `Sources/AriaApplication/AssistantCoordinator.swift` - Modified

### Testing
- `Tests/AriaApplicationTests/ClarificationFlowTests.swift` - Created

## Conclusion

The ambiguity clarification flow has been successfully implemented and integrated into the Aria assistant system. The implementation provides:

- Natural Indonesian clarification messages
- Flexible answer parsing supporting multiple formats
- Session-safe state management
- Proper cancellation handling
- Memory prevention for clarification interactions
- Preservation of personality and TTS
- Comprehensive test coverage

The system is ready for testing and deployment.
