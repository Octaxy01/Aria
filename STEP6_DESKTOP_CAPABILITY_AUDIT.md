# STEP 6: DESKTOP CAPABILITY & TOOL ARCHITECTURE AUDIT

## 1. EXECUTIVE SUMMARY

Aria currently has **NO desktop execution capabilities**. The application is purely a conversational AI companion with no ability to launch applications, open files, execute shell commands, or interact with the macOS desktop.

The repository does contain a **placeholder** for future tool architecture (`ToolDefinition.swift`) that was established in Stage 1 for Stage 8 implementation, but no actual tool execution exists.

The current architecture is clean and well-structured, providing a solid foundation for adding safe desktop capabilities. The application appears to be **unsandboxed** based on the absence of entitlements files, which provides flexibility for future desktop tool implementation.

**Overall Assessment**: Aria is ready for Phase 6 desktop capability implementation with MINOR architectural additions needed. No existing behavior needs to be modified.

---

## 2. EXISTING DESKTOP CAPABILITIES

### Current Desktop Capabilities: NONE

Aria currently cannot:
- Launch applications
- Open files or folders
- Execute shell commands
- Retrieve system information
- Interact with macOS desktop APIs
- Control application lifecycle
- Search filesystem
- Modify system settings

### External Process Usage: CONTROLLED (TTS ONLY)

**File**: `Sources/AriaInfrastructure/TextToSpeech/PiperTTSService.swift`

**Function**: External TTS process execution

**API Used**: `Foundation.Process`

**Current Responsibility**: Launch external Piper TTS process for text-to-speech synthesis

**Code Snippet**:
```swift
private var currentProcess: Process?

public init(piperPath: String? = nil, modelDirectory: URL? = nil, audioDirectory: URL? = nil) throws {
    let piperLocations = [
        piperPath,
        "/Users/salmansalim/Library/Python/3.11/bin/piper",
        "/usr/local/bin/piper",
        "/opt/homebrew/bin/piper"
    ].compactMap { $0 }
    
    guard let foundPiper = piperLocations.first(where: { FileManager.default.fileExists(atPath: $0) }) else {
        throw TTSError.externalProcessUnavailable
    }
    
    self.piperPath = foundPiper
}

public func synthesize(text: String, language: Language, voice: VoiceConfiguration, style: SpeechStyle? = nil) async throws -> URL? {
    let process = Process()
    process.executableURL = URL(fileURLWithPath: piperPath)
    var arguments = [
        "-m", modelPath.path,
        "-c", configPath.path,
        "-f", outputFile.path
    ]
    let lengthScale = 1.0 / voice.speed
    arguments.append(contentsOf: ["--length-scale", String(lengthScale)])
    process.arguments = arguments
    // ... process execution
}
```

**Safety Assessment**: SAFE
- Only executes known, fixed TTS binary
- Arguments are controlled and validated
- No user-provided shell commands
- Process lifecycle is managed (cancellation, timeout)
- Isolated to TTS functionality only

**Reusability**: NOT REUSABLE for general desktop tools
- Piper-specific implementation
- Hardcoded arguments for TTS synthesis
- No general process execution abstraction

**Test Coverage**: COMPREHENSIVE
- `PiperTTSServiceTests.swift` covers synthesis, cancellation, error handling

---

## 3. APPLICATION CONTROL FINDINGS

### Application Launching APIs: NONE FOUND

**Search Results**:
- NO `NSWorkspace` usage in Swift files
- NO `NSRunningApplication` usage in Swift files  
- NO `LaunchServices` usage in Swift files
- NO application launching code
- NO application quitting code
- NO application focusing code
- NO installed application enumeration

**Conclusion**: Aria has NO mechanism to control macOS applications.

---

## 4. FILESYSTEM FINDINGS

### Filesystem APIs: LIMITED TO STORAGE & TTS

**File**: `Sources/AriaInfrastructure/Memory/PersistentMemoryStore.swift`

**API Used**: `FileManager`

**Current Responsibility**: Persistent JSON storage for memory entries

