# PHASE 8 STEP 1 — RUNTIME UI ARCHITECTURE & STATE OWNERSHIP AUDIT

**Date**: 2026-08-15  
**Objective**: Determine the correct architecture for connecting a real macOS runtime UI to the existing Aria backend  
**Scope**: Runtime UI architecture, state ownership analysis, backend-to-UI integration design

---

## 1. Executive Summary

Aria currently has a robust backend architecture with clear separation of concerns (Domain → Application → Infrastructure → Presentation). The existing presentation layer consists of a console runtime and a Live2D avatar renderer using AppKit. The backend is actor-based with proper concurrency isolation and comprehensive session safety.

**Key Finding**: The backend is well-architected for UI integration. The existing `AssistantCoordinator` already serves as the correct integration boundary, and the current `AvatarRendering` and `DesktopUIRendering` protocols provide the right abstraction layer.

**Recommended Approach**: Hybrid SwiftUI + AppKit architecture. SwiftUI for the conversation interface and controls, AppKit for the existing Live2D avatar window. A new `RuntimeAdapter` layer will bridge the actor-based backend to the reactive UI layer using Swift's `@Observable` and `AsyncStream`.

**Critical Principle**: The UI must NEVER become a duplicate source of truth. All backend-owned state must remain in the backend, with the UI observing and requesting changes only through the established `AssistantCoordinator` boundary.

**Final Status**: READY FOR PHASE 8 STEP 2 — UI FOUNDATION

---

## 2. Current Presentation Architecture

### Current Executable/App Entry

**File**: `/Volumes/T7Sheald/Aria/Sources/AriaApp/main.swift`

**Current Responsibilities**:
- Command-line argument parsing (Live2D test mode detection)
- Configuration loading (`AppConfiguration.load()`)
- Logger initialization (`ConsoleLogger`)
- Live2D avatar initialization (`Live2DAvatarRenderer`)
- OpenRouter provider initialization
- Async coordinator bootstrap via `AppBootstrap.createCoordinator()`
- Avatar state manager initialization
- TTS service initialization with avatar integration
- Console UI renderer instantiation (`ConsoleUIRenderer`)
- Main console loop with command processing
- Direct TTS synthesis and playback coordination

**Current Architecture**:
```
main.swift (console runtime)
    ↓
AppBootstrap (dependency injection)
    ↓
AssistantCoordinator (orchestration)
    ↓
Backend Systems (actors)
    ↓
Presentation Layer (protocols)
    ↓
ConsoleUIRenderer + Live2DAvatarRenderer
```

### SwiftUI Usage

**Current Status**: NOT USED
- No SwiftUI code exists in the current codebase
- All UI is console-based or AppKit-based (Live2D window)

### AppKit Usage

**Current Status**: USED (Live2D only)
- `Live2DWindow` extends `NSWindow`
- `Live2DAvatarRenderer` is marked `@MainActor`
- Live2D rendering uses MetalKit (`MTKView`)
- AppKit is only used for the avatar window, not for conversation UI

### Existing Live2D Integration

**Location**: `/Volumes/T7Sheald/Aria/Sources/AriaPresentation/Live2D/`

**Components**:
- `Live2DWindow.swift` - AppKit window for Live2D rendering
- `Live2DSwiftBridge.swift` - C bridge to native Live2D library
- `Live2DAvatarRenderer` - Swift wrapper implementing `AvatarRendering` protocol

**Current Rendering**: 
- Metal-based rendering via `MTKView`
- C bridge to native Live2D library
- Window lifecycle managed by AppKit
- Avatar state updates via `updateState()` method

### Current Console Runtime Implementation

**Location**: `/Volumes/T7Sheald/Aria/Sources/AriaApp/main.swift` (lines 140-287)

**Features**:
- Interactive console loop with `readLine()`
- Command processing: help, status, mute, unmute, stop, clear, exit
- Direct `coordinator.handleUserInput()` calls
- Direct `ttsService` calls for audio control
- Direct `avatar.update()` calls for emotion updates
- Manual TTS synthesis and playback coordination
- Error handling with logger output

**Current Dependency/Bootstrap Flow**:
```
main.swift
    ↓
AppConfiguration.load()
    ↓
ConsoleLogger
    ↓
Live2DAvatarRenderer (immediate window show)
    ↓
OpenRouterConfiguration.make()
    ↓
OpenRouterProvider
    ↓
AppBootstrap.createCoordinator() (async)
    ↓
AppBootstrap.createAvatarStateManager()
    ↓
AppBootstrap.createTTSServiceWithAvatar()
    ↓
AppBootstrap.createAudioPlaybackService()
    ↓
ConsoleUIRenderer
    ↓
Main console loop
```

### Existing UI Shell

**Status**: PARTIAL
- Live2D window exists as AppKit-based shell
- Console runtime exists as text-based shell
- No graphical conversation interface exists
- No unified application shell exists

---

## 3. UI Framework Evaluation

### Option A: SwiftUI

**Pros**:
- Modern, declarative UI paradigm
- Built-in state management with `@Observable` and `@State`
- Excellent for list-based interfaces (conversation history)
- Native macOS support with macOS-specific controls
- Future-ready with active Apple development
- Easy animation and transition support
- Better for rapid UI development

**Cons**:
- Limited integration with existing AppKit Live2D window
- Would require `NSViewRepresentable` bridge for Live2D
- Less control over window lifecycle compared to AppKit
- Potential threading complexity with actor-based backend
- Learning curve if team unfamiliar with SwiftUI

**Fit with Existing Codebase**: MEDIUM
- No existing SwiftUI code to build upon
- Would require new UI layer from scratch
- Actor-based backend requires careful integration

### Option B: AppKit

**Pros**:
- Existing Live2D integration already uses AppKit
- Full control over window lifecycle
- Proven, mature framework
- Direct integration with existing `Live2DWindow`
- Familiar to macOS developers
- Fine-grained control over rendering and events

**Cons**:
- Imperative, verbose UI code
- Manual state management required
- More boilerplate for list interfaces
- Older paradigm with less active development
- Harder to implement modern UI patterns
- Animation and transitions require more code

**Fit with Existing Codebase**: HIGH
- Live2D already uses AppKit
- Existing AppKit patterns to build upon
- Direct integration with `Live2DWindow`

### Option C: Hybrid SwiftUI + AppKit

**Pros**:
- Best of both worlds: SwiftUI for conversation UI, AppKit for Live2D
- SwiftUI provides modern, declarative interface for chat
- AppKit provides proven Live2D integration
- Clear separation: conversation in SwiftUI, avatar in AppKit
- Future-ready while preserving existing investment
- Can use `NSHostingController` or `NSViewRepresentable` for integration

**Cons**:
- More complex architecture with two frameworks
- Requires careful coordination between SwiftUI and AppKit
- Threading complexity across framework boundaries
- Potential for framework-specific bugs

**Fit with Existing Codebase**: HIGH
- Preserves existing Live2D AppKit investment
- Adds modern SwiftUI for conversation interface
- Clear separation of concerns
- Minimal disruption to existing code

### Recommendation: Hybrid SwiftUI + AppKit

