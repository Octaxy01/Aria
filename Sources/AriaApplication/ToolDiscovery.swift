import Foundation
import AriaDomain

/// Intent classification for user requests.
/// Determines whether a request requires tool execution or is conversational.
public enum UserIntent: Sendable, Equatable {
    /// Request requires tool execution (actionable)
    case toolRequired
    /// Request is conversational, no tool needed
    case conversational
    /// Intent is uncertain, should clarify with user
    case uncertain
}

/// Tool discovery abstraction for intent-based tool selection.
/// Provides read-only access to tool definitions with optional filtering.
/// ToolRegistry remains authoritative - this is a query layer only.
public actor ToolDiscovery {
    private let toolRegistry: ToolRegistry
    
    public init(toolRegistry: ToolRegistry) {
        self.toolRegistry = toolRegistry
    }
    
    /// Returns all available tool definitions.
    /// - Returns: All registered tool definitions
    public func availableTools() async -> [ToolDefinition] {
        return await toolRegistry.allTools()
    }
    
    /// Returns tools filtered by category.
    /// - Parameter category: The category to filter by
    /// - Returns: Tool definitions in the specified category
    public func tools(inCategory category: ToolCategory) async -> [ToolDefinition] {
        return await toolRegistry.tools(inCategory: category)
    }
    
    /// Returns tools relevant to a specific intent.
    /// - Parameter intent: The user's intent
    /// - Returns: Tool definitions relevant to the intent
    public func tools(relevantTo intent: UserIntent) async -> [ToolDefinition] {
        switch intent {
        case .toolRequired:
            // For tool-required intent, return all tools
            // The LLM will select the appropriate one
            return await toolRegistry.allTools()
        case .conversational:
            // For conversational intent, no tools needed
            return []
        case .uncertain:
            // For uncertain intent, provide a safe broader set
            // Better to over-provide than under-provide
            return await toolRegistry.allTools()
        }
    }
    
    /// Returns tools relevant to a specific user message.
    /// This is a simple heuristic-based classification.
    /// - Parameter message: The user's message
    /// - Returns: Tool definitions relevant to the message
    public func tools(relevantTo message: String) async -> [ToolDefinition] {
        let intent = classifyIntent(message)
        return await tools(relevantTo: intent)
    }
    
    /// Classifies the user's intent from their message.
    /// - Parameter message: The user's message
    /// - Returns: The classified intent
    public func classifyIntent(_ message: String) -> UserIntent {
        let lowercased = message.lowercased()
        
        // Check for uncertain/vague requests
        if isUncertainIntent(lowercased) {
            return .uncertain
        }
        
        // Check for actionable tool requests
        if isToolRequiredIntent(lowercased) {
            return .toolRequired
        }
        
        // Default to conversational
        return .conversational
    }
    
    /// Determines if the message indicates uncertain intent.
    /// - Parameter message: The lowercased message
    /// - Returns: True if intent is uncertain
    private func isUncertainIntent(_ message: String) -> Bool {
        // Vague requests without specific targets
        let vaguePatterns = [
            "bisa buka",
            "bisa buka sesuatu",
            "cari dong",
            "cari saja",
            "buka saja",
            "apa saja",
            "apa pun"
        ]
        
        for pattern in vaguePatterns {
            if message.contains(pattern) {
                return true
            }
        }
        
        return false
    }
    
    /// Determines if the message requires tool execution.
    /// - Parameter message: The lowercased message
    /// - Returns: True if tool is required
    private func isToolRequiredIntent(_ message: String) -> Bool {
        // Application-related keywords (Indonesian, English, Russian, Japanese)
        let applicationKeywords = [
            // Indonesian
            "buka", "tutup", "fokus",
            // English
            "open", "launch", "start", "close", "quit", "exit", "focus", "switch",
            // Russian
            "открой", "закрой", "открыть", "запустить", "закрыть", "выйти",
            // Japanese
            "開いて", "開く", "閉じて", "閉じる", "起動", "終了"
        ]
        
        // File-related keywords (Indonesian, English, Russian, Japanese)
        let fileKeywords = [
            // Indonesian
            "file", "folder", "dokumen", "downloads", "desktop", "pictures",
            // English
            "document",
            // Russian
            "файл", "папка", "документ", "загрузки", "рабочий стол", "изображения",
            // Japanese
            "ファイル", "フォルダ", "ドキュメント", "ダウンロード", "デスクトップ", "画像"
        ]
        
        // Search-related keywords (Indonesian, English, Russian, Japanese)
        let searchKeywords = [
            // Indonesian
            "cari", "temukan",
            // English
            "find", "search", "look for", "locate",
            // Russian
            "найди", "найти", "поиск", "искать",
            // Japanese
            "探して", "見つけて", "検索", "探す"
        ]
        
        // System information keywords (Indonesian, English, Russian, Japanese)
        let systemKeywords = [
            // Indonesian
            "storage", "baterai", "sisa", "kapasitas", "system info",
            // English
            "battery", "ram", "system information",
            // Russian
            "память", "батарея", "остаток", "емкость", "системная информация", "свободного места",
            // Japanese
            "ストレージ", "バッテリー", "残り", "容量", "システム情報"
        ]
        
        let allKeywords = applicationKeywords + fileKeywords + searchKeywords + systemKeywords
        
        for keyword in allKeywords {
            if message.contains(keyword) {
                return true
            }
        }
        
        return false
    }
}