**Code Snippet**:
```swift
public init(appName: String = "Aria") {
    let fileManager = FileManager.default
    let appSupportURL = fileManager.urls(for: .applicationSupportDirectory, in: .userDomainMask).first!
    let appDirectory = appSupportURL.appendingPathComponent(appName, isDirectory: true)
    
    try? fileManager.createDirectory(at: appDirectory, withIntermediateDirectories: true)
    
    self.fileURL = appDirectory.appendingPathComponent("memories.json")
}
```

**File**: `Sources/AriaInfrastructure/Relationship/PersistentRelationshipStore.swift`

**API Used**: `FileManager`

**Current Responsibility**: Persistent JSON storage for relationship state

**File**: `Sources/AriaInfrastructure/TextToSpeech/VoiceVoxTTSService.swift`

**API Used**: `FileManager`

**Current Responsibility**: Create audio output directory for TTS files

**File**: `Sources/AriaInfrastructure/TextToSpeech/PiperTTSService.swift`

**API Used**: `FileManager`

**Current Responsibility**: Create audio output directory and verify executable existence

**File**: `Sources/AriaApplication/TextToSpeech/AudioPlaybackService.swift`

**API Used**: `FileManager`

**Current Responsibility**: Verify audio file existence

### Filesystem Abstractions: NONE

**Finding**: NO dedicated filesystem service or abstraction layer exists.

**Current Usage**: Direct `FileManager.default` calls throughout Infrastructure layer

**Ownership**: Individual services manage their own file operations

**Dependencies**: Foundation framework only

**Tests**: Persistent storage tests cover file operations

**Limitations**:
- No centralized file service
- No path abstraction
- No file search capability
- No directory enumeration service
- No security-scoped resource handling
- No bookmark management

**Conclusion**: Filesystem usage is limited to internal storage (memory, relationship, TTS audio). NO file tools or user file access capabilities exist.

---

## 5. SYSTEM INFORMATION FINDINGS

### System Information APIs: NONE FOUND

**Search Results**:
- NO battery information APIs
- NO storage information APIs  
- NO system information APIs
- NO macOS version detection
- NO CPU information retrieval
- NO memory information retrieval

**Conclusion**: Aria has NO system information capabilities.

---

## 6. MACOS PERMISSION & SECURITY FINDINGS

### Sandbox Configuration: UNCERTAIN (LIKELY UNSANDBOXED)

**Search Results**:
- NO `.entitlements` files found
- NO sandbox configuration found in Swift files
- NO Info.plist in AriaApp target (only in build artifacts and third-party)

**File Search**: No entitlements files discovered in the repository

**Package.swift Analysis**: No sandbox-related build settings

**Conclusion**: Application appears to be **UNSandboxED** based on absence of entitlements configuration. This provides flexibility for desktop tool implementation but may require future entitlements for file access and automation.

### File Access Permissions: NONE CONFIGURED

**Finding**: NO TCC (Transparency, Consent, and Control) configurations found

**Current File Access**:
- Application Support directory (for persistent storage)
- Temporary directory (for TTS audio)
- Home directory (for Piper models)

**Security-Scoped Resources**: NONE

**Bookmarks**: NONE

### Automation/Accessibility Permissions: NONE CONFIGURED

**Finding**: NO accessibility or automation entitlements found

**AppleScript**: NO AppleScript usage found in Swift files

**osascript**: NO osascript execution found

**Conclusion**: No automation capabilities currently configured.

---

## 7. LLM TOOL CALLING FINDINGS

### Structured Tool Calling: NOT IMPLEMENTED

**Current LLM Interface**: Simple text request/response

**File**: `Sources/AriaDomain/LLM/LLMRequest.swift`

**Current Structure**:
```swift
public struct LLMRequest: Sendable, Equatable {
    public let messages: [ConversationMessage]
    public let systemContext: String?
}
```

**File**: `Sources/AriaDomain/LLM/LLMResponse.swift`

**Current Structure**:
```swift
public struct LLMResponse: Sendable, Equatable {
    public let text: String
    public let emotionSignal: EmotionSignal?
}
```

**Finding**: NO tool calling mechanism exists

**OpenRouter Implementation**: Simple HTTP-based chat completions with no function calling

**JSON Mode**: NOT configured

**Response Parsing**: Centralized in OpenRouterProvider but only extracts text and emotion signal

