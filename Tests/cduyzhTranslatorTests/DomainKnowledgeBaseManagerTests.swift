import XCTest
@testable import cduyzhTranslatorCore

@MainActor
final class DomainKnowledgeBaseManagerTests: XCTestCase {
    private var tempDirectory: URL!

    override func setUp() async throws {
        try await super.setUp()
        tempDirectory = FileManager.default.temporaryDirectory.appendingPathComponent("DomainKBTests-\(UUID().uuidString)", isDirectory: true)
        try FileManager.default.createDirectory(at: tempDirectory, withIntermediateDirectories: true)
    }

    override func tearDown() async throws {
        if let tempDirectory {
            try? FileManager.default.removeItem(at: tempDirectory)
        }
        try await super.tearDown()
    }

    func testBuiltInSeedsInitialization() throws {
        let manager = DomainKnowledgeBaseManager(directoryURL: tempDirectory, loadSeedsIfEmpty: true)
        XCTAssertGreaterThanOrEqual(manager.categories.count, 2)
        XCTAssertTrue(manager.categories.contains { $0.name == "网络热梗词" })
        XCTAssertTrue(manager.categories.contains { $0.name == "网络俚语" })
        // 彻底清除旧测试领域
        XCTAssertFalse(manager.categories.contains { $0.name.contains("计算机") })
        XCTAssertFalse(manager.categories.contains { $0.name.contains("医学") })
        XCTAssertFalse(manager.categories.contains { $0.name.contains("法律") })

        XCTAssertGreaterThan(manager.items.count, 40)
        // 英文热梗与俚语
        XCTAssertTrue(manager.items.contains { $0.sourceTerm == "rizz" })
        XCTAssertTrue(manager.items.contains { $0.sourceTerm == "lowkey" })
        // 中文热梗与俚语
        XCTAssertTrue(manager.items.contains { $0.sourceTerm == "遥遥领先" })
        XCTAssertTrue(manager.items.contains { $0.sourceTerm == "显眼包" })
        XCTAssertTrue(manager.items.contains { $0.sourceTerm == "凡尔赛" })
    }

    func testCategoryAndItemCRUD() throws {
        let manager = DomainKnowledgeBaseManager(directoryURL: tempDirectory, loadSeedsIfEmpty: false)
        XCTAssertEqual(manager.categories.count, 0)
        XCTAssertEqual(manager.items.count, 0)

        // 添加分类
        let cat = try manager.addCategory(name: "潮流文化", description: "亚文化流行词汇")
        XCTAssertEqual(manager.categories.count, 1)
        XCTAssertEqual(cat.name, "潮流文化")

        // 添加词条
        let item1 = try manager.upsertItem(
            categoryId: cat.id,
            sourceTerm: "drip",
            preferredTranslation: "穿搭有型 / 潮酷行头",
            sourceLang: "en",
            targetLang: "zh-CN",
            notes: "街头潮流俚语"
        )
        XCTAssertEqual(manager.items.count, 1)
        XCTAssertEqual(item1.sourceTerm, "drip")

        // 重复添加相同 sourceTerm 应当是更新
        let item1Updated = try manager.upsertItem(
            categoryId: cat.id,
            sourceTerm: "Drip",
            preferredTranslation: "绝绝子穿搭 / 潮酷行头",
            sourceLang: "en",
            targetLang: "zh-CN",
            notes: "更新备注"
        )
        XCTAssertEqual(manager.items.count, 1)
        XCTAssertEqual(item1Updated.id, item1.id)
        XCTAssertEqual(manager.items.first?.preferredTranslation, "绝绝子穿搭 / 潮酷行头")

        // 禁用词条
        try manager.setItemEnabled(id: item1.id, isEnabled: false)
        XCTAssertFalse(manager.items.first?.isEnabled ?? true)

        // 恢复启用
        try manager.setItemEnabled(id: item1.id, isEnabled: true)
        XCTAssertTrue(manager.items.first?.isEnabled ?? false)

        // 删除词条
        try manager.deleteItem(id: item1.id)
        XCTAssertEqual(manager.items.count, 0)

        // 删除分类（级联删除词条）
        _ = try manager.upsertItem(categoryId: cat.id, sourceTerm: "test", preferredTranslation: "测试")
        XCTAssertEqual(manager.items.count, 1)
        try manager.deleteCategory(id: cat.id)
        XCTAssertEqual(manager.categories.count, 0)
        XCTAssertEqual(manager.items.count, 0)
    }

