import Foundation
import Combine

/// 行业专业知识库与词库管理器
/// 统一管理行业/领域专业词条，负责向 AI Agent 翻译提供按需、精准、严格限制 Token 上下文的前置知识。
@MainActor
public final class DomainKnowledgeBaseManager: ObservableObject {
    public nonisolated static let fileName = "domain-knowledge-base.json"
    public static let shared = DomainKnowledgeBaseManager()

    @Published public private(set) var categories: [DomainGlossaryCategory] = []
    @Published public private(set) var items: [DomainGlossaryItem] = []
    @Published public private(set) var persistenceError: String?

    public let storageFileURL: URL
    private var storeIsReadable = true

    private struct StoredKnowledgeBase: Codable {
        var version: Int = 2
        var categories: [DomainGlossaryCategory]
        var items: [DomainGlossaryItem]
    }

    public init(directoryURL: URL? = nil, loadSeedsIfEmpty: Bool = true) {
        let directory = directoryURL ?? FileManager.default.urls(for: .applicationSupportDirectory, in: .userDomainMask)[0]
            .appendingPathComponent("cduyzhTranslator", isDirectory: true)
        storageFileURL = directory.appendingPathComponent(Self.fileName)

        do {
            if FileManager.default.fileExists(atPath: storageFileURL.path) {
                let data = try Data(contentsOf: storageFileURL)
                let stored = try Self.decoder().decode(StoredKnowledgeBase.self, from: data)

                // 检查是否包含旧测试领域数据（计算机、医学、法律、测试领域_）或者版本过低
                let legacyCatIds: Set<String> = ["cat-ai-tech", "cat-medicine", "cat-law-finance"]
                let hasLegacy = stored.categories.contains {
                    legacyCatIds.contains($0.id) ||
                    $0.name.contains("计算机") ||
                    $0.name.contains("医学") ||
                    $0.name.contains("法律") ||
                    $0.name.contains("测试领域") ||
                    $0.id.hasPrefix("cat-test-")
                }

                if stored.version < 2 || hasLegacy {
                    // 清理测试领域分类与关联词条
                    let filteredCategories = stored.categories.filter {
                        !legacyCatIds.contains($0.id) &&
                        !$0.name.contains("计算机") &&
                        !$0.name.contains("医学") &&
                        !$0.name.contains("法律") &&
                        !$0.name.contains("测试领域") &&
                        !$0.id.hasPrefix("cat-test-")
                    }
                    let validCatIds = Set(filteredCategories.map(\.id))
                    let filteredItems = stored.items.filter {
                        validCatIds.contains($0.categoryId) &&
                        !$0.sourceTerm.starts(with: "LiDAR_") &&
                        !$0.sourceTerm.starts(with: "odometry_")
                    }

                    let seeds = Self.builtInSeeds()
                    var mergedCategories = seeds.categories
                    var mergedItems = seeds.items

                    // 保留用户自行创建的其它非测试分类与词条
                    for cat in filteredCategories where !mergedCategories.contains(where: { $0.id == cat.id || $0.name == cat.name }) {
                        mergedCategories.append(cat)
                    }
                    for item in filteredItems where !legacyCatIds.contains(item.categoryId) && validCatIds.contains(item.categoryId) {
                        if !mergedItems.contains(where: { $0.id == item.id }) {
                            mergedItems.append(item)
                        }
                    }

                    categories = mergedCategories
                    items = mergedItems
                    try persist(categories: categories, items: items)
                } else {
                    categories = stored.categories
                    items = stored.items
                }
            } else if loadSeedsIfEmpty {
                let seeds = Self.builtInSeeds()
                categories = seeds.categories
                items = seeds.items
                try persist(categories: categories, items: items)
            }
        } catch {
            storeIsReadable = false
            persistenceError = error.localizedDescription
            return
        }
    }

    // MARK: - 分类管理

