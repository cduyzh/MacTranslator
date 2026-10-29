import Foundation

/// 行业/专业领域词库分类
public struct DomainGlossaryCategory: Identifiable, Codable, Equatable, Hashable, Sendable {
    public var id: String
    public var name: String
    public var description: String
    public var isEnabled: Bool
    public var createdAt: Date
    public var updatedAt: Date

    public init(
        id: String = UUID().uuidString,
        name: String,
        description: String = "",
        isEnabled: Bool = true,
        createdAt: Date = Date(),
        updatedAt: Date = Date()
    ) {
        self.id = id
        self.name = name
        self.description = description
        self.isEnabled = isEnabled
        self.createdAt = createdAt
        self.updatedAt = updatedAt
    }
}

/// 行业/专业领域词条
public struct DomainGlossaryItem: Identifiable, Codable, Equatable, Hashable, Sendable {
    public var id: String
    public var categoryId: String
    public var sourceTerm: String
    public var preferredTranslation: String
    public var sourceLang: String
    public var targetLang: String
    public var notes: String
    public var isEnabled: Bool
    public var createdAt: Date
    public var updatedAt: Date

    public init(
        id: String = UUID().uuidString,
        categoryId: String,
        sourceTerm: String,
        preferredTranslation: String,
        sourceLang: String = "auto",
        targetLang: String = "zh-CN",
        notes: String = "",
        isEnabled: Bool = true,
        createdAt: Date = Date(),
        updatedAt: Date = Date()
    ) {
        self.id = id
        self.categoryId = categoryId
        self.sourceTerm = sourceTerm
        self.preferredTranslation = preferredTranslation
        self.sourceLang = sourceLang
        self.targetLang = targetLang
        self.notes = notes
        self.isEnabled = isEnabled
        self.createdAt = createdAt
        self.updatedAt = updatedAt
    }
}

/// 知识库动态检索与 Token 上下文管控结果
public struct KnowledgeContextMatchResult: Equatable, Sendable {
    public let matchedItems: [DomainGlossaryItem]
    public let renderedPrompt: String
    public let totalCandidateCount: Int
    public let suppressedCount: Int
    public let estimatedCharactersSaved: Int

    public init(
        matchedItems: [DomainGlossaryItem] = [],
        renderedPrompt: String = "",
        totalCandidateCount: Int = 0,
        suppressedCount: Int = 0,
        estimatedCharactersSaved: Int = 0
    ) {
        self.matchedItems = matchedItems
        self.renderedPrompt = renderedPrompt
        self.totalCandidateCount = totalCandidateCount
        self.suppressedCount = suppressedCount
        self.estimatedCharactersSaved = estimatedCharactersSaved
    }
}

/// 知识库异常类型
public enum DomainKnowledgeBaseError: LocalizedError {
    case emptyCategoryName
    case categoryNotFound
    case emptySourceTerm
    case emptyTranslation
    case invalidTargetLanguage
    case itemNotFound
    case unreadableStore
    case invalidImportFormat(String)

    public var errorDescription: String? {
        switch self {
        case .emptyCategoryName:
            return "请输入知识库分类名称"
        case .categoryNotFound:
            return "指定的知识库分类不存在"
        case .emptySourceTerm:
            return "请输入原文专业词汇"
        case .emptyTranslation:
            return "请输入推荐译法"
        case .invalidTargetLanguage:
            return "请选择明确的目标语言"
        case .itemNotFound:
            return "词条不存在，请刷新后重试"
        case .unreadableStore:
            return "知识库存储文件读取失败"
        case .invalidImportFormat(let reason):
            return "导入格式错误：\(reason)"
        }
    }
}