    func testDynamicContextMatchingAndZeroInjectionWhenNoMatch() throws {
        let manager = DomainKnowledgeBaseManager(directoryURL: tempDirectory, loadSeedsIfEmpty: true)

        // 场景 1: 输入日常句子，不含任何网络热梗或俚语 -> 必须零匹配，零上下文注入！避免无谓 Token 消耗！
        let noMatchResult = manager.queryContext(
            text: "Good morning, how are you today?",
            sourceLang: "en",
            targetLang: "zh-CN"
        )
        XCTAssertEqual(noMatchResult.matchedItems.count, 0)
        XCTAssertEqual(noMatchResult.renderedPrompt, "")
        XCTAssertEqual(noMatchResult.totalCandidateCount, 0)

        // 场景 2: 英文输入包含 "rizz" 和 "no cap" -> 应精准命中两个热梗
        let matchResult = manager.queryContext(
            text: "He showed undeniable rizz on the stage, no cap!",
            sourceLang: "en",
            targetLang: "zh-CN"
        )
        XCTAssertGreaterThanOrEqual(matchResult.matchedItems.count, 2)
        let terms = matchResult.matchedItems.map(\.sourceTerm)
        XCTAssertTrue(terms.contains("rizz"))
        XCTAssertTrue(terms.contains("no cap"))
        XCTAssertTrue(matchResult.renderedPrompt.contains("rizz ->"))
        XCTAssertTrue(matchResult.renderedPrompt.contains("no cap ->"))

        // 场景 3: 中文输入包含 "显眼包" 与 "破防" 翻译成英文 -> 应精准命中中译英词条
        let zhResult = manager.queryContext(
            text: "今天在会上那个显眼包彻底让我破防了",
            sourceLang: "zh-CN",
            targetLang: "en"
        )
        XCTAssertGreaterThanOrEqual(zhResult.matchedItems.count, 2)
        let zhTerms = zhResult.matchedItems.map(\.sourceTerm)
        XCTAssertTrue(zhTerms.contains("显眼包"))
        XCTAssertTrue(zhTerms.contains("破防"))
    }

    func testWordBoundaryMatchingPreventsSubstringFalsePositives() throws {
        let manager = DomainKnowledgeBaseManager(directoryURL: tempDirectory, loadSeedsIfEmpty: false)
        let cat = try manager.addCategory(name: "Slang")
        try manager.upsertItem(categoryId: cat.id, sourceTerm: "in", preferredTranslation: "在...里面")
        try manager.upsertItem(categoryId: cat.id, sourceTerm: "to", preferredTranslation: "到达")

        // 文本中虽然包含 "information" 和 "token"，但不包含独立的 "in" 和 "to"
        let text = "Information tokens are processed quickly."
        let result = manager.queryContext(text: text, sourceLang: "en", targetLang: "zh-CN")
        XCTAssertEqual(result.matchedItems.count, 0, "不应将 information 或 token 中的字母碎片误判为 in/to")

        // 当包含独立单词 "in" 时，才应命中
        let textWithIn = "Logged in successfully."
        let result2 = manager.queryContext(text: textWithIn, sourceLang: "en", targetLang: "zh-CN")
        XCTAssertEqual(result2.matchedItems.count, 1)
        XCTAssertEqual(result2.matchedItems.first?.sourceTerm, "in")
    }

    func testTokenGatekeeperMaxTermsAndCharacterBudget() throws {
        let manager = DomainKnowledgeBaseManager(directoryURL: tempDirectory, loadSeedsIfEmpty: true)

        // 一段同时包含多个网络热梗的文字
        let text = """
        He tried to flex his main character energy and show off his rizz,
        acting like a sigma, but it is giving pure cringe.
        """

        // 限制最多注入 2 条
        let budgetResult = manager.queryContext(
            text: text,
            sourceLang: "en",
            targetLang: "zh-CN",
            maxTerms: 2,
            maxCharacters: 500
        )
        XCTAssertEqual(budgetResult.matchedItems.count, 2, "受到 maxTerms 限制，最多只能注入 2 条")
        XCTAssertGreaterThan(budgetResult.totalCandidateCount, 2, "总候选词条数应大于 2")
        XCTAssertEqual(budgetResult.suppressedCount, budgetResult.totalCandidateCount - 2, "被守卫拦截节约的词条数")
        XCTAssertGreaterThan(budgetResult.estimatedCharactersSaved, 0)

        // 验证最长匹配优先策略：高特异性复合词应当优先排在前面
        let terms = budgetResult.matchedItems.map(\.sourceTerm)
        XCTAssertTrue(terms.contains("main character energy") || terms.contains("it's giving"), "长词热梗应优先被选取")
    }

