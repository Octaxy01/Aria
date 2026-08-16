import Foundation
import AriaDomain

/// Executor for system information tools.
/// Implements safe macOS system information operations using native APIs.
public actor SystemToolExecutor: ToolExecuting {
    
    private let systemInfoProvider: any SystemInfoProviding
    private let batteryStatusProvider: any BatteryStatusProviding
    private let storageInfoProvider: any StorageInfoProviding
    
    public init(
        systemInfoProvider: any SystemInfoProviding = NativeSystemInfoProvider(),
        batteryStatusProvider: any BatteryStatusProviding = NativeBatteryStatusProvider(),
        storageInfoProvider: any StorageInfoProviding = NativeStorageInfoProvider()
    ) {
        self.systemInfoProvider = systemInfoProvider
        self.batteryStatusProvider = batteryStatusProvider
        self.storageInfoProvider = storageInfoProvider
    }
    
    public func execute(_ call: ToolCall) async throws -> ToolResult {
        // Check for cancellation
        try Task.checkCancellation()
        
        // Route to specific tool implementation
        switch call.toolIdentifier {
        case .getSystemInfo:
            return try await getSystemInfo(sessionID: call.sessionID)
        case .getBatteryStatus:
            return try await getBatteryStatus(sessionID: call.sessionID)
        case .getStorageInfo:
            return try await getStorageInfo(sessionID: call.sessionID)
        default:
            throw ToolExecutionError.toolNotFound(call.toolIdentifier)
        }
    }
    
    // MARK: - Get System Info
    
    private func getSystemInfo(sessionID: UUID) async throws -> ToolResult {
        // Check for cancellation
        try Task.checkCancellation()
        
        // Get system information
        let systemInfo = try await systemInfoProvider.getSystemInfo()
        
        // Check for cancellation after retrieval
        try Task.checkCancellation()
        
        // Build result dictionary
        var result: [String: Any] = [
            "computerName": systemInfo.computerName,
            "operatingSystem": systemInfo.operatingSystem,
            "operatingSystemVersion": systemInfo.operatingSystemVersion
        ]
        
        // Add architecture if available
        if let architecture = systemInfo.architecture {
            result["architecture"] = architecture
        }
        
        return ToolResult.success(result)
    }
    
    // MARK: - Get Battery Status
    
    private func getBatteryStatus(sessionID: UUID) async throws -> ToolResult {
        // Check for cancellation
        try Task.checkCancellation()
        
        // Get battery status
        let batteryStatus = try await batteryStatusProvider.getBatteryStatus()
        
        // Check for cancellation after retrieval
        try Task.checkCancellation()
        
        // Handle battery unavailable case
        if batteryStatus.isBatteryUnavailable {
            return ToolResult.success([
                "batteryUnavailable": true,
                "message": "Battery information is not available on this device"
            ])
        }
        
        // Build result dictionary
        var result: [String: Any] = [:]
        
        if let percentage = batteryStatus.percentage {
            result["percentage"] = percentage
        }
        
        if let isCharging = batteryStatus.isCharging {
            result["isCharging"] = isCharging
        }
        
        if let powerSource = batteryStatus.powerSource {
            result["powerSource"] = powerSource
        }
        
        return ToolResult.success(result)
    }
    
    // MARK: - Get Storage Info
    
    private func getStorageInfo(sessionID: UUID) async throws -> ToolResult {
        // Check for cancellation
        try Task.checkCancellation()
        
        // Get storage information
        let storageInfo = try await storageInfoProvider.getStorageInfo()
        
        // Check for cancellation after retrieval
        try Task.checkCancellation()
        
        // Validate storage info
        guard storageInfo.isValid else {
            return ToolResult.failure("Invalid storage information", errorCode: "invalidData")
        }
        
        // Build result dictionary
        let result: [String: Any] = [
            "volumeName": storageInfo.volumeName,
            "totalCapacity": storageInfo.totalCapacity,
            "availableCapacity": storageInfo.availableCapacity,
            "usedCapacity": storageInfo.usedCapacity
        ]
        
        return ToolResult.success(result)
    }
}
