import Foundation
import Combine

/// Agent 自动生成或分析出的词条草稿
public struct AgentGeneratedGlossaryDraft: Identifiable, Codable, Equatable, Hashable, Sendable {
    public var id: String
    public var sourceTerm: String
    public var preferredTranslation: String
    public var sourceLang: String
    public var targetLang: String
    public var suggestedCategoryName: String
    public var notes: String
    public var isSelected: Bool

    public init(
        id: String = UUID().uuidString,
        sourceTerm: String,
        preferredTranslation: String,
        sourceLang: String = "auto",
        targetLang: String = "zh-CN",
        suggestedCategoryName: String = "",
        notes: String = "",
        isSelected: Bool = true
    ) {
        self.id = id
        self.sourceTerm = sourceTerm
        self.preferredTranslation = preferredTranslation
        self.sourceLang = sourceLang
        self.targetLang = targetLang
        self.suggestedCategoryName = suggestedCategoryName
        self.notes = notes
        self.isSelected = isSelected
    }

    /// 转换为知识库实体
    public func toDomainItem(categoryId: String) -> DomainGlossaryItem {
        DomainGlossaryItem(
            id: UUID().uuidString,
            categoryId: categoryId,
            sourceTerm: sourceTerm,
            preferredTranslation: preferredTranslation,
            sourceLang: sourceLang,
            targetLang: targetLang,
            notes: notes,
            isEnabled: true
        )
    }
}

/// Agent 词库助理错误类型
public enum AgentGlossaryAssistantError: LocalizedError, Equatable {
    case missingApiKey
    case emptyPrompt
    case networkError(String)
    case invalidResponseFormat(String)
    case serverError(String)

    public var errorDescription: String? {
        switch self {
        case .missingApiKey:
            return "未检测到 API Key。请先在「设置 - API Key」中配置有效的 DeepSeek API Key"
        case .emptyPrompt:
            return "请输入想要让 Agent 检索或生成的词条主题、术语或指令"
        case .networkError(let reason):
            return "网络通信异常：\(reason)"
        case .invalidResponseFormat(let details):
            return "Agent 响应解析失败：\(details)"
        case .serverError(let msg):
            return "大模型服务报错：\(msg)"
        }
    }
}

/// 提供了 API Key 的 Agent 智能词库助理
/// 负责与大模型对话、获取信息并按照 TransBar 结构化规范提取并写入本地文件管理
@MainActor
public final class AgentGlossaryAssistant: ObservableObject {
    public static let shared = AgentGlossaryAssistant()

    @Published public private(set) var isGenerating: Bool = false
    @Published public private(set) var lastError: String?

    private let session: URLSession
    private let configProvider: () -> DeepSeekConfiguration

    public init(
        session: URLSession = .shared,
        configProvider: (() -> DeepSeekConfiguration)? = nil
    ) {
        self.session = session
        self.configProvider = configProvider ?? { DeepSeekConfiguration.current() }
    }

    // MARK: - 核心对话与智能生成

    /// 使用自然语言与 Agent 对话，根据主题、词汇、文章段落或指令批量生成规范化词条草稿
    public func chatAndGenerate(
        prompt: String,
        contextCategoryName: String? = nil,
        existingCategories: [DomainGlossaryCategory] = []
    ) async throws -> [AgentGeneratedGlossaryDraft] {
        let trimmedPrompt = prompt.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !trimmedPrompt.isEmpty else { throw AgentGlossaryAssistantError.emptyPrompt }

        let config = configProvider()
        let apiKey = config.apiKey.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !apiKey.isEmpty else { throw AgentGlossaryAssistantError.missingApiKey }

        isGenerating = true
        lastError = nil
        defer { isGenerating = false }

        let categoryHints = existingCategories.map(\.name).joined(separator: ", ")
        let systemPrompt = buildSystemPrompt(existingCategories: categoryHints, preferredCategory: contextCategoryName)

        let requestMessages = [
            DeepSeekMessage(role: "system", content: systemPrompt),
            DeepSeekMessage(role: "user", content: trimmedPrompt)
        ]

        let rawResponseContent = try await executeChatCompletion(messages: requestMessages, config: config)
        let drafts = try Self.parseDrafts(from: rawResponseContent, fallbackCategoryName: contextCategoryName)
        return drafts
    }

