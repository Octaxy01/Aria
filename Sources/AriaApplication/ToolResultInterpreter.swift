import Foundation
import AriaDomain

/// Interprets raw tool execution results into structured semantic information.
/// Converts ToolResult into ToolResultInterpretation with natural language summaries.
public actor ToolResultInterpreter {
    
    public init() {}
    
    /// Interprets a tool result based on the tool identifier and result data.
    /// - Parameters:
    ///   - result: The raw tool result to interpret
    ///   - toolCall: The tool call that produced the result
    ///   - sessionID: The current session ID for entity recording
    /// - Returns: Structured interpretation of the result
    /// RESPONSE TRUTHFULNESS: Never converts failure/cancellation to success
    public func interpret(
        _ result: ToolResult,
        for toolCall: ToolCall,
        sessionID: UUID
    ) -> ToolResultInterpretation {
        
        // Handle cancelled results - must remain cancelled
        if result.errorCode == "cancelled" {
            return .cancelled()
        }
        
        // Handle stale session - must remain failure
        if result.errorCode == "stale_session" {
            return .failure(
                summary: "Sesi sudah tidak valid, operasi dibatalkan.",
                errorCategory: .staleSession
            )
        }
        
        // Handle based on tool type
        switch toolCall.toolIdentifier {
        case .openApplication:
            return interpretOpenApplication(result, sessionID: sessionID)
            
        case .quitApplication:
            return interpretQuitApplication(result)
            
        case .focusApplication:
            return interpretFocusApplication(result)
            
        case .openFile:
            return interpretOpenFile(result, sessionID: sessionID)
            
        case .openFolder:
            return interpretOpenFolder(result, sessionID: sessionID)
            
        case .findFile:
            return interpretFindFile(result, sessionID: sessionID)
            
        case .getSystemInfo:
            return interpretSystemInfo(result)
            
        case .getBatteryStatus:
            return interpretBatteryStatus(result)
            
        case .getStorageInfo:
            return interpretStorageInfo(result)
            
        default:
            return interpretGeneric(result)
        }
    }
    
    // MARK: - Application Tools
    
    private func interpretOpenApplication(_ result: ToolResult, sessionID: UUID) -> ToolResultInterpretation {
        guard result.success, let data = result.data else {
            return .failure(
                summary: "Aku nggak bisa menemukan atau membuka aplikasi tersebut.",
                errorCategory: .notFound
            )
        }
        
        guard let appName = data["applicationName"] as? String else {
            return .failure(
                summary: "Aku nggak bisa membuka aplikasi tersebut.",
                errorCategory: .executionFailed
            )
        }
        
        // Create entity for reference resolution
        let entity: RuntimeEntity?
        if let bundleID = data["bundleIdentifier"] as? String,
           let path = data["path"] as? String {
            entity = RuntimeEntity(
                kind: .application,
                displayName: appName,
                path: path,
                applicationIdentifier: bundleID,
                sessionID: sessionID
            )
        } else {
            entity = nil
        }
        
        return .success(
            summary: "\(appName) berhasil dibuka.",
            details: data,
            entities: entity.map { [$0] }
        )
    }
    
    private func interpretQuitApplication(_ result: ToolResult) -> ToolResultInterpretation {
        guard result.success, let data = result.data else {
            return .failure(
                summary: "Aplikasi tersebut nggak sedang berjalan.",
                errorCategory: .notFound
            )
        }
        
        guard let appName = data["applicationName"] as? String else {
            return .failure(
                summary: "Aku nggak bisa menutup aplikasi tersebut.",
                errorCategory: .executionFailed
            )
        }
        
        return .success(
            summary: "\(appName) sudah ditutup.",
            details: data
        )
    }
    
    private func interpretFocusApplication(_ result: ToolResult) -> ToolResultInterpretation {
        guard result.success, let data = result.data else {
            return .failure(
                summary: "Aku nggak menemukan aplikasi tersebut yang sedang berjalan.",
                errorCategory: .notFound
            )
        }
        
        guard let appName = data["applicationName"] as? String else {
            return .failure(
                summary: "Aku nggak bisa memfokuskan aplikasi tersebut.",
                errorCategory: .executionFailed
            )
        }
        
        return .success(
            summary: "\(appName) sudah aku fokuskan.",
            details: data
        )
    }
    
    // MARK: - Filesystem Tools
    
    private func interpretOpenFile(_ result: ToolResult, sessionID: UUID) -> ToolResultInterpretation {
        guard result.success, let data = result.data else {
            return .failure(
                summary: "Aku nggak bisa membuka file tersebut.",
                errorCategory: .notFound
            )
        }
        
        guard let fileName = data["fileName"] as? String else {
            return .failure(
                summary: "Aku nggak bisa membuka file tersebut.",
                errorCategory: .executionFailed
            )
        }
        
        // Create entity for reference resolution (without exposing full path)
        let entity: RuntimeEntity?
        if let path = data["path"] as? String {
            entity = RuntimeEntity(
                kind: .file,
                displayName: fileName,
                path: path,
                sessionID: sessionID
            )
        } else {
            entity = nil
        }
        
        return .success(
            summary: "File \(fileName) sudah dibuka.",
            details: data,
            entities: entity.map { [$0] }
        )
    }
    
    private func interpretOpenFolder(_ result: ToolResult, sessionID: UUID) -> ToolResultInterpretation {
        guard result.success, let data = result.data else {
            return .failure(
                summary: "Aku nggak bisa membuka folder tersebut.",
                errorCategory: .notFound
            )
        }
        
        guard let folderName = data["folderName"] as? String else {
            return .failure(
                summary: "Aku nggak bisa membuka folder tersebut.",
                errorCategory: .executionFailed
            )
        }
        
        // Create entity for reference resolution
        let entity: RuntimeEntity?
        if let path = data["path"] as? String {
            entity = RuntimeEntity(
                kind: .folder,
                displayName: folderName,
                path: path,
                sessionID: sessionID
            )
        } else {
            entity = nil
        }
        
        return .success(
            summary: "Folder \(folderName) sudah dibuka.",
            details: data,
            entities: entity.map { [$0] }
        )
    }
    
    private func interpretFindFile(_ result: ToolResult, sessionID: UUID) -> ToolResultInterpretation {
        guard result.success, let data = result.data else {
            return .failure(
                summary: "Aku nggak bisa mencari file.",
                errorCategory: .executionFailed
            )
        }
        
        guard let results = data["results"] as? [[String: Sendable]] else {
            return .failure(
                summary: "Aku belum menemukan file yang cocok.",
                errorCategory: .notFound
            )
        }
        
        let count = results.count
        
        if count == 0 {
            return .success(
                summary: "Aku belum menemukan file yang cocok.",
                details: data
            )
        }
        
        // Extract entities for reference resolution (preserve all results)
        let entities: [RuntimeEntity] = results.compactMap { resultItem in
            guard let path = resultItem["path"] as? String,
                  let fileName = resultItem["fileName"] as? String else {
                return nil
            }
            return RuntimeEntity(
                kind: .searchResult,
                displayName: fileName,
                path: path,
                sessionID: sessionID
            )
        }
        
        // Generate bounded summary for display
        let visibleCount = min(count, 5)
        let visibleResults = results.prefix(visibleCount)
        
        if count == 1 {
            let fileName = results.first?["fileName"] as? String ?? "file"
            return .success(
                summary: "Aku menemukan \(fileName).",
                details: data,
                entities: entities
            )
        }
        
        let visibleNames = visibleResults.compactMap { $0["fileName"] as? String }
        let namesList = visibleNames.prefix(4).joined(separator: ", ")
        
        if count <= 5 {
            return .success(
                summary: "Aku menemukan \(count) file: \(namesList).",
                details: data,
                entities: entities
            )
        }
        
        return .success(
            summary: "Aku menemukan \(count) file: \(namesList), dan \(count - 5) lainnya.",
            details: data,
            entities: entities
        )
    }
    
    // MARK: - System Tools
    
    private func interpretSystemInfo(_ result: ToolResult) -> ToolResultInterpretation {
        guard result.success, let data = result.data else {
            return .failure(
                summary: "Aku nggak bisa mendapatkan informasi sistem.",
                errorCategory: .unavailable
            )
        }
        
        var summaryParts: [String] = []
        
        if let osVersion = data["osVersion"] as? String {
            summaryParts.append("macOS \(osVersion)")
        }
        
        if let architecture = data["architecture"] as? String {
            summaryParts.append(architecture)
        }
        
        if let computerName = data["computerName"] as? String {
            // Only include computer name if it's user-friendly (not exposing internal details)
            if !computerName.contains("Mac") && computerName.count < 30 {
                summaryParts.append("(\(computerName))")
            }
        }
        
        let summary = summaryParts.isEmpty ? "Informasi sistem berhasil diambil." : summaryParts.joined(separator: " ")
        
        return .success(
            summary: summary,
            details: data
        )
    }
    
    private func interpretBatteryStatus(_ result: ToolResult) -> ToolResultInterpretation {
        guard result.success, let data = result.data else {
            return .failure(
                summary: "Mac ini tidak melaporkan informasi baterai.",
                errorCategory: .unavailable
            )
        }
        
        guard let percentage = data["percentage"] as? Int else {
            return .failure(
                summary: "Mac ini tidak melaporkan informasi baterai.",
                errorCategory: .unavailable
            )
        }
        
        let isCharging = (data["isCharging"] as? Bool) ?? false
        let chargingText = isCharging ? "dan sedang mengisi daya" : "dan tidak sedang mengisi daya"
        
        return .success(
            summary: "Bateraimu sekarang \(percentage)% \(chargingText).",
            details: data
        )
    }
    
    private func interpretStorageInfo(_ result: ToolResult) -> ToolResultInterpretation {
        guard result.success, let data = result.data else {
            return .failure(
                summary: "Aku nggak bisa mendapatkan informasi penyimpanan.",
                errorCategory: .unavailable
            )
        }
        
        guard let availableGB = data["availableGB"] as? Double,
              let totalGB = data["totalGB"] as? Double else {
            return .failure(
                summary: "Aku nggak bisa mendapatkan informasi penyimpanan.",
                errorCategory: .executionFailed
            )
        }
        
        let availableFormatted = String(format: "%.0f", availableGB)
        let totalFormatted = String(format: "%.0f", totalGB)
        
        return .success(
            summary: "Penyimpanan yang tersedia sekitar \(availableFormatted) GB dari total \(totalFormatted) GB.",
            details: data
        )
    }
    
    // MARK: - Generic
    
    private func interpretGeneric(_ result: ToolResult) -> ToolResultInterpretation {
        if result.success {
            return .success(
                summary: "Operasi berhasil.",
                details: result.data
            )
        } else {
            let errorCategory = determineErrorCategory(from: result.errorCode)
            let errorMessage = result.error ?? "Terjadi kesalahan."
            return .failure(
                summary: errorMessage,
                errorCategory: errorCategory,
                details: result.data
            )
        }
    }
    
    // MARK: - Helpers
    
    private func determineErrorCategory(from errorCode: String?) -> ToolErrorCategory {
        guard let errorCode = errorCode else {
            return .executionFailed
        }
        
        switch errorCode {
        case "not_found", "file_not_found", "app_not_found":
            return .notFound
        case "permission_denied", "access_denied":
            return .permissionDenied
        case "invalid_arguments", "validation_failed":
            return .invalidArguments
        case "unavailable", "service_unavailable":
            return .unavailable
        case "cancelled":
            return .cancelled
        case "stale_session":
            return .staleSession
        default:
            return .executionFailed
        }
    }
}
