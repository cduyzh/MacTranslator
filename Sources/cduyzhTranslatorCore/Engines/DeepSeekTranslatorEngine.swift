import Foundation
import CryptoKit

/// 请求开始时快照配置，避免设置变化污染在途请求和缓存。
public struct DeepSeekConfiguration: Sendable {
    public let apiKey: String
    public let baseURL: String
    public let model: String
    public let effort: ReasoningEffortLevel

    public static func current() -> DeepSeekConfiguration {
        let settings = AppSettings.shared
        return DeepSeekConfiguration(
            apiKey: settings.deepSeekApiKey.trimmingCharacters(in: .whitespacesAndNewlines),
            baseURL: settings.customApiBaseUrl,
            model: settings.selectedModel,
            effort: settings.reasoningEffort
        )
    }

    public var normalizedBaseURL: String {
        let trimmed = baseURL.trimmingCharacters(in: .whitespacesAndNewlines)
        return (trimmed.isEmpty ? "https://api.deepseek.com" : trimmed).trimmingCharacters(in: CharacterSet(charactersIn: "/"))
    }

    /// 缓存仅保留配置摘要；凭证变化后不复用另一个账户的结果。
    public var cacheIdentity: String {
        let data = try! JSONEncoder().encode([normalizedBaseURL, model, effort.rawValue, apiKey])
        return SHA256.hash(data: data).map { String(format: "%02x", $0) }.joined()
    }
}

/// DeepSeek 翻译只使用 content，丢弃独立的 reasoning_content 通道。
public final class DeepSeekTranslatorEngine: TranslationEngineProtocol {
    public static let shared = DeepSeekTranslatorEngine()
    public var engineType: TranslationEngineType { .deepseek }
    public var baseUrl: String { configuration().normalizedBaseURL }

    private let session: URLSession
    private let configuration: () -> DeepSeekConfiguration
    private let contextProvider: (TranslationRequest) async -> TranslationPromptContext

    public convenience init() {
        self.init(session: .shared, configuration: DeepSeekConfiguration.current, contextProvider: { request in
            await MainActor.run { TranslationPromptContext.current(for: request) }
        })
    }

    init(session: URLSession, configuration: @escaping () -> DeepSeekConfiguration, contextProvider: @escaping (TranslationRequest) async -> TranslationPromptContext = { _ in TranslationPromptContext() }) {
        self.session = session
        self.configuration = configuration
        self.contextProvider = contextProvider
    }

    public func fetchAvailableModels(apiKey: String) async throws -> [DeepSeekModelInfo] {
        try Task.checkCancellation()
        let key = apiKey.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !key.isEmpty else { throw TranslationError.apiKeyMissing }
        let url = try endpoint(baseURL: baseUrl, path: "models")
        var request = URLRequest(url: url)
        request.httpMethod = "GET"
        request.setValue("Bearer \(key)", forHTTPHeaderField: "Authorization")
        request.setValue("application/json", forHTTPHeaderField: "Accept")
        request.timeoutInterval = 10
        let (data, response) = try await session.data(for: request)
        try Task.checkCancellation()
        try validate(response)
        return try JSONDecoder().decode(DeepSeekModelListResponse.self, from: data).data
    }