    @discardableResult
    public func addCategory(name: String, description: String = "", isEnabled: Bool = true) throws -> DomainGlossaryCategory {
        try ensureReadable()
        let trimmedName = name.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !trimmedName.isEmpty else { throw DomainKnowledgeBaseError.emptyCategoryName }

        if let existing = categories.first(where: { Self.normalized($0.name) == Self.normalized(trimmedName) }) {
            return existing
        }

        let now = Date()
        let category = DomainGlossaryCategory(
            id: UUID().uuidString,
            name: trimmedName,
            description: description.trimmingCharacters(in: .whitespacesAndNewlines),
            isEnabled: isEnabled,
            createdAt: now,
            updatedAt: now
        )
        var nextCategories = categories
        nextCategories.append(category)
        try persist(categories: nextCategories, items: items)
        categories = nextCategories
        return category
    }

    public func updateCategory(id: String, name: String, description: String, isEnabled: Bool) throws {
        try ensureReadable()
        let trimmedName = name.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !trimmedName.isEmpty else { throw DomainKnowledgeBaseError.emptyCategoryName }
        guard let index = categories.firstIndex(where: { $0.id == id }) else {
            throw DomainKnowledgeBaseError.categoryNotFound
        }

        var nextCategories = categories
        nextCategories[index].name = trimmedName
        nextCategories[index].description = description.trimmingCharacters(in: .whitespacesAndNewlines)
        nextCategories[index].isEnabled = isEnabled
        nextCategories[index].updatedAt = Date()

        try persist(categories: nextCategories, items: items)
        categories = nextCategories
    }

    public func setCategoryEnabled(id: String, isEnabled: Bool) throws {
        try ensureReadable()
        guard let index = categories.firstIndex(where: { $0.id == id }) else {
            throw DomainKnowledgeBaseError.categoryNotFound
        }
        guard categories[index].isEnabled != isEnabled else { return }

        var nextCategories = categories
        nextCategories[index].isEnabled = isEnabled
        nextCategories[index].updatedAt = Date()

        try persist(categories: nextCategories, items: items)
        categories = nextCategories
    }

    public func deleteCategory(id: String) throws {
        try ensureReadable()
        let nextCategories = categories.filter { $0.id != id }
        let nextItems = items.filter { $0.categoryId != id }

        try persist(categories: nextCategories, items: nextItems)
        categories = nextCategories
        items = nextItems
    }

    // MARK: - 词条管理

    @discardableResult
    public func upsertItem(
        categoryId: String,
        sourceTerm: String,
        preferredTranslation: String,
        sourceLang: String = "auto",
        targetLang: String = "zh-CN",
        notes: String = "",
        isEnabled: Bool = true,
        id: String? = nil
    ) throws -> DomainGlossaryItem {
        try ensureReadable()
        guard categories.contains(where: { $0.id == categoryId }) else {
            throw DomainKnowledgeBaseError.categoryNotFound
        }

        let source = sourceTerm.trimmingCharacters(in: .whitespacesAndNewlines)
        let preferred = preferredTranslation.trimmingCharacters(in: .whitespacesAndNewlines)
        let sourceLanguage = sourceLang.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty ? "auto" : sourceLang.trimmingCharacters(in: .whitespacesAndNewlines)
        let targetLanguage = targetLang.trimmingCharacters(in: .whitespacesAndNewlines)

        guard !source.isEmpty else { throw DomainKnowledgeBaseError.emptySourceTerm }
        guard !preferred.isEmpty else { throw DomainKnowledgeBaseError.emptyTranslation }
        guard !targetLanguage.isEmpty, Self.language(targetLanguage) != "auto" else { throw DomainKnowledgeBaseError.invalidTargetLanguage }

        let existingIndex: Int?
        if let id {
            guard let index = items.firstIndex(where: { $0.id == id }) else { throw DomainKnowledgeBaseError.itemNotFound }
            existingIndex = index
        } else {
            existingIndex = items.firstIndex {
                $0.categoryId == categoryId
                    && Self.normalized($0.sourceTerm) == Self.normalized(source)
                    && Self.language($0.sourceLang) == Self.language(sourceLanguage)
                    && Self.language($0.targetLang) == Self.language(targetLanguage)
            }
        }

        let existing = existingIndex.map { items[$0] }
        let now = Date()
        let item = DomainGlossaryItem(
            id: existing?.id ?? UUID().uuidString,
            categoryId: categoryId,
            sourceTerm: source,
            preferredTranslation: preferred,
            sourceLang: sourceLanguage,
            targetLang: targetLanguage,
            notes: notes.trimmingCharacters(in: .whitespacesAndNewlines),
            isEnabled: isEnabled,
            createdAt: existing?.createdAt ?? now,
            updatedAt: now
        )

        var nextItems = items
        if let existingIndex {
            nextItems[existingIndex] = item
        } else {
            nextItems.insert(item, at: 0)
        }

        try persist(categories: categories, items: nextItems)
        items = nextItems
        return item
    }