    /// 针对单个术语或词汇，让 Agent 深度分析并自动补充推荐译法、语言方向、语境备注和建议分类
    public func analyzeAndEnrichTerm(
        term: String,
        preferredCategoryName: String? = nil,
        existingCategories: [DomainGlossaryCategory] = []
    ) async throws -> AgentGeneratedGlossaryDraft {
        let trimmedTerm = term.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !trimmedTerm.isEmpty else { throw AgentGlossaryAssistantError.emptyPrompt }

        let config = configProvider()
        let apiKey = config.apiKey.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !apiKey.isEmpty else { throw AgentGlossaryAssistantError.missingApiKey }

        isGenerating = true
        lastError = nil
        defer { isGenerating = false }

        let categoryHints = existingCategories.map(\.name).joined(separator: ", ")
        let systemPrompt = buildSingleTermSystemPrompt(existingCategories: categoryHints, preferredCategory: preferredCategoryName)

        let requestMessages = [
            DeepSeekMessage(role: "system", content: systemPrompt),
            DeepSeekMessage(role: "user", content: "分析并规范化词条：\(trimmedTerm)")
        ]

        let rawResponseContent = try await executeChatCompletion(messages: requestMessages, config: config)
        let drafts = try Self.parseDrafts(from: rawResponseContent, fallbackCategoryName: preferredCategoryName)
        guard let first = drafts.first else {
            throw AgentGlossaryAssistantError.invalidResponseFormat("未能成功提取词条字段")
        }
        return first
    }

    // MARK: - 写入本地文件管理 (Commit to Storage)

    /// 将选中的词条草稿原子批量写入本地知识库文件管理
    /// 若分类不存在则自动创建，支持指定目标分类或采用 Agent 建议的分类
    @discardableResult
    public func commitToKnowledgeBase(
        drafts: [AgentGeneratedGlossaryDraft],
        defaultCategoryId: String? = nil,
        manager: DomainKnowledgeBaseManager? = nil
    ) throws -> (savedCount: Int, categoryNames: Set<String>) {
        let kb = manager ?? DomainKnowledgeBaseManager.shared
        let selectedDrafts = drafts.filter { $0.isSelected && !$0.sourceTerm.isEmpty && !$0.preferredTranslation.isEmpty }
        guard !selectedDrafts.isEmpty else { return (0, []) }

        var savedCount = 0
        var impactedCategoryNames = Set<String>()

        for draft in selectedDrafts {
            var targetCategoryId = defaultCategoryId

            // 若未指定或为全部，尝试根据建议分类名称查找或自动新建分类
            if targetCategoryId == nil || targetCategoryId == "all" || targetCategoryId?.isEmpty == true {
                let catName = draft.suggestedCategoryName.trimmingCharacters(in: .whitespacesAndNewlines)
                if !catName.isEmpty {
                    if let existing = kb.categories.first(where: {
                        DomainKnowledgeBaseManager.normalized($0.name) == DomainKnowledgeBaseManager.normalized(catName)
                    }) {
                        targetCategoryId = existing.id
                        impactedCategoryNames.insert(existing.name)
                    } else {
                        let newCat = try kb.addCategory(name: catName, description: "由 AI Agent 自动创建的分类")
                        targetCategoryId = newCat.id
                        impactedCategoryNames.insert(newCat.name)
                    }
                } else if let firstCat = kb.categories.first {
                    targetCategoryId = firstCat.id
                    impactedCategoryNames.insert(firstCat.name)
                }
            }

            guard let finalCatId = targetCategoryId, !finalCatId.isEmpty else { continue }

            try kb.upsertItem(
                categoryId: finalCatId,
                sourceTerm: draft.sourceTerm,
                preferredTranslation: draft.preferredTranslation,
                sourceLang: draft.sourceLang,
                targetLang: draft.targetLang,
                notes: draft.notes,
                isEnabled: true
            )
            savedCount += 1
            if let cat = kb.categories.first(where: { $0.id == finalCatId }) {
                impactedCategoryNames.insert(cat.name)
            }
        }

        return (savedCount, impactedCategoryNames)
    }

