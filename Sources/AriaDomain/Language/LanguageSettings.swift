import Foundation

/// Supported languages for Aria's input and output.
/// Extends the existing Language enum from TextToSpeeching with additional capabilities.
public enum SupportedLanguage: String, Sendable, Codable, CaseIterable {
    case auto = "auto"
    case indonesian = "id_ID"
    case japanese = "ja_JP"
    case english = "en_US"
    case russian = "ru_RU"
    
    /// Display name for UI purposes
    public var displayName: String {
        switch self {
        case .auto: return "Auto"
        case .indonesian: return "Indonesian"
        case .japanese: return "Japanese"
        case .english: return "English"
        case .russian: return "Russian"
        }
    }
    
    /// Convert to existing Language enum for TTS compatibility
    public var toTTSLanguage: AriaDomain.Language {
        switch self {
        case .auto: return .english // Default fallback for auto
        case .indonesian: return .indonesian
        case .japanese: return .japanese
        case .english: return .english
        case .russian: return .russian
        }
    }
}

/// Translation mode for handling multilingual interactions
public enum TranslationMode: String, Sendable, Codable, CaseIterable {
    case onDemand = "on_demand"
    case always = "always"
    case never = "never"
    
    public var displayName: String {
        switch self {
        case .onDemand: return "On Demand"
        case .always: return "Always"
        case .never: return "Never"
        }
    }
}

/// Centralized language configuration for Aria.
/// This is the single source of truth for language behavior.
public struct LanguageSettings: Sendable, Codable, Equatable {
    /// Input language detection mode
    public var inputLanguage: SupportedLanguage
    
    /// Default output language for responses
    public var outputLanguage: SupportedLanguage
    
    /// When to perform translation
    public var translationMode: TranslationMode
    
    /// Temporary override for current conversation (nil = use default)
    public var conversationOverride: SupportedLanguage?
    
    public init(
        inputLanguage: SupportedLanguage = .auto,
        outputLanguage: SupportedLanguage = .japanese,
        translationMode: TranslationMode = .onDemand,
        conversationOverride: SupportedLanguage? = nil
    ) {
        self.inputLanguage = inputLanguage
        self.outputLanguage = outputLanguage
        self.translationMode = translationMode
        self.conversationOverride = conversationOverride
    }
    
    /// Get the effective output language (considering conversation override)
    public var effectiveOutputLanguage: SupportedLanguage {
        conversationOverride ?? outputLanguage
    }
    
    /// Default settings with Japanese as output language
    public static let `default` = LanguageSettings(
        inputLanguage: .auto,
        outputLanguage: .japanese,
        translationMode: .onDemand
    )
    
    /// Set a temporary conversation override
    public mutating func setConversationOverride(_ language: SupportedLanguage?) {
        self.conversationOverride = language
    }
    
    /// Clear the conversation override and return to default
    public mutating func clearConversationOverride() {
        self.conversationOverride = nil
    }
}