**Conclusion**: LLM integration is purely conversational. NO structured tool calling or function execution capabilities exist.

---

## 8. ASSISTANTCOORDINATOR INTEGRATION POINT

### Current Conversation Flow

```
User Input
    ↓
AssistantCoordinator.handleUserInput()
    ↓
[UUID session validation]
    ↓
AvatarStateManager.transitionToThinking()
    ↓
ConversationService.append(role: .user, content: text)
    ↓
Language detection
    ↓
Tone classification
    ↓
PersonalityBehaviorResolver.resolve()
    ↓
SpeechStyleResolver.resolve()
    ↓
SystemPromptBuilder (assemble context)
    ↓
LLMRequest(messages, systemContext)
    ↓
LLMResponding.respond() → LLMResponse(text, emotionSignal?)
    ↓
[UUID validation]
    ↓
Response validation
    ↓
ConversationService.append(role: .assistant, content: text)
    ↓
EmotionService.nextState()
    ↓
RelationshipService.nextState()
    ↓
MemoryFormationService.processUserMessage() [async]
    ↓
AvatarStateManager.transitionToTalking()
    ↓
Return AssistantTurnResult
```

### Future Tool Integration Point

**Recommended Location**: After LLM response, before avatar transition

**Proposed Flow**:
```
LLMResponse(text, emotionSignal?)
    ↓
[Parse for tool calls]
    ↓
If tool call detected:
    ↓
ToolExecutor.execute(toolCall)
    ↓
ToolResult
    ↓
[Aria formulates response about tool result]
    ↓
Continue normal flow
```

**Integration Challenges**:
1. LLM response format needs extension to support tool calls
2. Tool execution must respect UUID session validation
3. Tool execution must be cancellable
4. Tool results must be integrated into conversation history
5. Tool failures must be handled gracefully

**Session Validation Boundary**: Tool execution must check `currentRequestID` before any state mutation

---

## 9. SESSION / CANCELLATION INTEGRATION

### Current Phase 4 Guarantees

**UUID-Based Session Tracking**:
```swift
let requestID = UUID()
currentRequestID = requestID

guard currentRequestID == requestID else {
    // Stale request - return early without state changes
    throw AriaError.invalidState(reason: "Request was superseded by newer input")
}
```

**Cancellation Safety**:
```swift
currentRequestTask?.cancel()
try Task.checkCancellation()
```

**Avatar Cleanup**: Guaranteed on all error paths

### Required Tool Execution Behavior

**Scenario**: Request A tool execution, Request B starts

**Question**: Can Request A still mutate state after Request B becomes active?

**Answer**: NO

**Required Protection**:
```swift
// Tool execution must check session validity
func executeTool(_ toolCall: ToolCall, requestID: UUID) async throws -> ToolResult {
    guard currentRequestID == requestID else {
        throw ToolError.sessionExpired
    }
    
    // Execute tool
    let result = try await toolExecutor.execute(toolCall)
    
    // Double-check session after tool execution
    guard currentRequestID == requestID else {
        throw ToolError.sessionExpired
    }
    
    return result
}
```

**State Mutation Boundary**: Tool execution MUST NOT modify:
- Conversation history (except via tool result integration)
- Avatar state (except via explicit coordinator control)
- Emotion state (except via tool result processing)
- Relationship state (except via tool result processing)

**Cancellation Handling**: Tool execution must respond to `Task.isCancelled`

---

## 10. PROPOSED TOOL ARCHITECTURE

### Minimal Required Components

Based on existing architecture, the minimal components needed are:

#### 1. Domain Layer Extensions

**File**: `Sources/AriaDomain/Tool/` (already exists)

**Existing**: `ToolDefinition.swift` (placeholder)

**Needed Additions**:
```swift
// ToolCall.swift
public struct ToolCall: Sendable, Equatable {
    public let toolName: String
    public let parameters: [String: Sendable]
    public let requestID: UUID
}

// ToolResult.swift
public struct ToolResult: Sendable, Equatable {
    public let success: Bool
    public let data: [String: Sendable]?
    public let error: String?
}

// ToolError.swift (extension to AriaError)
public enum ToolError: Error, Sendable {
    case sessionExpired
    case toolNotFound(name: String)
    case executionFailed(reason: String)
    case permissionDenied(tool: String)
}

// ToolExecuting.swift (protocol)
public protocol ToolExecuting: Sendable {
    func execute(_ call: ToolCall) async throws -> ToolResult
}
```

