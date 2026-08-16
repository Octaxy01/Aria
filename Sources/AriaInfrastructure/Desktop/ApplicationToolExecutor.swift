import Foundation
import AppKit
import AriaDomain

/// Executor for application control tools.
/// Implements safe macOS application operations using native APIs.
public actor ApplicationToolExecutor: ToolExecuting {
    
    private let applicationResolver: any ApplicationResolving
    
    public init(applicationResolver: any ApplicationResolving = NativeApplicationResolver()) {
        self.applicationResolver = applicationResolver
    }
    
    public func execute(_ call: ToolCall) async throws -> ToolResult {
        // Check for cancellation
        try Task.checkCancellation()
        
        // Validate arguments
        guard let applicationName = call.arguments["applicationName"] as? String else {
            throw ToolExecutionError.invalidArguments("Missing required parameter: applicationName")
        }
        
        // Route to specific tool implementation
        switch call.toolIdentifier {
        case .openApplication:
            return try await openApplication(named: applicationName, sessionID: call.sessionID)
        case .quitApplication:
            return try await quitApplication(named: applicationName, sessionID: call.sessionID)
        case .focusApplication:
            return try await focusApplication(named: applicationName, sessionID: call.sessionID)
        default:
            throw ToolExecutionError.toolNotFound(call.toolIdentifier)
        }
    }
    
    // MARK: - Open Application
    
    private func openApplication(named name: String, sessionID: UUID) async throws -> ToolResult {
        // Check for cancellation
        try Task.checkCancellation()
        
        // Validate application name is not empty or whitespace-only
        let trimmedName = name.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !trimmedName.isEmpty else {
            return ToolResult.failure("Application name cannot be empty", errorCode: "invalid_arguments")
        }
        
        // Resolve application
        guard let appURL = try await applicationResolver.resolveApplication(named: trimmedName) else {
            return ToolResult.failure("Application '\(trimmedName)' not found", errorCode: "application_not_found")
        }
        
        // Check for cancellation after resolution
        try Task.checkCancellation()
        
        // Launch application using NSWorkspace
        let success = await Task.detached(priority: .userInitiated) {
            let workspace = NSWorkspace.shared
            let config = NSWorkspace.OpenConfiguration()
            return try? workspace.openApplication(at: appURL, configuration: config)
        }.value
        
        if let runningApp = success {
            // Get bundle identifier if available
            let bundleIdentifier = Bundle(url: appURL)?.bundleIdentifier ?? "unknown"
            
            return ToolResult.success([
                "applicationName": trimmedName,
                "bundleIdentifier": bundleIdentifier,
                "path": appURL.path,
                "status": "launched"
            ])
        } else {
            return ToolResult.failure("Failed to launch application '\(trimmedName)'", errorCode: "launch_failed")
        }
    }
    
    // MARK: - Quit Application
    
    private func quitApplication(named name: String, sessionID: UUID) async throws -> ToolResult {
        // Check for cancellation
        try Task.checkCancellation()
        
        // Validate application name is not empty or whitespace-only
        let trimmedName = name.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !trimmedName.isEmpty else {
            return ToolResult.failure("Application name cannot be empty", errorCode: "invalid_arguments")
        }
        
        // Find running application
        guard let appInfo = await applicationResolver.findRunningApplication(named: trimmedName) else {
            return ToolResult.failure("Application '\(trimmedName)' is not running", errorCode: "application_not_running")
        }
        
        // Check for cancellation after finding
        try Task.checkCancellation()
        
        // Find the actual NSRunningApplication to terminate
        let runningApps = await Task.detached(priority: .userInitiated) {
            NSWorkspace.shared.runningApplications
        }.value
        
        guard let runningApp = runningApps.first(where: { $0.bundleIdentifier == appInfo.bundleIdentifier }) else {
            return ToolResult.failure("Application '\(trimmedName)' no longer running", errorCode: "application_not_running")
        }
        
        // Request termination gracefully
        let success = runningApp.terminate()
        
        if success {
            return ToolResult.success([
                "applicationName": trimmedName,
                "bundleIdentifier": appInfo.bundleIdentifier,
                "status": "terminated"
            ])
        } else {
            return ToolResult.failure("Failed to quit application '\(trimmedName)' - may require user interaction", errorCode: "quit_failed")
        }
    }
    
    // MARK: - Focus Application
    
    private func focusApplication(named name: String, sessionID: UUID) async throws -> ToolResult {
        // Check for cancellation
        try Task.checkCancellation()
        
        // Validate application name is not empty or whitespace-only
        let trimmedName = name.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !trimmedName.isEmpty else {
            return ToolResult.failure("Application name cannot be empty", errorCode: "invalid_arguments")
        }
        
        // Find running application
        guard let appInfo = await applicationResolver.findRunningApplication(named: trimmedName) else {
            return ToolResult.failure("Application '\(trimmedName)' is not running", errorCode: "application_not_running")
        }
        
        // Check for cancellation after finding
        try Task.checkCancellation()
        
        // Find the actual NSRunningApplication to activate
        let runningApps = await Task.detached(priority: .userInitiated) {
            NSWorkspace.shared.runningApplications
        }.value
        
        guard let runningApp = runningApps.first(where: { $0.bundleIdentifier == appInfo.bundleIdentifier }) else {
            return ToolResult.failure("Application '\(trimmedName)' no longer running", errorCode: "application_not_running")
        }
        
        // Activate application
        let success = runningApp.activate()
        
        if success {
            return ToolResult.success([
                "applicationName": trimmedName,
                "bundleIdentifier": appInfo.bundleIdentifier,
                "status": "focused"
            ])
        } else {
            return ToolResult.failure("Failed to focus application '\(trimmedName)'", errorCode: "focus_failed")
        }
    }
}