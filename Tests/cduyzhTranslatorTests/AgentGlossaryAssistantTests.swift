import XCTest
@testable import cduyzhTranslatorCore

@MainActor
final class AgentGlossaryAssistantTests: XCTestCase {
    private var tempDirectory: URL!

    override func setUp() async throws {
        try await super.setUp()
        tempDirectory = FileManager.default.temporaryDirectory.appendingPathComponent("AgentGlossaryTests-\(UUID().uuidString)", isDirectory: true)
        try FileManager.default.createDirectory(at: tempDirectory, withIntermediateDirectories: true)
    }

    override func tearDown() async throws {
        if let tempDirectory {
            try? FileManager.default.removeItem(at: tempDirectory)
        }
        try await super.tearDown()
    }

    // MARK: - 1. API Key 严格门禁测试

    func testMissingApiKeyThrowsError() async {
        // 提供一个 API Key 为空的配置
        let emptyConfigProvider: () -> DeepSeekConfiguration = {
            DeepSeekConfiguration(
                apiKey: "",
                baseURL: "https://api.deepseek.com",
                model: "deepseek-chat",
                effort: .off
            )
        }

        let assistant = AgentGlossaryAssistant(configProvider: emptyConfigProvider)

        do {
            _ = try await assistant.chatAndGenerate(prompt: "帮我生成 5 个网络热梗")
            XCTFail("未配置 API Key 时应当严格抛出 missingApiKey 错误")
        } catch let err as AgentGlossaryAssistantError {
            XCTAssertEqual(err, .missingApiKey)
        } catch {
            XCTFail("预期的错误类型为 AgentGlossaryAssistantError.missingApiKey，但收到: \(error)")
        }

        do {
            _ = try await assistant.analyzeAndEnrichTerm(term: "rizz")
            XCTFail("未配置 API Key 时应当严格抛出 missingApiKey 错误")
        } catch let err as AgentGlossaryAssistantError {
            XCTAssertEqual(err, .missingApiKey)
        } catch {
            XCTFail("预期的错误类型为 AgentGlossaryAssistantError.missingApiKey，但收到: \(error)")
        }
    }

    func testEmptyPromptThrowsError() async {
        let validConfigProvider: () -> DeepSeekConfiguration = {
            DeepSeekConfiguration(
                apiKey: "sk-mock-valid-key",
                baseURL: "https://api.deepseek.com",
                model: "deepseek-chat",
                effort: .off
            )
        }

        let assistant = AgentGlossaryAssistant(configProvider: validConfigProvider)

        do {
            _ = try await assistant.chatAndGenerate(prompt: "   \n\t  ")
            XCTFail("空 prompt 应当抛出 emptyPrompt 错误")
        } catch let err as AgentGlossaryAssistantError {
            XCTAssertEqual(err, .emptyPrompt)
        } catch {
            XCTFail("意外错误: \(error)")
        }
    }

    // MARK: - 2. 响应解析器与防御性 Markdown 代码块剥离测试

    func testParseDraftsFromMarkdownWrappedJSON() throws {
        let markdownResponse = """
        ```json
        [
          {
            "source_term": "brainrot",
            "preferred_translation": "电子降智 / 脑腐梗",
            "source_lang": "en",
            "target_lang": "zh-CN",
            "suggested_category_name": "网络热梗词",
            "notes": "刷无脑短视频引起的思维空洞"
          },
          {
            "source_term": "遥遥领先",
            "preferred_translation": "far ahead / miles ahead",
            "source_lang": "zh-CN",
            "target_lang": "en",
            "suggested_category_name": "网络热梗词",
            "notes": "国产科技发布会爆梗"
          }
        ]
        ```
        """

        let drafts = try AgentGlossaryAssistant.parseDrafts(from: markdownResponse)
        XCTAssertEqual(drafts.count, 2)

        XCTAssertEqual(drafts[0].sourceTerm, "brainrot")
        XCTAssertEqual(drafts[0].preferredTranslation, "电子降智 / 脑腐梗")
        XCTAssertEqual(drafts[0].sourceLang, "en")
        XCTAssertEqual(drafts[0].targetLang, "zh-CN")
        XCTAssertEqual(drafts[0].suggestedCategoryName, "网络热梗词")
        XCTAssertEqual(drafts[0].notes, "刷无脑短视频引起的思维空洞")
        XCTAssertTrue(drafts[0].isSelected)

        XCTAssertEqual(drafts[1].sourceTerm, "遥遥领先")
        XCTAssertEqual(drafts[1].preferredTranslation, "far ahead / miles ahead")
        XCTAssertEqual(drafts[1].sourceLang, "zh-CN")
        XCTAssertEqual(drafts[1].targetLang, "en")
    }

    func testParseDraftsFromSingleObjectAndAlternativeFieldNames() throws {
        let singleObjectResponse = """
        {
          "source": "sigma",
          "target": "独行强者 / 孤狼",
          "category": "网络俚语",
          "notes": "特立独行自律的硬汉"
        }
        """

        let drafts = try AgentGlossaryAssistant.parseDrafts(from: singleObjectResponse)
        XCTAssertEqual(drafts.count, 1)
        XCTAssertEqual(drafts[0].sourceTerm, "sigma")
        XCTAssertEqual(drafts[0].preferredTranslation, "独行强者 / 孤狼")
        XCTAssertEqual(drafts[0].suggestedCategoryName, "网络俚语")
        XCTAssertEqual(drafts[0].notes, "特立独行自律的硬汉")
    }

    // MARK: - 3. 原子写入本地文件管理 (Commit to Knowledge Base) 测试

