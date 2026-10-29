import XCTest
@testable import cduyzhTranslatorCore

@MainActor
final class TranslationCoordinatorTests: XCTestCase {
    func testOlderResultCannotReplaceLatestPresentation() async throws {
        let translator = SuspendedTranslator()
        let coordinator = TranslationCoordinator(engineTranslator: translator.translate)

        let older = Task { try await coordinator.translate(text: "older", sourceLang: "en", targetLang: "zh-CN", engine: .deepseek) }
        await translator.waitUntilStarted("older")
        let latest = Task { try await coordinator.translate(text: "latest", sourceLang: "en", targetLang: "ja", engine: .deepseek) }
        await translator.waitUntilStarted("latest")

        translator.succeed("latest")
        _ = try await latest.value
        translator.succeed("older")
        _ = try await older.value

        XCTAssertEqual(coordinator.lastResult?.sourceText, "latest")
        XCTAssertNil(coordinator.currentError)
        XCTAssertFalse(coordinator.isTranslating)
    }

    func testOlderCompletionDoesNotEndLatestLoadingState() async throws {
        let translator = SuspendedTranslator()
        let coordinator = TranslationCoordinator(engineTranslator: translator.translate)

        let older = Task { try await coordinator.translate(text: "older", sourceLang: "en", targetLang: "zh-CN", engine: .deepseek) }
        await translator.waitUntilStarted("older")
        let latest = Task { try await coordinator.translate(text: "latest", sourceLang: "en", targetLang: "ja", engine: .deepseek) }
        await translator.waitUntilStarted("latest")

        translator.succeed("older")
        _ = try await older.value
        XCTAssertTrue(coordinator.isTranslating)
        XCTAssertNil(coordinator.lastResult)

        translator.succeed("latest")
        _ = try await latest.value
        XCTAssertFalse(coordinator.isTranslating)
        XCTAssertEqual(coordinator.lastResult?.sourceText, "latest")
    }

    func testOlderFailureCannotReplaceLatestSuccess() async throws {
        let translator = SuspendedTranslator()
        let coordinator = TranslationCoordinator(engineTranslator: translator.translate)

        let older = Task { try await coordinator.translate(text: "older", sourceLang: "en", targetLang: "zh-CN", engine: .deepseek) }
        await translator.waitUntilStarted("older")
        let latest = Task { try await coordinator.translate(text: "latest", sourceLang: "en", targetLang: "ja", engine: .deepseek) }
        await translator.waitUntilStarted("latest")

        translator.succeed("latest")
        _ = try await latest.value
        translator.fail("older", with: TranslationError.rateLimited)
        _ = try? await older.value

        XCTAssertEqual(coordinator.lastResult?.sourceText, "latest")
        XCTAssertNil(coordinator.currentError)
        XCTAssertFalse(coordinator.isTranslating)
    }

    func testIndependentRequestDoesNotMutateActivePresentation() async throws {
        let translator = SuspendedTranslator()
        var successCount = 0
        let coordinator = TranslationCoordinator(
            engineTranslator: translator.translate,
            recordSuccess: { _, _ in successCount += 1 }
        )

        let presented = Task { try await coordinator.translate(text: "presented", sourceLang: "en", targetLang: "zh-CN", engine: .deepseek) }
        await translator.waitUntilStarted("presented")
        let independent = Task { try await coordinator.translate(text: "independent", sourceLang: "en", targetLang: "ja", engine: .deepseek, updatesPresentation: false) }
        await translator.waitUntilStarted("independent")

        translator.succeed("independent")
        let result = try await independent.value
        XCTAssertEqual(result.sourceText, "independent")
        XCTAssertTrue(coordinator.isTranslating)
        XCTAssertNil(coordinator.lastResult)
        XCTAssertNil(coordinator.currentError)
        XCTAssertEqual(successCount, 1)

        translator.succeed("presented")
        _ = try await presented.value
        XCTAssertEqual(coordinator.lastResult?.sourceText, "presented")
    }

