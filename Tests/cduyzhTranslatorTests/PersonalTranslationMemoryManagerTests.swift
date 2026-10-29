import XCTest
@testable import cduyzhTranslatorCore

@MainActor
final class PersonalTranslationMemoryManagerTests: XCTestCase {
    private var directory: URL!

    override func setUp() async throws {
        directory = FileManager.default.temporaryDirectory.appendingPathComponent("PersonalTranslationMemoryTests-\(UUID().uuidString)", isDirectory: true)
        try FileManager.default.createDirectory(at: directory, withIntermediateDirectories: true)
    }

    override func tearDown() async throws {
        try? FileManager.default.removeItem(at: directory)
    }

    private func manager(migrateLegacy: Bool = false) -> PersonalTranslationMemoryManager {
        PersonalTranslationMemoryManager(directoryURL: directory, migrateLegacy: migrateLegacy)
    }

    func testCRUDPersistsWithoutAutomaticHistory() throws {
        let store = manager()
        XCTAssertTrue(store.items.isEmpty)
        let created = try store.upsert(sourceTerm: "  authentication  ", preferredTranslation: " 身份验证 ", sourceLang: "en", notes: "用于安全文档")
        XCTAssertEqual(created.sourceTerm, "authentication")
        XCTAssertEqual(created.preferredTranslation, "身份验证")
        XCTAssertEqual(store.storageFileURL.lastPathComponent, "personal-memory.json")
        let reopened = manager()
        XCTAssertEqual(reopened.items.first?.id, created.id)
        XCTAssertEqual(reopened.items.first?.notes, "用于安全文档")
        let edited = try reopened.upsert(sourceTerm: "authentication", preferredTranslation: "认证", sourceLang: "en", id: created.id)
        XCTAssertEqual(edited.id, created.id)
        XCTAssertEqual(edited.createdAt, reopened.items.first?.createdAt)
        XCTAssertEqual(reopened.items.count, 1)
        try reopened.setEnabled(id: created.id, enabled: false)
        XCTAssertFalse(manager().items[0].isEnabled)
        try reopened.delete(id: created.id)
        XCTAssertTrue(manager().items.isEmpty)
    }

    func testUpsertUpdatesSameLanguageTermAndPreservesOtherPairs() throws {
        let store = manager()
        let original = try store.upsert(sourceTerm: "Account", preferredTranslation: "账户", sourceLang: "en")
        let updated = try store.upsert(sourceTerm: "account", preferredTranslation: "账号", sourceLang: "en")
        XCTAssertEqual(original.id, updated.id)
        XCTAssertEqual(store.items.count, 1)
        _ = try store.upsert(sourceTerm: "account", preferredTranslation: "compte", sourceLang: "en", targetLang: "fr")
        XCTAssertEqual(store.items.count, 2)
        XCTAssertFalse(store.context(text: "account", sourceLang: "en", targetLang: "fr").contains("账号"))
    }

    func testContextSelectsOnlyEnabledRelevantLanguagePairWithWordBoundaries() throws {
        let store = manager()
        _ = try store.upsert(sourceTerm: "art", preferredTranslation: "美术", sourceLang: "en")
        _ = try store.upsert(sourceTerm: "API", preferredTranslation: "接口", sourceLang: "en")
        _ = try store.upsert(sourceTerm: "disabled", preferredTranslation: "不应出现", sourceLang: "en", isEnabled: false)
        _ = try store.upsert(sourceTerm: "art", preferredTranslation: "Kunst", sourceLang: "en", targetLang: "de")
        _ = try store.upsert(sourceTerm: "Gift", preferredTranslation: "毒药", sourceLang: "de")
        XCTAssertTrue(store.context(text: "start the article", sourceLang: "en", targetLang: "zh-CN").isEmpty)
        let context = store.context(text: "ART and API, disabled. Gift.", sourceLang: "en", targetLang: "zh-CN")
        XCTAssertTrue(context.contains("美术"))
        XCTAssertTrue(context.contains("接口"))
        XCTAssertFalse(context.contains("不应出现"))
        XCTAssertFalse(context.contains("Kunst"))
        XCTAssertFalse(context.contains("毒药"))
        XCTAssertTrue(store.context(text: "APIX", sourceLang: "en", targetLang: "zh-CN").isEmpty)
        XCTAssertTrue(store.context(text: "调用API即可", sourceLang: "en", targetLang: "zh-CN").contains("接口"))
    }

