import XCTest
@testable import cduyzhTranslatorCore

@MainActor
final class TranslationHistoryTests: XCTestCase {
    private var tempDirectory: URL!
    private var historyManager: TranslationHistoryManager!

    override func setUp() async throws {
        try await super.setUp()
        tempDirectory = FileManager.default.temporaryDirectory
            .appendingPathComponent("TransBarHistoryTests-\(UUID().uuidString)", isDirectory: true)
        try FileManager.default.createDirectory(at: tempDirectory, withIntermediateDirectories: true)
        historyManager = TranslationHistoryManager(directoryURL: tempDirectory)
    }

    override func tearDown() async throws {
        if let tempDirectory {
            try? FileManager.default.removeItem(at: tempDirectory)
        }
        try await super.tearDown()
    }

    func testRecordAndRetrieveHistory() {
        XCTAssertEqual(historyManager.items.count, 0)

        historyManager.record(
            sourceText: "Hello world",
            translatedText: "你好，世界",
            sourceLang: "en",
            targetLang: "zh-CN",
            engine: "Google"
        )

        XCTAssertEqual(historyManager.items.count, 1)
        XCTAssertEqual(historyManager.items.first?.sourceText, "Hello world")
        XCTAssertEqual(historyManager.items.first?.translatedText, "你好，世界")
        XCTAssertEqual(historyManager.items.first?.engine, "Google")
    }

    func testFreeTierCapacityLimitFIFO() {
        // 创建一个模拟免费版（isPro = false）的实例
        let freeManager = TranslationHistoryManager(directoryURL: tempDirectory, isProProvider: { false })

        // 写入 55 条历史记录
        for i in 1...55 {
            freeManager.record(
                sourceText: "Source text \(i)",
                translatedText: "译文 \(i)",
                sourceLang: "en",
                targetLang: "zh-CN",
                engine: "Google"
            )
        }

        // 验证：免费版不能超过 50 条上限
        XCTAssertEqual(freeManager.items.count, TranslationHistoryManager.maxFreeHistoryCount)
        XCTAssertEqual(freeManager.items.count, 50)

        // 最新的记录在前面
        XCTAssertEqual(freeManager.items.first?.sourceText, "Source text 55")

        // 验证时间最早的记录 (1~5) 已经按 FIFO 淘汰，尾部应该是第 6 条
        XCTAssertEqual(freeManager.items.last?.sourceText, "Source text 6")
    }

    func testDeleteAndClearHistory() {
        let item1 = historyManager.record(sourceText: "Text 1", translatedText: "译文 1", sourceLang: "en", targetLang: "zh-CN", engine: "DeepSeek")
        _ = historyManager.record(sourceText: "Text 2", translatedText: "译文 2", sourceLang: "en", targetLang: "zh-CN", engine: "DeepSeek")

        XCTAssertEqual(historyManager.items.count, 2)

        historyManager.delete(id: item1.id)
        XCTAssertEqual(historyManager.items.count, 1)
        XCTAssertEqual(historyManager.items.first?.sourceText, "Text 2")

        historyManager.clearAll()
        XCTAssertEqual(historyManager.items.count, 0)
    }

    func testPersistenceReload() {
        historyManager.record(sourceText: "Persistent text", translatedText: "持久化文本", sourceLang: "en", targetLang: "zh-CN", engine: "MyMemory")

        // 从同一个目录重新初始化一个新的 Manager 实例验证磁盘读取
        let reloaded = TranslationHistoryManager(directoryURL: tempDirectory)
        XCTAssertEqual(reloaded.items.count, 1)
        XCTAssertEqual(reloaded.items.first?.sourceText, "Persistent text")
        XCTAssertEqual(reloaded.items.first?.translatedText, "持久化文本")
    }
}