    // MARK: - Prompt 构建与通信

    private func buildSystemPrompt(existingCategories: String, preferredCategory: String?) -> String {
        var base = """
        你是一个精通跨语言专业术语、网络热梗与网络俚语的专业词库构建 Agent。
        请根据用户的需求、词汇、段落或指令，生成结构化的词条数据。
        必须严格输出纯 JSON 数组，严禁包含任何前言、后记、Markdown解释或额外问候。

        输出 JSON 的每个元素必须包含以下字段：
        - "source_term": 原文词汇、网络流行语或缩写（保持精确拼写）
        - "preferred_translation": 推荐的最佳地道译法（多个可选译法用 / 分隔）
        - "source_lang": 源语言代码，如 en, zh-CN, ja 等
        - "target_lang": 目标语言代码，如 zh-CN, en 等
        - "suggested_category_name": 建议分类名称
        - "notes": 语境出处、专业说明、流行典故或缩写全称（简明扼要，控制在30字内）
        """

        if !existingCategories.isEmpty {
            base += "\n当前本地已有的分类包括：[\(existingCategories)]，优先匹配已有分类名称。"
        }
        if let preferredCategory, !preferredCategory.isEmpty {
            base += "\n用户当前优先指定的分类名称为：\"\(preferredCategory)\"。"
        }

        base += """
        \n示例输出格式：
        [
          {
            "source_term": "brainrot",
            "preferred_translation": "电子降智 / 脑腐梗",
            "source_lang": "en",
            "target_lang": "zh-CN",
            "suggested_category_name": "网络热梗词",
            "notes": "刷无脑短视频引起的思维空洞"
          }
        ]
        """
        return base
    }

    private func buildSingleTermSystemPrompt(existingCategories: String, preferredCategory: String?) -> String {
        var base = """
        你是一个专业词汇分析与规范化 Agent。用户将提供一个词汇、缩写或短语。
        请深入理解其语境，自动补充最佳地道推荐译法、语向、分类及语境注释。
        必须严格输出包含单个对象的纯 JSON 数组，严禁任何额外文本。

        输出字段：
        - "source_term": 标准化原文
        - "preferred_translation": 地道精准的推荐译法
        - "source_lang": 源语言 (en 或 zh-CN 等)
        - "target_lang": 目标语言 (zh-CN 或 en 等)
        - "suggested_category_name": 建议归属分类
        - "notes": 简明语境或典故注释
        """
        if !existingCategories.isEmpty {
            base += "\n已有分类候选：[\(existingCategories)]。"
        }
        if let preferredCategory, !preferredCategory.isEmpty {
            base += "\n当前优先分类：\"\(preferredCategory)\"。"
        }
        return base
    }

    private func executeChatCompletion(messages: [DeepSeekMessage], config: DeepSeekConfiguration) async throws -> String {
        let baseURL = config.normalizedBaseURL
        guard let url = URL(string: "\(baseURL)/chat/completions") else {
            throw AgentGlossaryAssistantError.networkError("无效的服务端点: \(baseURL)")
        }

        var request = URLRequest(url: url)
        request.httpMethod = "POST"
        request.setValue("application/json", forHTTPHeaderField: "Content-Type")
        request.setValue("Bearer \(config.apiKey)", forHTTPHeaderField: "Authorization")
        request.timeoutInterval = 30

        let payload = DeepSeekChatRequest(
            model: config.model.isEmpty ? "deepseek-chat" : config.model,
            messages: messages,
            reasoningEffort: nil,
            thinking: DeepSeekThinkingConfig(type: "disabled"),
            stream: false
        )

        let bodyData = try JSONEncoder().encode(payload)
        request.httpBody = bodyData

        let data: Data
        let response: URLResponse
        do {
            (data, response) = try await session.data(for: request)
        } catch {
            throw AgentGlossaryAssistantError.networkError(error.localizedDescription)
        }

        guard let httpResponse = response as? HTTPURLResponse else {
            throw AgentGlossaryAssistantError.networkError("无效的网络响应")
        }

        if httpResponse.statusCode == 401 || httpResponse.statusCode == 403 {
            throw AgentGlossaryAssistantError.missingApiKey
        }

        guard httpResponse.statusCode == 200 else {
            let errorText = String(data: data, encoding: .utf8) ?? "HTTP \(httpResponse.statusCode)"
            throw AgentGlossaryAssistantError.serverError("大模型返回错误 (\(httpResponse.statusCode)): \(errorText)")
        }

        let chatResponse = try JSONDecoder().decode(DeepSeekChatResponse.self, from: data)
        guard let content = chatResponse.choices?.first?.message?.content, !content.isEmpty else {
            throw AgentGlossaryAssistantError.invalidResponseFormat("响应内容为空")
        }
        return content
    }