    public func deleteItem(id: String) throws {
        try ensureReadable()
        let nextItems = items.filter { $0.id != id }
        guard nextItems.count != items.count else { return }
        try persist(categories: categories, items: nextItems)
        items = nextItems
    }

    public func setItemEnabled(id: String, isEnabled: Bool) throws {
        try ensureReadable()
        guard let index = items.firstIndex(where: { $0.id == id }) else { throw DomainKnowledgeBaseError.itemNotFound }
        guard items[index].isEnabled != isEnabled else { return }

        var nextItems = items
        nextItems[index].isEnabled = isEnabled
        nextItems[index].updatedAt = Date()

        try persist(categories: categories, items: nextItems)
        items = nextItems
    }

    public func resetToSeeds() throws {
        try ensureReadable()
        let seeds = Self.builtInSeeds()
        try persist(categories: seeds.categories, items: seeds.items)
        categories = seeds.categories
        items = seeds.items
    }

    // MARK: - 核心：动态相关性检索与 Token 上下文管控

    /// 根据当前输入的待翻译文本，智能提取与原文高度相关的行业词汇，并严格施加条数与字符预算。
    /// 确保只有真正出现的相关词汇进入 Prompt，避免无谓的 token 消耗。
    public func queryContext(
        text: String,
        sourceLang: String = "auto",
        targetLang: String = "zh-CN",
        maxTerms: Int = 10,
        maxCharacters: Int = 800,
        excludedTerms: Set<String> = []
    ) -> KnowledgeContextMatchResult {
        let trimmed = text.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !trimmed.isEmpty else { return KnowledgeContextMatchResult() }

        let enabledCategoryIDs = Set(categories.filter(\.isEnabled).map(\.id))
        guard !enabledCategoryIDs.isEmpty else { return KnowledgeContextMatchResult() }

        let reqSource = Self.language(sourceLang)

        // 1. 过滤候选词条：处于启用分类、词条自身启用、语言契合、未在排除集合（如个人记忆）中
        let candidateItems = items.filter { item in
            guard enabledCategoryIDs.contains(item.categoryId), item.isEnabled else { return false }
            guard Self.isLanguageCompatible(termLang: item.targetLang, requestLang: targetLang) else { return false }

            if reqSource != "auto" && !Self.isLanguageCompatible(termLang: item.sourceLang, requestLang: sourceLang) {
                return false
            }

            let normalizedSource = Self.normalized(item.sourceTerm)
            if excludedTerms.contains(normalizedSource) {
                return false
            }

            return Self.matches(sourceTerm: item.sourceTerm, inText: trimmed)
        }

        guard !candidateItems.isEmpty else { return KnowledgeContextMatchResult() }

        // 2. 冲突消解与去重：同一 sourceTerm 若存在多条（跨分类），优先取分类排序早或更新时间较新的
        let grouped = Dictionary(grouping: candidateItems) { Self.normalized($0.sourceTerm) }
        var uniqueCandidates = grouped.values.compactMap { group -> DomainGlossaryItem? in
            group.sorted { lhs, rhs in
                if lhs.sourceLang == reqSource && rhs.sourceLang != reqSource { return true }
                if rhs.sourceLang == reqSource && lhs.sourceLang != reqSource { return false }
                return lhs.updatedAt > rhs.updatedAt
            }.first
        }

        // 3. Token 效益排序（最长匹配优先策略）：
        // 长词特异性高、信息量密集且歧义极低（如 "Large Language Model" 优于 "Model"），优先保障高价值专业词
        uniqueCandidates.sort { lhs, rhs in
            if lhs.sourceTerm.count != rhs.sourceTerm.count {
                return lhs.sourceTerm.count > rhs.sourceTerm.count
            }
            return lhs.updatedAt > rhs.updatedAt
        }

        let totalCandidates = uniqueCandidates.count

        // 4. 配额截断与字符预算管理（严格防止 Token 上下文膨胀）
        var selectedItems: [DomainGlossaryItem] = []
        var renderedLines: [String] = []
        var currentLength = 0
        let categoryMap = Dictionary(uniqueKeysWithValues: categories.map { ($0.id, $0.name) })

        let budgetCount = max(1, min(maxTerms, 30))
        let characterLimit = max(100, maxCharacters)

        for item in uniqueCandidates {
            if selectedItems.count >= budgetCount { break }

            let categoryName = categoryMap[item.categoryId] ?? "行业专词"
            let noteStr = item.notes.isEmpty ? "" : " (\(item.notes))"
            let line = "- \(item.sourceTerm) -> \(item.preferredTranslation) [\(categoryName)]\(noteStr)"
            let lineLength = line.utf8.count + 1

            if currentLength + lineLength > characterLimit && !selectedItems.isEmpty {
                break
            }

            selectedItems.append(item)
            renderedLines.append(line)
            currentLength += lineLength
        }

        let suppressedCount = max(0, totalCandidates - selectedItems.count)
        // 估算节约字符数（如果把全库启用词汇全部注入与当前精准注入的差值）
        let allEnabledCount = items.filter { enabledCategoryIDs.contains($0.categoryId) && $0.isEnabled }.count
        let estimatedSavedChars = max(0, (allEnabledCount - selectedItems.count) * 45)

        if selectedItems.isEmpty {
            return KnowledgeContextMatchResult(
                matchedItems: [],
                renderedPrompt: "",
                totalCandidateCount: totalCandidates,
                suppressedCount: suppressedCount,
                estimatedCharactersSaved: estimatedSavedChars
            )
        }

        let prompt = """
        ## Domain knowledge base terms (apply when matching context)
        The following verified domain-specific terms match the source context. Prioritize these preferred translations:
        \(renderedLines.joined(separator: "\n"))
        """

        return KnowledgeContextMatchResult(
            matchedItems: selectedItems,
            renderedPrompt: prompt,
            totalCandidateCount: totalCandidates,
            suppressedCount: suppressedCount,
            estimatedCharactersSaved: estimatedSavedChars
        )
    }