**Rationale**:
1. **Preserves Existing Investment**: Live2D integration is already working in AppKit - no need to rewrite
2. **Modern UI for Conversation**: SwiftUI is ideal for chat interfaces with lists and reactive state
3. **Clear Separation**: Conversation UI (SwiftUI) and Avatar (AppKit) have different requirements
4. **Future-Ready**: SwiftUI is the future of macOS UI development
5. **Minimal Disruption**: Existing backend and Live2D code remain unchanged
6. **Proven Pattern**: Apple recommends this hybrid approach for complex macOS apps

**Architecture**:
```
NSApplication (AppKit)
    ↓
Main Window (AppKit)
    ├── Live2D View (AppKit - existing)
    └── Conversation View (SwiftUI - new)
        ↓
    SwiftUI Views
        ↓
    Runtime Adapter (new)
        ↓
    AssistantCoordinator (existing)
```

---

## 4. Recommended UI Architecture

### Overall Architecture

```
┌─────────────────────────────────────────────────────────────┐
│                    NSApplication (AppKit)                   │
│  ┌─────────────────────────────────────────────────────────┐ │
│  │              Main Window (AppKit NSWindow)               │ │
│  │  ┌──────────────────┐  ┌──────────────────────────────┐ │ │
│  │  │  Live2D Avatar   │  │   Conversation UI (SwiftUI)    │ │ │
│  │  │  (AppKit MTKView)│  │   (NSHostingController)      │ │ │
│  │  │  - Existing      │  │   - Message List              │ │ │
│  │  │  - Metal Render  │  │   - Text Input                │ │ │
│  │  │  - AppKit Lifecycle│ │   - Controls                 │ │ │
│  │  └──────────────────┘  └──────────────────────────────┘ │ │
│  └─────────────────────────────────────────────────────────┘ │
└─────────────────────────────────────────────────────────────┘
                            ↓
┌─────────────────────────────────────────────────────────────┐
│              Runtime Adapter Layer (New)                    │
│  ┌─────────────────────────────────────────────────────────┐ │
│  │  ConversationViewModel (@Observable)                   │ │
│  │  - Observes backend state                               │ │
│  │  - Provides UI state                                    │ │
│  │  - Handles user actions                                 │ │
│  │  - Manages AsyncStream subscriptions                    │ │
│  └─────────────────────────────────────────────────────────┘ │
└─────────────────────────────────────────────────────────────┘
                            ↓
┌─────────────────────────────────────────────────────────────┐
│              AssistantCoordinator (Existing)                │
│  - Actor-based orchestration                                │
│  - Session management                                        │
│  - Cancellation handling                                    │
│  - Avatar state integration                                  │
└─────────────────────────────────────────────────────────────┘
                            ↓
┌─────────────────────────────────────────────────────────────┐
│              Backend Systems (Existing Actors)              │
│  - ConversationService, MemoryService, TTS, etc.            │
└─────────────────────────────────────────────────────────────┘
```

### Key Architectural Decisions

**1. Runtime Adapter Layer**
- New layer between SwiftUI UI and actor-based backend
- Implements `@Observable` for SwiftUI state observation
- Uses `AsyncStream` for event streaming from actors
- Provides main-thread safe APIs for UI
- Handles actor-to-main-thread coordination

**2. State Observation Strategy**
- Backend state observed via snapshot APIs on actors
- Changes streamed via `AsyncStream` from actors
- UI subscribes to streams and updates `@Observable` state
- No polling - event-driven updates only
- Session-safe updates with request ID validation

**3. Action Flow**
- UI actions → Runtime Adapter → AssistantCoordinator
- All backend mutations go through AssistantCoordinator
- UI never directly calls backend actors
- Session ID validation enforced at coordinator level
- Cancellation handled via coordinator

**4. Live2D Integration**
- Existing `Live2DAvatarRenderer` remains unchanged
- Avatar state still controlled by backend
- UI observes avatar state via Runtime Adapter
- No direct UI-to-avatar communication

**5. Threading Model**
- Backend: Actor-based (concurrent)
- Runtime Adapter: Main-thread isolated
- UI: Main-thread (SwiftUI/AppKit)
- Actor-to-main-thread bridging via `Task { @MainActor in ... }`

---

## 5. Complete State Ownership Matrix

### Conversation State

| State | Owner | UI Read Access | UI Write Access | Update Mechanism | Session Scoped? | Persistent? | Can UI Cache? | Can UI Derive? |
|-------|-------|----------------|-----------------|-----------------|-----------------|-------------|---------------|---------------|
| Conversation history | ConversationService | Yes (via snapshot) | No (via coordinator) | Actor mutation | No | No | Yes (read-only) | No |
| Current user input | UI (draft) | Yes | Yes (draft only) | Local UI state | No | No | Yes | No |
| Current request | AssistantCoordinator | Yes (via status) | No (via coordinator) | Actor mutation | Yes | No | No | No |
| Processing state | AssistantCoordinator | Yes (via status) | No | Actor mutation | Yes | No | No | No |
| Current response | AssistantCoordinator | Yes (via turn result) | No | Actor mutation | Yes | No | Yes (read-only) | No |

### Runtime State

| State | Owner | UI Read Access | UI Write Access | Update Mechanism | Session Scoped? | Persistent? | Can UI Cache? | Can UI Derive? |
|-------|-------|----------------|-----------------|-----------------|-----------------|-------------|---------------|---------------|
| Current session UUID | AssistantCoordinator | Yes (via status) | No | Actor mutation | Yes | No | No | No |
| Cancellation state | AssistantCoordinator | Yes (via status) | No (via coordinator) | Actor mutation | Yes | No | No | No |
| Runtime errors | AssistantCoordinator | Yes (via turn result) | No | Actor mutation | Yes | No | Yes (read-only) | No |

### Avatar State

| State | Owner | UI Read Access | UI Write Access | Update Mechanism | Session Scoped? | Persistent? | Can UI Cache? | Can UI Derive? |
|-------|-------|----------------|-----------------|-----------------|-----------------|-------------|---------------|---------------|
| Current AvatarState | AvatarStateManager | Yes (via status) | No | Actor mutation | No | No | Yes (read-only) | No |

### Audio State

| State | Owner | UI Read Access | UI Write Access | Update Mechanism | Session Scoped? | Persistent? | Can UI Cache? | Can UI Derive? |
|-------|-------|----------------|-----------------|-----------------|-----------------|-------------|---------------|---------------|
| Mute state | TextToSpeechService | Yes (via TTS service) | Yes (via coordinator) | Actor mutation | No | No | Yes (read-only) | No |
| Active audio session | AudioPlaybackService | Yes (via status) | No | Actor mutation | No | No | No | No |
| Speaking state | AudioPlaybackService | Yes (via status) | No | Actor mutation | No | No | No | Yes (from avatar state) |

### Tool State

| State | Owner | UI Read Access | UI Write Access | Update Mechanism | Session Scoped? | Persistent? | Can UI Cache? | Can UI Derive? |
|-------|-------|----------------|-----------------|-----------------|-----------------|-------------|---------------|---------------|
| Available tools | ToolRegistry | Yes (via snapshot) | No | Actor mutation | No | No | Yes (read-only) | No |
| Active tool execution | ToolOrchestrator | Yes (via status) | No | Actor mutation | Yes | No | No | No |
| Tool results | ToolOrchestrator | Yes (via turn result) | No | Actor mutation | Yes | No | Yes (read-only) | No |
| Confirmation request | ToolOrchestrator | Yes (via status) | No (via coordinator) | Actor mutation | Yes | No | Yes (read-only) | No |
| Clarification request | ClarificationManager | Yes (via status) | No (via coordinator) | Actor mutation | Yes | No | Yes (read-only) | No |
| Failure recovery state | ToolFailureRecoveryPolicy | Yes (via turn result) | No | Actor mutation | Yes | No | Yes (read-only) | No |