    func testIndependentFailurePreservesExistingPresentation() async throws {
        let translator = SuspendedTranslator()
        let coordinator = TranslationCoordinator(engineTranslator: translator.translate)
        let presented = Task { try await coordinator.translate(text: "presented", sourceLang: "en", targetLang: "zh-CN", engine: .deepseek) }
        await translator.waitUntilStarted("presented")
        translator.succeed("presented")
        _ = try await presented.value

        let independent = Task { try await coordinator.translate(text: "independent", sourceLang: "en", targetLang: "ja", engine: .deepseek, updatesPresentation: false) }
        await translator.waitUntilStarted("independent")
        translator.fail("independent", with: TranslationError.rateLimited)
        _ = try? await independent.value

        XCTAssertEqual(coordinator.lastResult?.sourceText, "presented")
        XCTAssertNil(coordinator.currentError)
        XCTAssertFalse(coordinator.isTranslating)
    }

    func testCancellationDiscardsEngineResultAndPersistence() async {
        let translator = SuspendedTranslator()
        var successCount = 0
        var failureCount = 0
        let coordinator = TranslationCoordinator(
            engineTranslator: translator.translate,
            recordSuccess: { _, _ in successCount += 1 },
            recordFailure: { _ in failureCount += 1 }
        )

        let task = Task { try await coordinator.translate(text: "cancelled", sourceLang: "en", targetLang: "zh-CN", engine: .deepseek) }
        await translator.waitUntilStarted("cancelled")
        task.cancel()
        // 模拟不响应取消、仍然返回结果的引擎。
        translator.succeed("cancelled")
        do {
            _ = try await task.value
            XCTFail("已取消请求必须抛出取消错误")
        } catch {
            XCTAssertTrue(error is CancellationError)
        }

        XCTAssertEqual(successCount, 0)
        XCTAssertEqual(failureCount, 0)
        XCTAssertNil(coordinator.lastResult)
        XCTAssertNil(coordinator.currentError)
        XCTAssertFalse(coordinator.isTranslating)
    }

    func testCancellationDoesNotStartAnotherEngineOrRecordFailure() async {
        for cancellation in [CancellationError() as Error, URLError(.cancelled) as Error] {
            var engines: [TranslationEngineType] = []
            var successCount = 0
            var failureCount = 0
            let coordinator = TranslationCoordinator(
                engineTranslator: { engine, _ in
                    engines.append(engine)
                    throw cancellation
                },
                recordSuccess: { _, _ in successCount += 1 },
                recordFailure: { _ in failureCount += 1 }
            )

            do {
                _ = try await coordinator.translate(text: "cancelled", sourceLang: "en", targetLang: "zh-CN", engine: .deepseek)
                XCTFail("取消错误必须向上传递")
            } catch {
                XCTAssertTrue(error is CancellationError)
            }

            XCTAssertEqual(engines, [.deepseek])
            XCTAssertEqual(successCount, 0)
            XCTAssertEqual(failureCount, 0)
            XCTAssertNil(coordinator.currentError)
            XCTAssertFalse(coordinator.isTranslating)
        }
    }

    func testAlreadyCancelledTaskDoesNotPrepareContextOrStartEngine() async {
        var lookupCount = 0
        var engineCount = 0
        var successCount = 0
        let coordinator = TranslationCoordinator(
            engineTranslator: { _, request in
                engineCount += 1
                return makeResult(request)
            },
            recordSuccess: { _, _ in successCount += 1 },
            promptContextProvider: { _ in
                lookupCount += 1
                return TranslationPromptContext(personalMemory: "user-confirmed context")
            }
        )

        let task = Task { try await coordinator.translate(text: "cancelled", sourceLang: "en", targetLang: "zh-CN", engine: .deepseek) }
        task.cancel()
        do {
            _ = try await task.value
            XCTFail("已取消请求必须在读取个人上下文前退出")
        } catch {
            XCTAssertTrue(error is CancellationError)
        }

        XCTAssertEqual(lookupCount, 0)
        XCTAssertEqual(engineCount, 0)
        XCTAssertEqual(successCount, 0)
        XCTAssertFalse(coordinator.isTranslating)
    }

