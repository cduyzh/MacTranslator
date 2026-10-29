import Foundation

/// 翻译协调器：配置隔离的短期缓存、请求合并、取消与统计。
@MainActor
public final class TranslationCoordinator: ObservableObject {
    public static let shared = TranslationCoordinator()

    @Published public var isTranslating = false
    @Published public var lastResult: TranslationResult?
    @Published public var currentError: String?

    private var activePresentationID: UUID?
    private let engineTranslator: (TranslationEngineType, TranslationRequest) async throws -> TranslationResult
    private let recordSuccess: (TranslationRequest, TranslationResult) -> Void
    private let recordFailure: (TranslationEngineType) -> Void
    private let rememberLanguages: (String, String) -> Void
    private let cacheContext: (TranslationRequest) -> String
    private let promptContextProvider: (TranslationRequest) -> TranslationPromptContext
    private let now: () -> Date
    private let cacheTTL: TimeInterval
    private let cacheCapacity: Int

    private struct RequestKey: Hashable {
        let text: String
        let source: String
        let target: String
        let engine: String
        let context: String
    }

    private struct CacheEntry {
        let result: TranslationResult
        let expiresAt: Date
        var accessedAt: Date
    }

    /// 同一次网络响应只记一次账单，独立 UI 调用仍分别维护展示状态。
    private final class SharedResponse {
        var result: TranslationResult
        var recorded = false
        init(_ result: TranslationResult) { self.result = result }
    }

    @MainActor private final class SharedFailure: Error {
        let underlying: Error
        var recorded = false
        init(_ error: Error) { underlying = error }
    }

    private struct Flight {
        let id: UUID
        let task: Task<Void, Never>
        var waiters: [UUID: CheckedContinuation<SharedResponse, Error>]
    }

    private var cache: [RequestKey: CacheEntry] = [:]
    private var flights: [RequestKey: Flight] = [:]

    private convenience init() {
        self.init(
            engineTranslator: { engine, request in
                switch engine {
                case .google: return try await GoogleTranslatorEngine.shared.translate(request: request)
                case .deepseek: return try await DeepSeekTranslatorEngine.shared.translate(request: request)
                }
            },
            recordSuccess: { request, result in
                UsageStatisticsManager.shared.record(
                    engine: result.fromMemory ? "SessionCache" : result.engineUsed,
                    success: true,
                    promptTokens: result.promptTokens,
                    completionTokens: result.completionTokens,
                    reasoningTokens: result.reasoningTokens,
                    latencyMs: result.latencyMs
                )
                TranslationHistoryManager.shared.record(
                    sourceText: request.text,
                    translatedText: result.targetText,
                    sourceLang: request.sourceLang,
                    targetLang: request.targetLang,
                    engine: result.fromMemory ? "Cache" : result.engineUsed
                )
            },
            recordFailure: { engine in UsageStatisticsManager.shared.record(engine: engine.rawValue, success: false, latencyMs: 0) },
            rememberLanguages: { source, target in
                AppSettings.shared.lastTargetLanguage = target
                if source != "auto" { AppSettings.shared.lastSourceLanguage = source }
            },
            promptContextProvider: TranslationPromptContext.current(for:)
        )
    }

    /// 注入边界用于离线测试；缓存上限和有效期可独立验证。
    init(
        engineTranslator: @escaping (TranslationEngineType, TranslationRequest) async throws -> TranslationResult,
        recordSuccess: @escaping (TranslationRequest, TranslationResult) -> Void = { _, _ in },
        recordFailure: @escaping (TranslationEngineType) -> Void = { _ in },
        rememberLanguages: @escaping (String, String) -> Void = { _, _ in },
        cacheContext: @escaping (TranslationRequest) -> String = { $0.cacheIdentity },
        promptContextProvider: @escaping (TranslationRequest) -> TranslationPromptContext = { _ in TranslationPromptContext() },
        now: @escaping () -> Date = Date.init,
        cacheTTL: TimeInterval = 300,
        cacheCapacity: Int = 64
    ) {
        self.engineTranslator = engineTranslator
        self.recordSuccess = recordSuccess
        self.recordFailure = recordFailure
        self.rememberLanguages = rememberLanguages
        self.cacheContext = cacheContext
        self.promptContextProvider = promptContextProvider
        self.now = now
        self.cacheTTL = cacheTTL
        self.cacheCapacity = cacheCapacity
    }

