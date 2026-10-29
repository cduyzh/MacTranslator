import XCTest
@testable import cduyzhTranslatorCore

final class DeepSeekTranslatorEngineTests: XCTestCase {
    private var session: URLSession!

    override func setUp() {
        super.setUp()
        let config = URLSessionConfiguration.ephemeral
        config.protocolClasses = [DeepSeekStubProtocol.self]
        session = URLSession(configuration: config)
    }

    override func tearDown() {
        session.invalidateAndCancel()
        session = nil
        DeepSeekStubProtocol.handler = nil
        DeepSeekStubProtocol.onSuspendedStart = nil
        DeepSeekStubProtocol.onStop = nil
        super.tearDown()
    }

    private func engine(_ effort: ReasoningEffortLevel = .off, baseURL: String = "https://translation.invalid/") -> DeepSeekTranslatorEngine {
        DeepSeekTranslatorEngine(session: session) {
            DeepSeekConfiguration(apiKey: "unit-test-credential", baseURL: baseURL, model: "deepseek-flash", effort: effort)
        }
    }

    func testOffExplicitlyDisablesThinkingAndOmitsTemperature() async throws {
        DeepSeekStubProtocol.handler = { request in
            XCTAssertEqual(request.url?.absoluteString, "https://translation.invalid/chat/completions")
            XCTAssertEqual(request.value(forHTTPHeaderField: "Authorization"), "Bearer unit-test-credential")
            let body = try JSONSerialization.jsonObject(with: XCTUnwrap(request.httpBody)) as! [String: Any]
            XCTAssertEqual((body["thinking"] as? [String: String])?["type"], "disabled")
            XCTAssertNil(body["reasoning_effort"])
            XCTAssertNil(body["temperature"])
            XCTAssertEqual(body["stream"] as? Bool, false)
            let messages = try XCTUnwrap(body["messages"] as? [[String: String]])
            XCTAssertTrue(messages[0]["content"]!.contains("Source language: English."))
            XCTAssertTrue(messages[0]["content"]!.contains("Chinese (Simplified)"))
            return (200, Self.fixture())
        }
        let result = try await engine().translate(request: TranslationRequest(text: " Hello ", sourceLang: "en"))
        XCTAssertEqual(result.sourceText, "Hello")
        XCTAssertEqual(result.targetText, "你好")
        XCTAssertNil(result.reasoningContent)
        XCTAssertEqual(result.reasoningTokens, 4)
        XCTAssertEqual(result.totalTokens, 12)
    }

    func testLowEnablesOnlyLowEffortAndDiscardsReasoningChannel() async throws {
        DeepSeekStubProtocol.handler = { request in
            let body = try JSONSerialization.jsonObject(with: XCTUnwrap(request.httpBody)) as! [String: Any]
            XCTAssertEqual((body["thinking"] as? [String: String])?["type"], "enabled")
            XCTAssertEqual(body["reasoning_effort"] as? String, "low")
            XCTAssertNil(body["temperature"])
            return (200, Self.fixture())
        }
        let result = try await engine(.low).translate(request: TranslationRequest(text: "Hello"))
        XCTAssertEqual(result.targetText, "你好")
        XCTAssertNil(result.reasoningContent)
        XCTAssertEqual(ReasoningEffortLevel.allCases.map(\.rawValue), ["off", "low"])
    }