    // MARK: - 响应解析器 (含防御性 Markdown/JSON 剥离)

    public static func parseDrafts(from rawText: String, fallbackCategoryName: String? = nil) throws -> [AgentGeneratedGlossaryDraft] {
        var clean = rawText.trimmingCharacters(in: .whitespacesAndNewlines)

        // 剥离 ```json ... ``` 或 ``` ... ``` 代码块标记
        if clean.hasPrefix("```") {
            let lines = clean.components(separatedBy: .newlines)
            if lines.count >= 2 {
                let stripped = lines.dropFirst().dropLast().joined(separator: "\n")
                clean = stripped.trimmingCharacters(in: .whitespacesAndNewlines)
            }
        }

        guard let data = clean.data(using: .utf8) else {
            throw AgentGlossaryAssistantError.invalidResponseFormat("数据编码异常")
        }

        struct RawTerm: Codable {
            var source_term: String?
            var source: String?
            var preferred_translation: String?
            var target: String?
            var source_lang: String?
            var target_lang: String?
            var suggested_category_name: String?
            var category: String?
            var notes: String?
        }

        var rawList: [RawTerm] = []

        if let list = try? JSONDecoder().decode([RawTerm].self, from: data) {
            rawList = list
        } else if let single = try? JSONDecoder().decode(RawTerm.self, from: data) {
            rawList = [single]
        } else if let dict = try? JSONSerialization.jsonObject(with: data) as? [String: Any] {
            // 尝试提取可能嵌套的 terms 或 items 数组
            if let termsArray = dict["terms"] as? [[String: Any]] ?? dict["items"] as? [[String: Any]] {
                let subData = try JSONSerialization.data(withJSONObject: termsArray)
                rawList = (try? JSONDecoder().decode([RawTerm].self, from: subData)) ?? []
            }
        }

        guard !rawList.isEmpty else {
            throw AgentGlossaryAssistantError.invalidResponseFormat("未解析出有效的词条数组")
        }

        var drafts: [AgentGeneratedGlossaryDraft] = []
        for item in rawList {
            let src = (item.source_term ?? item.source ?? "").trimmingCharacters(in: .whitespacesAndNewlines)
            let tgt = (item.preferred_translation ?? item.target ?? "").trimmingCharacters(in: .whitespacesAndNewlines)
            guard !src.isEmpty, !tgt.isEmpty else { continue }

            let sLang = (item.source_lang ?? "auto").trimmingCharacters(in: .whitespacesAndNewlines)
            let tLang = (item.target_lang ?? (src.contains(where: { $0.isASCII && $0.isLetter }) ? "zh-CN" : "en")).trimmingCharacters(in: .whitespacesAndNewlines)
            let catName = (item.suggested_category_name ?? item.category ?? fallbackCategoryName ?? "").trimmingCharacters(in: .whitespacesAndNewlines)
            let note = (item.notes ?? "").trimmingCharacters(in: .whitespacesAndNewlines)

            drafts.append(AgentGeneratedGlossaryDraft(
                sourceTerm: src,
                preferredTranslation: tgt,
                sourceLang: sLang.isEmpty ? "auto" : sLang,
                targetLang: tLang.isEmpty ? "zh-CN" : tLang,
                suggestedCategoryName: catName,
                notes: note,
                isSelected: true
            ))
        }

        guard !drafts.isEmpty else {
            throw AgentGlossaryAssistantError.invalidResponseFormat("提取的词条原文或译文为空")
        }

        return drafts
    }
}
