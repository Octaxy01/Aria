import XCTest
@testable import AriaInfrastructure
@testable import AriaDomain

final class SystemInfoProvidersTests: XCTestCase {
    
    // MARK: - SystemInfoProvider Tests
    
    func testMockSystemInfoProviderReturnsSetInfo() async throws {
        let provider = MockSystemInfoProvider()
        let expectedInfo = SystemInfo(
            computerName: "TestMac",
            operatingSystem: "macOS",
            operatingSystemVersion: "14.0",
            architecture: "arm64"
        )
        
        await provider.setSystemInfo(expectedInfo)
        let result = try await provider.getSystemInfo()
        
        XCTAssertEqual(result.computerName, "TestMac")
        XCTAssertEqual(result.operatingSystem, "macOS")
        XCTAssertEqual(result.operatingSystemVersion, "14.0")
        XCTAssertEqual(result.architecture, "arm64")
    }
    
    func testMockSystemInfoProviderThrowsWhenNoInfoSet() async {
        let provider = MockSystemInfoProvider()
        
        do {
            _ = try await provider.getSystemInfo()
            XCTFail("Expected SystemInfoError.unavailable to be thrown")
        } catch SystemInfoError.unavailable {
            // Expected
        } catch {
            XCTFail("Expected SystemInfoError.unavailable, got \(error)")
        }
    }
    
    func testSystemInfoEquatable() {
        let info1 = SystemInfo(
            computerName: "Mac",
            operatingSystem: "macOS",
            operatingSystemVersion: "14.0",
            architecture: "arm64"
        )
        
        let info2 = SystemInfo(
            computerName: "Mac",
            operatingSystem: "macOS",
            operatingSystemVersion: "14.0",
            architecture: "arm64"
        )
        
        XCTAssertEqual(info1, info2)
    }
    
    func testSystemInfoWithNilArchitecture() {
        let info1 = SystemInfo(
            computerName: "Mac",
            operatingSystem: "macOS",
            operatingSystemVersion: "14.0",
            architecture: nil
        )
        
        let info2 = SystemInfo(
            computerName: "Mac",
            operatingSystem: "macOS",
            operatingSystemVersion: "14.0",
            architecture: nil
        )
        
        XCTAssertEqual(info1, info2)
    }
    
    // MARK: - BatteryStatusProvider Tests
    
    func testMockBatteryStatusProviderReturnsSetStatus() async throws {
        let provider = MockBatteryStatusProvider()
        let expectedStatus = BatteryStatus(
            percentage: 85,
            isCharging: false,
            powerSource: "battery",
            isBatteryUnavailable: false
        )
        
        await provider.setBatteryStatus(expectedStatus)
        let result = try await provider.getBatteryStatus()
        
        XCTAssertEqual(result.percentage, 85)
        XCTAssertEqual(result.isCharging, false)
        XCTAssertEqual(result.powerSource, "battery")
        XCTAssertEqual(result.isBatteryUnavailable, false)
    }
    
    func testMockBatteryStatusProviderThrowsWhenNoStatusSet() async {
        let provider = MockBatteryStatusProvider()
        
        do {
            _ = try await provider.getBatteryStatus()
            XCTFail("Expected SystemInfoError.unavailable to be thrown")
        } catch SystemInfoError.unavailable {
            // Expected
        } catch {
            XCTFail("Expected SystemInfoError.unavailable, got \(error)")
        }
    }
    
    func testBatteryStatusUnavailable() {
        let status = BatteryStatus.unavailable()
        
        XCTAssertTrue(status.isBatteryUnavailable)
        XCTAssertNil(status.percentage)
        XCTAssertNil(status.isCharging)
        XCTAssertNil(status.powerSource)
    }
    
    func testBatteryStatusEquatable() {
        let status1 = BatteryStatus(
            percentage: 75,
            isCharging: true,
            powerSource: "AC Power",
            isBatteryUnavailable: false
        )
        
        let status2 = BatteryStatus(
            percentage: 75,
            isCharging: true,
            powerSource: "AC Power",
            isBatteryUnavailable: false
        )
        
        XCTAssertEqual(status1, status2)
    }
    