    func testChineseTermsMatchInSentencesAndExamplesRequireCompleteSource() throws {
        let store = manager()
        _ = try store.upsert(sourceTerm: "花火", preferredTranslation: "Sparkle", sourceLang: "zh-CN", targetLang: "en")
        _ = try store.upsert(sourceTerm: "请绑定账户", preferredTranslation: "Please link your account", sourceLang: "zh-CN", targetLang: "en", kind: .example)
        let context = store.context(text: "花火：请绑定账户。", sourceLang: "zh-CN", targetLang: "en")
        XCTAssertTrue(context.contains("Sparkle"))
        XCTAssertTrue(context.contains("Please link your account"))
        XCTAssertFalse(store.context(text: "请绑定其他账户", sourceLang: "zh-CN", targetLang: "en").contains("Please link your account"))
    }

    func testAutoSourceSkipsConflictingHomographs() throws {
        let store = manager()
        _ = try store.upsert(sourceTerm: "Gift", preferredTranslation: "礼物", sourceLang: "en")
        _ = try store.upsert(sourceTerm: "Gift", preferredTranslation: "毒药", sourceLang: "de")
        XCTAssertTrue(store.context(text: "Gift", sourceLang: "auto", targetLang: "zh-CN").isEmpty)
        let english = store.context(text: "Gift", sourceLang: "en", targetLang: "zh-CN")
        XCTAssertTrue(english.contains("礼物"))
        XCTAssertFalse(english.contains("毒药"))
    }

    func testRelevantChangesToggleAndDeletionAlterContextImmediately() throws {
        let store = manager()
        let item = try store.upsert(sourceTerm: "account", preferredTranslation: "账户", sourceLang: "en")
        let initial = store.context(text: "account", sourceLang: "en", targetLang: "zh-CN")
        _ = try store.upsert(sourceTerm: "unrelated", preferredTranslation: "无关", sourceLang: "en")
        XCTAssertEqual(initial, store.context(text: "account", sourceLang: "en", targetLang: "zh-CN"))
        _ = try store.upsert(sourceTerm: "account", preferredTranslation: "账号", sourceLang: "en", id: item.id)
        let edited = store.context(text: "account", sourceLang: "en", targetLang: "zh-CN")
        XCTAssertNotEqual(initial, edited)
        try store.setEnabled(id: item.id, enabled: false)
        XCTAssertTrue(store.context(text: "account", sourceLang: "en", targetLang: "zh-CN").isEmpty)
        try store.setEnabled(id: item.id, enabled: true)
        XCTAssertEqual(edited, store.context(text: "account", sourceLang: "en", targetLang: "zh-CN"))
        try store.delete(id: item.id)
        XCTAssertTrue(store.context(text: "account", sourceLang: "en", targetLang: "zh-CN").isEmpty)
    }

    func testMigrationImportsOnlyManualCorrectionsAndNeverResurrectsDeletedItems() throws {
        let sourceURL = directory.appendingPathComponent("memory.json")
        let legacy = [
            TranslationMemoryItem(id: "ordinary", sourceText: "ordinary", targetText: "普通历史", frequency: 50),
            TranslationMemoryItem(id: "favorite", sourceText: "favorite", targetText: "收藏历史", frequency: 50, favorite: true),
            TranslationMemoryItem(id: "corrected", sourceText: "Please link your account", targetText: "请关联账号", sourceLang: "en", userModified: true)
        ]
        let encoder = JSONEncoder()
        encoder.dateEncodingStrategy = .iso8601
        let sourceData = try encoder.encode(legacy)
        try sourceData.write(to: sourceURL)
        let store = manager(migrateLegacy: true)
        XCTAssertEqual(store.items.count, 1)
        XCTAssertEqual(store.items[0].id, "legacy-corrected")
        XCTAssertEqual(store.items[0].kind, .example)
        XCTAssertEqual(try Data(contentsOf: sourceURL), sourceData)
        XCTAssertEqual(manager(migrateLegacy: true).items.count, 1)
        try store.delete(id: "legacy-corrected")
        XCTAssertTrue(manager(migrateLegacy: true).items.isEmpty)
        XCTAssertEqual(try Data(contentsOf: sourceURL), sourceData)
    }

    func testMigrationDoesNotOverwriteExistingPersonalMapping() throws {
        let store = manager()
        let item = try store.upsert(sourceTerm: "account", preferredTranslation: "我的账号", sourceLang: "en")
        let old = TranslationMemoryItem(id: "old", sourceText: "account", targetText: "旧账户", sourceLang: "en", userModified: true)
        let encoder = JSONEncoder()
        encoder.dateEncodingStrategy = .iso8601
        try encoder.encode([old]).write(to: directory.appendingPathComponent("memory.json"))
        let migrated = manager(migrateLegacy: true)
        XCTAssertEqual(migrated.items.count, 1)
        XCTAssertEqual(migrated.items[0].id, item.id)
        XCTAssertEqual(migrated.items[0].preferredTranslation, "我的账号")
    }