    // MARK: - 匹配算法

    /// 文本包含与词边界匹配：
    /// 针对英文/西文，严格实施词边界匹配，杜绝 "to", "in", "or", "as" 等子串在长单词中被虚假命中；
    /// 针对中文等无空格分词语言，要求至少 2 个字符的子串匹配。
    public static func matches(sourceTerm: String, inText text: String) -> Bool {
        let trimmedTerm = sourceTerm.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !trimmedTerm.isEmpty, !text.isEmpty else { return false }

        // 仅当包含西文字母（ASCII 字母）或数字时，尝试西文词边界匹配，避免中文字符被误判为包含西文字母
        let hasLatinOrDigits = trimmedTerm.unicodeScalars.contains { scalar in
            scalar.isASCII && (CharacterSet.letters.contains(scalar) || CharacterSet.decimalDigits.contains(scalar))
        }

        if hasLatinOrDigits {
            // 对特殊字符进行安全转义
            let pattern = "\\b" + NSRegularExpression.escapedPattern(for: trimmedTerm) + "\\b"
            if let regex = try? NSRegularExpression(pattern: pattern, options: [.caseInsensitive]) {
                let range = NSRange(text.startIndex..<text.endIndex, in: text)
                if regex.firstMatch(in: text, options: [], range: range) != nil {
                    return true
                }
            }
            // 若带有连字符、下划线等特殊边界，退化为无边界不区分大小写匹配
            if trimmedTerm.contains("-") || trimmedTerm.contains("_") || trimmedTerm.contains("/") {
                return text.range(of: trimmedTerm, options: [.caseInsensitive]) != nil
            }
            return false
        } else {
            // 纯中文/日文表意字符：单字通常过于泛化，至少匹配 2 字；若原词本身只有 1 字，则精确子串
            return text.range(of: trimmedTerm, options: [.caseInsensitive]) != nil
        }
    }