### Context State

| State | Owner | UI Read Access | UI Write Access | Update Mechanism | Session Scoped? | Persistent? | Can UI Cache? | Can UI Derive? |
|-------|-------|----------------|-----------------|-----------------|-----------------|-------------|---------------|---------------|
| RuntimeEntityContext | RuntimeEntityContext | Yes (via snapshot) | No | Actor mutation | Yes | No | Yes (read-only) | No |
| DesktopTaskContext | TaskContextManager | Yes (via snapshot) | No | Actor mutation | Yes | No | Yes (read-only) | No |
| IntentHistory | IntentHistory | Yes (via snapshot) | No | Actor mutation | Yes | No | Yes (read-only) | No |

### Memory State

| State | Owner | UI Read Access | UI Write Access | Update Mechanism | Session Scoped? | Persistent? | Can UI Cache? | Can UI Derive? |
|-------|-------|----------------|-----------------|-----------------|-----------------|-------------|---------------|---------------|
| Retrieved memories | MemoryService | Yes (via turn result) | No | Actor mutation | No | Yes | Yes (read-only) | No |
| Persistent memory | MemoryService | Yes (via query) | No (via coordinator) | Actor mutation | No | Yes | Yes (read-only) | No |

---

## 6. Backend-Owned vs UI-Owned State

### BACKEND-OWNED STATE (UI must only observe or request changes)

**Conversation**:
- Conversation history (ConversationService)
- Current request state (AssistantCoordinator)
- Processing state (AssistantCoordinator)
- Current response (AssistantCoordinator)

**Runtime**:
- Current session UUID (AssistantCoordinator)
- Cancellation state (AssistantCoordinator)
- Runtime errors (AssistantCoordinator)

**Avatar**:
- Current AvatarState (AvatarStateManager)
- Avatar lifecycle (AvatarStateManager)

**Audio**:
- Mute state (TextToSpeechService)
- Active audio session (AudioPlaybackService)
- Speaking state (AudioPlaybackService)

**Tools**:
- Available tools (ToolRegistry)
- Active tool execution (ToolOrchestrator)
- Tool results (ToolOrchestrator)
- Confirmation request (ToolOrchestrator)
- Clarification request (ClarificationManager)
- Failure recovery state (ToolFailureRecoveryPolicy)

**Context**:
- RuntimeEntityContext (RuntimeEntityContext)
- DesktopTaskContext (TaskContextManager)
- IntentHistory (IntentHistory)

**Memory**:
- Retrieved memories (MemoryService)
- Persistent memory (MemoryService)

### UI-OWNED STATE (UI has full ownership)

**Draft State**:
- Current user input draft (before send)
- Text field focus state
- Selection state in text field

**Visual State**:
- Scroll position in message list
- Selected message (for copy/actions)
- Expanded/collapsed state of UI elements
- Animation progress
- Transition state

**Transient State**:
- Button hover states
- Menu open/close state
- Dropdown selection state
- Modal dialog state
- Tooltip visibility

**Presentation State**:
- Window position and size
- Split view divider position
- Panel visibility
- Theme/appearance preferences (if added)

**Local State**:
- Undo/redo stack for text input
- Clipboard contents (if managed locally)
- Temporary selections
- Drag-and-drop state

---

## 7. Backend → UI Data Flow

### Recommended Architecture: AsyncStream + @Observable

**Pattern**: Event-driven streaming with reactive UI observation

**Flow**:
```
Backend Actor State Change
    ↓
Actor publishes change via AsyncStream
    ↓
Runtime Adapter subscribes to AsyncStream
    ↓
Runtime Adapter updates @Observable state on @MainActor
    ↓
SwiftUI view observes @Observable state
    ↓
SwiftUI view re-renders
```

### Implementation Details

**1. Actor Side (Backend)**:
```swift
// Add to AssistantCoordinator
private var stateChangeContinuation: AsyncStream<BackendStateChange>.Continuation?

public func stateChanges() -> AsyncStream<BackendStateChange> {
    AsyncStream { continuation in
        self.stateChangeContinuation = continuation
    }
}

// When state changes:
stateChangeContinuation?.yield(.conversationUpdated)
```

**2. Runtime Adapter Side**:
```swift
@MainActor
@Observable
public class ConversationViewModel {
    private let coordinator: AssistantCoordinator
    private var stateChangeTask: Task<Void, Never>?
    
    public init(coordinator: AssistantCoordinator) {
        self.coordinator = coordinator
        subscribeToStateChanges()
    }
    
    private func subscribeToStateChanges() {
        stateChangeTask = Task {
            for await change in await coordinator.stateChanges() {
                await handleStateChange(change)
            }
        }
    }
    
    private func handleStateChange(_ change: BackendStateChange) async {
        switch change {
        case .conversationUpdated:
            conversationMessages = await coordinator.getConversationSnapshot()
        // ... other cases
        }
    }
}
```

**3. UI Side (SwiftUI)**:
```swift
struct ConversationView: View {
    @State private var viewModel: ConversationViewModel
    
    var body: some View {
        MessageList(messages: viewModel.conversationMessages)
    }
}
```

### Requirements Satisfied

**No Polling**: Event-driven via AsyncStream
**No Duplicate Mutable State**: UI observes backend state, doesn't duplicate
**No Direct Actor Internals**: Actor exposes only snapshot APIs and streams
**Main-Thread UI Safety**: Runtime Adapter ensures @MainActor updates
**Session-Safe Updates**: Backend validates session ID before yielding changes
**Stale Event Protection**: Request ID validation prevents stale updates

### Alternative Considered: ObservableObject

**Rejected Because**:
- `@Observable` is the modern Swift replacement
- Better performance with fine-grained updates
- Simpler syntax
- Apple's recommended direction

### Alternative Considered: Combine Publishers

**Rejected Because**:
- AsyncStream is more natural with Swift Concurrency
- Better integration with actors
- Simpler cancellation semantics
- No need for Combine framework dependency

---

## 8. UI → Backend Action Flow

### Recommended Architecture: Direct Coordinator Calls

**Pattern**: UI actions → Runtime Adapter → AssistantCoordinator

**Flow**:
```
User Action (SwiftUI)
    ↓
SwiftUI View Handler
    ↓
Runtime Adapter Method
    ↓
AssistantCoordinator Method
    ↓
Backend Systems (Actors)
```

### Implementation Details

**1. UI Side (SwiftUI)**:
```swift
struct ConversationView: View {
    @State private var viewModel: ConversationViewModel
    
    var body: some View {
        TextField("Message", text: $viewModel.inputText)
            .onSubmit {
                Task {
                    await viewModel.sendMessage()
                }
            }
    }
}
```

