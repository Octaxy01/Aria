import SwiftUI
import AppKit
import AriaDomain
import AriaApplication
import AriaPresentation
import AriaInfrastructure

/// The SwiftUI application for Aria desktop GUI.
/// This is used when running in GUI mode.
public struct AriaDesktopApp: App {
    @NSApplicationDelegateAdaptor(AppDelegate.self)
    var appDelegate: AppDelegate
    
    public init() {
        // Initialization handled by AppDelegate
    }
    
    public var body: some Scene {
        WindowGroup {
            AriaRootView()
                .frame(minWidth: 600, minHeight: 400)
        }
        .windowStyle(.hiddenTitleBar)
        .windowResizability(.contentSize)
        .commands {
            CommandMenu("Conversation") {
                Button("Clear Conversation") {
                    if let appDelegate = NSApplication.shared.delegate as? AppDelegate {
                        Task { @MainActor in
                            await appDelegate.runtimeAdapter?.clearConversation()
                        }
                    }
                }
                .keyboardShortcut("k", modifiers: .command)
            }
        }
    }
}

/// Application delegate for NSApplication lifecycle management.
public class AppDelegate: NSObject, NSApplicationDelegate {
    var coordinator: AssistantCoordinator?
    var runtimeAdapter: AriaRuntimeAdapter?
    
    public func applicationDidFinishLaunching(_ notification: Notification) {
        // Initialize backend components
        Task { @MainActor in
            await initializeBackend()
        }
    }
    
    @MainActor
    private func initializeBackend() async {
        let config = AppConfiguration.load()
        let logger = ConsoleLogger(minimumLevel: config.logLevel)
        
        // Initialize OpenRouter
        let openRouterConfiguration: OpenRouterConfiguration
        do {
            openRouterConfiguration = try OpenRouterConfiguration.make(
                apiKey: config.openRouterAPIKey,
                model: config.openRouterModel,
                temperature: config.openRouterTemperature,
                timeout: config.openRouterRequestTimeoutSeconds
            )
        } catch {
            logger.error("Startup failed: \(error). Set OPENROUTER_API_KEY and try again.")
            NSApplication.shared.terminate(nil)
            return
        }
        
        let llmProvider = OpenRouterProvider(
            configuration: openRouterConfiguration,
            logger: logger
        )
        
        // Initialize coordinator
        let coordinator = await AppBootstrap.createCoordinator(
            llm: llmProvider,
            logger: logger,
            config: config
        )
        
        // Initialize avatar state manager
        let avatarStateManager = AppBootstrap.createAvatarStateManager()
        await coordinator.setAvatarStateManager(avatarStateManager)
        
        // Initialize runtime adapter
        let runtimeAdapter = AppBootstrap.createRuntimeAdapter(coordinator: coordinator)
        
        // Store for cleanup
        self.coordinator = coordinator
        self.runtimeAdapter = runtimeAdapter
        
        // Load initial conversation
        await loadInitialConversation()
    }
    
    @MainActor
    private func loadInitialConversation() async {
        guard let coordinator = coordinator else { return }
        
        // Get conversation history
        let conversation = await coordinator.getConversation()
        
        // Convert to view data
        let viewData = conversation.map { ConversationMessageViewData.from($0) }
        
        // Update runtime adapter via its update method
        runtimeAdapter?.messages = viewData
    }
    
    public func applicationShouldTerminate(_ sender: NSApplication) -> NSApplication.TerminateReply {
        // Allow termination after cleanup
        Task {
            await performCleanup()
        }
        return .terminateNow
    }
    
    public func applicationWillTerminate(_ notification: Notification) {
        // Cleanup handled in applicationShouldTerminate
    }
    
    @MainActor
    private func performCleanup() async {
        // Cancel runtime adapter event stream
        runtimeAdapter?.cancelEventStream()
        
        // Clear conversation
        await coordinator?.clearConversation()
        
        // Release references
        coordinator = nil
        runtimeAdapter = nil
    }
}