    public func translate(
        text: String,
        sourceLang: String? = nil,
        targetLang: String? = nil,
        engine: TranslationEngineType? = nil,
        historyContext: String = "",
        updatesPresentation: Bool = true
    ) async throws -> TranslationResult {
        try Task.checkCancellation()
        let trimmed = text.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !trimmed.isEmpty else { throw TranslationError.emptyInput }
        let settings = AppSettings.shared
        let source = sourceLang ?? settings.lastSourceLanguage
        let target = targetLang ?? settings.lastTargetLanguage
        let selected = engine ?? settings.selectedEngine
        var request = TranslationRequest(text: trimmed, sourceLang: source, targetLang: target, engine: selected)
        if selected == .deepseek {
            request.deepSeekConfiguration = .current()
            let baseContext = promptContextProvider(request)
            request.promptContext = TranslationPromptContext(
                sharedPrompt: baseContext.sharedPrompt,
                instructions: baseContext.instructions,
                personalMemory: baseContext.personalMemory,
                domainKnowledge: baseContext.domainKnowledge,
                historyContext: historyContext
            )
        }
        let key = RequestKey(text: trimmed, source: source, target: target, engine: selected.rawValue, context: cacheContext(request))
        rememberLanguages(source, target)
        let presentationID = updatesPresentation ? UUID() : nil
        if let presentationID {
            activePresentationID = presentationID
            isTranslating = true
            currentError = nil
            lastResult = nil
        }
        defer {
            if let presentationID, activePresentationID == presentationID { isTranslating = false }
        }

        do {
            let response: SharedResponse
            if var entry = cache[key], entry.expiresAt > now() {
                entry.accessedAt = now()
                cache[key] = entry
                var result = entry.result
                result.id = UUID()
                result.timestamp = now()
                result.fromMemory = true
                result.latencyMs = 0
                result.promptTokens = 0
                result.completionTokens = 0
                result.reasoningTokens = 0
                result.totalTokens = 0
                response = SharedResponse(result)
            } else {
                cache.removeValue(forKey: key)
                response = try await sharedTranslation(request, key: key)
            }
            try Task.checkCancellation()
            // 所有出口丢弃独立思考通道，包括注入引擎和未来的其他实现。
            response.result.reasoningContent = nil
            if !response.recorded {
                recordSuccess(request, response.result)
                response.recorded = true
                if !response.result.fromMemory { store(response.result, for: key) }
            }
            if let presentationID, activePresentationID == presentationID { lastResult = response.result }
            return response.result
        } catch {
            let sharedFailure = error as? SharedFailure
            let underlying = sharedFailure?.underlying ?? error
            try rethrowCancellation(underlying)
            if sharedFailure?.recorded != true {
                recordFailure(selected)
                sharedFailure?.recorded = true
            }
            if let presentationID, activePresentationID == presentationID { currentError = underlying.localizedDescription }
            throw underlying
        }
    }

    private func sharedTranslation(_ request: TranslationRequest, key: RequestKey) async throws -> SharedResponse {
        let waiterID = UUID()
        return try await withTaskCancellationHandler(operation: {
            try Task.checkCancellation()
            return try await withCheckedThrowingContinuation { continuation in
                if Task.isCancelled {
                    continuation.resume(throwing: CancellationError())
                    return
                }
                if flights[key] != nil {
                    flights[key]?.waiters[waiterID] = continuation
                    return
                }
                let flightID = UUID()
                let task = Task { [engineTranslator] in
                    do {
                        try Task.checkCancellation()
                        let result = try await engineTranslator(request.engine, request)
                        try Task.checkCancellation()
                        finish(key: key, flightID: flightID, result: .success(SharedResponse(result)))
                    } catch {
                        finish(key: key, flightID: flightID, result: .failure(SharedFailure(error)))
                    }
                }
                flights[key] = Flight(id: flightID, task: task, waiters: [waiterID: continuation])
            }
        }, onCancel: {
            Task { @MainActor [weak self] in self?.cancelWaiter(waiterID, key: key) }
        })
    }

    private func cancelWaiter(_ waiterID: UUID, key: RequestKey) {
        guard let continuation = flights[key]?.waiters.removeValue(forKey: waiterID) else { return }
        continuation.resume(throwing: CancellationError())
        if flights[key]?.waiters.isEmpty == true {
            flights.removeValue(forKey: key)?.task.cancel()
        }
    }

    private func finish(key: RequestKey, flightID: UUID, result: Result<SharedResponse, Error>) {
        // 已取消的同 key 旧任务不得完成后来的重试。
        guard flights[key]?.id == flightID, let flight = flights.removeValue(forKey: key) else { return }
        for continuation in flight.waiters.values { continuation.resume(with: result) }
    }

    private func store(_ result: TranslationResult, for key: RequestKey) {
        guard cacheCapacity > 0, cacheTTL > 0 else { return }
        let date = now()
        cache = cache.filter { $0.value.expiresAt > date }
        if cache.count >= cacheCapacity, let oldest = cache.min(by: { $0.value.accessedAt < $1.value.accessedAt })?.key {
            cache.removeValue(forKey: oldest)
        }
        cache[key] = CacheEntry(result: result, expiresAt: date.addingTimeInterval(cacheTTL), accessedAt: date)
    }

    private func rethrowCancellation(_ error: Error) throws {
        try Task.checkCancellation()
        if error is CancellationError || (error as? URLError)?.code == .cancelled { throw CancellationError() }
    }
}