#### 2. Infrastructure Layer Implementation

**File**: `Sources/AriaInfrastructure/Desktop/` (new directory)

**Components**:
```swift
// DesktopToolExecutor.swift
public actor DesktopToolExecutor: ToolExecuting {
    private let permissionPolicy: ToolPermissionPolicy
    
    public func execute(_ call: ToolCall) async throws -> ToolResult {
        // Validate session
        // Check permissions
        // Execute tool
        // Return result
    }
}

// ToolPermissionPolicy.swift
public struct ToolPermissionPolicy {
    public func canExecute(_ tool: ToolDefinition) -> Bool
}

// Tier 1 Tool Implementations:
// - ApplicationLauncher.swift
// - FileOpener.swift
// - SystemInfoProvider.swift
```

#### 3. Application Layer Integration

**File**: `Sources/AriaApplication/` (extend existing)

**Modification**: Extend `AssistantCoordinator` to include tool execution

**No New Services Needed**: Tool execution can be integrated into existing coordinator

### Architecture Fit

**Existing Pattern**: Domain (protocols) → Application (orchestration) → Infrastructure (implementation)

**Tool Architecture Follows Same Pattern**:
- Domain: `ToolExecuting` protocol, tool types
- Application: Tool execution in `AssistantCoordinator`
- Infrastructure: `DesktopToolExecutor` and concrete tools

**No New Abstractions Needed**: Existing patterns are sufficient

---

## 11. TOOL SAFETY CLASSIFICATION

### Tier 1 — Safe (Phase 6 Implementation)

**Examples**:
- `open_application` - Launch macOS applications
- `open_folder` - Open Finder to specific directory
- `open_file` - Open file with default application
- `get_system_info` - Retrieve macOS version, hardware info
- `get_battery_status` - Get battery level and charging status
- `get_storage_info` - Get disk usage information

**Risk Assessment**: LOW
- Read-only operations
- No data modification
- No destructive actions
- User-visible operations
- Can be undone manually

**Permission Model**: Automatic (no confirmation needed)

---

### Tier 2 — Potentially Sensitive (Future Phases)

**Examples**:
- `find_file` - Search filesystem for files
- `inspect_directory` - List directory contents
- `read_file` - Read file contents
- `get_running_processes` - List running applications

**Risk Assessment**: MEDIUM
- Read access to user data
- Potential privacy concerns
- Information disclosure risks

**Permission Model**: Requires confirmation or scope limiting

---

### Tier 3 — Destructive / High Risk (NOT for Phase 6)

**Examples**:
- `delete_file` - Delete files
- `modify_file` - Write/modify file contents
- `execute_shell_command` - Arbitrary shell execution
- `terminate_process` - Kill running applications
- `change_system_settings` - Modify system preferences

**Risk Assessment**: HIGH
- Destructive operations
- Data loss potential
- Security risks
- System stability risks

**Permission Model**: Requires explicit user confirmation, may need additional entitlements

**Phase 6 Scope**: IMPLEMENT TIER 1 ONLY

---

## 12. TEST COVERAGE

### Existing Test Coverage

| Component | Test File | Coverage |
|-----------|-----------|----------|
| **Process Execution** | `PiperTTSServiceTests.swift` | COMPREHENSIVE - TTS process execution, cancellation, error handling |
| **File Operations** | `PersistentMemoryStoreTests.swift`, `PersistentRelationshipStoreTests.swift` | COMPREHENSIVE - JSON persistence, file I/O |
| **AssistantCoordinator** | `AssistantCoordinatorTests.swift` | COMPREHENSIVE - Conversation flow, cancellation, session management |
| **LLM Integration** | `RealLLMMemoryRuntimeValidationTests.swift` | COMPREHENSIVE - Real LLM integration, response parsing |
| **Cancellation** | `AssistantCoordinatorTests.swift`, `AudioPlaybackServiceTests.swift` | COMPREHENSIVE - Cancellation scenarios |
| **Session Invalidation** | `AssistantCoordinatorTests.swift` | COMPREHENSIVE - UUID-based session validation |

