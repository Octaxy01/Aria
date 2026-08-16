import AriaDomain

/// Simple, deterministic, keyword-based read on a user message's tone.
/// Intentionally not ML — Stage 3 explicitly rules that out. Good enough
/// to give `RelationshipService` and the prompt something better than
/// nothing; not meant to be linguistically rigorous.
///
/// Rules are checked in order and the first match wins, so ordering
/// reflects priority (rude beats joking beats affectionate beats serious).
public enum ConversationToneClassifier {
    private static let rudeMarkers = [
        "shut up", "stupid", "idiot", "hate you", "screw you", "dumb"
    ]

    private static let emotionalMarkers = [
        "capek", "lelah", "sedih", "down", "pusing", "stres", "kesel", "kecewa",
        "tired", "exhausted", "sad", "stressed", "angry", "frustrated", "disappointed",
        "letih", "penat", "galau", "nyesek", "marah"
    ]

    private static let seriousMarkers = [
        "help me", "i need", "problem", "urgent", "deadline",
        "tolong", "butuh bantuan", "masalah", "penting"
    ]

    private static let technicalMarkers = [
        "code", "function", "api", "debug", "compile", "syntax",
        "programming", "development", "framework", "library",
        "bug", "stack trace", "exception", "algorithm", "error",
        "koding", "fungsi", "debug", "kompilasi", "sintaks",
        "swift", "async", "await", "actor", "struct", "class", "build", "gagal"
    ]

    private static let affectionateMarkers = [
        "love you", "miss you", "❤", "💕", "you're the best", "you are the best",
        "sayang", "cinta", "kangen", "lucu", "cantik", "keren", "perhatian", "suka"
    ]

    private static let achievementMarkers = [
        "finished", "completed", "done", "success", "accomplished", "solved",
        "selesai", "berhasil", "tuntas", "selesaikan", "alhamdulillah", "mantap",
        "lulus", "memperbaiki"
    ]

    private static let jokingMarkers = [
        "lol", "lmao", "haha", "hehe", "wkwk", "😂", "🤣", "just kidding", "jk"
    ]

    public static func classify(_ text: String) -> ConversationTone {
        let normalized = text.lowercased()

        if rudeMarkers.contains(where: normalized.contains) {
            return .rude
        }
        if emotionalMarkers.contains(where: normalized.contains) {
            return .emotional
        }
        if seriousMarkers.contains(where: normalized.contains) {
            return .serious
        }
        if technicalMarkers.contains(where: normalized.contains) {
            return .technical
        }
        if affectionateMarkers.contains(where: normalized.contains) {
            return .affectionate
        }
        if achievementMarkers.contains(where: normalized.contains) {
            return .achievement
        }
        if jokingMarkers.contains(where: normalized.contains) {
            return .joking
        }
        return .casual
    }
}