    func testExportsSeparateFullStorageFromEnabledAgentPreferences() throws {
        let store = manager()
        _ = try store.upsert(sourceTerm: "account", preferredTranslation: "账号", sourceLang: "en", notes: "含\"引号\"和换行\n说明")
        _ = try store.upsert(sourceTerm: "disabled", preferredTranslation: "禁用内容", isEnabled: false)
        let json = store.exportJSON()
        let decoded = try JSONSerialization.jsonObject(with: XCTUnwrap(json.data(using: .utf8))) as! [[String: Any]]
        XCTAssertEqual(decoded.count, 2)
        XCTAssertTrue(json.contains("禁用内容"))
        XCTAssertTrue(store.exportAgentPrompt().contains("账号"))
        XCTAssertFalse(store.exportAgentPrompt().contains("禁用内容"))
        XCTAssertTrue(store.exportAgentPrompt(maxItems: 0).isEmpty)
        let prompt = store.context(text: "account", sourceLang: "en", targetLang: "zh-CN")
        let payload = try XCTUnwrap(prompt.split(separator: "\n").last)
        XCTAssertNoThrow(try JSONSerialization.jsonObject(with: Data(payload.utf8)))
    }

    func testInvalidInputAndFailedWriteDoNotChangePublishedItems() throws {
        let store = manager()
        XCTAssertThrowsError(try store.upsert(sourceTerm: " ", preferredTranslation: "译文"))
        XCTAssertThrowsError(try store.upsert(sourceTerm: "term", preferredTranslation: " "))
        XCTAssertThrowsError(try store.upsert(sourceTerm: "term", preferredTranslation: "译文", targetLang: "auto"))
        XCTAssertTrue(store.items.isEmpty)
        try FileManager.default.removeItem(at: directory)
        try Data("this path is a file".utf8).write(to: directory)
        XCTAssertThrowsError(try store.upsert(sourceTerm: "term", preferredTranslation: "译文"))
        XCTAssertTrue(store.items.isEmpty)
        XCTAssertNotNil(store.persistenceError)
    }

    func testCorruptPersonalStoreIsPreservedAndNotOverwrittenByCRUD() throws {
        let storeURL = directory.appendingPathComponent(PersonalTranslationMemoryManager.fileName)
        let original = Data("not-json".utf8)
        try original.write(to: storeURL)
        let store = manager(migrateLegacy: true)
        XCTAssertNotNil(store.persistenceError)
        XCTAssertThrowsError(try store.upsert(sourceTerm: "term", preferredTranslation: "译文"))
        XCTAssertEqual(try Data(contentsOf: storeURL), original)
    }

    func testCorrectionSuggestionsDoNotInferSourceAlignmentForSentences() {
        let suggestions = suggestTerms(sourceText: "Please bind the account.", originalTranslation: "请绑定账户。", correctedTranslation: "请关联账号。")
        XCTAssertEqual(suggestions.count, 1)
        XCTAssertTrue(suggestions[0].requiresSourceSelection)
        XCTAssertEqual(suggestions[0].sourceTerm, "")
        XCTAssertEqual(suggestions[0].preferredTranslation, "关联账号")
        let word = suggestTerms(sourceText: "account", originalTranslation: "账户", correctedTranslation: "账号")
        XCTAssertEqual(word.first?.sourceTerm, "account")
        XCTAssertEqual(word.first?.preferredTranslation, "账号")
        let slang = suggestTerms(sourceText: "WTF", originalTranslation: "WTF（粗俗缩写）", correctedTranslation: "我去（表示震惊或不满）")
        XCTAssertEqual(slang.first?.sourceTerm, "WTF")
        XCTAssertEqual(slang.first?.preferredTranslation, "我去（表示震惊或不满）")
        XCTAssertEqual(suggestTerms(sourceText: "我喜欢苹果", originalTranslation: "I love apples", correctedTranslation: "I prefer apples").first?.sourceTerm, "")
        XCTAssertTrue(suggestTerms(sourceText: "account", originalTranslation: "账号", correctedTranslation: "账号").isEmpty)
        XCTAssertTrue(suggestTerms(sourceText: "Hello.", originalTranslation: "你好。", correctedTranslation: "你好！").isEmpty)
    }
}