    func testFailureClearsPreviouslyPresentedResult() async throws {
        let translator = SuspendedTranslator()
        let coordinator = TranslationCoordinator(engineTranslator: translator.translate)
        let previous = Task { try await coordinator.translate(text: "previous", sourceLang: "en", targetLang: "zh-CN", engine: .deepseek) }
        await translator.waitUntilStarted("previous")
        translator.succeed("previous")
        _ = try await previous.value

        let latest = Task { try await coordinator.translate(text: "latest", sourceLang: "en", targetLang: "ja", engine: .deepseek) }
        await translator.waitUntilStarted("latest")
        XCTAssertNil(coordinator.lastResult)
        translator.fail("latest", with: TranslationError.rateLimited)
        _ = try? await latest.value

        XCTAssertNil(coordinator.lastResult)
        XCTAssertNotNil(coordinator.currentError)
        XCTAssertFalse(coordinator.isTranslating)
    }

    func testRepeatedTranslationUsesCacheWithoutAnotherBillableRequest() async throws {
        var engineCount = 0
        var tokensRecorded = 0
        let coordinator = TranslationCoordinator(
            engineTranslator: { _, request in
                engineCount += 1
                var result = makeResult(request)
                result.totalTokens = 17
                result.promptTokens = 9
                result.completionTokens = 8
                result.reasoningContent = "hidden reasoning"
                return result
            },
            recordSuccess: { _, result in tokensRecorded += result.totalTokens }
        )
        let original = try await coordinator.translate(text: "same", sourceLang: "en", targetLang: "zh-CN", engine: .deepseek)
        let cached = try await coordinator.translate(text: " same ", sourceLang: "en", targetLang: "zh-CN", engine: .deepseek)
        XCTAssertEqual(engineCount, 1)
        XCTAssertEqual(tokensRecorded, 17)
        XCTAssertEqual(cached.targetText, original.targetText)
        XCTAssertTrue(cached.fromMemory)
        XCTAssertEqual(cached.latencyMs, 0)
        XCTAssertEqual(cached.totalTokens, 0)
        XCTAssertNil(original.reasoningContent)
        XCTAssertNil(cached.reasoningContent)
        XCTAssertNotEqual(original.id, cached.id)
    }

    func testCacheSeparatesLanguageEngineAndConfiguration() async throws {
        var context = "first-model-off"
        var engineCount = 0
        let coordinator = TranslationCoordinator(
            engineTranslator: { _, request in engineCount += 1; return makeResult(request) },
            cacheContext: { _ in context }
        )
        _ = try await coordinator.translate(text: "same", sourceLang: "en", targetLang: "zh-CN", engine: .deepseek)
        _ = try await coordinator.translate(text: "same", sourceLang: "ja", targetLang: "zh-CN", engine: .deepseek)
        _ = try await coordinator.translate(text: "same", sourceLang: "en", targetLang: "ja", engine: .deepseek)
        _ = try await coordinator.translate(text: "same", sourceLang: "en", targetLang: "zh-CN", engine: .google)
        context = "second-model-low"
        _ = try await coordinator.translate(text: "same", sourceLang: "en", targetLang: "zh-CN", engine: .deepseek)
        XCTAssertEqual(engineCount, 5)
    }

    func testCacheExpiresAndEvictsOldestResult() async throws {
        var clock = Date(timeIntervalSince1970: 100)
        var engineCount = 0
        let coordinator = TranslationCoordinator(
            engineTranslator: { _, request in engineCount += 1; return makeResult(request) },
            now: { clock }, cacheTTL: 10, cacheCapacity: 1
        )
        _ = try await coordinator.translate(text: "first", engine: .deepseek)
        clock = clock.addingTimeInterval(1)
        _ = try await coordinator.translate(text: "second", engine: .deepseek)
        _ = try await coordinator.translate(text: "first", engine: .deepseek)
        XCTAssertEqual(engineCount, 3)
        clock = clock.addingTimeInterval(11)
        _ = try await coordinator.translate(text: "first", engine: .deepseek)
        XCTAssertEqual(engineCount, 4)
    }