/// The root SwiftUI view for the Aria desktop application.
public struct AriaRootView: View {
    @State private var runtimeAdapter: AriaRuntimeAdapter?
    
    public init() {}
    
    public var body: some View {
        Group {
            if let adapter = runtimeAdapter {
                ConversationView(adapter: adapter)
            } else {
                LoadingView()
            }
        }
        .onAppear {
            setupRuntimeAdapter()
        }
    }
    
    private func setupRuntimeAdapter() {
        // Get the adapter from the app delegate
        if let appDelegate = NSApplication.shared.delegate as? AppDelegate {
            runtimeAdapter = appDelegate.runtimeAdapter
        }
    }
}

/// Loading view shown during initialization.
private struct LoadingView: View {
    var body: some View {
        VStack(spacing: 20) {
            ProgressView()
                .scaleEffect(1.5)
            Text("Aria sedang memuat...")
                .font(.headline)
        }
        .frame(maxWidth: .infinity, maxHeight: .infinity)
    }
}

/// Main conversation view for Aria.
@MainActor
public struct ConversationView: View {
    var adapter: AriaRuntimeAdapter
    @State private var messageDraft: String = ""
    @FocusState private var isInputFocused: Bool
    
    public init(adapter: AriaRuntimeAdapter) {
        self.adapter = adapter
    }
    
    public var body: some View {
        GeometryReader { geometry in
            HStack(spacing: 0) {
                // Avatar sidebar
                avatarSidebar
                    .frame(width: avatarWidth(for: geometry.size.width))
                    .background(Color(NSColor.controlBackgroundColor))
                
                // Main conversation area
                VStack(spacing: 0) {
                    // Header
                    headerView
                    
                    // Conversation area
                    conversationArea
                    
                    // Input area
                    inputArea
                }
                .background(Color(NSColor.windowBackgroundColor))
            }
        }
    }
    
    private func avatarWidth(for totalWidth: CGFloat) -> CGFloat {
        if totalWidth < 800 {
            // Narrow window: shrink avatar sidebar
            return min(200, totalWidth * 0.3)
        } else if totalWidth < 1200 {
            // Medium window: moderate avatar sidebar
            return 250
        } else {
            // Wide window: full avatar sidebar
            return 300
        }
    }
    
    private var avatarSidebar: some View {
        VStack(spacing: 12) {
            // Live2D avatar view
            Live2DView(
                configuration: .sumireDefault,
                avatarState: adapter.avatarState
            )
            .frame(maxWidth: .infinity, maxHeight: .infinity)
            .background(Color.clear)
            .clipped()
            
            // Avatar state indicator
            avatarStateIndicator
        }
        .padding()
        .frame(maxWidth: .infinity, maxHeight: .infinity)
    }
    
    private var avatarStateIndicator: some View {
        HStack(spacing: 8) {
            Circle()
                .fill(stateColor(for: adapter.avatarState))
                .frame(width: 8, height: 8)
            
            Text(stateText(for: adapter.avatarState))
                .font(.caption)
                .foregroundColor(.secondary)
        }
        .padding(.horizontal, 12)
        .padding(.vertical, 6)
        .background(Color(NSColor.controlBackgroundColor))
        .cornerRadius(12)
    }
    
    private func stateColor(for state: AvatarState) -> Color {
        switch state {
        case .idle:
            return .green
        case .thinking:
            return .orange
        case .talking:
            return .blue
        case .listening:
            return .purple
        }
    }
    
    private func stateText(for state: AvatarState) -> String {
        switch state {
        case .idle:
            return "Siap"
        case .thinking:
            return "Berpikir"
        case .talking:
            return "Berbicara"
        case .listening:
            return "Mendengarkan"
        }
    }
    