    // MARK: - 内部持久化与辅助

    private func persist(categories: [DomainGlossaryCategory], items: [DomainGlossaryItem]) throws {
        do {
            let data = try Self.encoder().encode(StoredKnowledgeBase(categories: categories, items: items))
            try FileManager.default.createDirectory(at: storageFileURL.deletingLastPathComponent(), withIntermediateDirectories: true)
            try data.write(to: storageFileURL, options: .atomic)
            persistenceError = nil
        } catch {
            persistenceError = error.localizedDescription
            throw error
        }
    }

    private func ensureReadable() throws {
        guard storeIsReadable else { throw DomainKnowledgeBaseError.unreadableStore }
    }

    public static func language(_ value: String) -> String {
        value.trimmingCharacters(in: .whitespacesAndNewlines).replacingOccurrences(of: "_", with: "-").lowercased()
    }

    /// 评估词条语言与请求语言的兼容性
    /// 支持 "auto"、同码匹配、同语族别名映射（如 "zh", "zh-CN", "zh-Hans" 互通，"en", "en-US", "en-GB" 互通）
    public static func isLanguageCompatible(termLang: String, requestLang: String) -> Bool {
        let term = language(termLang)
        let req = language(requestLang)
        if term == "auto" || req == "auto" { return true }
        if term == req { return true }

        let zhVariants: Set<String> = ["zh", "zh-cn", "zh-hans", "zh-sg", "zh-tw", "zh-hant", "zh-hk"]
        if zhVariants.contains(term) && zhVariants.contains(req) { return true }

        let enVariants: Set<String> = ["en", "en-us", "en-gb", "en-ca", "en-au"]
        if enVariants.contains(term) && enVariants.contains(req) { return true }

        return false
    }

    public static func normalized(_ value: String) -> String {
        value.precomposedStringWithCanonicalMapping.folding(options: [.caseInsensitive], locale: Locale(identifier: "en_US_POSIX"))
    }

    private static func encoder() -> JSONEncoder {
        let encoder = JSONEncoder()
        encoder.outputFormatting = [.prettyPrinted, .sortedKeys]
        encoder.dateEncodingStrategy = .iso8601
        return encoder
    }

    private static func decoder() -> JSONDecoder {
        let decoder = JSONDecoder()
        decoder.dateDecodingStrategy = .iso8601
        return decoder
    }

    // MARK: - 内置开箱即用行业词库预设（Seed Data - 网络热梗词与网络俚语）

