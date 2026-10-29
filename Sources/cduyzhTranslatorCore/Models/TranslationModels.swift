import Foundation
import CryptoKit

/// 翻译支持的语言模型
public struct LanguageItem: Identifiable, Hashable, Codable {
    public var id: String { code }
    public let code: String
    public let name: String
    public let englishName: String
    public let flag: String
    
    public init(code: String, name: String, englishName: String, flag: String) {
        self.code = code
        self.name = name
        self.englishName = englishName
        self.flag = flag
    }
}

/// 支持的常用语言集
public struct SupportedLanguages {
    public static let auto = LanguageItem(code: "auto", name: "自动识别", englishName: "Auto Detect", flag: "🌐")
    
    public static let all: [LanguageItem] = [
        auto,
        LanguageItem(code: "zh-CN", name: "简体中文", englishName: "Chinese (Simplified)", flag: "🇨🇳"),
        LanguageItem(code: "zh-TW", name: "繁体中文", englishName: "Chinese (Traditional)", flag: "🇭🇰"),
        LanguageItem(code: "en", name: "英语", englishName: "English", flag: "🇺🇸"),
        LanguageItem(code: "ja", name: "日语", englishName: "Japanese", flag: "🇯🇵"),
        LanguageItem(code: "ko", name: "韩语", englishName: "Korean", flag: "🇰🇷"),
        LanguageItem(code: "fr", name: "法语", englishName: "French", flag: "🇫🇷"),
        LanguageItem(code: "de", name: "德语", englishName: "German", flag: "🇩🇪"),
        LanguageItem(code: "es", name: "西班牙语", englishName: "Spanish", flag: "🇪🇸"),
        LanguageItem(code: "ru", name: "俄语", englishName: "Russian", flag: "🇷🇺"),
        LanguageItem(code: "it", name: "意大利语", englishName: "Italian", flag: "🇮🇹"),
        LanguageItem(code: "pt", name: "葡萄牙语", englishName: "Portuguese", flag: "🇵🇹"),
        LanguageItem(code: "ar", name: "阿拉伯语", englishName: "Arabic", flag: "🇸🇦"),
        LanguageItem(code: "vi", name: "越南语", englishName: "Vietnamese", flag: "🇻🇳"),
        LanguageItem(code: "th", name: "泰语", englishName: "Thai", flag: "🇹🇭"),
        LanguageItem(code: "id", name: "印尼语", englishName: "Indonesian", flag: "🇮🇩"),
        LanguageItem(code: "hi", name: "印地语", englishName: "Hindi", flag: "🇮🇳"),
        LanguageItem(code: "tr", name: "土耳其语", englishName: "Turkish", flag: "🇹🇷"),
        LanguageItem(code: "nl", name: "荷兰语", englishName: "Dutch", flag: "🇳🇱"),
        LanguageItem(code: "pl", name: "波兰语", englishName: "Polish", flag: "🇵🇱")
    ]
    
    public static func find(by code: String) -> LanguageItem? {
        return all.first { $0.code == code }
    }
}

/// 支持的翻译引擎类型
public enum TranslationEngineType: String, CaseIterable, Identifiable, Codable, Hashable, Sendable {
    case google = "google"
    case deepseek = "deepseek"
    
    public var id: String { rawValue }
    
    public var displayName: String {
        switch self {
        case .google:
            return "Google Free"
        case .deepseek:
            return "DeepSeek"
        }
    }
    
    public var icon: String {
        switch self {
        case .google:
            return "g.circle.fill"
        case .deepseek:
            return "brain.head.profile"
        }
    }
}

/// 翻译请求
public struct TranslationPromptContext: Equatable, Sendable {
    public let sharedPrompt: String
    public let instructions: String
    public let personalMemory: String
    public let domainKnowledge: String
    public let historyContext: String

    public init(sharedPrompt: String = TranslationPromptDefaults.standard,
                instructions: String = "", personalMemory: String = "", domainKnowledge: String = "", historyContext: String = "") {
        self.sharedPrompt = sharedPrompt.trimmingCharacters(in: .whitespacesAndNewlines)
        self.instructions = instructions.trimmingCharacters(in: .whitespacesAndNewlines)
        self.personalMemory = personalMemory
        self.domainKnowledge = domainKnowledge
        self.historyContext = historyContext.trimmingCharacters(in: .whitespacesAndNewlines)
    }