    private var headerView: some View {
        HStack {
            Text("Aria")
                .font(.headline)
                .fontWeight(.bold)
            
            Spacer()
        }
        .padding()
        .background(Color(NSColor.controlBackgroundColor))
    }
    
    private var conversationArea: some View {
        ScrollViewReader { proxy in
            ScrollView {
                VStack(spacing: 12) {
                    if adapter.messages.isEmpty {
                        emptyStateView
                    } else {
                        ForEach(adapter.messages) { message in
                            MessageView(message: message)
                                .id(message.id)
                        }
                        
                        conversationStatusViews
                    }
                }
                .padding()
            }
            .onChange(of: adapter.messages.count) { oldValue, newValue in
                scrollToBottom(proxy: proxy)
            }
            .onChange(of: adapter.isProcessing) { oldValue, newValue in
                scrollToBottom(proxy: proxy)
            }
            .onChange(of: adapter.lastError) { oldValue, newValue in
                scrollToBottom(proxy: proxy)
            }
            .onChange(of: adapter.currentToolActivity) { oldValue, newValue in
                scrollToBottom(proxy: proxy)
            }
            .onChange(of: adapter.isClarificationPending) { oldValue, newValue in
                scrollToBottom(proxy: proxy)
            }
            .onChange(of: adapter.isConfirmationPending) { oldValue, newValue in
                scrollToBottom(proxy: proxy)
            }
            .onChange(of: adapter.canRetryTool) { oldValue, newValue in
                scrollToBottom(proxy: proxy)
            }
        }
    }
    
    private var conversationStatusViews: some View {
        VStack(spacing: 8) {
            // User interactions take precedence
            if adapter.isClarificationPending {
                clarificationView
                    .id("clarification")
            } else if adapter.isConfirmationPending {
                confirmationView
                    .id("confirmation")
            } else if adapter.canRetryTool {
                recoveryView
                    .id("recovery")
            }
            // Tool activity takes precedence over general processing
            else if adapter.currentToolActivity != nil {
                toolActivityView
                    .id("toolActivity")
            }
            // General processing indicator
            else if adapter.isProcessing {
                processingIndicator
                    .id("processing")
            }
            
            // Error always shown if present
            if adapter.lastError != nil {
                errorView
                    .id("error")
            }
        }
    }
    
    private var emptyStateView: some View {
        VStack(spacing: 16) {
            Image(systemName: "message.circle")
                .font(.system(size: 48))
                .foregroundColor(.secondary)
            
            VStack(spacing: 8) {
                Text("Halo, aku Aria")
                    .font(.headline)
                    .foregroundColor(.primary)
                
                Text("Ada yang bisa aku bantu?")
                    .font(.subheadline)
                    .foregroundColor(.secondary)
            }
        }
        .frame(maxWidth: .infinity, maxHeight: .infinity)
    }
    
    private var processingIndicator: some View {
        HStack(spacing: 8) {
            ProgressView()
                .scaleEffect(0.8)
            Text("Aria sedang berpikir...")
                .font(.caption)
                .foregroundColor(.secondary)
        }
        .padding()
        .background(Color(NSColor.controlBackgroundColor))
        .cornerRadius(8)
    }
    
    private var errorView: some View {
        HStack(spacing: 8) {
            Image(systemName: "exclamationmark.triangle.fill")
                .foregroundColor(.orange)
            Text(adapter.lastError ?? "Terjadi kesalahan")
                .font(.caption)
                .foregroundColor(.primary)
                .lineLimit(2)
        }
        .padding(.horizontal, 12)
        .padding(.vertical, 8)
        .background(Color.orange.opacity(0.1))
        .cornerRadius(8)
        .accessibilityLabel("Error: \(adapter.lastError ?? "Terjadi kesalahan")")
    }
    