    public static func builtInSeeds() -> (categories: [DomainGlossaryCategory], items: [DomainGlossaryItem]) {
        let catMemes = DomainGlossaryCategory(
            id: "cat-internet-memes",
            name: "网络热梗词",
            description: "国内外火爆流行梗、名场面典故与本土化地道互译（双向支持）",
            isEnabled: true
        )
        let catSlang = DomainGlossaryCategory(
            id: "cat-internet-slang",
            name: "网络俚语",
            description: "跨文化日常网聊俚语、英文缩写与当代流行口头禅（双向支持）",
            isEnabled: true
        )

        var seedItems: [DomainGlossaryItem] = []

        func item(_ catId: String, _ src: String, _ tgt: String, _ sLang: String, _ tLang: String, _ note: String = "") {
            seedItems.append(DomainGlossaryItem(
                categoryId: catId,
                sourceTerm: src,
                preferredTranslation: tgt,
                sourceLang: sLang,
                targetLang: tLang,
                notes: note,
                isEnabled: true
            ))
        }

        // ==================== 1. 网络热梗词 (Internet Memes) ====================
        // --- 英文 -> 中文 (en -> zh-CN) ---
        item(catMemes.id, "rizz", "魅力值 / 撩妹技巧", "en", "zh-CN", "缩写自 charisma，吸引异性的个人魅力")
        item(catMemes.id, "skibidi", "魔性 / 脑腐梗 / 无厘头", "en", "zh-CN", "欧美爆火马桶人魔性代名词")
        item(catMemes.id, "gyatt", "太顶了 / 绝了 / 哇塞", "en", "zh-CN", "惊叹炸裂场面或惊艳身材")
        item(catMemes.id, "sigma", "独行王者 / 独立孤狼", "en", "zh-CN", "指冷静自律、特立独行不迎合群体的酷人")
        item(catMemes.id, "let him cook", "让他发挥 / 别打断他，看他怎么操作", "en", "zh-CN", "示意给某人空间展现才华或整活")
        item(catMemes.id, "no cap", "说真的 / 保真不吹牛", "en", "zh-CN", "cap指撒谎吹牛，no cap意为千真万确")
        item(catMemes.id, "touch grass", "去大自然走走 / 回归现实别老上网了", "en", "zh-CN", "劝沉迷网络者接地气生活")
        item(catMemes.id, "delulu", "恋爱脑妄想 / 自我感动 / 痴心妄想", "en", "zh-CN", "源自 delusional，沉浸在不切实际的幻想")
        item(catMemes.id, "main character energy", "主角光环 / 拿了大女主(男主)剧本", "en", "zh-CN", "举手投足充满掌控全场的气场")
        item(catMemes.id, "rent free", "挥之不去 / 脑海里死循环", "en", "zh-CN", "常搭配 living rent-free in my head")
        item(catMemes.id, "it's giving", "很有...那种味儿 / 扑面而来的...感", "en", "zh-CN", "评价整体调性或神态氛围")
        item(catMemes.id, "ate and left no crumbs", "杀疯了 / 表现太绝了毫不费力", "en", "zh-CN", "形容表现惊艳无懈可击")
        item(catMemes.id, "caught in 4k", "当场抓包 / 实锤确凿无从抵赖", "en", "zh-CN", "高清镜头下证据确凿")
        item(catMemes.id, "side eye", "大大的白眼 / 鄙视的小眼神", "en", "zh-CN", "表达怀疑、嫌弃或无语")
        item(catMemes.id, "brainrot", "电子降智 / 脑腐梗", "en", "zh-CN", "长期刷无脑短视频引起的思维空洞")
        item(catMemes.id, "rage bait", "骗愤怒流量 / 恶意引战内容", "en", "zh-CN", "故意发激怒他人的言论博眼球")
        item(catMemes.id, "core memory", "人生名场面 / 刻入骨髓的记忆", "en", "zh-CN", "头脑特工队引申，铭记一生的时刻")
        item(catMemes.id, "roman empire", "日常反复琢磨的事 / 念念不忘的执念", "en", "zh-CN", "源自男生多久想一次罗马帝国的网络梗")
        item(catMemes.id, "npc", "路人角色 / 毫无主见的工具人", "en", "zh-CN", "调侃行为举止刻板毫无个性")
        item(catMemes.id, "ick", "下头点 / 瞬间祛魅", "en", "zh-CN", "对方某个微小举动瞬间让人反感")

        // --- 中文 -> 英文 (zh-CN -> en) ---
        item(catMemes.id, "遥遥领先", "far ahead / miles ahead of the competition", "zh-CN", "en", "国产科技发布会经典爆梗")
        item(catMemes.id, "绝绝子", "absolutely fabulous / slay / pure perfection", "zh-CN", "en", "极度赞赏或惊艳")
        item(catMemes.id, "显眼包", "attention seeker (affectionate) / standout goofball", "zh-CN", "en", "爱出风头又喜感可爱的人")
        item(catMemes.id, "破防", "break down / emotional damage / hit right in the feels", "zh-CN", "en", "心理防线被瞬间击溃")
        item(catMemes.id, "尊嘟假嘟", "for real? / are you serious? (cutesy)", "zh-CN", "en", "拟声词卖萌表达真的假的")
        item(catMemes.id, "泰裤辣", "that's so freaking cool", "zh-CN", "en", "太酷啦谐音梗")
        item(catMemes.id, "打工人", "wage earner / corporate grinder / daily laborer", "zh-CN", "en", "当代上班族自嘲黑话")
        item(catMemes.id, "摸鱼", "slacking off / coasting on the clock / loitering", "zh-CN", "en", "上班时间消极怠工做私事")
        item(catMemes.id, "躺平", "lying flat / quiet quitting", "zh-CN", "en", "不内卷、低欲望的生活态度")
        item(catMemes.id, "内卷", "involution / rat race / toxic hyper-competition", "zh-CN", "en", "无实质发展的过度恶性竞争")
        item(catMemes.id, "摆烂", "let it rot / giving up completely / throw in the towel", "zh-CN", "en", "破罐子破摔不作抵抗")
        item(catMemes.id, "疯狂星期四", "Crazy Thursday (KFC meme)", "zh-CN", "en", "肯德基优惠活动引发的文案狂欢")
        item(catMemes.id, "情绪价值", "emotional value / emotional support", "zh-CN", "en", "提供让人舒适、快乐与被认可的心情")
        item(catMemes.id, "纯爱战神", "hopeless romantic / true-love warrior", "zh-CN", "en", "坚守忠贞真挚爱情的纯爱拥趸")
        item(catMemes.id, "真香", "eating one's words / hypocritically loving it", "zh-CN", "en", "违背先前誓言并深陷其中")
        item(catMemes.id, "吃瓜", "eating melon / sipping tea / enjoying internet drama", "zh-CN", "en", "围观网络八卦")
        item(catMemes.id, "扎心了", "that hits right in the heart / hurts too real", "zh-CN", "en", "被戳中痛处或深感共鸣")
        item(catMemes.id, "社死", "social death / peak public embarrassment", "zh-CN", "en", "当众丢脸到无地自容")
        item(catMemes.id, "家人们谁懂啊", "family, you won't believe this / who gets me here", "zh-CN", "en", "短视频诉苦开场高频句式")
        item(catMemes.id, "大冤种", "poor sucker / big fall guy", "zh-CN", "en", "付出很多却落得吃亏受罪的人")

        // ==================== 2. 网络俚语 (Internet Slang) ====================
        // --- 英文 -> 中文 (en -> zh-CN) ---
        item(catSlang.id, "ngl", "说实话 / 不瞒你说", "en", "zh-CN", "not gonna lie 缩写")
        item(catSlang.id, "tbh", "老实说 / 平心而论", "en", "zh-CN", "to be honest 缩写")
        item(catSlang.id, "lowkey", "暗戳戳 / 稍微有点 / 低调地", "en", "zh-CN", "表达轻微、隐秘的心情或倾向")
        item(catSlang.id, "highkey", "明目张胆 / 超级 / 毫不避讳", "en", "zh-CN", "强烈的、公开的态度")
        item(catSlang.id, "ghosting", "玩失踪 / 突然断联", "en", "zh-CN", "社交中无故突然断绝一切联系")
        item(catSlang.id, "gaslighting", "煤气灯操纵 / 精神PUA", "en", "zh-CN", "心理操纵让人怀疑自身记忆或神智")
        item(catSlang.id, "red flag", "危险信号 / 避雷预警", "en", "zh-CN", "提示关系或事物存在严重隐患")
        item(catSlang.id, "green flag", "靠谱特质 / 加分项", "en", "zh-CN", "让人感到安全、值得信赖的良好品质")
        item(catSlang.id, "simp", "舔狗 / 过度讨好者", "en", "zh-CN", "为追求对方无底线放低姿态的人")
        item(catSlang.id, "flex", "炫耀 / 秀肌肉 / 晒优越", "en", "zh-CN", "展示财富、才华或成就")
        item(catSlang.id, "spill the tea", "爆料 / 讲八卦 / 快说内幕", "en", "zh-CN", "tea指八卦真相")
        item(catSlang.id, "salty", "酸了 / 输不起心里不平衡", "en", "zh-CN", "因失利或嫉妒而恼羞成怒")
        item(catSlang.id, "shook", "震惊到石化 / 惊呆了", "en", "zh-CN", "极度惊愕或难以置信")
        item(catSlang.id, "bussing", "绝赞好吃 / 太好吃了", "en", "zh-CN", "俚语形容食物格外美味")
        item(catSlang.id, "sus", "可疑 / 看着不对劲", "en", "zh-CN", "suspicious 缩写")
        item(catSlang.id, "fomo", "错失恐惧症", "en", "zh-CN", "fear of missing out，担心错过热点或机会")
        item(catSlang.id, "based", "有种 / 敢说真话 / 霸气", "en", "zh-CN", "坚持自我原则不在乎外界评价")
        item(catSlang.id, "cringe", "尴尬得脚趾抠地 / 太尴尬了", "en", "zh-CN", "令人极为尴尬反胃的人事物")
        item(catSlang.id, "bet", "妥了 / 没问题 / 说定了", "en", "zh-CN", "表示赞同、接受挑战或确认约定")

        // --- 中文 -> 英文 (zh-CN -> en) ---
        item(catSlang.id, "凡尔赛", "humblebrag / subtle flexing", "zh-CN", "en", "先抑后扬看似抱怨实则炫耀")
        item(catSlang.id, "秒懂", "get it instantly / catch on right away", "zh-CN", "en", "瞬间心领神会")
        item(catSlang.id, "拔草", "remove from wishlist / change one's mind about buying", "zh-CN", "en", "打消购买或体验念头")
        item(catSlang.id, "种草", "plant the seed / highly recommend (product/experience)", "zh-CN", "en", "唤起强烈的购买与体验欲望")
        item(catSlang.id, "上头", "hooked / obsessed / intoxicatingly excited", "zh-CN", "en", "情绪被煽动或产生强烈迷恋")
        item(catSlang.id, "下头", "turned off / mood killed / ick-inducing", "zh-CN", "en", "热情冷却、好感尽失")
        item(catSlang.id, "硬核", "hardcore / solid and rigorous", "zh-CN", "en", "门槛高、专业强、难度大")
        item(catSlang.id, "翻车", "fail epicly / trainwreck / crash and burn", "zh-CN", "en", "计划落空或当众出丑搞砸")
        item(catSlang.id, "白嫖", "freeloading / get something for nothing", "zh-CN", "en", "免费享受他人劳动或资源不付代价")
        item(catSlang.id, "带节奏", "stir up the pot / control the narrative maliciously", "zh-CN", "en", "故意引导舆论方向煽动群众")
        item(catSlang.id, "杠精", "contrarian / nitpicker / troll", "zh-CN", "en", "为反对而反对、抬杠成瘾的人")
        item(catSlang.id, "柠檬精", "sour grapes / green with envy", "zh-CN", "en", "看到别人好心生酸意的人")
        item(catSlang.id, "放鸽子", "stand someone up / flake on someone", "zh-CN", "en", "爽约不来")
        item(catSlang.id, "立flag", "set a jinxed goal / declare a risky promise", "zh-CN", "en", "许下容易惨遭打脸的预言或目标")
        item(catSlang.id, "画饼", "selling an empty dream / making false promises", "zh-CN", "en", "做出不切实际的口头承诺")
        item(catSlang.id, "背锅", "take the blame / be the scapegoat", "zh-CN", "en", "代替他人承担过失责任")
        item(catSlang.id, "降维打击", "dimensional strike / totally outclassing", "zh-CN", "en", "高层次对低层次形成压倒性优势")
        item(catSlang.id, "原地封神", "instant classic / reached god tier", "zh-CN", "en", "表现超凡脱俗堪称神作")
        item(catSlang.id, "无语子", "rendered speechless / at a total loss for words", "zh-CN", "en", "卖萌表达极度无奈无话可说")
        item(catSlang.id, "吃土", "dirt poor / broke after shopping", "zh-CN", "en", "挥霍消费后囊中羞涩的自嘲")

        return (categories: [catMemes, catSlang], items: seedItems)
    }
}
