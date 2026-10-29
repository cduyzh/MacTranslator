import XCTest
@testable import cduyzhTranslatorCore

@MainActor
final class AgentTranslationContextStoreTests: XCTestCase {
    func testSessionIsolationPersistenceAndMostRecentTurnBudget() throws {
        let directory = FileManager.default.temporaryDirectory.appendingPathComponent(UUID().uuidString)
        defer { try? FileManager.default.removeItem(at: directory) }
        let file = directory.appendingPathComponent("context.json")
        let now = Date(timeIntervalSince1970: 1_800_000_000)
        let store = AgentTranslationContextStore(fileURL: file, now: { now })

        XCTAssertTrue(store.append(sessionID: "document-a", sourceText: "First", targetText: "第一",
                                   sourceLang: "en", targetLang: "zh-CN", maxCharacters: 2_000, retentionDays: 1))
        XCTAssertTrue(store.append(sessionID: "document-a", sourceText: "Second", targetText: "第二",
                                   sourceLang: "en", targetLang: "zh-CN", maxCharacters: 2_000, retentionDays: 1))

        let reloaded = AgentTranslationContextStore(fileURL: file, now: { now })
        let latest = reloaded.snapshot(sessionID: "document-a", sourceLang: "en", targetLang: "zh-CN",
                                       maxTurns: 1, maxCharacters: 2_000, retentionDays: 1)
        XCTAssertEqual(latest.turnCount, 1)
        XCTAssertTrue(latest.text.contains("Second"))
        XCTAssertFalse(latest.text.contains("First"))
        let isolated = reloaded.snapshot(sessionID: "document-b", sourceLang: "en", targetLang: "zh-CN",
                                         maxTurns: 4, maxCharacters: 2_000, retentionDays: 1)
        XCTAssertEqual(isolated.turnCount, 0)
        XCTAssertTrue(isolated.text.isEmpty)
    }

    func testContextIsBoundedByWholeTurnsAndExpiresByRetentionDays() throws {
        let directory = FileManager.default.temporaryDirectory.appendingPathComponent(UUID().uuidString)
        defer { try? FileManager.default.removeItem(at: directory) }
        let file = directory.appendingPathComponent("context.json")
        var now = Date(timeIntervalSince1970: 1_800_000_000)
        let store = AgentTranslationContextStore(fileURL: file, now: { now })
        XCTAssertTrue(store.append(sessionID: "doc", sourceText: "short", targetText: "短",
                                   sourceLang: "en", targetLang: "zh-CN", maxCharacters: 300, retentionDays: 1))
        let tooSmall = store.snapshot(sessionID: "doc", sourceLang: "en", targetLang: "zh-CN",
                                      maxTurns: 4, maxCharacters: 20, retentionDays: 1)
        XCTAssertEqual(tooSmall.turnCount, 0)

        now.addTimeInterval(2 * 86_400)
        let expired = store.snapshot(sessionID: "doc", sourceLang: "en", targetLang: "zh-CN",
                                     maxTurns: 4, maxCharacters: 2_000, retentionDays: 1)
        XCTAssertEqual(expired.turnCount, 0)
        XCTAssertFalse(FileManager.default.fileExists(atPath: file.path))
    }

    func testOversizedTurnIsNotStoredAndClearRemovesLocalFile() throws {
        let directory = FileManager.default.temporaryDirectory.appendingPathComponent(UUID().uuidString)
        defer { try? FileManager.default.removeItem(at: directory) }
        let file = directory.appendingPathComponent("context.json")
        let store = AgentTranslationContextStore(fileURL: file)
        XCTAssertFalse(store.append(sessionID: "doc", sourceText: String(repeating: "x", count: 400), targetText: "y",
                                    sourceLang: "en", targetLang: "zh-CN", maxCharacters: 100, retentionDays: 1))
        XCTAssertFalse(FileManager.default.fileExists(atPath: file.path))
        XCTAssertTrue(store.append(sessionID: "doc", sourceText: "Hello", targetText: "你好",
                                   sourceLang: "en", targetLang: "zh-CN", maxCharacters: 300, retentionDays: 1))
        XCTAssertTrue(FileManager.default.fileExists(atPath: file.path))
        store.clearAll()
        XCTAssertFalse(FileManager.default.fileExists(atPath: file.path))
    }
}