    func testModelsUseInjectedSessionAndNormalizeEndpoint() async throws {
        DeepSeekStubProtocol.handler = { request in
            XCTAssertEqual(request.url?.absoluteString, "https://translation.invalid/v1/models")
            XCTAssertEqual(request.httpMethod, "GET")
            return (200, Data(#"{"data":[{"id":"deepseek-flash"}]}"#.utf8))
        }
        let models = try await engine(baseURL: " https://translation.invalid/v1/ ").fetchAvailableModels(apiKey: "unit-test-credential")
        XCTAssertEqual(models.map(\.id), ["deepseek-flash"])
    }

    func testReasoningWithoutFinalContentIsNotUsedAsTranslation() async {
        DeepSeekStubProtocol.handler = { _ in (200, Self.fixture(content: "")) }
        do {
            _ = try await engine(.low).translate(request: TranslationRequest(text: "Hello"))
            XCTFail("只有思考内容时必须拒绝响应")
        } catch {
            XCTAssertTrue(error.localizedDescription.contains("未返回有效译文"))
        }
    }

    func testTruncatedResultIsRejected() async {
        DeepSeekStubProtocol.handler = { _ in (200, Self.fixture(finishReason: "length")) }
        do {
            _ = try await engine().translate(request: TranslationRequest(text: "Hello"))
            XCTFail("不应将截断响应当作完整译文")
        } catch {
            XCTAssertTrue(error.localizedDescription.contains("不完整结果"))
        }
    }

    func testErrorDoesNotExposeResponseBody() async {
        DeepSeekStubProtocol.handler = { _ in (500, Data("echoed-secret-response".utf8)) }
        do {
            _ = try await engine().translate(request: TranslationRequest(text: "Hello"))
            XCTFail("错误状态必须抛出")
        } catch {
            XCTAssertTrue(error.localizedDescription.contains("500"))
            XCTAssertFalse(error.localizedDescription.contains("echoed-secret"))
        }
    }

    func testMissingKeyAndEmptyInputNeverStartNetwork() async {
        DeepSeekStubProtocol.handler = { _ in
            XCTFail("输入错误必须在网络前拦截")
            return (500, Data())
        }
        let missingKey = DeepSeekTranslatorEngine(session: session) {
            DeepSeekConfiguration(apiKey: "", baseURL: "https://translation.invalid", model: "deepseek-flash", effort: .off)
        }
        do {
            _ = try await missingKey.translate(request: TranslationRequest(text: "Hello"))
            XCTFail("必须提示缺少 Key")
        } catch { XCTAssertTrue(error.localizedDescription.contains("缺少 API Key")) }
        do {
            _ = try await engine().translate(request: TranslationRequest(text: " \n "))
            XCTFail("必须提示空文本")
        } catch { XCTAssertTrue(error.localizedDescription.contains("待翻译文本为空")) }
    }

    func testConfigurationIdentitySeparatesEveryResponseAffectingSetting() {
        func identity(key: String = "test-account", url: String = "https://translation.invalid", model: String = "deepseek-flash", effort: ReasoningEffortLevel = .off) -> String {
            DeepSeekConfiguration(apiKey: key, baseURL: url, model: model, effort: effort).cacheIdentity
        }
        let baseline = identity()
        XCTAssertEqual(baseline, identity(url: "https://translation.invalid/"))
        XCTAssertNotEqual(baseline, identity(key: "another-account"))
        XCTAssertNotEqual(baseline, identity(url: "https://another.invalid"))
        XCTAssertNotEqual(baseline, identity(model: "another-model"))
        XCTAssertNotEqual(baseline, identity(effort: .low))
        XCTAssertFalse(baseline.contains("test-account"))
    }

    func testRequestConfigurationSnapshotIsUsedAfterSettingsChange() async throws {
        DeepSeekStubProtocol.handler = { request in
            XCTAssertEqual(request.url?.host, "snapshot.invalid")
            let body = try JSONSerialization.jsonObject(with: XCTUnwrap(request.httpBody)) as! [String: Any]
            XCTAssertEqual(body["model"] as? String, "snapshot-model")
            XCTAssertEqual(body["reasoning_effort"] as? String, "low")
            return (200, Self.fixture())
        }
        var request = TranslationRequest(text: "Hello")
        request.deepSeekConfiguration = DeepSeekConfiguration(apiKey: "snapshot-test-credential", baseURL: "https://snapshot.invalid", model: "snapshot-model", effort: .low)
        _ = try await engine(.off).translate(request: request)
    }

    func testUserInstructionsAndPersonalContextUseRequestSnapshot() async throws {
        var providerCalls = 0
        let translator = DeepSeekTranslatorEngine(session: session, configuration: {
            DeepSeekConfiguration(apiKey: "prompt-test-credential", baseURL: "https://translation.invalid", model: "deepseek-flash", effort: .off)
        }, contextProvider: { _ in
            providerCalls += 1
            return TranslationPromptContext(instructions: "live preferences must not replace snapshot")
        })
        DeepSeekStubProtocol.handler = { request in
            let body = try JSONSerialization.jsonObject(with: XCTUnwrap(request.httpBody)) as! [String: Any]
            let messages = try XCTUnwrap(body["messages"] as? [[String: String]])
            let prompt = try XCTUnwrap(messages.first?["content"])
            XCTAssertTrue(prompt.contains("## Translation parameters"))
            XCTAssertTrue(prompt.contains("Source language: Auto Detect."))
            XCTAssertTrue(prompt.contains("Target language: Chinese (Simplified)."))
            XCTAssertTrue(prompt.contains("## User translation requirements\nUse a concise product tone."))
            XCTAssertTrue(prompt.contains("account => 账号"))
            XCTAssertTrue(prompt.contains("Output only the final translation"))
            XCTAssertLessThan(try XCTUnwrap(prompt.range(of: "## Shared translation rules")).lowerBound,
                              try XCTUnwrap(prompt.range(of: "## User translation requirements")).lowerBound)
            XCTAssertFalse(prompt.contains("live preferences must not"))
            return (200, Self.fixture())
        }
        let request = TranslationRequest(text: "account", promptContext: TranslationPromptContext(instructions: "Use a concise product tone.", personalMemory: "account => 账号"))
        _ = try await translator.translate(request: request)
        XCTAssertEqual(providerCalls, 0)
    }

    func testCancellationStopsUnderlyingURLSessionRequest() async throws {
        let started = expectation(description: "URLSession started")
        let stopped = expectation(description: "URLSession cancelled")
        DeepSeekStubProtocol.onSuspendedStart = { _ in started.fulfill() }
        DeepSeekStubProtocol.onStop = { stopped.fulfill() }
        let translator = engine()
        let pending = Task { try await translator.translate(request: TranslationRequest(text: "Hello")) }
        await fulfillment(of: [started], timeout: 2)
        pending.cancel()
        do {
            _ = try await pending.value
            XCTFail("取消的 URLSession 不应返回译文")
        } catch {
            XCTAssertTrue(error is CancellationError || (error as? URLError)?.code == .cancelled)
        }
        await fulfillment(of: [stopped], timeout: 2)
    }

    private static func fixture(content: String = "你好", finishReason: String = "stop") -> Data {
        try! JSONSerialization.data(withJSONObject: [
            "choices": [["message": ["content": content, "reasoning_content": "internal reasoning should never leave engine"], "finish_reason": finishReason]],
            "usage": ["prompt_tokens": 5, "completion_tokens": 7, "total_tokens": 12, "completion_tokens_details": ["reasoning_tokens": 4]]
        ])
    }
}

private final class DeepSeekStubProtocol: URLProtocol {
    static var handler: ((URLRequest) throws -> (Int, Data))?
    static var onSuspendedStart: ((URLRequest) -> Void)?
    static var onStop: (() -> Void)?
    override class func canInit(with request: URLRequest) -> Bool { true }
    override class func canonicalRequest(for request: URLRequest) -> URLRequest { request }

    override func startLoading() {
        if let onSuspendedStart = Self.onSuspendedStart {
            onSuspendedStart(request)
            return
        }
        do {
            // URLSession 可能将 HTTP body 转为流。
            var captured = request
            if captured.httpBody == nil, let stream = captured.httpBodyStream {
                stream.open()
                defer { stream.close() }
                var data = Data()
                let buffer = UnsafeMutablePointer<UInt8>.allocate(capacity: 4096)
                defer { buffer.deallocate() }
                while stream.hasBytesAvailable {
                    let count = stream.read(buffer, maxLength: 4096)
                    if count <= 0 { break }
                    data.append(buffer, count: count)
                }
                captured.httpBody = data
            }
            guard let handler = Self.handler else { throw URLError(.unsupportedURL) }
            let (status, data) = try handler(captured)
            let response = HTTPURLResponse(url: request.url!, statusCode: status, httpVersion: nil, headerFields: ["Content-Type": "application/json"])!
            client?.urlProtocol(self, didReceive: response, cacheStoragePolicy: .notAllowed)
            client?.urlProtocol(self, didLoad: data)
            client?.urlProtocolDidFinishLoading(self)
        } catch { client?.urlProtocol(self, didFailWithError: error) }
    }
    override func stopLoading() { Self.onStop?() }
}