**2. Runtime Adapter Side**:
```swift
@MainActor
@Observable
public class ConversationViewModel {
    private let coordinator: AssistantCoordinator
    
    public func sendMessage() async {
        guard !inputText.isEmpty else { return }
        let message = inputText
        inputText = "" // Clear immediately
        
        do {
            _ = try await coordinator.handleUserInput(message)
        } catch {
            // Handle error
        }
    }
    
    public func cancelRequest() async {
        await coordinator.cancelCurrentRequest()
    }
    
    public func clearConversation() async {
        await coordinator.clearConversation()
    }
    
    public func respondToClarification(_ answer: String) async {
        // This goes through normal handleUserInput flow
        _ = try? await coordinator.handleUserInput(answer)
    }
    
    public func respondToConfirmation(_ approved: Bool) async {
        // This goes through normal handleUserInput flow
        let response = approved ? "ya" : "tidak"
        _ = try? await coordinator.handleUserInput(response)
    }
    
    public func setMuted(_ muted: Bool) async {
        // This needs to go through coordinator or TTS service
        // Coordinator should provide this interface
    }
    
    public func stopSpeech() async {
        // This needs to go through coordinator or TTS service
        // Coordinator should provide this interface
    }
}
```

**3. Coordinator Side (AssistantCoordinator)**:
```swift
// Add these methods to AssistantCoordinator
public func cancelCurrentRequest() async {
    currentRequestTask?.cancel()
    currentRequestID = nil
    
    if let manager = avatarStateManager {
        try? await manager.transitionToIdle()
    }
}

public func setMuted(_ muted: Bool) async {
    // This needs to be added - coordinator should control TTS
    // Currently TTS is controlled directly from main.swift
    // This is a gap that needs to be filled
}

public func stopSpeech() async {
    // This needs to be added - coordinator should control TTS
    // Currently TTS is controlled directly from main.swift
    // This is a gap that needs to be filled
}
```

### Requirements Satisfied

**No Direct Backend Access**: UI only talks to Runtime Adapter
**No Direct Actor Calls**: Runtime Adapter talks to Coordinator only
**Session Safety**: Coordinator enforces session validation
**Cancellation**: Coordinator handles cancellation properly
**Single Entry Point**: All actions go through Coordinator

---

## 9. AssistantCoordinator Integration Boundary

### Current Public Interface

**Existing Methods**:
- `handleUserInput(_ text: String) async throws -> AssistantTurnResult`
- `clearConversation() async`
- `setAvatarStateManager(_ manager: AvatarStateManager) async`
- `getRuntimeStatus() async -> ConversationRuntimeStatus`

### Required Additional Methods

**Audio Control** (currently missing):
- `setMuted(_ muted: Bool) async` - Control TTS mute state
- `stopSpeech() async` - Stop current TTS playback

**Clarification/Confirmation** (already handled via handleUserInput):
- No additional methods needed - answers go through normal input flow

**Session Control** (already exists):
- `clearConversation() async` - Already exists

**Status Query** (already exists):
- `getRuntimeStatus() async -> ConversationRuntimeStatus` - Already exists

### Minimal Public Interface

**Recommended Interface**:
```swift
public actor AssistantCoordinator {
    // Existing
    public func handleUserInput(_ text: String) async throws -> AssistantTurnResult
    public func clearConversation() async
    public func setAvatarStateManager(_ manager: AvatarStateManager) async
    public func getRuntimeStatus() async -> ConversationRuntimeStatus
    
    // New - Audio Control
    public func setMuted(_ muted: Bool) async
    public func stopSpeech() async
    
    // New - State Observation
    public func stateChanges() -> AsyncStream<BackendStateChange>
    public func getConversationSnapshot() async -> [ConversationMessage]
    
    // New - Cancellation
    public func cancelCurrentRequest() async
}
```

### Integration Boundary Summary

**UI Must NOT Call Directly**:
- ToolOrchestrator
- ToolRegistry for execution
- MemoryService
- RuntimeEntityContext
- TaskContextManager
- TextToSpeechService internals
- ClarificationManager
- AvatarStateManager

**UI Must Call Only**:
- AssistantCoordinator public methods
- Through Runtime Adapter layer

---

## 10. Runtime Event Model Decision

### Decision: Bounded Event Stream Required

**Rationale**: While existing state can be observed directly via snapshot APIs, an explicit event stream is needed for:

1. **Efficient Updates**: Polling snapshots would be inefficient
2. **Real-time Reactivity**: UI needs to react immediately to state changes
3. **Session Safety**: Events can carry request ID for validation
4. **Cancellation**: Event streams can be cancelled with tasks
5. **Ordering**: Events preserve ordering of state changes

### Event Types

**Conversation Events**:
- `requestStarted(requestID: UUID)`
- `requestCancelled(requestID: UUID)`
- `requestCompleted(requestID: UUID, result: AssistantTurnResult)`
- `requestFailed(requestID: UUID, error: Error)`

**Avatar Events**:
- `avatarStateChanged(to: AvatarState)`

**Audio Events**:
- `speechStarted`
- `speechStopped`
- `muteChanged(to: Bool)`

**Tool Events**:
- `toolExecutionStarted(tool: ToolIdentifier)`
- `toolExecutionCompleted(tool: ToolIdentifier, result: ToolResult)`
- `clarificationRequested(request: ClarificationRequest)`
- `confirmationRequested(request: PendingToolConfirmation)`

### Event Model Definition

```swift
public enum BackendStateChange: Sendable {
    case requestStarted(UUID)
    case requestCancelled(UUID)
    case requestCompleted(UUID, AssistantTurnResult)
    case requestFailed(UUID, Error)
    case avatarStateChanged(AvatarState)
    case speechStarted
    case speechStopped
    case muteChanged(Bool)
    case toolExecutionStarted(ToolIdentifier)
    case toolExecutionCompleted(ToolIdentifier, ToolResult)
    case clarificationRequested(ClarificationRequest)
    case confirmationRequested(PendingToolConfirmation)
}
```

### Ownership & Lifecycle

**Owner**: AssistantCoordinator
**Lifecycle**: Per-application instance
**Session Identity**: Events carry request ID for session validation
**Stale Event Handling**: Request ID validation prevents stale updates
**Cancellation Behavior**: Event stream cancelled when task cancelled

### Implementation

```swift
// In AssistantCoordinator
private var stateChangeContinuation: AsyncStream<BackendStateChange>.Continuation?

public func stateChanges() -> AsyncStream<BackendStateChange> {
    AsyncStream { continuation in
        self.stateChangeContinuation = continuation
    }
}

// When state changes:
stateChangeContinuation?.yield(.requestStarted(requestID))
```

---

## 11. Conversation UI Projection Model

### Existing Conversation Models

**Domain Models** (must NOT be contaminated with UI properties):
- `ConversationMessage` (role, content, timestamp)
- `ConversationRole` (user, assistant, system)
- `ConversationTone` (casual, formal, etc.)

### Presentation-Specific Projection Model

**Required**: UI-specific projection model for rendering

**Rationale**: 
- Existing models are domain-focused
- UI needs rendering-specific properties (display state, animation state, etc.)
- Must not contaminate Domain models with UI concerns

### Projection Model Definition

```swift
@Observable
public class ConversationMessageViewModel: Identifiable, Sendable {
    public let id: UUID
    public let role: ConversationRole
    public let content: String
    public let timestamp: Date
    
    // UI-specific properties
    public var isAnimating: Bool = false
    public var isHighlighted: Bool = false
    public var displayState: DisplayState = .normal
    
    public enum DisplayState: Sendable {
        case normal
        case thinking
        case processing
        case error
        case cancelled
    }
    
    public init(from message: ConversationMessage) {
        self.id = UUID()
        self.role = message.role
        self.content = message.content
        self.timestamp = message.timestamp
    }
}
```

