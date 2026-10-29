import Foundation

/// 本地翻译记忆库数据模型
public struct TranslationMemoryItem: Identifiable, Codable, Equatable {
    public var id: String
    public var sourceHash: String
    public var sourceText: String
    public var targetText: String
    public var sourceLang: String
    public var targetLang: String
    public var engine: String
    public var frequency: Int
    public var userModified: Bool
    public var favorite: Bool
    public var lastUsedAt: Date
    public var createdAt: Date
    public var tags: [String]
    
    public init(
        id: String = UUID().uuidString,
        sourceText: String,
        targetText: String,
        sourceLang: String = "auto",
        targetLang: String = "zh-CN",
        engine: String = "google",
        frequency: Int = 1,
        userModified: Bool = false,
        favorite: Bool = false,
        lastUsedAt: Date = Date(),
        createdAt: Date = Date(),
        tags: [String] = []
    ) {
        self.id = id
        self.sourceHash = TranslationMemoryItem.computeHash(for: sourceText, targetLang: targetLang)
        self.sourceText = sourceText
        self.targetText = targetText
        self.sourceLang = sourceLang
        self.targetLang = targetLang
        self.engine = engine
        self.frequency = frequency
        self.userModified = userModified
        self.favorite = favorite
        self.lastUsedAt = lastUsedAt
        self.createdAt = createdAt
        self.tags = tags
    }
    
    public static func computeHash(for text: String, targetLang: String) -> String {
        let cleaned = text.trimmingCharacters(in: .whitespacesAndNewlines).lowercased()
        return "\(targetLang)::\(cleaned)"
    }
}

/// 专业术语/自适应词典条目
public struct GlossaryItem: Identifiable, Codable, Equatable {
    public var id: String
    public var term: String
    public var translation: String
    public var sourceLang: String
    public var targetLang: String
    public var notes: String
    
    public init(
        id: String = UUID().uuidString,
        term: String,
        translation: String,
        sourceLang: String = "en",
        targetLang: String = "zh-CN",
        notes: String = ""
    ) {
        self.id = id
        self.term = term
        self.translation = translation
        self.sourceLang = sourceLang
        self.targetLang = targetLang
        self.notes = notes
    }
}
