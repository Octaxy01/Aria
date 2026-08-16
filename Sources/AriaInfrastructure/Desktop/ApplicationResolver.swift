import Foundation
import AppKit
import AriaDomain

/// Sendable wrapper for NSRunningApplication information.
public struct RunningApplicationInfo: Sendable {
    public let bundleIdentifier: String
    public let localizedName: String
    public let bundleURL: URL?
    
    public init(bundleIdentifier: String, localizedName: String, bundleURL: URL? = nil) {
        self.bundleIdentifier = bundleIdentifier
        self.localizedName = localizedName
        self.bundleURL = bundleURL
    }
}

/// Protocol for resolving macOS applications by name.
/// This abstraction allows for testing with mock implementations.
public protocol ApplicationResolving: Sendable {
    /// Resolves an application name to its URL.
    /// - Parameter name: The application name to resolve
    /// - Returns: The application URL if found, nil otherwise
    func resolveApplication(named name: String) async throws -> URL?
    
    /// Finds a running application by name.
    /// - Parameter name: The application name to find
    /// - Returns: The running application info if found, nil otherwise
    func findRunningApplication(named name: String) async -> RunningApplicationInfo?
    
    /// Checks if an application with the given name exists.
    /// - Parameter name: The application name to check
    /// - Returns: True if the application exists, false otherwise
    func applicationExists(named name: String) async -> Bool
    
    /// Checks if an application is currently running.
    /// - Parameter name: The application name to check
    /// - Returns: True if the application is running, false otherwise
    func isApplicationRunning(named name: String) async -> Bool
}

/// Mock implementation for testing.
public actor MockApplicationResolver: ApplicationResolving {
    private var applications: [String: URL] = [:]
    private var runningApplications: Set<String> = []
    
    public init() {}
    
    public func setApplication(_ name: String, url: URL) {
        applications[name] = url
    }
    
    public func setRunningApplication(_ name: String) {
        runningApplications.insert(name)
    }
    
    public func setRunningApplicationWithApp(_ name: String, url: URL) {
        runningApplications.insert(name)
        applications[name] = url
    }
    
    public func removeRunningApplication(_ name: String) {
        runningApplications.remove(name)
    }
    
    public func resolveApplication(named name: String) async throws -> URL? {
        return applications[name]
    }
    
    public func findRunningApplication(named name: String) async -> RunningApplicationInfo? {
        if runningApplications.contains(name) {
            return RunningApplicationInfo(
                bundleIdentifier: "com.test.\(name)",
                localizedName: name,
                bundleURL: applications[name]
            )
        }
        return nil
    }
    
    public func applicationExists(named name: String) async -> Bool {
        return applications[name] != nil
    }
    
    public func isApplicationRunning(named name: String) async -> Bool {
        return runningApplications.contains(name)
    }
}



/// Native macOS implementation of application resolution using NSWorkspace.
public actor NativeApplicationResolver: ApplicationResolving {
    
    public init() {}
    
    public func resolveApplication(named name: String) async throws -> URL? {
        // Use NSWorkspace to find the application URL
        let workspace = NSWorkspace.shared
        
        // Try to find the application by name
        if let url = workspace.urlForApplication(withBundleIdentifier: name) {
            return url
        }
        
        // Try to find by localizedName (display name)
        let runningApps = NSWorkspace.shared.runningApplications
        for app in runningApps {
            if app.localizedName?.caseInsensitiveCompare(name) == .orderedSame {
                return app.bundleURL
            }
        }
        
        // Try to find in common locations
        let searchPaths = [
            "/Applications",
            "/System/Applications",
            FileManager.default.homeDirectoryForCurrentUser.appendingPathComponent("Applications").path
        ]
        
        for searchPath in searchPaths {
            let applicationsPath = searchPath as NSString
            if let contents = try? FileManager.default.contentsOfDirectory(atPath: searchPath) {
                for item in contents {
                    if item.hasSuffix(".app") {
                        let appName = item.replacingOccurrences(of: ".app", with: "")
                        if appName.caseInsensitiveCompare(name) == .orderedSame {
                            return URL(fileURLWithPath: applicationsPath.appendingPathComponent(item))
                        }
                    }
                }
            }
        }
        
        return nil
    }
    
    public func findRunningApplication(named name: String) async -> RunningApplicationInfo? {
        let runningApps = await Task.detached(priority: .userInitiated) {
            NSWorkspace.shared.runningApplications
        }.value
        
        // Try exact match first
        if let exactMatch = runningApps.first(where: { $0.localizedName == name }) {
            return RunningApplicationInfo(
                bundleIdentifier: exactMatch.bundleIdentifier ?? "unknown",
                localizedName: exactMatch.localizedName ?? "unknown",
                bundleURL: exactMatch.bundleURL
            )
        }
        
        // Try case-insensitive match
        if let caseInsensitiveMatch = runningApps.first(where: { 
            $0.localizedName?.caseInsensitiveCompare(name) == .orderedSame 
        }) {
            return RunningApplicationInfo(
                bundleIdentifier: caseInsensitiveMatch.bundleIdentifier ?? "unknown",
                localizedName: caseInsensitiveMatch.localizedName ?? "unknown",
                bundleURL: caseInsensitiveMatch.bundleURL
            )
        }
        
        // Try bundle identifier match
        if let bundleMatch = runningApps.first(where: { 
            $0.bundleIdentifier?.caseInsensitiveCompare(name) == .orderedSame 
        }) {
            return RunningApplicationInfo(
                bundleIdentifier: bundleMatch.bundleIdentifier ?? "unknown",
                localizedName: bundleMatch.localizedName ?? "unknown",
                bundleURL: bundleMatch.bundleURL
            )
        }
        
        return nil
    }
    
    public func applicationExists(named name: String) async -> Bool {
        do {
            return try await resolveApplication(named: name) != nil
        } catch {
            return false
        }
    }
    
    public func isApplicationRunning(named name: String) async -> Bool {
        return await findRunningApplication(named: name) != nil
    }
}

/// Error types for application resolution.
public enum ApplicationResolutionError: Error, Equatable {
    case applicationNotFound(String)
    case ambiguousApplication(String, candidates: [String])
    case invalidApplicationName(String)
}