    @MainActor static func current(for request: TranslationRequest) -> TranslationPromptContext {
        let memory = PersonalTranslationMemoryManager.shared.context(text: request.text, sourceLang: request.sourceLang, targetLang: request.targetLang)
        let domainKnowledge: String
        if AppSettings.shared.knowledgeBaseEnabled {
            let excluded = Set(PersonalTranslationMemoryManager.shared.items.filter(\.isEnabled).map {
                $0.sourceTerm.precomposedStringWithCanonicalMapping.folding(options: [.caseInsensitive], locale: Locale(identifier: "en_US_POSIX"))
            })
            let match = DomainKnowledgeBaseManager.shared.queryContext(
                text: request.text,
                sourceLang: request.sourceLang,
                targetLang: request.targetLang,
                maxTerms: AppSettings.shared.knowledgeBaseMaxTerms,
                maxCharacters: AppSettings.shared.knowledgeBaseMaxCharacters,
                excludedTerms: excluded
            )
            domainKnowledge = match.renderedPrompt
        } else {
            domainKnowledge = ""
        }
        return TranslationPromptContext(
            sharedPrompt: AppSettings.shared.translationPromptTemplate,
            instructions: AppSettings.shared.translationInstructions,
            personalMemory: memory,
            domainKnowledge: domainKnowledge
        )
    }

    var cacheIdentity: String {
        let data = try! JSONEncoder().encode([sharedPrompt, instructions, personalMemory, domainKnowledge, historyContext])
        return SHA256.hash(data: data).map { String(format: "%02x", $0) }.joined()
    }
}

public struct TranslationRequest {
    public let text: String
    public let sourceLang: String
    public let targetLang: String
    public let engine: TranslationEngineType
    var deepSeekConfiguration: DeepSeekConfiguration?
    public var promptContext: TranslationPromptContext?
    
    public init(text: String, sourceLang: String = "auto", targetLang: String = "zh-CN", engine: TranslationEngineType = .deepseek, promptContext: TranslationPromptContext? = nil) {
        self.text = text
        self.sourceLang = sourceLang
        self.targetLang = targetLang
        self.engine = engine
        self.promptContext = promptContext
    }

    var cacheIdentity: String {
        (deepSeekConfiguration?.cacheIdentity ?? "") + ":" + (promptContext?.cacheIdentity ?? "")
    }
}

/// 翻译结果
public struct TranslationResult: Identifiable, Codable, Sendable {
    public var id: UUID = UUID()
    public var sourceText: String
    public var targetText: String
    public var detectedSourceLang: String
    public var targetLang: String
    public var engineUsed: String
    public var reasoningContent: String?
    public var promptTokens: Int
    public var completionTokens: Int
    public var reasoningTokens: Int
    public var totalTokens: Int
    public var latencyMs: Int
    public var fromMemory: Bool
    public var timestamp: Date
    
    public init(
        sourceText: String,
        targetText: String,
        detectedSourceLang: String = "auto",
        targetLang: String = "zh-CN",
        engineUsed: String,
        reasoningContent: String? = nil,
        promptTokens: Int = 0,
        completionTokens: Int = 0,
        reasoningTokens: Int = 0,
        totalTokens: Int = 0,
        latencyMs: Int = 0,
        fromMemory: Bool = false,
        timestamp: Date = Date()
    ) {
        self.sourceText = sourceText
        self.targetText = targetText
        self.detectedSourceLang = detectedSourceLang
        self.targetLang = targetLang
        self.engineUsed = engineUsed
        self.reasoningContent = reasoningContent
        self.promptTokens = promptTokens
        self.completionTokens = completionTokens
        self.reasoningTokens = reasoningTokens
        self.totalTokens = totalTokens
        self.latencyMs = latencyMs
        self.fromMemory = fromMemory
        self.timestamp = timestamp
    }
}