    public func translate(request: TranslationRequest) async throws -> TranslationResult {
        try Task.checkCancellation()
        let trimmed = request.text.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !trimmed.isEmpty else { throw TranslationError.emptyInput }
        let config = request.deepSeekConfiguration ?? configuration()
        guard !config.apiKey.isEmpty else { throw TranslationError.apiKeyMissing }
        let url = try endpoint(baseURL: config.normalizedBaseURL, path: "chat/completions")
        let context: TranslationPromptContext
        if let snapshot = request.promptContext { context = snapshot }
        else { context = await contextProvider(request) }
        try Task.checkCancellation()
        let systemPrompt = TranslationPromptBuilder.render(
            sharedPrompt: context.sharedPrompt,
            instructions: context.instructions,
            sourceLang: request.sourceLang,
            targetLang: request.targetLang,
            personalMemory: context.personalMemory,
            domainKnowledge: context.domainKnowledge,
            historyContext: context.historyContext,
            sourceText: trimmed
        )
        // DeepSeek 默认启用 high 思考；off 必须显式关闭，不能仅省略 effort。
        // https://api-docs.deepseek.com/guides/thinking_mode/
        let body = DeepSeekChatRequest(
            model: config.model,
            messages: [DeepSeekMessage(role: "system", content: systemPrompt), DeepSeekMessage(role: "user", content: trimmed)],
            reasoningEffort: config.effort == .low ? "low" : nil,
            thinking: DeepSeekThinkingConfig(type: config.effort == .off ? "disabled" : "enabled"),
            stream: false
        )
        var urlRequest = URLRequest(url: url)
        urlRequest.httpMethod = "POST"
        urlRequest.setValue("Bearer \(config.apiKey)", forHTTPHeaderField: "Authorization")
        urlRequest.setValue("application/json", forHTTPHeaderField: "Content-Type")
        urlRequest.setValue("application/json", forHTTPHeaderField: "Accept")
        urlRequest.timeoutInterval = 30
        urlRequest.httpBody = try JSONEncoder().encode(body)

        let start = ContinuousClock.now
        let (data, response) = try await session.data(for: urlRequest)
        try Task.checkCancellation()
        try validate(response)
        let decoded = try JSONDecoder().decode(DeepSeekChatResponse.self, from: data)
        guard let choice = decoded.choices?.first else {
            throw TranslationError.invalidResponse("DeepSeek 未返回译文")
        }
        guard choice.finishReason != "length" else {
            throw TranslationError.invalidResponse("译文超出模型输出长度，已停止显示不完整结果；请分段翻译")
        }
        guard let content = choice.message?.content?.trimmingCharacters(in: .whitespacesAndNewlines), !content.isEmpty else {
            throw TranslationError.invalidResponse("DeepSeek 未返回有效译文内容")
        }
        let promptTokens = decoded.usage?.promptTokens ?? 0
        let completionTokens = decoded.usage?.completionTokens ?? 0
        let elapsed = start.duration(to: .now).components
        return TranslationResult(
            sourceText: trimmed,
            targetText: content,
            detectedSourceLang: request.sourceLang,
            targetLang: request.targetLang,
            engineUsed: "DeepSeek (\(config.model))",
            reasoningContent: nil,
            promptTokens: promptTokens,
            completionTokens: completionTokens,
            reasoningTokens: decoded.usage?.completionTokensDetails?.reasoningTokens ?? 0,
            totalTokens: decoded.usage?.totalTokens ?? (promptTokens + completionTokens),
            latencyMs: Int(elapsed.seconds * 1_000 + elapsed.attoseconds / 1_000_000_000_000_000)
        )
    }

    private func endpoint(baseURL: String, path: String) throws -> URL {
        guard let url = URL(string: "\(baseURL)/\(path)"),
              let scheme = url.scheme?.lowercased(), ["https", "http"].contains(scheme),
              url.host != nil else {
            throw TranslationError.networkError("DeepSeek API 地址无效，请在设置中检查")
        }
        return url
    }

    private func validate(_ response: URLResponse) throws {
        guard let http = response as? HTTPURLResponse else { throw TranslationError.networkError("非 HTTP 响应") }
        switch http.statusCode {
        case 200...299: return
        case 401: throw TranslationError.networkError("DeepSeek API Key 无效或未授权 (401)")
        case 402: throw TranslationError.networkError("DeepSeek 账户余额不足，请前往开放平台充值")
        case 429: throw TranslationError.rateLimited
        default:
            // 自定义端点可能在响应体回显请求头，错误 UI 不展示原始响应体。
            throw TranslationError.networkError("DeepSeek 接口返回状态码 \(http.statusCode)")
        }
    }
}