    func testPersonalMemoryPrioritySuppression() throws {
        let manager = DomainKnowledgeBaseManager(directoryURL: tempDirectory, loadSeedsIfEmpty: true)

        // 假设个人翻译记忆中已经自定义了 "rizz" 的专属翻译
        let excludedTerms: Set<String> = ["rizz"]

        let result = manager.queryContext(
            text: "He has endless rizz and undeniable charm, no cap.",
            sourceLang: "en",
            targetLang: "zh-CN",
            excludedTerms: excludedTerms
        )

        let terms = result.matchedItems.map(\.sourceTerm)
        XCTAssertFalse(terms.contains("rizz"), "个人记忆中已有的词汇在知识库检索中必须被排除，防止重复与冲突")
        XCTAssertTrue(terms.contains("no cap"), "未冲突的热梗应正常被注入")
    }

    func testDisabledCategorySuppressesItems() throws {
        let manager = DomainKnowledgeBaseManager(directoryURL: tempDirectory, loadSeedsIfEmpty: true)
        let memeCat = try XCTUnwrap(manager.categories.first { $0.name == "网络热梗词" })

        // 禁用网络热梗分类
        try manager.setCategoryEnabled(id: memeCat.id, isEnabled: false)

        let text = "He has that natural rizz."
        let result = manager.queryContext(text: text, sourceLang: "en", targetLang: "zh-CN")
        XCTAssertEqual(result.matchedItems.count, 0, "禁用分类下的词条不应被检索或注入")

        // 重新启用
        try manager.setCategoryEnabled(id: memeCat.id, isEnabled: true)
        let resultEnabled = manager.queryContext(text: text, sourceLang: "en", targetLang: "zh-CN")
        XCTAssertEqual(resultEnabled.matchedItems.count, 1)
        XCTAssertEqual(resultEnabled.matchedItems.first?.sourceTerm, "rizz")
    }

    func testLegacyTestCategoryMigrationAndPurge() throws {
        // 构造一个包含旧测试领域的模拟存储数据 (v1)
        let oldJson = """
        {
          "version": 1,
          "categories": [
            {
              "id": "cat-ai-tech",
              "name": "计算机与人工智能",
              "description": "测试领域",
              "isEnabled": true,
              "createdAt": "2026-10-28T00:00:00Z",
              "updatedAt": "2026-10-28T00:00:00Z"
            },
            {
              "id": "user-custom-cat",
              "name": "我的游戏黑话",
              "description": "个人自定义保留分类",
              "isEnabled": true,
              "createdAt": "2026-10-28T00:00:00Z",
              "updatedAt": "2026-10-28T00:00:00Z"
            }
          ],
          "items": [
            {
              "id": "item-legacy-1",
              "categoryId": "cat-ai-tech",
              "sourceTerm": "zero-shot",
              "preferredTranslation": "零样本",
              "sourceLang": "en",
              "targetLang": "zh-CN",
              "notes": "",
              "isEnabled": true,
              "createdAt": "2026-10-28T00:00:00Z",
              "updatedAt": "2026-10-28T00:00:00Z"
            },
            {
              "id": "item-custom-1",
              "categoryId": "user-custom-cat",
              "sourceTerm": "gg",
              "preferredTranslation": "打得好 / 投降认输",
              "sourceLang": "en",
              "targetLang": "zh-CN",
              "notes": "游戏术语",
              "isEnabled": true,
              "createdAt": "2026-10-28T00:00:00Z",
              "updatedAt": "2026-10-28T00:00:00Z"
            }
          ]
        }
        """

        let storeFile = tempDirectory.appendingPathComponent(DomainKnowledgeBaseManager.fileName)
        try oldJson.write(to: storeFile, atomically: true, encoding: .utf8)

        // 重新启动管理器，应当自动清除旧测试领域，注入新热梗和俚语，并保留用户自定义分类
        let manager = DomainKnowledgeBaseManager(directoryURL: tempDirectory, loadSeedsIfEmpty: true)

        XCTAssertFalse(manager.categories.contains { $0.id == "cat-ai-tech" })
        XCTAssertFalse(manager.categories.contains { $0.name.contains("计算机") })
        XCTAssertFalse(manager.items.contains { $0.sourceTerm == "zero-shot" })

        // 验证用户自定义分类与词条被安全保留
        XCTAssertTrue(manager.categories.contains { $0.id == "user-custom-cat" })
        XCTAssertTrue(manager.items.contains { $0.sourceTerm == "gg" })

        // 验证官方热梗和俚语分类已注入
        XCTAssertTrue(manager.categories.contains { $0.name == "网络热梗词" })
        XCTAssertTrue(manager.categories.contains { $0.name == "网络俚语" })
        XCTAssertTrue(manager.items.contains { $0.sourceTerm == "rizz" })
    }
}