### Message Type Distinction

**User Message**:
- Role: .user
- Display: Right-aligned, different color
- No animation needed

**Assistant Message**:
- Role: .assistant
- Display: Left-aligned, different color
- Typing animation when generating

**Thinking/Processing**:
- Display: Indeterminate progress indicator
- State: .thinking or .processing

**Tool Activity**:
- Display: Inline tool indicator
- Show tool name and status

**Clarification**:
- Display: Interactive list of candidates
- User can select from list

**Confirmation**:
- Display: Yes/No buttons
- Show tool and parameters

**Failure**:
- Display: Error message with retry option
- State: .error

**Cancelled Request**:
- Display: Strikethrough or faded
- State: .cancelled

### Projection Strategy

**Backend → UI**:
1. Backend yields `ConversationMessage` via event stream
2. Runtime Adapter creates `ConversationMessageViewModel` from domain model
3. UI observes and renders view model

**UI → Backend**:
1. UI actions go through Runtime Adapter
2. Runtime Adapter calls AssistantCoordinator
3. No domain model contamination

---

## 12. Tool UX Architecture

### Normal Tool Execution Flow

**User Request**: "Buka Safari"

**Expected UX Flow**:
```
User types "Buka Safari"
    ↓
User sends message
    ↓
UI shows user message (right-aligned)
    ↓
UI shows thinking indicator
    ↓
Backend processes request
    ↓
Backend executes tool (open_application)
    ↓
UI shows tool activity indicator (optional)
    ↓
Backend interprets result
    ↓
Backend generates assistant response
    ↓
UI shows assistant message (left-aligned)
    ↓
UI hides thinking indicator
```

**Implementation**:
- User message shown immediately
- Thinking indicator shown while processing
- Tool activity indicator optional (can be subtle)
- Assistant message shown when ready
- No special UI logic needed - backend handles everything

### Clarification UX Flow

**User Request**: "Buka file tugas"

**Backend Behavior**:
1. File search returns multiple results
2. Backend detects ambiguity
3. Backend creates `ClarificationRequest`
4. Backend yields clarification event
5. Backend waits for user answer

**UI Flow**:
```
User types "Buka file tugas"
    ↓
UI shows user message
    ↓
UI shows thinking indicator
    ↓
Backend processes request
    ↓
Backend executes tool (find_file)
    ↓
Backend detects ambiguity
    ↓
Backend yields clarificationRequested event
    ↓
UI shows clarification UI:
    - "Which file did you mean?"
    - List of candidates (file1.txt, file2.txt, etc.)
    - Selection options (buttons or numbered list)
    ↓
User selects "file1.txt"
    ↓
UI sends selection to backend
    ↓
Backend continues with resolved entity
    ↓
Backend executes tool (open_file)
    ↓
Backend generates assistant response
    ↓
UI shows assistant message
```

**UI Responsibilities**:
- Render clarification request naturally
- Provide selection mechanism
- Send user answer to backend
- Do NOT resolve ambiguity itself

**Backend Responsibilities**:
- Detect ambiguity
- Create clarification request
- Wait for user answer
- Continue with resolved entity
- All tool execution logic

### Confirmation UX Flow

**User Request**: Action requiring confirmation (e.g., destructive operation)

**Backend Behavior**:
1. Backend determines confirmation required
2. Backend creates `PendingToolConfirmation`
3. Backend yields confirmationRequested event
4. Backend waits for user answer

**UI Flow**:
```
User requests action
    ↓
UI shows user message
    ↓
UI shows thinking indicator
    ↓
Backend processes request
    ↓
Backend determines confirmation required
    ↓
Backend yields confirmationRequested event
    ↓
UI shows confirmation UI:
    - "Are you sure you want to...?"
    - Tool description
    - Yes/No buttons
    ↓
User clicks "Yes"
    ↓
UI sends approval to backend
    ↓
Backend executes tool
    ↓
Backend generates assistant response
    ↓
UI shows assistant message
```

**UI Responsibilities**:
- Render confirmation request naturally
- Provide approval mechanism
- Send user answer to backend
- Do NOT implement confirmation policy

**Backend Responsibilities**:
- Determine confirmation requirement
- Create confirmation request
- Wait for user answer
- Execute tool if approved
- All confirmation policy logic

### Failure Recovery UX Flow

**User Request**: Tool execution fails

**Backend Behavior**:
1. Tool execution fails
2. Backend applies failure recovery policy
3. Backend determines retry eligibility
4. Backend generates failure response

**UI Flow**:
```
User requests action
    ↓
UI shows user message
    ↓
UI shows thinking indicator
    ↓
Backend processes request
    ↓
Tool execution fails
    ↓
Backend applies recovery policy
    ↓
Backend generates failure response
    ↓
UI shows assistant message with error
    ↓
UI may show retry button (if backend indicates retryable)
    ↓
User clicks retry (optional)
    ↓
UI sends retry request to backend
    ↓
Backend retries tool execution
```

**UI Responsibilities**:
- Display error message naturally
- Show retry option if backend indicates retryable
- Send retry request to backend
- Do NOT implement retry logic

**Backend Responsibilities**:
- Handle tool failure
- Apply failure recovery policy
- Determine retry eligibility
- Generate appropriate error response
- All retry logic

---

## 13. Clarification UX

### UI Components

**Clarification Display**:
- Natural language question: "Which file did you mean?"
- List of candidates with display names
- Selection mechanism (buttons or numbered list)
- Cancel option

**Candidate Display**:
```
Which file did you mean?

1. file1.txt
2. file2.txt
3. file3.pdf

[1] [2] [3] [Cancel]
```

**Alternative Display**:
```
Which file did you mean?

[ file1.txt ]
[ file2.txt ]
[ file3.pdf ]

[Cancel]
```

### User Interaction

**Selection Methods**:
1. Click on candidate button
2. Type number (if numbered list)
3. Type name (if supported by parser)

**Cancellation**:
- Cancel button
- Type "cancel" or "batal"

### Backend Integration

**UI → Backend**:
- User selection sent via `handleUserInput()`
- Backend parses answer via `ClarificationAnswerParser`
- Backend continues with resolved entity

**Backend → UI**:
- Backend yields `clarificationRequested` event
- UI renders clarification UI
- Backend waits for answer

### UI Responsibilities

- Render clarification naturally
- Provide selection mechanism
- Send user answer to backend
- Handle cancellation
- Do NOT resolve ambiguity

### Backend Responsibilities

- Detect ambiguity
- Create clarification request
- Parse user answer
- Resolve entity
- Continue tool execution

---

## 14. Confirmation UX

### UI Components

**Confirmation Display**:
- Natural language question: "Are you sure you want to...?"
- Tool description
- Action description
- Yes/No buttons

**Example Display**:
```
Are you sure you want to quit Safari?

This will close the Safari application.

[Yes] [No]
```

### User Interaction

**Approval Methods**:
1. Click "Yes" button
2. Type "yes" or "ya"
3. Type "no" or "tidak"

### Backend Integration

**UI → Backend**:
- User approval sent via `handleUserInput()`
- Backend parses answer via `ConfirmationAnswerParser`
- Backend executes or cancels tool

**Backend → UI**:
- Backend yields `confirmationRequested` event
- UI renders confirmation UI
- Backend waits for answer