    func testConcurrentDuplicatesShareNetworkAndBillOnce() async throws {
        let translator = SuspendedTranslator()
        var engineCount = 0
        var recordCount = 0
        let coordinator = TranslationCoordinator(
            engineTranslator: { engine, request in
                engineCount += 1
                return try await translator.translate(engine: engine, request: request)
            },
            recordSuccess: { _, _ in recordCount += 1 }
        )
        let first = Task { try await coordinator.translate(text: "duplicate", sourceLang: "en", targetLang: "ja", engine: .deepseek) }
        await translator.waitUntilStarted("duplicate")
        let second = Task { try await coordinator.translate(text: "duplicate", sourceLang: "en", targetLang: "ja", engine: .deepseek, updatesPresentation: false) }
        for _ in 0..<3 { await Task.yield() }
        translator.succeed("duplicate")
        let original = try await first.value
        let shared = try await second.value
        XCTAssertEqual(original.targetText, shared.targetText)
        XCTAssertEqual(engineCount, 1)
        XCTAssertEqual(recordCount, 1)
    }

    func testCancellingOneDuplicateReturnsBeforeEngineAndKeepsOtherWaiter() async throws {
        let translator = SuspendedTranslator()
        var engineCount = 0
        let coordinator = TranslationCoordinator(engineTranslator: { engine, request in
            engineCount += 1
            return try await translator.translate(engine: engine, request: request)
        })
        let first = Task { try await coordinator.translate(text: "shared", sourceLang: "en", targetLang: "ja", engine: .deepseek) }
        await translator.waitUntilStarted("shared")
        let second = Task { try await coordinator.translate(text: "shared", sourceLang: "en", targetLang: "ja", engine: .deepseek) }
        for _ in 0..<3 { await Task.yield() }
        first.cancel()
        do { _ = try await first.value; XCTFail("取消必须立即返回") }
        catch { XCTAssertTrue(error is CancellationError) }
        XCTAssertTrue(coordinator.isTranslating)
        translator.succeed("shared")
        let result = try await second.value
        XCTAssertEqual(result.sourceText, "shared")
        XCTAssertEqual(engineCount, 1)
    }

    func testLastWaiterCancellationCancelsUnderlyingEngineAndDoesNotCache() async throws {
        let started = expectation(description: "engine started")
        let cancelled = expectation(description: "engine cancelled")
        var engineCount = 0
        var recordCount = 0
        let coordinator = TranslationCoordinator(
            engineTranslator: { _, request in
                engineCount += 1
                if engineCount > 1 { return makeResult(request) }
                started.fulfill()
                return try await withTaskCancellationHandler(operation: {
                    try await Task.sleep(for: .seconds(20))
                    return makeResult(request)
                }, onCancel: { cancelled.fulfill() })
            },
            recordSuccess: { _, _ in recordCount += 1 }
        )
        let pending = Task { try await coordinator.translate(text: "cancel", engine: .deepseek) }
        await fulfillment(of: [started], timeout: 2)
        pending.cancel()
        do { _ = try await pending.value; XCTFail("取消必须向上传递") }
        catch { XCTAssertTrue(error is CancellationError) }
        await fulfillment(of: [cancelled], timeout: 2)
        XCTAssertEqual(recordCount, 0)
        XCTAssertNil(coordinator.lastResult)
        XCTAssertFalse(coordinator.isTranslating)
        _ = try await coordinator.translate(text: "cancel", engine: .deepseek)
        XCTAssertEqual(engineCount, 2)
        XCTAssertEqual(recordCount, 1)
    }

