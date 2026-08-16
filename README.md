# Aria — Stage 2: Conversation Core & Gemini Integration

Personal desktop AI companion. Stage 1 built the layered architecture and a
stub LLM provider. **Stage 2** replaces the stub with a real Gemini-backed
`GeminiProvider` (plain `URLSession`, no SDK), adds structured
request/response models, a system-prompt builder, and a simple context
limit. No voice, no Live2D, no tool execution, no memory database yet —
see "Known limitations" below and the roadmap this was built against.

## Requirements

- macOS 13+ (Apple Silicon)
- Xcode 15+ / Swift 5.9+ toolchain (`swift build` works from the command
  line too — Xcode is not required, just the toolchain)
- A Gemini API key (get one from Google AI Studio) set as `GEMINI_API_KEY`

This package was written and reviewed on a Linux sandbox that does **not**
have a Swift toolchain installed, so `swift build` / `swift test` could not
be executed as part of producing this code, and the real Gemini HTTP call
has not been exercised end-to-end by me. Everything was checked by hand for
API/type consistency, and the request-building/response-parsing logic has
offline unit test coverage — but **please run `swift build && swift test`
yourself first**, then try one real `swift run AriaApp` conversation, before
trusting this is fully working.

## How to run

```bash
cd Aria
make run                    # Recommended: copies metallibs and runs the app
# Or manually:
swift build
./Scripts/copy-metallibs.sh debug
swift test
GEMINI_API_KEY="your-key-here" swift run AriaApp
```

**Important**: Due to Live2D Metal shader loading, you must run `make run` (or manually run `./Scripts/copy-metallibs.sh debug` before `swift run`). The metallibs script copies required `.metallib` files to the SPM build directory.

Optional environment overrides:

```bash
export GEMINI_MODEL="gemini-2.5-flash"        # verify this is still current for your account
export GEMINI_TEMPERATURE="0.8"
export GEMINI_REQUEST_TIMEOUT_SECONDS="30"
export ARIA_LOG_LEVEL="debug"                  # debug | info | warning | error
```

`swift run AriaApp` starts a console loop and talks to the real Gemini API:

```
You: hello aria
Aria (embarrassed, 0.40): Hmph... h-hello. Don't expect me to say it twice.
```

If `GEMINI_API_KEY` isn't set, the app exits immediately with a clear error
instead of crashing or silently failing later.

`swift test` never calls the network or needs an API key — it uses fake/
recording providers and offline request/response parsing tests instead.

## Layout

```
Aria/
├── Package.swift
├── Sources/
│   ├── AriaDomain/            Pure models + protocols. No dependencies.
│   │   ├── Conversation/
│   │   ├── Emotion/
│   │   ├── Character/
│   │   ├── Tool/               (shape only, nothing executes yet)
│   │   ├── LLM/                 LLMRequest, LLMResponding, LLMResponse
│   │   └── Common/               AriaError (typed, not string-based)
│   ├── AriaApplication/        Orchestration. Depends only on AriaDomain.
│   │   ├── ConversationService.swift  (+ recentHistory context limit)
│   │   ├── EmotionService.swift        (deterministic EmotionEngining impl)
│   │   ├── SystemPromptBuilder.swift   (the one place personality → text)
│   │   └── AssistantCoordinator.swift
│   ├── AriaInfrastructure/     Concrete implementations of Domain protocols.
│   │   ├── LLM/GeminiProvider.swift        (real URLSession HTTP call)
│   │   ├── LLM/GeminiConfiguration.swift   (validated at construction)
│   │   ├── LLM/GeminiProviderError.swift   (typed HTTP/network errors)
│   │   ├── Config/AppConfiguration.swift
│   │   └── Logging/AriaLogger.swift
│   ├── AriaPresentation/       Interfaces + stubs for how Aria is shown.
│   │   ├── DesktopUI/           (console stub; real window is Stage 6)
│   │   └── Avatar/               (no-op stub; Live2D is Stage 7)
│   └── AriaApp/                Composition root — the only file allowed
│       └── main.swift            to construct concrete implementations.
└── Tests/
    ├── AriaDomainTests/
    ├── AriaApplicationTests/
    └── AriaInfrastructureTests/  (offline: config validation, request
                                    building, response parsing)
```

Dependency direction is enforced by the Swift Package Manager targets
themselves (not just convention): `AriaApplication`, `AriaInfrastructure`,
and `AriaPresentation` can only import `AriaDomain`. Only `AriaApp`
(the composition root) is allowed to import all four and wire concrete
types together. This is what keeps the Gemini provider from leaking into
the rest of the codebase, and keeps the LLM from being able to touch
application state directly — it can only return an `LLMResponse` (text +
an advisory `EmotionSignal`), and only `EmotionService` decides what that
actually does to Aria's real `EmotionState`.


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