import Foundation
import AriaDomain

// MARK: - System Information

/// Struct representing basic system information.
public struct SystemInfo: Sendable, Equatable {
    public let computerName: String
    public let operatingSystem: String
    public let operatingSystemVersion: String
    public let architecture: String?
    
    public init(
        computerName: String,
        operatingSystem: String,
        operatingSystemVersion: String,
        architecture: String? = nil
    ) {
        self.computerName = computerName
        self.operatingSystem = operatingSystem
        self.operatingSystemVersion = operatingSystemVersion
        self.architecture = architecture
    }
}

/// Protocol for providing system information.
public protocol SystemInfoProviding: Sendable {
    /// Gets basic system information.
    /// - Returns: System information if available
    func getSystemInfo() async throws -> SystemInfo
}

/// Mock implementation for testing.
public actor MockSystemInfoProvider: SystemInfoProviding {
    private var systemInfo: SystemInfo?
    
    public init(systemInfo: SystemInfo? = nil) {
        self.systemInfo = systemInfo
    }
    
    public func setSystemInfo(_ info: SystemInfo) {
        self.systemInfo = info
    }
    
    public func getSystemInfo() async throws -> SystemInfo {
        guard let info = systemInfo else {
            throw SystemInfoError.unavailable
        }
        return info
    }
}

/// Native macOS implementation using ProcessInfo.
public actor NativeSystemInfoProvider: SystemInfoProviding {
    
    public init() {}
    
    public func getSystemInfo() async throws -> SystemInfo {
        let processInfo = ProcessInfo.processInfo
        
        // Get computer name
        let computerName = processInfo.hostName
        
        // Get operating system name and version
        let operatingSystem = "macOS"
        let operatingSystemVersion = processInfo.operatingSystemVersionString
        
        // Get architecture if available
        var architecture: String?
        #if arch(x86_64)
        architecture = "x86_64"
        #elseif arch(arm64)
        architecture = "arm64"
        #endif
        
        return SystemInfo(
            computerName: computerName,
            operatingSystem: operatingSystem,
            operatingSystemVersion: operatingSystemVersion,
            architecture: architecture
        )
    }
}

// MARK: - Battery Status

/// Struct representing battery status.
public struct BatteryStatus: Sendable, Equatable {
    public let percentage: Int?
    public let isCharging: Bool?
    public let powerSource: String?
    public let isBatteryUnavailable: Bool
    
    public init(
        percentage: Int? = nil,
        isCharging: Bool? = nil,
        powerSource: String? = nil,
        isBatteryUnavailable: Bool = false
    ) {
        self.percentage = percentage
        self.isCharging = isCharging
        self.powerSource = powerSource
        self.isBatteryUnavailable = isBatteryUnavailable
    }
    
    /// Creates a battery unavailable status.
    public static func unavailable() -> BatteryStatus {
        BatteryStatus(isBatteryUnavailable: true)
    }
}

/// Protocol for providing battery status.
public protocol BatteryStatusProviding: Sendable {
    /// Gets current battery status.
    /// - Returns: Battery status if available
    func getBatteryStatus() async throws -> BatteryStatus
}

/// Mock implementation for testing.
public actor MockBatteryStatusProvider: BatteryStatusProviding {
    private var batteryStatus: BatteryStatus?
    
    public init(batteryStatus: BatteryStatus? = nil) {
        self.batteryStatus = batteryStatus
    }
    
    public func setBatteryStatus(_ status: BatteryStatus) {
        self.batteryStatus = status
    }
    
    public func getBatteryStatus() async throws -> BatteryStatus {
        guard let status = batteryStatus else {
            throw SystemInfoError.unavailable
        }
        return status
    }
}

