import Foundation
import AriaDomain
import AriaInfrastructure

/// Resolves natural language references to concrete entities from runtime context.
/// Handles references like "itu", "yang pertama", "di situ", etc.
public actor ReferenceResolver {
    
    private let entityContext: RuntimeEntityContext
    private let logger: any Logging
    
    // Multilingual reference patterns
    private let demonstrativeReferences = Set([
        // Indonesian
        "itu", "ini", "tersebut", "tadi",
        // English
        "that", "this", "the one",
        // Russian
        "это", "тот", "этот",
        // Japanese
        "それ", "これ", "あれ"
    ])
    private let contextReferences: [String: EntityKind] = [
        // Indonesian
        "foldernya": .folder,
        "filenya": .file,
        "aplikasinya": .application,
        "aplikasi itu": .application,
        "file itu": .file,
        "folder itu": .folder,
        // English
        "the folder": .folder,
        "the file": .file,
        "the application": .application,
        "that folder": .folder,
        "that file": .file,
        "that application": .application,
        // Russian
        "папка": .folder,
        "файл": .file,
        "приложение": .application,
        "эта папка": .folder,
        "этот файл": .file,
        "это приложение": .application,
        // Japanese
        "フォルダ": .folder,
        "ファイル": .file,
        "アプリ": .application,
        "そのフォルダ": .folder,
        "そのファイル": .file,
        "そのアプリ": .application
    ]
    private let locationReferences = Set([
        // Indonesian
        "di situ", "di sana",
        // English
        "there",
        // Russian
        "там",
        // Japanese
        "そこ"
    ])
    
    public init(
        entityContext: RuntimeEntityContext,
        logger: any Logging = ConsoleLogger(minimumLevel: .info)
    ) {
        self.entityContext = entityContext
        self.logger = logger
    }
    
    /// Types of references that can be resolved.
    public enum ReferenceType: Sendable, Equatable {
        /// Demonstrative pronouns: "itu", "ini", "tersebut", "tadi"
        case demonstrative
        
        /// Positional references: "yang pertama", "yang kedua", "yang ketiga"
        case positional(Int)
        
        /// Context references: "di situ", "di sana", "foldernya", "filenya", "aplikasinya"
        case context(EntityKind)
        
        /// Recency references: "yang terbaru", "yang paling baru", "yang terakhir", "yang paling lama"
        case recency(RecencyKind)
        
        /// Unrecognized reference pattern
        case unknown
    }

    /// Kinds of recency-based references.
    public enum RecencyKind: Sendable, Equatable {
        case newest
        case oldest
    }
    
    /// Resolves a reference string to a concrete entity.
    /// - Parameter reference: The reference string to resolve (e.g., "itu", "yang pertama")
    /// - Returns: Resolution result indicating success, ambiguity, or failure
    public func resolve(_ reference: String) async -> ResolutionResult {
        let referenceType = classifyReference(reference)
        
        switch referenceType {
        case .demonstrative:
            return await resolveDemonstrative(reference)
        case .positional(let position):
            return await resolvePositional(position)
        case .context(let kind):
            return await resolveContext(kind)
        case .recency(let recencyKind):
            return await resolveRecency(recencyKind)
        case .unknown:
            logger.debug("Unknown reference pattern: \(reference)")
            return .unresolved
        }
    }
    
    /// Classifies a reference string into its type.
    /// - Parameter reference: The reference string to classify
    /// - Returns: The reference type
    private nonisolated func classifyReference(_ reference: String) -> ReferenceType {
        let normalized = reference.lowercased().trimmingCharacters(in: .whitespaces)
        
        // Check for demonstrative references
        if demonstrativeReferences.contains(normalized) {
            return .demonstrative
        }
        
        // Check for positional references
        if normalized.hasPrefix("yang ke-") || normalized.hasPrefix("yang ke ") {
            if let position = extractPosition(normalized) {
                return .positional(position)
            }
        }
        
        if normalized == "yang pertama" {
            return .positional(1)
        }
        
        if normalized == "yang kedua" {
            return .positional(2)
        }
        
        if normalized == "yang ketiga" {
            return .positional(3)
        }
        
        // Check for context references
        for (pattern, kind) in contextReferences {
            if normalized == pattern {
                return .context(kind)
            }
        }
        
        // Check for location references
        if locationReferences.contains(normalized) {
            return .context(.folder)
        }
        
        // Check for recency references
        if normalized == "yang terbaru" || normalized == "yang paling baru" || normalized == "yang terakhir" {
            return .recency(.newest)
        }
        
        if normalized == "yang paling lama" {
            return .recency(.oldest)
        }
        
        return .unknown
    }
    
    /// Extracts position number from positional reference.
    /// - Parameter reference: The reference string (e.g., "yang ke-5")
    /// - Returns: The position number, or nil if invalid
    private nonisolated func extractPosition(_ reference: String) -> Int? {
        let patterns = ["yang ke-", "yang ke "]
        
        for pattern in patterns {
            if reference.hasPrefix(pattern) {
                let numberPart = String(reference.dropFirst(pattern.count))
                return Int(numberPart)
            }
        }
        
        return nil
    }
    
    /// Resolves demonstrative references (itu, ini, tersebut, tadi).
    /// - Parameter reference: The reference string
    /// - Returns: Resolution result
    private func resolveDemonstrative(_ reference: String) async -> ResolutionResult {
        // "itu" resolves to most recent relevant entity
        // Check if there are multiple equally relevant candidates
        let apps = await entityContext.entities(kind: .application)
        let files = await entityContext.entities(kind: .file)
        let folders = await entityContext.entities(kind: .folder)
        let recentEntities = apps + files + folders
        
        // If no entities, return unresolved
        if recentEntities.isEmpty {
            logger.debug("Could not resolve demonstrative '\(reference)' - no entities available")
            return .unresolved
        }
        
        // If only one entity, resolve to it
        if recentEntities.count == 1 {
            let entity = recentEntities.first!
            logger.debug("Resolved demonstrative '\(reference)' to: \(entity.displayName)")
            return .resolved(entity)
        }
        
        // If multiple entities, check if they are equally relevant
        // For demonstrative references, we consider entities from the same kind group as ambiguous
        // if there are multiple recent entities of the same kind
        
        // Check if there are multiple entities of the same kind
        if apps.count > 1 {
            let candidates = Array(apps.prefix(3)) // Limit to top 3 candidates
            logger.debug("Demonstrative '\(reference)' is ambiguous - \(candidates.count) application candidates")
            return .ambiguous(candidates)
        }
        
        if files.count > 1 {
            let candidates = Array(files.prefix(3))
            logger.debug("Demonstrative '\(reference)' is ambiguous - \(candidates.count) file candidates")
            return .ambiguous(candidates)
        }
        
        if folders.count > 1 {
            let candidates = Array(folders.prefix(3))
            logger.debug("Demonstrative '\(reference)' is ambiguous - \(candidates.count) folder candidates")
            return .ambiguous(candidates)
        }
        
        // If we have mixed kinds but only one of each, resolve to the most recent overall
        if let entity = await entityContext.latest() {
            logger.debug("Resolved demonstrative '\(reference)' to: \(entity.displayName)")
            return .resolved(entity)
        }
        
        logger.debug("Could not resolve demonstrative '\(reference)' - no entities available")
        return .unresolved
    }
    
    /// Resolves positional references (yang pertama, yang kedua, etc.).
    /// - Parameter position: The 1-based position
    /// - Returns: Resolution result
    private func resolvePositional(_ position: Int) async -> ResolutionResult {
        if let entity = await entityContext.entity(at: position) {
            logger.debug("Resolved positional reference to position \(position): \(entity.displayName)")
            return .resolved(entity)
        }
        
        logger.debug("Could not resolve positional reference to position \(position)")
        return .invalidPosition
    }
    
    /// Resolves context references (foldernya, filenya, aplikasinya, etc.).
    /// - Parameter kind: The entity kind to resolve
    /// - Returns: Resolution result
    private func resolveContext(_ kind: EntityKind) async -> ResolutionResult {
        let entities = await entityContext.entities(kind: kind)
        
        // If no entities of this kind, return unresolved
        if entities.isEmpty {
            logger.debug("Could not resolve context reference to \(kind.rawValue) - no entities available")
            return .unresolved
        }
        
        // If only one entity of this kind, resolve to it
        if entities.count == 1 {
            let entity = entities.first!
            logger.debug("Resolved context reference to \(kind.rawValue): \(entity.displayName)")
            return .resolved(entity)
        }
        
        // If multiple entities of this kind, return ambiguous
        let candidates = Array(entities.prefix(3)) // Limit to top 3 candidates
        logger.debug("Context reference to \(kind.rawValue) is ambiguous - \(candidates.count) candidates")
        return .ambiguous(candidates)
    }
    
    /// Resolves recency references (yang terbaru, yang paling lama, etc.).
    /// - Parameter recencyKind: The kind of recency reference
    /// - Returns: Resolution result
    private func resolveRecency(_ recencyKind: RecencyKind) async -> ResolutionResult {
        // Get the latest result set from entity context
        guard let latestResultSet = await entityContext.latestResultSet() else {
            logger.debug("Could not resolve recency reference - no result set available")
            return .unresolved
        }
        
        // Filter entities with modification dates
        let datedEntities = latestResultSet.filter { entity in
            // Check if entity has timestamp (we use timestamp as proxy for modification date)
            // In a real implementation, this would use actual file metadata
            return true
        }
        
        guard !datedEntities.isEmpty else {
            logger.debug("Could not resolve recency reference - no entities with metadata")
            return .unresolved
        }
        
        // Sort by timestamp (newest first)
        let sortedEntities = datedEntities.sorted { $0.timestamp > $1.timestamp }
        
        let selectedEntity: RuntimeEntity
        switch recencyKind {
        case .newest:
            selectedEntity = sortedEntities[0]
        case .oldest:
            selectedEntity = sortedEntities[sortedEntities.count - 1]
        }
        
        logger.debug("Resolved recency reference to: \(selectedEntity.displayName)")
        return .resolved(selectedEntity)
    }
    
    /// Checks if a string appears to be a reference.
    /// - Parameter text: The text to check
    /// - Returns: True if the text appears to be a reference
    public nonisolated func isReference(_ text: String) -> Bool {
        let referenceType = classifyReference(text)
        return referenceType != .unknown
    }
}
