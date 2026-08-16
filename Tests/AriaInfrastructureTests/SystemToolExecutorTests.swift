import XCTest
@testable import AriaInfrastructure
@testable import AriaDomain

final class SystemToolExecutorTests: XCTestCase {
    
    // MARK: - get_system_info Tests
    
    func testGetSystemInfoSuccess() async throws {
        let mockSystemInfoProvider = MockSystemInfoProvider()
        let expectedInfo = SystemInfo(
            computerName: "TestMac",
            operatingSystem: "macOS",
            operatingSystemVersion: "14.0",
            architecture: "arm64"
        )
        await mockSystemInfoProvider.setSystemInfo(expectedInfo)
        
        let executor = SystemToolExecutor(
            systemInfoProvider: mockSystemInfoProvider,
            batteryStatusProvider: MockBatteryStatusProvider(),
            storageInfoProvider: MockStorageInfoProvider()
        )
        
        let call = ToolCall(
            toolIdentifier: .getSystemInfo,
            arguments: [:],
            sessionID: UUID()
        )
        
        let result = try await executor.execute(call)
        
        XCTAssertTrue(result.success)
        XCTAssertEqual(result.data?["computerName"] as? String, "TestMac")
        XCTAssertEqual(result.data?["operatingSystem"] as? String, "macOS")
        XCTAssertEqual(result.data?["operatingSystemVersion"] as? String, "14.0")
        XCTAssertEqual(result.data?["architecture"] as? String, "arm64")
    }
    
    func testGetSystemInfoWithNilArchitecture() async throws {
        let mockSystemInfoProvider = MockSystemInfoProvider()
        let expectedInfo = SystemInfo(
            computerName: "TestMac",
            operatingSystem: "macOS",
            operatingSystemVersion: "14.0",
            architecture: nil
        )
        await mockSystemInfoProvider.setSystemInfo(expectedInfo)
        
        let executor = SystemToolExecutor(
            systemInfoProvider: mockSystemInfoProvider,
            batteryStatusProvider: MockBatteryStatusProvider(),
            storageInfoProvider: MockStorageInfoProvider()
        )
        
        let call = ToolCall(
            toolIdentifier: .getSystemInfo,
            arguments: [:],
            sessionID: UUID()
        )
        
        let result = try await executor.execute(call)
        
        XCTAssertTrue(result.success)
        XCTAssertEqual(result.data?["computerName"] as? String, "TestMac")
        XCTAssertNil(result.data?["architecture"])
    }
    
    func testGetSystemInfoProviderFailure() async {
        let mockSystemInfoProvider = MockSystemInfoProvider()
        // Don't set system info, so it will throw
        
        let executor = SystemToolExecutor(
            systemInfoProvider: mockSystemInfoProvider,
            batteryStatusProvider: MockBatteryStatusProvider(),
            storageInfoProvider: MockStorageInfoProvider()
        )
        
        let call = ToolCall(
            toolIdentifier: .getSystemInfo,
            arguments: [:],
            sessionID: UUID()
        )
        
        do {
            _ = try await executor.execute(call)
            XCTFail("Expected error to be thrown")
        } catch {
            // Expected error
        }
    }
    
    // MARK: - get_battery_status Tests
    
    func testGetBatteryStatusSuccess() async throws {
        let mockBatteryProvider = MockBatteryStatusProvider()
        let expectedStatus = BatteryStatus(
            percentage: 85,
            isCharging: false,
            powerSource: "battery",
            isBatteryUnavailable: false
        )
        await mockBatteryProvider.setBatteryStatus(expectedStatus)
        
        let executor = SystemToolExecutor(
            systemInfoProvider: MockSystemInfoProvider(),
            batteryStatusProvider: mockBatteryProvider,
            storageInfoProvider: MockStorageInfoProvider()
        )
        
        let call = ToolCall(
            toolIdentifier: .getBatteryStatus,
            arguments: [:],
            sessionID: UUID()
        )
        
        let result = try await executor.execute(call)
        
        XCTAssertTrue(result.success)
        XCTAssertEqual(result.data?["percentage"] as? Int, 85)
        XCTAssertEqual(result.data?["isCharging"] as? Bool, false)
        XCTAssertEqual(result.data?["powerSource"] as? String, "battery")
    }
    
    func testGetBatteryStatusUnavailable() async throws {
        let mockBatteryProvider = MockBatteryStatusProvider()
        let expectedStatus = BatteryStatus.unavailable()
        await mockBatteryProvider.setBatteryStatus(expectedStatus)
        
        let executor = SystemToolExecutor(
            systemInfoProvider: MockSystemInfoProvider(),
            batteryStatusProvider: mockBatteryProvider,
            storageInfoProvider: MockStorageInfoProvider()
        )
        
        let call = ToolCall(
            toolIdentifier: .getBatteryStatus,
            arguments: [:],
            sessionID: UUID()
        )
        
        let result = try await executor.execute(call)
        
        XCTAssertTrue(result.success)
        XCTAssertEqual(result.data?["batteryUnavailable"] as? Bool, true)
        XCTAssertEqual(result.data?["message"] as? String, "Battery information is not available on this device")
    }
    
    func testGetBatteryStatusWithPartialData() async throws {
        let mockBatteryProvider = MockBatteryStatusProvider()
        let expectedStatus = BatteryStatus(
            percentage: 50,
            isCharging: true,
            powerSource: nil,
            isBatteryUnavailable: false
        )
        await mockBatteryProvider.setBatteryStatus(expectedStatus)
        
        let executor = SystemToolExecutor(
            systemInfoProvider: MockSystemInfoProvider(),
            batteryStatusProvider: mockBatteryProvider,
            storageInfoProvider: MockStorageInfoProvider()
        )
        
        let call = ToolCall(
            toolIdentifier: .getBatteryStatus,
            arguments: [:],
            sessionID: UUID()
        )
        
        let result = try await executor.execute(call)
        
        XCTAssertTrue(result.success)
        XCTAssertEqual(result.data?["percentage"] as? Int, 50)
        XCTAssertEqual(result.data?["isCharging"] as? Bool, true)
        XCTAssertNil(result.data?["powerSource"])
    }
    