/// Native macOS implementation using IOKit.
public actor NativeBatteryStatusProvider: BatteryStatusProviding {
    
    public init() {}
    
    public func getBatteryStatus() async throws -> BatteryStatus {
        // Use IOKit to get battery information
        // This requires IOKit framework which is available on macOS
        
        let batteryInfo = await getBatteryInfoFromIOKit()
        
        return batteryInfo
    }
    
    private func getBatteryInfoFromIOKit() async -> BatteryStatus {
        // Try to get battery information from IOKit
        // Note: This is a simplified implementation that checks for battery presence
        // A full implementation would use IOKit APIs to get detailed battery info
        
        // For now, we'll use a basic check via ProcessInfo
        // In a production implementation, you would use IOKit to get:
        // - Battery capacity
        // - Charging state
        // - Power source
        
        // Since IOKit requires complex setup and may not be available in all environments,
        // we'll return an unavailable status for now
        // This can be enhanced later with proper IOKit integration
        
        return BatteryStatus.unavailable()
    }
}

// MARK: - Storage Information

/// Struct representing storage information.
public struct StorageInfo: Sendable, Equatable {
    public let volumeName: String
    public let totalCapacity: Int64
    public let availableCapacity: Int64
    public let usedCapacity: Int64
    
    public init(
        volumeName: String,
        totalCapacity: Int64,
        availableCapacity: Int64,
        usedCapacity: Int64
    ) {
        self.volumeName = volumeName
        self.totalCapacity = totalCapacity
        self.availableCapacity = availableCapacity
        self.usedCapacity = usedCapacity
    }
    
    /// Validates that the storage information is valid.
    public var isValid: Bool {
        return totalCapacity > 0 && availableCapacity >= 0 && usedCapacity >= 0
    }
}

/// Protocol for providing storage information.
public protocol StorageInfoProviding: Sendable {
    /// Gets storage information for the primary volume.
    /// - Returns: Storage information if available
    func getStorageInfo() async throws -> StorageInfo
}

/// Mock implementation for testing.
public actor MockStorageInfoProvider: StorageInfoProviding {
    private var storageInfo: StorageInfo?
    
    public init(storageInfo: StorageInfo? = nil) {
        self.storageInfo = storageInfo
    }
    
    public func setStorageInfo(_ info: StorageInfo) {
        self.storageInfo = info
    }
    
    public func getStorageInfo() async throws -> StorageInfo {
        guard let info = storageInfo else {
            throw SystemInfoError.unavailable
        }
        return info
    }
}

/// Native macOS implementation using FileManager.
public actor NativeStorageInfoProvider: StorageInfoProviding {
    
    public init() {}
    
    public func getStorageInfo() async throws -> StorageInfo {
        // Get the root volume URL
        let rootURL = URL(fileURLWithPath: "/")
        
        // Get volume name
        let volumeName: String
        if let name = try? rootURL.resourceValues(forKeys: [.localizedNameKey]).localizedName {
            volumeName = name
        } else {
            volumeName = "Macintosh HD"
        }
        
        // Get capacity information
        guard let totalCapacity = try? rootURL.resourceValues(forKeys: [.volumeTotalCapacityKey]).volumeTotalCapacity,
              let availableCapacity = try? rootURL.resourceValues(forKeys: [.volumeAvailableCapacityKey]).volumeAvailableCapacity else {
            throw SystemInfoError.unavailable
        }
        
        // Calculate used capacity
        let usedCapacity = totalCapacity - availableCapacity
        
        // Validate values
        guard totalCapacity > 0, availableCapacity >= 0, usedCapacity >= 0 else {
            throw SystemInfoError.invalidData
        }
        
        return StorageInfo(
            volumeName: volumeName,
            totalCapacity: Int64(totalCapacity),
            availableCapacity: Int64(availableCapacity),
            usedCapacity: Int64(usedCapacity)
        )
    }
}

// MARK: - Errors

/// Errors that can occur when retrieving system information.
public enum SystemInfoError: Error, Equatable {
    case unavailable
    case permissionDenied
    case invalidData
}