    func testDuplicateFailureIsNotCachedAndRecordsOnce() async throws {
        let translator = SuspendedTranslator()
        var engineCount = 0
        var failureCount = 0
        let coordinator = TranslationCoordinator(
            engineTranslator: { engine, request in
                engineCount += 1
                return try await translator.translate(engine: engine, request: request)
            },
            recordFailure: { _ in failureCount += 1 }
        )
        let first = Task { try await coordinator.translate(text: "failed", engine: .deepseek) }
        await translator.waitUntilStarted("failed")
        let second = Task { try await coordinator.translate(text: "failed", engine: .deepseek) }
        for _ in 0..<3 { await Task.yield() }
        translator.fail("failed", with: TranslationError.rateLimited)
        _ = try? await first.value
        _ = try? await second.value
        XCTAssertEqual(engineCount, 1)
        XCTAssertEqual(failureCount, 1)
        let retry = Task { try await coordinator.translate(text: "failed", engine: .deepseek) }
        await translator.waitUntilStarted("failed")
        translator.succeed("failed")
        _ = try await retry.value
        XCTAssertEqual(engineCount, 2)
    }

    func testPersonalInstructionsAndMemoryAreSnapshottedAndInvalidateCache() async throws {
        let directory = FileManager.default.temporaryDirectory.appendingPathComponent("CoordinatorPersonalMemory-\(UUID().uuidString)")
        defer { try? FileManager.default.removeItem(at: directory) }
        let memory = PersonalTranslationMemoryManager(directoryURL: directory, migrateLegacy: false)
        let item = try memory.upsert(sourceTerm: "account", preferredTranslation: "账户", sourceLang: "en")
        var instructions = "Use concise wording."
        var snapshots: [TranslationPromptContext] = []
        let coordinator = TranslationCoordinator(
            engineTranslator: { _, request in
                snapshots.append(try XCTUnwrap(request.promptContext))
                return makeResult(request)
            },
            promptContextProvider: { request in
                TranslationPromptContext(instructions: instructions, personalMemory: memory.context(text: request.text, sourceLang: request.sourceLang, targetLang: request.targetLang))
            }
        )
        _ = try await coordinator.translate(text: "account", sourceLang: "en", targetLang: "zh-CN", engine: .deepseek)
        _ = try await coordinator.translate(text: "account", sourceLang: "en", targetLang: "zh-CN", engine: .deepseek)
        XCTAssertEqual(snapshots.count, 1)
        XCTAssertEqual(snapshots[0].instructions, "Use concise wording.")
        XCTAssertTrue(snapshots[0].personalMemory.contains("账户"))
        instructions = "Use our product voice."
        _ = try await coordinator.translate(text: "account", sourceLang: "en", targetLang: "zh-CN", engine: .deepseek)
        XCTAssertEqual(snapshots.count, 2)
        _ = try memory.upsert(sourceTerm: "account", preferredTranslation: "账号", sourceLang: "en", id: item.id)
        _ = try await coordinator.translate(text: "account", sourceLang: "en", targetLang: "zh-CN", engine: .deepseek)
        XCTAssertEqual(snapshots.count, 3)
        XCTAssertTrue(snapshots[2].personalMemory.contains("账号"))
        try memory.delete(id: item.id)
        _ = try await coordinator.translate(text: "account", sourceLang: "en", targetLang: "zh-CN", engine: .deepseek)
        XCTAssertEqual(snapshots.count, 4)
        XCTAssertTrue(snapshots[3].personalMemory.isEmpty)
        XCTAssertTrue(memory.items.isEmpty, "普通翻译不能重新生成已删除的个人记忆")
    }