    func testGetBatteryStatusProviderFailure() async {
        let mockBatteryProvider = MockBatteryStatusProvider()
        // Don't set battery status, so it will throw
        
        let executor = SystemToolExecutor(
            systemInfoProvider: MockSystemInfoProvider(),
            batteryStatusProvider: mockBatteryProvider,
            storageInfoProvider: MockStorageInfoProvider()
        )
        
        let call = ToolCall(
            toolIdentifier: .getBatteryStatus,
            arguments: [:],
            sessionID: UUID()
        )
        
        do {
            _ = try await executor.execute(call)
            XCTFail("Expected error to be thrown")
        } catch {
            // Expected error
        }
    }
    
    // MARK: - get_storage_info Tests
    
    func testGetStorageInfoSuccess() async throws {
        let mockStorageProvider = MockStorageInfoProvider()
        let expectedInfo = StorageInfo(
            volumeName: "Macintosh HD",
            totalCapacity: 1_000_000_000_000,
            availableCapacity: 500_000_000_000,
            usedCapacity: 500_000_000_000
        )
        await mockStorageProvider.setStorageInfo(expectedInfo)
        
        let executor = SystemToolExecutor(
            systemInfoProvider: MockSystemInfoProvider(),
            batteryStatusProvider: MockBatteryStatusProvider(),
            storageInfoProvider: mockStorageProvider
        )
        
        let call = ToolCall(
            toolIdentifier: .getStorageInfo,
            arguments: [:],
            sessionID: UUID()
        )
        
        let result = try await executor.execute(call)
        
        XCTAssertTrue(result.success)
        XCTAssertEqual(result.data?["volumeName"] as? String, "Macintosh HD")
        XCTAssertEqual(result.data?["totalCapacity"] as? Int64, 1_000_000_000_000)
        XCTAssertEqual(result.data?["availableCapacity"] as? Int64, 500_000_000_000)
        XCTAssertEqual(result.data?["usedCapacity"] as? Int64, 500_000_000_000)
    }
    
    func testGetStorageInfoInvalidData() async throws {
        let mockStorageProvider = MockStorageInfoProvider()
        let invalidInfo = StorageInfo(
            volumeName: "Mac",
            totalCapacity: 0,
            availableCapacity: 0,
            usedCapacity: 0
        )
        await mockStorageProvider.setStorageInfo(invalidInfo)
        
        let executor = SystemToolExecutor(
            systemInfoProvider: MockSystemInfoProvider(),
            batteryStatusProvider: MockBatteryStatusProvider(),
            storageInfoProvider: mockStorageProvider
        )
        
        let call = ToolCall(
            toolIdentifier: .getStorageInfo,
            arguments: [:],
            sessionID: UUID()
        )
        
        let result = try await executor.execute(call)
        
        XCTAssertFalse(result.success)
        XCTAssertEqual(result.errorCode, "invalidData")
    }
    
    func testGetStorageInfoProviderFailure() async {
        let mockStorageProvider = MockStorageInfoProvider()
        // Don't set storage info, so it will throw
        
        let executor = SystemToolExecutor(
            systemInfoProvider: MockSystemInfoProvider(),
            batteryStatusProvider: MockBatteryStatusProvider(),
            storageInfoProvider: mockStorageProvider
        )
        
        let call = ToolCall(
            toolIdentifier: .getStorageInfo,
            arguments: [:],
            sessionID: UUID()
        )
        
        do {
            _ = try await executor.execute(call)
            XCTFail("Expected error to be thrown")
        } catch {
            // Expected error
        }
    }
    
    // MARK: - Unknown Tool Tests
    
    func testUnknownToolIdentifier() async {
        let executor = SystemToolExecutor()
        
        let call = ToolCall(
            toolIdentifier: .openApplication, // Not a system tool
            arguments: [:],
            sessionID: UUID()
        )
        
        do {
            _ = try await executor.execute(call)
            XCTFail("Expected ToolExecutionError.toolNotFound")
        } catch ToolExecutionError.toolNotFound {
            // Expected
        } catch {
            XCTFail("Expected ToolExecutionError.toolNotFound, got \(error)")
        }
    }
    
    // MARK: - Cancellation Tests
    
    func testGetSystemInfoCancellation() async {
        let mockSystemInfoProvider = MockSystemInfoProvider()
        let expectedInfo = SystemInfo(
            computerName: "TestMac",
            operatingSystem: "macOS",
            operatingSystemVersion: "14.0",
            architecture: "arm64"
        )
        await mockSystemInfoProvider.setSystemInfo(expectedInfo)
        
        let executor = SystemToolExecutor(
            systemInfoProvider: mockSystemInfoProvider,
            batteryStatusProvider: MockBatteryStatusProvider(),
            storageInfoProvider: MockStorageInfoProvider()
        )
        
        let task = Task {
            let call = ToolCall(
                toolIdentifier: .getSystemInfo,
                arguments: [:],
                sessionID: UUID()
            )
            return try await executor.execute(call)
        }
        
        // Cancel the task
        task.cancel()
        
        do {
            _ = try await task.value
            XCTFail("Expected cancellation error")
        } catch is CancellationError {
            // Expected
        } catch {
            XCTFail("Expected CancellationError, got \(error)")
        }
    }
}