    func testCommitToKnowledgeBaseWritesToDiskAndAutoCreatesCategory() throws {
        let kbManager = DomainKnowledgeBaseManager(directoryURL: tempDirectory, loadSeedsIfEmpty: false)
        XCTAssertEqual(kbManager.categories.count, 0)
        XCTAssertEqual(kbManager.items.count, 0)

        let assistant = AgentGlossaryAssistant()

        let drafts = [
            AgentGeneratedGlossaryDraft(
                sourceTerm: "delulu",
                preferredTranslation: "恋爱脑妄想 / 自我感动",
                sourceLang: "en",
                targetLang: "zh-CN",
                suggestedCategoryName: "网络热梗词",
                notes: "源自 delusional",
                isSelected: true
            ),
            AgentGeneratedGlossaryDraft(
                sourceTerm: "显眼包",
                preferredTranslation: "standout goofball",
                sourceLang: "zh-CN",
                targetLang: "en",
                suggestedCategoryName: "网络热梗词",
                notes: "爱出风头又喜感的人",
                isSelected: true
            ),
            AgentGeneratedGlossaryDraft(
                sourceTerm: "unselected_term",
                preferredTranslation: "未被选中的词条",
                isSelected: false // 不应被保存
            )
        ]

        let commitResult = try assistant.commitToKnowledgeBase(drafts: drafts, manager: kbManager)

        // 验证写入结果
        XCTAssertEqual(commitResult.savedCount, 2, "仅被选中的 2 条词条应被写入")
        XCTAssertTrue(commitResult.categoryNames.contains("网络热梗词"))

        // 验证内存管理器数据
        XCTAssertEqual(kbManager.categories.count, 1)
        XCTAssertEqual(kbManager.items.count, 2)
        XCTAssertTrue(kbManager.items.contains { $0.sourceTerm == "delulu" })
        XCTAssertTrue(kbManager.items.contains { $0.sourceTerm == "显眼包" })

        // 验证磁盘物理文件是否真实持久化：新开一个干净的实例从同目录读取
        let reloadedManager = DomainKnowledgeBaseManager(directoryURL: tempDirectory, loadSeedsIfEmpty: false)
        XCTAssertEqual(reloadedManager.categories.count, 1)
        XCTAssertEqual(reloadedManager.items.count, 2)
        let loadedDelulu = reloadedManager.items.first { $0.sourceTerm == "delulu" }
        XCTAssertNotNil(loadedDelulu)
        XCTAssertEqual(loadedDelulu?.preferredTranslation, "恋爱脑妄想 / 自我感动")
    }

    // MARK: - 4. Mock 模拟 URLSession 网络通信测试

    func testMockAgentChatGeneratesAndParsesDrafts() async throws {
        let mockJson = """
        {
          "id": "chatcmpl-mock",
          "choices": [
            {
              "message": {
                "role": "assistant",
                "content": "[{\\"source_term\\":\\"gyatt\\",\\"preferred_translation\\":\\"太顶了 / 哇塞\\",\\"source_lang\\":\\"en\\",\\"target_lang\\":\\"zh-CN\\",\\"suggested_category_name\\":\\"网络热梗词\\",\\"notes\\":\\"身材惊艳或场面炸裂\\"}]"
              },
              "finish_reason": "stop"
            }
          ]
        }
        """

        let config = URLSessionConfiguration.ephemeral
        config.protocolClasses = [MockURLProtocol.self]
        let mockSession = URLSession(configuration: config)

        MockURLProtocol.requestHandler = { request in
            guard let url = request.url, url.path.contains("chat/completions") else {
                let resp = HTTPURLResponse(url: request.url!, statusCode: 404, httpVersion: nil, headerFields: nil)!
                return (resp, Data())
            }
            let resp = HTTPURLResponse(url: url, statusCode: 200, httpVersion: nil, headerFields: ["Content-Type": "application/json"])!
            return (resp, mockJson.data(using: .utf8)!)
        }

        let assistant = AgentGlossaryAssistant(
            session: mockSession,
            configProvider: {
                DeepSeekConfiguration(
                    apiKey: "sk-mock-test-key",
                    baseURL: "https://api.deepseek.com",
                    model: "deepseek-chat",
                    effort: .off
                )
            }
        )

        let drafts = try await assistant.chatAndGenerate(prompt: "分析 gyatt")
        XCTAssertEqual(drafts.count, 1)
        XCTAssertEqual(drafts.first?.sourceTerm, "gyatt")
        XCTAssertEqual(drafts.first?.preferredTranslation, "太顶了 / 哇塞")
        XCTAssertEqual(drafts.first?.suggestedCategoryName, "网络热梗词")
    }
}

/// 测试用 URLProtocol Mock
private final class MockURLProtocol: URLProtocol {
    nonisolated(unsafe) static var requestHandler: ((URLRequest) throws -> (HTTPURLResponse, Data))?

    override class func canInit(with request: URLRequest) -> Bool { true }
    override class func canonicalRequest(for request: URLRequest) -> URLRequest { request }

    override func startLoading() {
        guard let handler = Self.requestHandler else {
            client?.urlProtocol(self, didFailWithError: URLError(.badServerResponse))
            return
        }
        do {
            let (response, data) = try handler(request)
            client?.urlProtocol(self, didReceive: response, cacheStoragePolicy: .notAllowed)
            client?.urlProtocol(self, didLoad: data)
            client?.urlProtocolDidFinishLoading(self)
        } catch {
            client?.urlProtocol(self, didFailWithError: error)
        }
    }

    override func stopLoading() {}
}