    private var toolActivityView: some View {
        HStack(spacing: 8) {
            ProgressView()
                .scaleEffect(0.8)
            Text(adapter.currentToolActivity ?? "")
                .font(.caption)
                .foregroundColor(.secondary)
        }
        .padding(.horizontal, 12)
        .padding(.vertical, 8)
        .background(Color.blue.opacity(0.1))
        .cornerRadius(8)
    }
    
    private var clarificationView: some View {
        VStack(alignment: .leading, spacing: 12) {
            HStack(spacing: 8) {
                Image(systemName: "questionmark.circle.fill")
                    .foregroundColor(.blue)
                Text(adapter.clarificationQuestion ?? "Aku butuh klarifikasi")
                    .font(.subheadline)
                    .fontWeight(.medium)
            }
            
            if !adapter.clarificationCandidates.isEmpty {
                VStack(alignment: .leading, spacing: 8) {
                    ForEach(Array(adapter.clarificationCandidates.enumerated()), id: \.element.id) { index, candidate in
                        Button(action: {
                            Task {
                                await adapter.selectClarificationCandidate(index + 1)
                            }
                        }) {
                            HStack {
                                Text("\(index + 1).")
                                    .font(.caption)
                                    .foregroundColor(.secondary)
                                    .frame(width: 20, alignment: .leading)
                                Text(candidate.displayName)
                                    .font(.caption)
                                    .lineLimit(2)
                                Spacer()
                            }
                            .padding(.horizontal, 12)
                            .padding(.vertical, 8)
                            .background(Color(NSColor.controlBackgroundColor))
                            .cornerRadius(6)
                        }
                        .buttonStyle(.plain)
                        .disabled(adapter.isToolSubmissionPending)
                        .accessibilityLabel("Pilih \(candidate.displayName)")
                        .accessibilityHint("Opsi \(index + 1) dari \(adapter.clarificationCandidates.count)")
                    }
                }
            }
            
            HStack(spacing: 8) {
                Button(action: {
                    Task {
                        await adapter.cancelClarification()
                    }
                }) {
                    Text("Batal")
                        .font(.caption)
                        .padding(.horizontal, 12)
                        .padding(.vertical, 6)
                        .background(Color.red.opacity(0.1))
                        .foregroundColor(.red)
                        .cornerRadius(6)
                }
                .buttonStyle(.plain)
                .disabled(adapter.isToolSubmissionPending)
                .accessibilityLabel("Batalkan klarifikasi")
            }
        }
        .padding()
        .background(Color.blue.opacity(0.05))
        .cornerRadius(12)
    }
    
    private var confirmationView: some View {
        VStack(alignment: .leading, spacing: 12) {
            HStack(spacing: 8) {
                Image(systemName: "hand.raised.fill")
                    .foregroundColor(.orange)
                Text("Aria ingin melakukan tindakan:")
                    .font(.subheadline)
                    .fontWeight(.medium)
            }
            
            Text(adapter.confirmationAction ?? "")
                .font(.caption)
                .foregroundColor(.secondary)
                .lineLimit(3)
            
            HStack(spacing: 12) {
                Button(action: {
                    Task {
                        await adapter.respondToConfirmation(true)
                    }
                }) {
                    Text("Lanjut")
                        .font(.caption)
                        .padding(.horizontal, 16)
                        .padding(.vertical, 8)
                        .background(Color.green)
                        .foregroundColor(.white)
                        .cornerRadius(6)
                }
                .buttonStyle(.plain)
                .disabled(adapter.isToolSubmissionPending)
                .accessibilityLabel("Lanjutkan tindakan")
                .accessibilityHint("Izinkan Aria melakukan tindakan ini")
                
                Button(action: {
                    Task {
                        await adapter.respondToConfirmation(false)
                    }
                }) {
                    Text("Batal")
                        .font(.caption)
                        .padding(.horizontal, 16)
                        .padding(.vertical, 8)
                        .background(Color.red.opacity(0.8))
                        .foregroundColor(.white)
                        .cornerRadius(6)
                }
                .buttonStyle(.plain)
                .disabled(adapter.isToolSubmissionPending)
                .accessibilityLabel("Batalkan tindakan")
                .accessibilityHint("Batalkan tindakan yang diminta Aria")
            }
        }
        .padding()
        .background(Color.orange.opacity(0.05))
        .cornerRadius(12)
    }
    