### Missing Coverage

| Area | Missing Tests | Risk |
|------|---------------|------|
| **Application Launching** | None exist - feature not implemented | N/A |
| **File Opening** | None exist - feature not implemented | N/A |
| **System Information** | None exist - feature not implemented | N/A |
| **Tool Execution** | None exist - feature not implemented | N/A |
| **Tool Permission Policy** | None exist - feature not implemented | N/A |
| **Desktop Tool Integration** | None exist - feature not implemented | N/A |

### Test Infrastructure Readiness

**Testing Patterns**: WELL-ESTABLISHED
- Mock objects for external dependencies
- Async test patterns
- Error scenario testing
- Cancellation testing
- File system test utilities

**Conclusion**: Test infrastructure is ready for desktop tool testing. No additional test framework setup needed.

---

## 13. RECOMMENDED PHASE 6 IMPLEMENTATION PLAN

### Step 1: Extend Domain Layer (1-2 hours)

1. Add `ToolCall.swift` to `Sources/AriaDomain/Tool/`
2. Add `ToolResult.swift` to `Sources/AriaDomain/Tool/`
3. Add `ToolError.swift` extension to `Sources/AriaDomain/Common/AriaError.swift`
4. Add `ToolExecuting.swift` protocol to `Sources/AriaDomain/Tool/`
5. Update existing `ToolDefinition.swift` if needed
6. Write unit tests for new domain types

**Risk**: LOW - Pure data structures, no external dependencies

---

### Step 2: Implement Tier 1 Tools (4-6 hours)

1. Create `Sources/AriaInfrastructure/Desktop/` directory
2. Implement `DesktopToolExecutor.swift` with permission policy
3. Implement `ApplicationLauncher.swift` using NSWorkspace
4. Implement `FileOpener.swift` using NSWorkspace
5. Implement `SystemInfoProvider.swift` using ProcessInfo and IOKit
6. Write unit tests for each tool
7. Write integration tests for tool executor

**Risk**: MEDIUM - Requires macOS API knowledge, but Tier 1 tools are safe

---

### Step 3: Extend LLM Integration (2-3 hours)

1. Extend `LLMResponse` to include optional tool calls
2. Extend `LLMRequest` to include tool definitions
3. Update `OpenRouterProvider` to support function calling API
4. Add tool call parsing logic
5. Add tool result formatting logic
6. Write tests for tool call parsing

**Risk**: MEDIUM - Requires OpenRouter API knowledge, but function calling is standard

---

### Step 4: Integrate into AssistantCoordinator (2-3 hours)

1. Add `ToolExecuting` dependency to `AssistantCoordinator`
2. Add tool call detection after LLM response
3. Add tool execution with session validation
4. Add tool result integration into conversation
5. Add error handling for tool failures
6. Update avatar lifecycle for tool execution
7. Write integration tests for tool execution flow

**Risk**: MEDIUM - Core integration point, must preserve existing behavior

---

### Step 5: Add Entitlements (1 hour)

1. Create `AriaApp.entitlements` file
2. Add required entitlements for Tier 1 tools
3. Update Package.swift if needed
4. Test entitlements in development

**Risk**: LOW - Tier 1 tools require minimal entitlements

---

### Step 6: Comprehensive Testing (2-3 hours)

1. Test tool execution with concurrent requests
2. Test tool execution cancellation
3. Test tool execution with stale sessions
4. Test tool failure scenarios
5. Test permission policy enforcement
6. Test end-to-end tool execution flow

**Risk**: LOW - Testing is safe, no production impact

---

### Total Estimated Effort

**Step 1**: 1-2 hours  
**Step 2**: 4-6 hours  
**Step 3**: 2-3 hours  
**Step 4**: 2-3 hours  
**Step 5**: 1 hour  
**Step 6**: 2-3 hours  

**Total**: 12-18 hours

---

## 14. REQUIRED DECISIONS

### A. Does Aria already have desktop execution capabilities?

**Answer**: NO

**Explanation**: Aria has no ability to launch applications, open files, execute commands, or interact with the macOS desktop. The only external process execution is for TTS (Piper), which is controlled and isolated.