    func testPersonalMemoryToggleInvalidatesCacheAndUnrelatedTermsDoNot() async throws {
        let directory = FileManager.default.temporaryDirectory.appendingPathComponent("CoordinatorPersonalToggle-\(UUID().uuidString)")
        defer { try? FileManager.default.removeItem(at: directory) }
        let memory = PersonalTranslationMemoryManager(directoryURL: directory, migrateLegacy: false)
        let item = try memory.upsert(sourceTerm: "account", preferredTranslation: "账号", sourceLang: "en")
        var count = 0
        let coordinator = TranslationCoordinator(
            engineTranslator: { _, request in count += 1; return makeResult(request) },
            promptContextProvider: { request in TranslationPromptContext(personalMemory: memory.context(text: request.text, sourceLang: request.sourceLang, targetLang: request.targetLang)) }
        )
        _ = try await coordinator.translate(text: "account", sourceLang: "en", targetLang: "zh-CN", engine: .deepseek)
        _ = try memory.upsert(sourceTerm: "unrelated", preferredTranslation: "无关", sourceLang: "en")
        _ = try await coordinator.translate(text: "account", sourceLang: "en", targetLang: "zh-CN", engine: .deepseek)
        XCTAssertEqual(count, 1)
        try memory.setEnabled(id: item.id, enabled: false)
        _ = try await coordinator.translate(text: "account", sourceLang: "en", targetLang: "zh-CN", engine: .deepseek)
        XCTAssertEqual(count, 2)
    }

    func testInFlightRequestKeepsPromptSnapshotWhenPreferencesChange() async throws {
        let translator = SuspendedTranslator()
        var instructions = "original instructions"
        var captured: [TranslationPromptContext] = []
        let coordinator = TranslationCoordinator(
            engineTranslator: { engine, request in
                captured.append(try XCTUnwrap(request.promptContext))
                return try await translator.translate(engine: engine, request: request)
            },
            promptContextProvider: { _ in TranslationPromptContext(instructions: instructions) }
        )
        let first = Task { try await coordinator.translate(text: "pending", engine: .deepseek) }
        await translator.waitUntilStarted("pending")
        instructions = "new instructions"
        XCTAssertEqual(captured.first?.instructions, "original instructions")
        translator.succeed("pending")
        _ = try await first.value
        let second = Task { try await coordinator.translate(text: "pending", engine: .deepseek) }
        await translator.waitUntilStarted("pending")
        XCTAssertEqual(captured.count, 2)
        XCTAssertEqual(captured[1].instructions, "new instructions")
        translator.succeed("pending")
        _ = try await second.value
    }

    func testGoogleCancellationDoesNotRetryOtherNodes() async {
        for cancellation in [CancellationError() as Error, URLError(.cancelled) as Error] {
            let counter = NodeCounter()
            let engine = GoogleTranslatorEngine { _, _, _ in
                await counter.visit()
                throw cancellation
            }

            do {
                _ = try await engine.translate(request: TranslationRequest(text: "cancelled"))
                XCTFail("Google 节点取消错误必须直接向上传递")
            } catch {
                XCTAssertTrue(error is CancellationError)
            }
            let count = await counter.count
            XCTAssertEqual(count, 1)
        }
    }
}

@MainActor
private final class SuspendedTranslator {
    private var pending: [String: (TranslationRequest, CheckedContinuation<TranslationResult, Error>)] = [:]
    private var startWaiters: [String: CheckedContinuation<Void, Never>] = [:]

    func translate(engine: TranslationEngineType, request: TranslationRequest) async throws -> TranslationResult {
        try await withCheckedThrowingContinuation { continuation in
            pending[request.text] = (request, continuation)
            startWaiters.removeValue(forKey: request.text)?.resume()
        }
    }

    func waitUntilStarted(_ text: String) async {
        if pending[text] != nil { return }
        await withCheckedContinuation { startWaiters[text] = $0 }
    }

    func succeed(_ text: String) {
        guard let (request, continuation) = pending.removeValue(forKey: text) else { return }
        continuation.resume(returning: makeResult(request))
    }

    func fail(_ text: String, with error: Error) {
        pending.removeValue(forKey: text)?.1.resume(throwing: error)
    }
}

private actor NodeCounter {
    private(set) var count = 0
    func visit() { count += 1 }
}

private func makeResult(_ request: TranslationRequest) -> TranslationResult {
    TranslationResult(sourceText: request.text, targetText: "translated: \(request.text)", detectedSourceLang: request.sourceLang, targetLang: request.targetLang, engineUsed: request.engine.rawValue)
}
