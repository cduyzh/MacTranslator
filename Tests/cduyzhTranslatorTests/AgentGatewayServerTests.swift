import XCTest
@testable import cduyzhTranslatorCore

final class AgentGatewayServerTests: XCTestCase {
    
    func testServerLifecycleAndHealthCheck() async throws {
        let server = AgentGatewayServer.shared
        let testPort: UInt16 = 11988
        server.start(port: testPort)
        
        // 等待服务监听就绪
        try await Task.sleep(nanoseconds: 300_000_000)
        
        guard let url = URL(string: "http://127.0.0.1:\(testPort)/health") else {
            XCTFail("无法构造健康检查 URL")
            return
        }
        
        let (data, response) = try await URLSession.shared.data(from: url)
        let httpResponse = response as? HTTPURLResponse
        XCTAssertEqual(httpResponse?.statusCode, 200)
        
        let json = try JSONSerialization.jsonObject(with: data) as? [String: Any]
        XCTAssertEqual(json?["status"] as? String, "ok")
        XCTAssertNil(httpResponse?.value(forHTTPHeaderField: "Access-Control-Allow-Origin"))

        var promptComponents = URLComponents(string: "http://127.0.0.1:\(testPort)/v1/prompt")!
        promptComponents.queryItems = [URLQueryItem(name: "source_lang", value: "en"),
                                       URLQueryItem(name: "target_lang", value: "ja")]
        let (promptData, promptResponse) = try await URLSession.shared.data(from: try XCTUnwrap(promptComponents.url))
        XCTAssertEqual((promptResponse as? HTTPURLResponse)?.statusCode, 200)
        let promptJSON = try JSONSerialization.jsonObject(with: promptData) as? [String: Any]
        XCTAssertEqual(promptJSON?["source_lang"] as? String, "en")
        XCTAssertEqual(promptJSON?["target_lang"] as? String, "ja")
        XCTAssertTrue((promptJSON?["prompt"] as? String ?? "").contains("Target language: Japanese."))

        var browserRequest = URLRequest(url: URL(string: "http://127.0.0.1:\(testPort)/v1/memory")!)
        browserRequest.setValue("https://unrelated.example", forHTTPHeaderField: "Origin")
        let (_, blockedResponse) = try await URLSession.shared.data(for: browserRequest)
        XCTAssertEqual((blockedResponse as? HTTPURLResponse)?.statusCode, 403)
        
        server.stop()
    }
}