### UI Responsibilities

- Render confirmation naturally
- Provide approval mechanism
- Send user answer to backend
- Do NOT implement confirmation policy

### Backend Responsibilities

- Determine confirmation requirement
- Create confirmation request
- Parse user answer
- Execute or cancel tool
- All confirmation policy logic

---

## 15. Failure Recovery UX

### UI Components

**Error Display**:
- Natural language error message
- Error description
- Retry button (if retryable)
- Cancel button

**Example Display**:
```
I couldn't open that application.

The application may not be installed.

[Retry] [Cancel]
```

### User Interaction

**Recovery Methods**:
1. Click "Retry" button
2. Type "retry" or "coba lagi"
3. Type "cancel" or "batal"

### Backend Integration

**UI → Backend**:
- User retry sent via `handleUserInput()`
- Backend applies failure recovery policy
- Backend retries or cancels

**Backend → UI**:
- Backend generates failure response
- UI renders error message
- UI shows retry option if retryable

### UI Responsibilities

- Display error naturally
- Show retry option if backend indicates retryable
- Send retry request to backend
- Do NOT implement retry logic

### Backend Responsibilities

- Handle tool failure
- Apply failure recovery policy
- Determine retry eligibility
- Generate appropriate error response
- All retry logic

---

## 16. Avatar & Live2D Integration Strategy

### Current Live2D Integration

**Location**: `/Volumes/T7Sheald/Aria/Sources/AriaPresentation/Live2D/`

**Components**:
- `Live2DWindow` - AppKit window extending `NSWindow`
- `Live2DBridge` - C bridge to native Live2D library
- `Live2DAvatarRenderer` - Swift wrapper implementing `AvatarRendering`

**Current Rendering**:
- Metal-based rendering via `MTKView`
- C bridge to native Live2D library
- Window lifecycle managed by AppKit
- Avatar state updates via `updateState()` method

### Avatar State Ownership

**Owner**: AvatarStateManager (backend actor)

**Current Flow**:
```
AssistantCoordinator
    ↓
AvatarStateManager
    ↓
Live2DAvatarRenderer
    ↓
Live2DWindow
    ↓
Metal Rendering
```

### UI Integration Strategy

**Decision**: Preserve existing AppKit Live2D integration

**Rationale**:
- Live2D already working in AppKit
- Metal rendering requires AppKit/MTKView
- No need to rewrite working code
- Clear separation: Avatar (AppKit) + Conversation (SwiftUI)

**Architecture**:
```
NSApplication (AppKit)
    ↓
Main Window (AppKit)
    ├── Live2D View (AppKit - existing)
    └── Conversation View (SwiftUI - new)
```

### Threading Requirements

**Current**: `Live2DAvatarRenderer` marked `@MainActor`

**UI Integration**: 
- Live2D remains on main thread (AppKit requirement)
- SwiftUI also on main thread
- No threading conflicts

### Lifecycle Requirements

**Current**: 
- Live2D window created in `main.swift`
- Window shown immediately
- Window lifecycle managed by AppKit

**UI Integration**:
- Live2D window lifecycle unchanged
- Main window now hosts both Live2D and SwiftUI
- Live2D window can be child of main window or separate

### NSView/NSViewRepresentable Bridge

**Decision**: No bridge needed for Live2D

**Rationale**:
- Live2D remains in pure AppKit
- SwiftUI conversation view separate
- No need to embed Live2D in SwiftUI
- Clear separation of concerns

**Alternative Considered**: NSViewRepresentable bridge
- Rejected because: Live2D already works in AppKit, no need to complicate

### UI Responsibilities

- Observe avatar state via Runtime Adapter
- Display avatar state in UI (optional status indicator)
- Do NOT control avatar state directly

### Backend Responsibilities

- Control avatar state via AvatarStateManager
- Update Live2D renderer via existing flow
- All avatar lifecycle management

---

## 17. Window & Application Lifecycle

### Application Startup

**Current Flow** (console runtime):
```
main.swift
    ↓
Configuration loading
    ↓
Logger initialization
    ↓
Live2D window creation
    ↓
OpenRouter initialization
    ↓
Coordinator bootstrap (async)
    ↓
TTS service initialization
    ↓
Console loop start
```

**Proposed Flow** (GUI runtime):
```
main.swift
    ↓
Configuration loading
    ↓
Logger initialization
    ↓
NSApplication setup
    ↓
Live2D window creation (existing)
    ↓
OpenRouter initialization
    ↓
Coordinator bootstrap (async)
    ↓
TTS service initialization
    ↓
Runtime Adapter creation
    ↓
SwiftUI window creation
    ↓
NSApplication.run()
```

### Dependency Bootstrap

**Current**: `AppBootstrap.createCoordinator()` handles async initialization

**Proposed**: 
- Preserve existing bootstrap
- Add Runtime Adapter creation after coordinator
- Add SwiftUI window setup after Runtime Adapter

### Window Creation

**Current**: 
- Live2D window created separately
- Console runtime has no window

**Proposed**:
- Main window hosts both Live2D and SwiftUI
- Live2D can be separate window or embedded
- SwiftUI conversation view in main window

### Shutdown

**Current**: 
- Console loop exits on "exit" command
- No explicit cleanup

**Proposed**:
- NSApplication termination handling
- Explicit cleanup of coordinator
- Explicit cleanup of TTS
- Explicit cleanup of Live2D
- Cancellation of ongoing tasks

### Cancellation During Shutdown

**Backend Protection**:
- `currentRequestTask?.cancel()` in coordinator
- Session ID validation prevents stale updates
- Actor isolation ensures safe cancellation

**UI Responsibility**:
- Cancel ongoing requests on shutdown
- Wait for cancellation to complete
- Clean up AsyncStream subscriptions

### Active TTS During Shutdown

**Backend Protection**:
- `tts.stopCurrentSpeech()` available
- Audio playback service handles cleanup
- Avatar state returns to idle

**UI Responsibility**:
- Call `stopSpeech()` on shutdown
- Wait for audio to stop
- Clean up audio resources

### Active Tool Execution During Shutdown

**Backend Protection**:
- Tool execution cancellable via task cancellation
- Session ID validation prevents stale tool calls
- ToolOrchestrator handles cancellation

**UI Responsibility**:
- Cancel ongoing requests on shutdown
- Wait for tool execution to complete or cancel
- Do not force-kill tool execution

### State Cleanup

**Backend Protection**:
- `clearConversation()` available
- Actor isolation ensures safe cleanup
- Session-scoped state cleared automatically

**UI Responsibility**:
- Call cleanup on shutdown
- Clear AsyncStream subscriptions
- Release Runtime Adapter references

---

## 18. Console Runtime Compatibility Strategy

### Decision: Preserve Console Runtime

**Rationale**:
- Valuable for development and debugging
- Useful for testing without UI
- Minimal overhead to preserve
- Provides fallback if UI has issues

### Implementation Strategy

**Option A**: Replace console runtime
- Rejected: Loses valuable debugging capability

**Option B**: Preserve as development/debug runtime
- **Recommended**: Keep console runtime for development

**Option C**: Support both temporarily
- Rejected: Unnecessary complexity

### Implementation

**Command-Line Flag**:
- Add `--console` flag to force console mode
- Default to GUI mode
- Console mode preserved for development