    private var recoveryView: some View {
        HStack(spacing: 12) {
            Button(action: {
                Task {
                    await adapter.retryTool()
                }
            }) {
                HStack(spacing: 6) {
                    Image(systemName: "arrow.clockwise")
                    Text("Coba Lagi")
                        .font(.caption)
                }
                .padding(.horizontal, 16)
                .padding(.vertical, 8)
                .background(Color.blue)
                .foregroundColor(.white)
                .cornerRadius(6)
            }
            .buttonStyle(.plain)
            .disabled(adapter.isToolSubmissionPending)
            .accessibilityLabel("Coba lagi tindakan yang gagal")
            .accessibilityHint("Ulangi tindakan yang sebelumnya gagal")
        }
        .padding()
        .background(Color.blue.opacity(0.05))
        .cornerRadius(12)
    }
    
    private var inputArea: some View {
        VStack(spacing: 8) {
            HStack(spacing: 8) {
                TextField("Ketik pesan...", text: $messageDraft, axis: .vertical)
                    .textFieldStyle(.roundedBorder)
                    .lineLimit(1...6)
                    .focused($isInputFocused)
                    .disabled(adapter.isProcessing || adapter.isClarificationPending || adapter.isConfirmationPending)
                    .onSubmit {
                        if canSend {
                            sendMessage()
                        }
                    }
                
                // Send button
                Button(action: sendMessage) {
                    Image(systemName: "arrow.up.circle.fill")
                        .font(.system(size: 24))
                        .foregroundColor(canSend ? .accentColor : .secondary)
                }
                .buttonStyle(.plain)
                .disabled(!canSend)
                .keyboardShortcut(.defaultAction)
                .accessibilityLabel("Kirim pesan")
                
                // Cancel button
                if adapter.isProcessing {
                    Button(action: {
                        Task {
                            await adapter.cancelRequest()
                        }
                    }) {
                        Image(systemName: "xmark.circle.fill")
                            .font(.system(size: 24))
                            .foregroundColor(.red)
                    }
                    .buttonStyle(.plain)
                    .accessibilityLabel("Batalkan permintaan")
                }
            }
            .padding()
        }
        .background(Color(NSColor.controlBackgroundColor))
    }
    
    private var canSend: Bool {
        !messageDraft.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty && !adapter.isProcessing
    }
    
    private func sendMessage() {
        let text = messageDraft.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !text.isEmpty else { return }
        
        Task {
            await adapter.sendMessage(text)
        }
        
        messageDraft = ""
    }
    
    private func scrollToBottom(proxy: ScrollViewProxy) {
        withAnimation {
            proxy.scrollTo("processing", anchor: .bottom)
        }
    }
}

/// Individual message view.
private struct MessageView: View {
    let message: ConversationMessageViewData
    
    var body: some View {
        HStack {
            if message.role == .user {
                Spacer()
            }
            
            VStack(alignment: message.role == .user ? .trailing : .leading, spacing: 4) {
                Text(message.role == .user ? "Kamu" : "Aria")
                    .font(.caption)
                    .foregroundColor(.secondary)
                
                Text(message.content)
                    .textSelection(.enabled)
                    .padding(.horizontal, 12)
                    .padding(.vertical, 8)
                    .background(message.role == .user ? Color.accentColor : Color(NSColor.controlBackgroundColor))
                    .foregroundColor(message.role == .user ? .white : .primary)
                    .cornerRadius(12)
            }
            .frame(maxWidth: 400, alignment: message.role == .user ? .trailing : .leading)
            
            if message.role == .assistant {
                Spacer()
            }
        }
    }
}
