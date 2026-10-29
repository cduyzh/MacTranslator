import XCTest
@testable import cduyzhTranslatorCore

final class AgentGatewayKnowledgeBaseTests: XCTestCase {
    private let testPort: UInt16 = 11993

    override func setUp() async throws {
        try await super.setUp()
        AgentGatewayServer.shared.start(port: testPort)
        try await Task.sleep(nanoseconds: 300_000_000)
    }

    override func tearDown() async throws {
        await MainActor.run {
            let testCats = DomainKnowledgeBaseManager.shared.categories.filter { $0.name.hasPrefix("测试领域_") }
            for cat in testCats {
                try? DomainKnowledgeBaseManager.shared.deleteCategory(id: cat.id)
            }
        }
        AgentGatewayServer.shared.stop()
        try await super.tearDown()
    }

    func testKnowledgeBaseOverviewEndpoint() async throws {
        let url = URL(string: "http://127.0.0.1:\(testPort)/v1/knowledge-base")!
        let (data, response) = try await URLSession.shared.data(from: url)
        let httpResponse = response as? HTTPURLResponse
        XCTAssertEqual(httpResponse?.statusCode, 200)

        let json = try JSONSerialization.jsonObject(with: data) as? [String: Any]
        XCTAssertNotNil(json?["enabled"])
        XCTAssertNotNil(json?["total_categories"])
        XCTAssertNotNil(json?["total_terms"])
        XCTAssertNotNil(json?["categories"])
    }

    func testKnowledgeBaseImportAndToggleEndpoint() async throws {
        let importURL = URL(string: "http://127.0.0.1:\(testPort)/v1/knowledge-base/import")!
        var request = URLRequest(url: importURL)
        request.httpMethod = "POST"
        request.setValue("application/json", forHTTPHeaderField: "Content-Type")

        let uniqueId = UUID().uuidString.prefix(6)
        let categoryName = "测试领域_\(uniqueId)"
        let term1 = "LiDAR_\(uniqueId)"

        let payload = """
        {
            "category": "\(categoryName)",
            "category_description": "感知、规划与控制",
            "terms": [
                {"source": "\(term1)", "target": "激光雷达", "notes": "测距传感器"},
                {"source": "odometry_\(uniqueId)", "target": "里程计", "notes": "位姿推算"}
            ]
        }
        """
        request.httpBody = payload.data(using: .utf8)

        let (data, response) = try await URLSession.shared.data(for: request)
        let httpResponse = response as? HTTPURLResponse
        XCTAssertEqual(httpResponse?.statusCode, 200)

        let json = try JSONSerialization.jsonObject(with: data) as? [String: Any]
        XCTAssertEqual(json?["status"] as? String, "ok")
        XCTAssertEqual(json?["category_name"] as? String, categoryName)
        let totalImported = (json?["added"] as? Int ?? 0) + (json?["updated"] as? Int ?? 0)
        XCTAssertGreaterThanOrEqual(totalImported, 2)

        let catId = json?["category_id"] as? String ?? ""
        XCTAssertFalse(catId.isEmpty)

        // 测试分类切换接口
        let toggleURL = URL(string: "http://127.0.0.1:\(testPort)/v1/knowledge-base/toggle")!
        var toggleRequest = URLRequest(url: toggleURL)
        toggleRequest.httpMethod = "POST"
        toggleRequest.setValue("application/json", forHTTPHeaderField: "Content-Type")
        toggleRequest.httpBody = "{\"category_id\":\"\(catId)\",\"is_enabled\":false}".data(using: .utf8)

        let (toggleData, toggleResponse) = try await URLSession.shared.data(for: toggleRequest)
        XCTAssertEqual((toggleResponse as? HTTPURLResponse)?.statusCode, 200)
        let toggleJSON = try JSONSerialization.jsonObject(with: toggleData) as? [String: Any]
        XCTAssertEqual(toggleJSON?["status"] as? String, "ok")

        // 显式清理本次测试生成的分类，防御污染持久化存储
        await MainActor.run {
            try? DomainKnowledgeBaseManager.shared.deleteCategory(id: catId)
        }
    }

    func testPromptEndpointIncludesKnowledgeBaseInfo() async throws {
        var components = URLComponents(string: "http://127.0.0.1:\(testPort)/v1/prompt")!
        components.queryItems = [
            URLQueryItem(name: "source_lang", value: "en"),
            URLQueryItem(name: "target_lang", value: "zh-CN"),
            URLQueryItem(name: "text", value: "He has endless rizz on stage, no cap!")
        ]

        let (data, response) = try await URLSession.shared.data(from: components.url!)
        XCTAssertEqual((response as? HTTPURLResponse)?.statusCode, 200)

        let json = try JSONSerialization.jsonObject(with: data) as? [String: Any]
        let kb = json?["knowledge_base"] as? [String: Any]
        XCTAssertNotNil(kb)
        XCTAssertEqual(kb?["enabled"] as? Bool, true)
        XCTAssertGreaterThanOrEqual(kb?["matched_terms"] as? Int ?? 0, 1)

        let promptText = json?["prompt"] as? String ?? ""
        XCTAssertTrue(promptText.contains("rizz -> 魅力值 / 撩妹技巧"), "Prompt 中应包含命中的网络热梗")
    }

    func testAgentChatEndpointValidation() async throws {
        let chatURL = URL(string: "http://127.0.0.1:\(testPort)/v1/knowledge-base/agent-chat")!
        var request = URLRequest(url: chatURL)
        request.httpMethod = "POST"
        request.setValue("application/json", forHTTPHeaderField: "Content-Type")

        // 缺少 prompt 字段应当返回 400
        request.httpBody = "{\"auto_commit\":true}".data(using: .utf8)
        let (_, response) = try await URLSession.shared.data(for: request)
        XCTAssertEqual((response as? HTTPURLResponse)?.statusCode, 400)
    }
}
