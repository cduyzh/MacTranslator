import Foundation

/// 高可用的 Google 翻译免费 RPC 引擎
public final class GoogleTranslatorEngine: TranslationEngineProtocol {
    public static let shared = GoogleTranslatorEngine()
    
    public var engineType: TranslationEngineType { .google }
    
    // Google 全球对等免费翻译端点
    private let hosts = [
        "clients1.google.com",
        "clients2.google.com",
        "clients3.google.com",
        "clients4.google.com",
        "clients5.google.com"
    ]
    
    private var currentHostIndex = 0
    private let lock = NSLock()
    private let nodeQuery: ((String, TranslationRequest, CFAbsoluteTime) async throws -> TranslationResult)?
    
    private func nextHost() -> String {
        lock.lock()
        defer { lock.unlock() }
        let host = hosts[currentHostIndex % hosts.count]
        currentHostIndex = (currentHostIndex + 1) % hosts.count
        return host
    }
    
    public init() {
        nodeQuery = nil
    }

    init(nodeQuery: @escaping (String, TranslationRequest, CFAbsoluteTime) async throws -> TranslationResult) {
        self.nodeQuery = nodeQuery
    }
    
    public func translate(request: TranslationRequest) async throws -> TranslationResult {
        try Task.checkCancellation()
        let trimmed = request.text.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !trimmed.isEmpty else {
            throw TranslationError.emptyInput
        }
        
        let startTime = CFAbsoluteTimeGetCurrent()
        
        // 尝试从当前节点请求，若失败则轮询备用节点
        var lastError: Error?
        for _ in 0..<hosts.count {
            try Task.checkCancellation()
            let host = nextHost()
            do {
                let result: TranslationResult
                if let nodeQuery {
                    result = try await nodeQuery(host, request, startTime)
                } else {
                    result = try await queryNode(host: host, text: trimmed, sourceLang: request.sourceLang, targetLang: request.targetLang, startTime: startTime)
                }
                try Task.checkCancellation()
                return result
            } catch {
                try Task.checkCancellation()
                if error is CancellationError || (error as? URLError)?.code == .cancelled {
                    throw CancellationError()
                }
                lastError = error
                continue
            }
        }
        
        throw lastError ?? TranslationError.networkError("所有 Google 免费节点均未能响应")
    }
    
    private func queryNode(host: String, text: String, sourceLang: String, targetLang: String, startTime: CFAbsoluteTime) async throws -> TranslationResult {
        // 构建请求 URL
        var components = URLComponents()
        components.scheme = "https"
        components.host = host
        components.path = "/translate_a/t"
        
        // 将内部语言编码映射为 Google 规范
        let sl = (sourceLang == "auto" || sourceLang.isEmpty) ? "auto" : sourceLang
        let tl = targetLang
        
        components.queryItems = [
            URLQueryItem(name: "client", value: "dict-chrome-ex"),
            URLQueryItem(name: "sl", value: sl),
            URLQueryItem(name: "tl", value: tl),
            URLQueryItem(name: "q", value: text)
        ]
        
        guard let url = components.url else {
            throw TranslationError.networkError("无法构建 Google 翻译 URL")
        }
        
        var urlRequest = URLRequest(url: url)
        urlRequest.httpMethod = "GET"
        urlRequest.timeoutInterval = 8.0
        // 模拟 Chrome 扩展原生请求头
        urlRequest.setValue("Mozilla/5.0 (Macintosh; Intel Mac OS X 10_15_7) AppleWebKit/537.36 (KHTML, like Gecko) Chrome/128.0.0.0 Safari/537.36", forHTTPHeaderField: "User-Agent")
        urlRequest.setValue("application/json, text/plain, */*", forHTTPHeaderField: "Accept")
        urlRequest.setValue("gzip, deflate, br", forHTTPHeaderField: "Accept-Encoding")
        
        let (data, response) = try await URLSession.shared.data(for: urlRequest)
        
        guard let httpResponse = response as? HTTPURLResponse else {
            throw TranslationError.networkError("非 HTTP 响应")
        }
        
        if httpResponse.statusCode == 429 {
            throw TranslationError.rateLimited
        }
        
        guard (200...299).contains(httpResponse.statusCode) else {
            throw TranslationError.networkError("Google 接口返回状态码: \(httpResponse.statusCode)")
        }
        
        // 解析 Google 返回的 JSON 结构: [["你好世界","en"]]
        let jsonObject = try JSONSerialization.jsonObject(with: data, options: [])
        
        var translatedText = ""
        var detectedLang = sourceLang
        
        if let outerArray = jsonObject as? [[Any]] {
            for inner in outerArray {
                if let segment = inner.first as? String {
                    translatedText += segment
                }
                if inner.count > 1, let lang = inner[1] as? String {
                    detectedLang = lang
                }
            }
        } else if let simpleArray = jsonObject as? [Any] {
            if let first = simpleArray.first as? String {
                translatedText = first
            }
        }
        
        guard !translatedText.isEmpty else {
            throw TranslationError.invalidResponse("Google 回包未能解析出有效译文")
        }
        
        let elapsed = Int((CFAbsoluteTimeGetCurrent() - startTime) * 1000)
        
        return TranslationResult(
            sourceText: text,
            targetText: translatedText,
            detectedSourceLang: detectedLang,
            targetLang: targetLang,
            engineUsed: "Google Free (\(host))",
            reasoningContent: nil,
            promptTokens: 0,
            completionTokens: 0,
            reasoningTokens: 0,
            totalTokens: 0,
            latencyMs: elapsed,
            fromMemory: false
        )
    }
}