---

### B. Does Aria already have application launching support?

**Answer**: NO

**Explanation**: No NSWorkspace, NSRunningApplication, or LaunchServices APIs are used. No application launching, quitting, or focusing capabilities exist.

---

### C. Does Aria already have filesystem/open-file support?

**Answer**: PARTIAL

**Explanation**: Aria uses FileManager for internal storage (memory, relationship state, TTS audio) but has NO user-facing file operations. No file opening, searching, or management capabilities exist.

---

### D. Does Aria already have structured LLM tool/function calling?

**Answer**: NO

**Explanation**: LLM integration is purely conversational with simple text request/response. No tool calling, function calling, or structured output for tool execution exists.

---

### E. Is arbitrary shell execution currently exposed?

**Answer**: NO

**Explanation**: The only external process execution is Piper TTS, which:
- Uses a fixed, known executable path
- Validates arguments before execution
- Has no user-provided shell commands
- Is isolated to TTS functionality
- Has comprehensive test coverage

**Risk Assessment**: SAFE - This is controlled external process execution, not arbitrary shell access.

---

### F. Is the application sandboxed?

**Answer**: UNCERTAIN (LIKELY UNSANDBOXED)

**Explanation**: 
- NO `.entitlements` files found in the repository
- NO sandbox configuration in Package.swift
- NO Info.plist in AriaApp target
- Application uses FileManager with standard directories successfully

**Assessment**: Application appears to be unsandboxed, which provides flexibility for desktop tool implementation but may require future entitlements for broader file access.

---

### G. What is the smallest architecture required to safely add Tier 1 tools?

**Recommended Architecture**:

```
Domain Layer (Extensions):
├── ToolCall (struct)
├── ToolResult (struct)  
├── ToolError (enum extension)
└── ToolExecuting (protocol)

Infrastructure Layer (New):
├── DesktopToolExecutor (actor)
├── ToolPermissionPolicy (struct)
├── ApplicationLauncher (struct)
├── FileOpener (struct)
└── SystemInfoProvider (struct)

Application Layer (Integration):
└── AssistantCoordinator (extend existing)
    ├── Add ToolExecuting dependency
    ├── Add tool call detection
    ├── Add tool execution with session validation
    └── Add tool result integration
```

**Key Principles**:
1. Follow existing Domain → Application → Infrastructure pattern
2. Reuse existing session validation (UUID-based)
3. Respect existing cancellation behavior
4. Preserve existing avatar lifecycle
5. No new services needed - integrate into existing coordinator
6. Tier 1 tools only (safe operations)
7. No arbitrary shell execution
8. Permission policy at Infrastructure layer

**Justification**: This minimal architecture:
- Fits existing patterns without restructuring
- Reuses Phase 4 session guarantees
- Requires no new services or abstractions
- Preserves all existing behavior
- Can be implemented incrementally
- Follows established safety boundaries

---

## 15. CONCLUSION

The Phase 6 desktop capability audit reveals that Aria currently has **NO desktop execution capabilities**, which provides a clean slate for implementing safe, controlled desktop tools.

**Key Strengths**:
1. Clean architecture with clear separation of concerns
2. Robust session validation and cancellation safety
3. Comprehensive test infrastructure
4. Placeholder tool architecture already established
5. Appears to be unsandboxed (flexibility for implementation)
6. Existing external process execution is safe and controlled

**Areas for Implementation**:
1. Extend Domain layer with tool types
2. Implement Infrastructure layer tool executor
3. Integrate tool execution into existing AssistantCoordinator
4. Add minimal entitlements for Tier 1 tools
5. Extend LLM integration for function calling

**Risk Assessment**: LOW
- Tier 1 tools are safe by definition
- Existing architecture provides strong safety boundaries
- Session validation prevents stale execution
- Test infrastructure is comprehensive

**Overall Assessment**: Aria is ready for Phase 6 implementation with MINOR architectural additions. The existing codebase provides an excellent foundation for safe desktop capability integration.

---

**Audit Completed**: 2026-08-14
**Auditor**: Devin (AI Assistant)
**Scope**: Phase 6 - Desktop Agent & Tool Execution
**Status**: READY FOR IMPLEMENTATION (Step 2)