**main.swift Modification**:
```swift
let consoleMode = CommandLine.arguments.contains("--console")

if consoleMode {
    // Existing console runtime
    runConsoleRuntime()
} else {
    // New GUI runtime
    runGUIRuntime()
}
```

### Benefits

- Development: Quick testing without UI
- Debugging: Console output for backend issues
- Testing: Automated testing with console interface
- Fallback: UI issues can be debugged with console

### Testing Impact

- Unit tests: No impact (don't use main.swift)
- Integration tests: Can use console mode
- Manual testing: Both modes available

---

## 19. UI Failure Mode Analysis

### Double-Send

**Scenario**: User clicks send button twice rapidly

**Backend Protection**:
- `currentRequestTask?.cancel()` cancels previous request
- Request ID validation prevents stale responses
- Session safety enforced at coordinator level

**UI Responsibility**:
- Disable send button while processing
- Show thinking indicator
- Re-enable on completion or error

**Additional UI Protection**: Debounce send button clicks

### Rapid Clicking

**Scenario**: User rapidly clicks multiple buttons

**Backend Protection**:
- Actor isolation prevents concurrent mutations
- Session ID validation prevents race conditions
- Cancellation handling prevents overlapping requests

**UI Responsibility**:
- Disable buttons during processing
- Show loading state
- Prevent multiple simultaneous actions

**Additional UI Protection**: Button state management

### Stale UI Updates

**Scenario**: Response arrives after user sent new request

**Backend Protection**:
- Request ID validation in coordinator
- Stale responses rejected
- Session safety enforced

**UI Responsibility**:
- Include request ID in UI state
- Validate request ID before updating UI
- Discard stale updates

**Additional UI Protection**: Request ID tracking in view model

### Cancelled Requests

**Scenario**: User cancels request while processing

**Backend Protection**:
- Task cancellation supported
- Avatar state returns to idle
- Tool execution cancellable

**UI Responsibility**:
- Show cancellation in UI
- Update UI state to idle
- Handle cancellation gracefully

**Additional UI Protection**: Cancellation state in view model

### Window Closes During Processing

**Scenario**: User closes window while request processing

**Backend Protection**:
- NSApplication termination handling
- Explicit cleanup on shutdown
- Task cancellation on shutdown

**UI Responsibility**:
- Cancel ongoing requests on window close
- Wait for cancellation to complete
- Clean up AsyncStream subscriptions

**Additional UI Protection**: Window close handler

### Response Arrives After UI State Changed

**Scenario**: Response arrives after user navigated away

**Backend Protection**:
- Request ID validation
- Session safety enforced
- Stale responses rejected

**UI Responsibility**:
- Validate request ID before updating UI
- Discard stale updates
- Handle navigation changes

**Additional UI Protection**: Request ID validation in view model

### Audio Continues After View Disappears

**Scenario**: Audio continues after view is hidden/closed

**Backend Protection**:
- Audio playback service independent of UI
- TTS service manages audio lifecycle
- Avatar state managed independently

**UI Responsibility**:
- Stop audio on view disappear
- Call `stopSpeech()` on cleanup
- Clean up audio resources

**Additional UI Protection**: View lifecycle handlers

### Duplicate Confirmation Submission

**Scenario**: User submits confirmation twice

**Backend Protection**:
- Pending confirmation cleared after first answer
- Session ID validation prevents duplicate submissions
- Actor isolation prevents race conditions

**UI Responsibility**:
- Disable confirmation buttons after submission
- Show processing state
- Re-enable on completion or error

**Additional UI Protection**: Button state management

### Clarification Answer Submitted Twice

**Scenario**: User submits clarification answer twice

**Backend Protection**:
- Pending clarification cleared after first answer
- Session ID validation prevents duplicate submissions
- Actor isolation prevents race conditions

**UI Responsibility**:
- Disable clarification UI after submission
- Show processing state
- Re-enable on completion or error

**Additional UI Protection**: UI state management

### Tool Result Arrives After New Request

**Scenario**: Tool result arrives after user sent new request

**Backend Protection**:
- Request ID validation in coordinator
- Stale tool results rejected
- Session safety enforced

**UI Responsibility**:
- Validate request ID before updating UI
- Discard stale tool results
- Handle new request priority

**Additional UI Protection**: Request ID validation in view model

---

## 20. Recommended Phase 8 Implementation Roadmap

### Phase 8 Step 2: Minimal Runtime UI Foundation

**Scope**:
- Application shell (NSApplication setup)
- Dependency injection (extend AppBootstrap)
- Runtime Adapter/ViewModel (ConversationViewModel)
- Backend state observation (AsyncStream integration)
- Basic SwiftUI window setup

**Files to Add**:
- `AriaApp/AriaApp.swift` (NSApplication delegate)
- `AriaPresentation/Runtime/ConversationViewModel.swift`
- `AriaPresentation/Runtime/RuntimeAdapter.swift`

**Files to Modify**:
- `AriaApp/main.swift` (add GUI mode selection)
- `AriaApplication/AssistantCoordinator.swift` (add stateChanges() method)
- `AriaApplication/AppBootstrap.swift` (add Runtime Adapter creation)

**Deliverables**:
- Application launches with GUI mode
- Runtime Adapter observes backend state
- Basic SwiftUI window visible
- Console mode preserved via --console flag

### Phase 8 Step 3: Conversation Interface

**Scope**:
- Message list view (SwiftUI)
- Text input view
- Send button
- Processing state display
- Cancellation button
- Error display

**Files to Add**:
- `AriaPresentation/UI/ConversationView.swift`
- `AriaPresentation/UI/MessageListView.swift`
- `AriaPresentation/UI/MessageInputView.swift`
- `AriaPresentation/UI/ConversationMessageViewModel.swift`

**Files to Modify**:
- `AriaPresentation/Runtime/ConversationViewModel.swift` (add UI state)
- `AriaApplication/AssistantCoordinator.swift` (add getConversationSnapshot())

**Deliverables**:
- Full conversation interface
- Send/receive messages
- Processing state visible
- Cancellation working
- Errors displayed

### Phase 8 Step 4: Tool Interaction UX

**Scope**:
- Tool activity indicator
- Clarification UI
- Confirmation UI
- Failure display
- Retry mechanism

**Files to Add**:
- `AriaPresentation/UI/ClarificationView.swift`
- `AriaPresentation/UI/ConfirmationView.swift`
- `AriaPresentation/UI/ToolActivityIndicator.swift`
- `AriaPresentation/UI/ErrorView.swift`

**Files to Modify**:
- `AriaPresentation/Runtime/ConversationViewModel.swift` (add tool state)
- `AriaApplication/AssistantCoordinator.swift` (add audio control methods)

**Deliverables**:
- Tool execution visible
- Clarification flow working
- Confirmation flow working
- Failures displayed with retry
- All tool UX complete

### Phase 8 Step 5: Avatar Runtime Integration

**Scope**:
- Live2D host integration
- AvatarState observation
- Lifecycle integration
- Window layout (Live2D + Conversation)

**Files to Add**:
- `AriaPresentation/UI/AvatarView.swift` (AppKit bridge if needed)
- `AriaPresentation/UI/MainWindow.swift` (combined window layout)

**Files to Modify**:
- `AriaApp/main.swift` (window layout)
- `AriaPresentation/Runtime/ConversationViewModel.swift` (add avatar state)

**Deliverables**:
- Live2D visible in main window
- Avatar state observed by UI
- Combined window layout working
- Avatar lifecycle integrated

### Phase 8 Step 6: Runtime Polish & Manual Validation

**Scope**:
- Window lifecycle (startup, shutdown)
- Rapid interaction testing
- Manual desktop tool testing
- Error handling validation
- Performance validation
- Console mode validation

**Files to Modify**:
- `AriaApp/AriaApp.swift` (lifecycle handlers)
- `AriaPresentation/Runtime/ConversationViewModel.swift` (cleanup)

**Deliverables**:
- Clean startup/shutdown
- Rapid interaction stable
- Desktop tools tested manually
- Error handling validated
- Performance acceptable
- Console mode working

---

## 21. Files Likely to Be Added

### Application Layer
- `AriaApp/AriaApp.swift` - NSApplication delegate
- `AriaApp/Info.plist` - Application metadata (if needed)

### Presentation Layer - Runtime
- `AriaPresentation/Runtime/ConversationViewModel.swift` - Main view model
- `AriaPresentation/Runtime/RuntimeAdapter.swift` - Backend adapter
- `AriaPresentation/Runtime/BackendStateChange.swift` - Event definitions

### Presentation Layer - UI
- `AriaPresentation/UI/ConversationView.swift` - Main conversation view
- `AriaPresentation/UI/MessageListView.swift` - Message list
- `AriaPresentation/UI/MessageInputView.swift` - Text input
- `AriaPresentation/UI/ConversationMessageViewModel.swift` - Message projection
- `AriaPresentation/UI/ClarificationView.swift` - Clarification UI
- `AriaPresentation/UI/ConfirmationView.swift` - Confirmation UI
- `AriaPresentation/UI/ToolActivityIndicator.swift` - Tool activity
- `AriaPresentation/UI/ErrorView.swift` - Error display
- `AriaPresentation/UI/AvatarView.swift` - Avatar integration (if needed)
- `AriaPresentation/UI/MainWindow.swift` - Main window layout

### Domain Layer (if needed)
- None expected - existing models sufficient

---

## 22. Existing Files That Must Remain Stable

### Critical Backend Files (MUST NOT CHANGE)
- `AriaDomain/` - All domain models
- `AriaApplication/AssistantCoordinator.swift` - Only add methods, don't change existing behavior
- `AriaApplication/ToolOrchestrator.swift` - No changes
- `AriaApplication/ToolRegistry.swift` - No changes
- `AriaApplication/MemoryService.swift` - No changes
- `AriaApplication/ConversationService.swift` - No changes
- `AriaApplication/TextToSpeechService.swift` - No changes
- `AriaApplication/Avatar/AvatarStateManager.swift` - No changes
- `AriaApplication/RuntimeEntityContext.swift` - No changes
- `AriaApplication/TaskContextManager.swift` - No changes
- `AriaApplication/ClarificationManager.swift` - No changes
- `AriaApplication/ReferenceResolver.swift` - No changes

### Presentation Layer (MINIMAL CHANGES)
- `AriaPresentation/Avatar/AvatarRendering.swift` - No changes
- `AriaPresentation/Live2D/Live2DWindow.swift` - No changes
- `AriaPresentation/Live2D/Live2DSwiftBridge.swift` - No changes
- `AriaPresentation/DesktopUI/DesktopUIRendering.swift` - No changes

### Application Bootstrap (EXTEND ONLY)
- `AriaApplication/AppBootstrap.swift` - Add Runtime Adapter creation only
- `AriaApp/main.swift` - Add GUI mode selection only

---

## 23. Architecture Risks

### High Risk

**1. Actor-to-Main-Thread Threading**
- **Risk**: Complex coordination between actor-based backend and main-thread UI
- **Mitigation**: Use @MainActor for Runtime Adapter, careful async/await usage
- **Impact**: Could cause UI freezes or crashes if mishandled

**2. AsyncStream Backpressure**
- **Risk**: Backend events faster than UI can process
- **Mitigation**: Buffer AsyncStream, handle backpressure explicitly
- **Impact**: Could cause memory issues or UI lag

**3. Request ID Validation**
- **Risk**: Stale updates corrupting UI state
- **Mitigation**: Strict request ID validation in Runtime Adapter
- **Impact**: Could show wrong state to user

### Medium Risk

**4. SwiftUI + AppKit Integration**
- **Risk**: Framework boundary issues
- **Mitigation**: Clear separation, minimal bridging
- **Impact**: Could cause rendering issues or crashes

**5. Live2D Window Lifecycle**
- **Risk**: Window lifecycle conflicts with SwiftUI
- **Mitigation**: Preserve existing AppKit lifecycle, minimal changes
- **Impact**: Could cause avatar rendering issues

**6. Cancellation Propagation**
- **Risk**: Cancellation not propagating correctly
- **Mitigation**: Explicit cancellation handling at all layers
- **Impact**: Could cause stuck requests or zombie tasks

### Low Risk

**7. State Synchronization**
- **Risk**: UI state diverging from backend state
- **Mitigation**: Single source of truth, UI observes only
- **Impact**: Could show incorrect state to user

**8. Memory Management**
- **Risk**: Memory leaks from AsyncStream subscriptions
- **Mitigation**: Explicit cleanup in deinit, task cancellation
- **Impact**: Could cause memory growth over time

---

## 24. Final Recommendation

### Architecture Decision

**Recommended Architecture**: Hybrid SwiftUI + AppKit

**Components**:
- SwiftUI for conversation interface
- AppKit for existing Live2D integration
- Runtime Adapter layer for backend integration
- AsyncStream + @Observable for state observation
- AssistantCoordinator as single integration boundary

### State Ownership Principle

**Backend-Owned State**:
- All conversation, runtime, tool, context, and memory state
- UI observes only via snapshot APIs and event streams
- UI requests changes only through AssistantCoordinator

**UI-Owned State**:
- Draft text, scroll position, visual state, transient UI state
- UI has full ownership of presentation-specific state
- No backend state duplication in UI

### Integration Boundary

**Single Entry Point**: AssistantCoordinator
- All UI actions go through coordinator
- All backend state observed through coordinator
- No direct actor access from UI
- Session safety enforced at coordinator level

### Implementation Strategy

**Incremental Approach**:
1. Foundation (app shell, Runtime Adapter)
2. Conversation interface
3. Tool interaction UX
4. Avatar integration
5. Polish and validation

**Preservation Strategy**:
- Console runtime preserved for development
- Live2D integration unchanged
- Backend behavior unchanged
- Minimal modifications to existing code

### Risk Mitigation

**Threading**: @MainActor for Runtime Adapter, careful async/await
**State Synchronization**: Single source of truth, no duplication
**Cancellation**: Explicit handling at all layers
**Request Validation**: Strict request ID validation
**Cleanup**: Explicit resource cleanup on shutdown

---

## Final Status

**READY FOR PHASE 8 STEP 2 — UI FOUNDATION**

The architecture audit is complete. The recommended hybrid approach (SwiftUI + AppKit) provides the best balance of modern UI development with preservation of existing Live2D investment. The state ownership boundaries are clear, and the integration strategy minimizes disruption to the existing robust backend architecture.

**Next Step**: Begin Phase 8 Step 2 - Minimal Runtime UI Foundation

---

**End of Architecture Audit**