    func testBatteryStatusWithOptionalFields() {
        let status1 = BatteryStatus(
            percentage: nil,
            isCharging: nil,
            powerSource: nil,
            isBatteryUnavailable: false
        )
        
        let status2 = BatteryStatus(
            percentage: nil,
            isCharging: nil,
            powerSource: nil,
            isBatteryUnavailable: false
        )
        
        XCTAssertEqual(status1, status2)
    }
    
    // MARK: - StorageInfoProvider Tests
    
    func testMockStorageInfoProviderReturnsSetInfo() async throws {
        let provider = MockStorageInfoProvider()
        let expectedInfo = StorageInfo(
            volumeName: "Macintosh HD",
            totalCapacity: 1_000_000_000_000,
            availableCapacity: 500_000_000_000,
            usedCapacity: 500_000_000_000
        )
        
        await provider.setStorageInfo(expectedInfo)
        let result = try await provider.getStorageInfo()
        
        XCTAssertEqual(result.volumeName, "Macintosh HD")
        XCTAssertEqual(result.totalCapacity, 1_000_000_000_000)
        XCTAssertEqual(result.availableCapacity, 500_000_000_000)
        XCTAssertEqual(result.usedCapacity, 500_000_000_000)
    }
    
    func testMockStorageInfoProviderThrowsWhenNoInfoSet() async {
        let provider = MockStorageInfoProvider()
        
        do {
            _ = try await provider.getStorageInfo()
            XCTFail("Expected SystemInfoError.unavailable to be thrown")
        } catch SystemInfoError.unavailable {
            // Expected
        } catch {
            XCTFail("Expected SystemInfoError.unavailable, got \(error)")
        }
    }
    
    func testStorageInfoValidation() {
        let validInfo = StorageInfo(
            volumeName: "Mac",
            totalCapacity: 1_000_000_000_000,
            availableCapacity: 500_000_000_000,
            usedCapacity: 500_000_000_000
        )
        
        XCTAssertTrue(validInfo.isValid)
    }
    
    func testStorageInfoInvalidWithZeroTotal() {
        let invalidInfo = StorageInfo(
            volumeName: "Mac",
            totalCapacity: 0,
            availableCapacity: 0,
            usedCapacity: 0
        )
        
        XCTAssertFalse(invalidInfo.isValid)
    }
    
    func testStorageInfoInvalidWithNegativeAvailable() {
        let invalidInfo = StorageInfo(
            volumeName: "Mac",
            totalCapacity: 1_000_000_000_000,
            availableCapacity: -100,
            usedCapacity: 1_000_000_000_100
        )
        
        XCTAssertFalse(invalidInfo.isValid)
    }
    
    func testStorageInfoInvalidWithNegativeUsed() {
        let invalidInfo = StorageInfo(
            volumeName: "Mac",
            totalCapacity: 1_000_000_000_000,
            availableCapacity: 1_100_000_000_000,
            usedCapacity: -100_000_000_000
        )
        
        XCTAssertFalse(invalidInfo.isValid)
    }
    
    func testStorageInfoEquatable() {
        let info1 = StorageInfo(
            volumeName: "Mac",
            totalCapacity: 1_000_000_000_000,
            availableCapacity: 500_000_000_000,
            usedCapacity: 500_000_000_000
        )
        
        let info2 = StorageInfo(
            volumeName: "Mac",
            totalCapacity: 1_000_000_000_000,
            availableCapacity: 500_000_000_000,
            usedCapacity: 500_000_000_000
        )
        
        XCTAssertEqual(info1, info2)
    }
    
    // MARK: - SystemInfoError Tests
    
    func testSystemInfoErrorEquatable() {
        XCTAssertEqual(SystemInfoError.unavailable, SystemInfoError.unavailable)
        XCTAssertEqual(SystemInfoError.permissionDenied, SystemInfoError.permissionDenied)
        XCTAssertEqual(SystemInfoError.invalidData, SystemInfoError.invalidData)
    }
    
    func testSystemInfoErrorNotEqual() {
        XCTAssertNotEqual(SystemInfoError.unavailable, SystemInfoError.permissionDenied)
        XCTAssertNotEqual(SystemInfoError.permissionDenied, SystemInfoError.invalidData)
        XCTAssertNotEqual(SystemInfoError.invalidData, SystemInfoError.unavailable)
    }
}
