import XCTest
@testable import cduyzhTranslatorCore

final class AppSettingsSecurityTests: XCTestCase {
    private let legacyKey = "cduyzh_deepseek_api_key"

    private func preferences() -> UserDefaults {
        UserDefaults(suiteName: "cduyzhTranslator.tests.\(UUID().uuidString)")!
    }

    func testFreshSettingsContainNoKeyAndDefaultToDeepSeekWithoutThinking() {
        let settings = AppSettings(defaults: preferences(), credentialStore: MemoryKeyStore())
        XCTAssertTrue(settings.deepSeekApiKey.isEmpty)
        XCTAssertEqual(settings.selectedEngine, .deepseek)
        XCTAssertEqual(settings.reasoningEffort, .off)
        XCTAssertNil(settings.apiKeyStorageError)
    }

    func testLocalAPIKeyFileHasOwnerOnlyPermissionsAndCanBeCleared() throws {
        let directory = FileManager.default.temporaryDirectory.appendingPathComponent(UUID().uuidString)
        defer { try? FileManager.default.removeItem(at: directory) }
        let url = directory.appendingPathComponent("api-key")
        let store = LocalAPIKeyStore(fileURL: url)
        XCTAssertNil(try store.load())
        try store.save("local-file-fixture")
        XCTAssertEqual(try store.load(), "local-file-fixture")
        let fileMode = (try FileManager.default.attributesOfItem(atPath: url.path)[.posixPermissions] as? NSNumber)?.intValue
        let directoryMode = (try FileManager.default.attributesOfItem(atPath: directory.path)[.posixPermissions] as? NSNumber)?.intValue
        XCTAssertEqual(fileMode.map { $0 & 0o777 }, 0o600)
        XCTAssertEqual(directoryMode.map { $0 & 0o777 }, 0o700)
        try store.save("")
        XCTAssertNil(try store.load())
    }

    func testExistingSharedAppDataDirectoryIsRestrictedWhenSavingKey() throws {
        let directory = FileManager.default.temporaryDirectory.appendingPathComponent(UUID().uuidString)
        defer { try? FileManager.default.removeItem(at: directory) }
        try FileManager.default.createDirectory(at: directory, withIntermediateDirectories: true,
                                               attributes: [.posixPermissions: 0o755])
        let store = LocalAPIKeyStore(fileURL: directory.appendingPathComponent("api-key"))
        try store.save("local-permission-fixture")
        let directoryMode = (try FileManager.default.attributesOfItem(atPath: directory.path)[.posixPermissions] as? NSNumber)?.intValue
        XCTAssertEqual(directoryMode.map { $0 & 0o777 }, 0o700)
    }

    func testLocalAPIKeyStoreRejectsSymbolicLinks() throws {
        let directory = FileManager.default.temporaryDirectory.appendingPathComponent(UUID().uuidString)
        defer { try? FileManager.default.removeItem(at: directory) }
        try FileManager.default.createDirectory(at: directory, withIntermediateDirectories: true)
        let target = directory.appendingPathComponent("other-file")
        let path = directory.appendingPathComponent("api-key")
        try Data("untouched-fixture".utf8).write(to: target)
        try FileManager.default.createSymbolicLink(at: path, withDestinationURL: target)
        XCTAssertThrowsError(try LocalAPIKeyStore(fileURL: path).load())
        XCTAssertEqual(try String(contentsOf: target, encoding: .utf8), "untouched-fixture")
    }

    func testTranslationInstructionsAndSelectionPreferencePersist() {
        let defaults = preferences()
        let settings = AppSettings(defaults: defaults, credentialStore: MemoryKeyStore())
        XCTAssertTrue(settings.selectionTranslationEnabled)
        XCTAssertEqual(settings.translationInstructions, "")
        XCTAssertEqual(settings.translationPromptTemplate, TranslationPromptDefaults.standard)
        XCTAssertFalse(settings.agentContextEnabled)
        settings.translationInstructions = "Use concise business language; keep product names unchanged."
        settings.translationPromptTemplate = "Output the translation only."
        settings.agentContextEnabled = true
        settings.agentContextMaxTurns = 6
        settings.agentContextMaxCharacters = 8_000
        settings.agentContextRetentionDays = 7
        settings.selectionTranslationEnabled = false
        let reloaded = AppSettings(defaults: defaults, credentialStore: MemoryKeyStore())
        XCTAssertEqual(reloaded.translationInstructions, settings.translationInstructions)
        XCTAssertEqual(reloaded.translationPromptTemplate, settings.translationPromptTemplate)
        XCTAssertTrue(reloaded.agentContextEnabled)
        XCTAssertEqual(reloaded.agentContextMaxTurns, 6)
        XCTAssertEqual(reloaded.agentContextMaxCharacters, 8_000)
        XCTAssertEqual(reloaded.agentContextRetentionDays, 7)
        XCTAssertFalse(reloaded.selectionTranslationEnabled)
    }

    func testAppearanceModePersistsAcrossSettingsReload() {
        let defaults = preferences()
        let settings = AppSettings(defaults: defaults, credentialStore: MemoryKeyStore())
        XCTAssertEqual(settings.appearanceMode, .system)
        settings.appearanceMode = .dark
        let reloaded = AppSettings(defaults: defaults, credentialStore: MemoryKeyStore())
        XCTAssertEqual(reloaded.appearanceMode, .dark)
    }

    func testLegacyKeyMigratesBeforePlaintextPreferenceIsRemoved() {
        let defaults = preferences()
        defaults.set("migration-fixture", forKey: legacyKey)
        let store = MemoryKeyStore()
        let settings = AppSettings(defaults: defaults, credentialStore: store)
        XCTAssertEqual(settings.deepSeekApiKey, "migration-fixture")
        XCTAssertEqual(store.key, "migration-fixture")
        XCTAssertNil(defaults.object(forKey: legacyKey))
    }

    func testMigrationFailureKeepsLegacyKeyAndReportsError() {
        let defaults = preferences()
        defaults.set("migration-fixture", forKey: legacyKey)
        let store = MemoryKeyStore()
        store.failSave = true
        let settings = AppSettings(defaults: defaults, credentialStore: store)
        XCTAssertEqual(settings.deepSeekApiKey, "migration-fixture")
        XCTAssertEqual(defaults.string(forKey: legacyKey), "migration-fixture")
        XCTAssertNotNil(settings.apiKeyStorageError)
    }

    func testSaveFailurePreservesPriorKey() {
        let store = MemoryKeyStore(key: "existing-fixture")
        let settings = AppSettings(defaults: preferences(), credentialStore: store)
        store.failSave = true
        settings.deepSeekApiKey = "replacement-fixture"
        XCTAssertEqual(settings.deepSeekApiKey, "existing-fixture")
        XCTAssertEqual(store.key, "existing-fixture")
        XCTAssertNotNil(settings.apiKeyStorageError)
        XCTAssertEqual(store.saveAttempts, 1, "回滚不能重复写入凭证")

        store.failSave = false
        settings.deepSeekApiKey = "retry-fixture"
        XCTAssertEqual(settings.deepSeekApiKey, "retry-fixture")
        XCTAssertEqual(store.key, "retry-fixture")
        XCTAssertEqual(store.saveAttempts, 2)
        XCTAssertNil(settings.apiKeyStorageError)
    }

    func testSavedLocalKeyWinsAndSuccessfulSaveNeverUsesPreferences() {
        let defaults = preferences()
        defaults.set("old-fixture", forKey: legacyKey)
        let store = MemoryKeyStore(key: "current-fixture")
        let settings = AppSettings(defaults: defaults, credentialStore: store)
        XCTAssertEqual(settings.deepSeekApiKey, "current-fixture")
        XCTAssertNil(defaults.object(forKey: legacyKey))
        settings.deepSeekApiKey = "updated-fixture"
        XCTAssertEqual(store.key, "updated-fixture")
        XCTAssertNil(defaults.object(forKey: legacyKey))
        settings.deepSeekApiKey = ""
        XCTAssertEqual(store.key, "")
        XCTAssertNil(defaults.object(forKey: legacyKey))
    }

    func testDeprecatedEngineAndEffortsFallBackToFastDeepSeek() {
        for effort in ["high", "max", "unknown"] {
            let defaults = preferences()
            defaults.set("smart", forKey: "cduyzh_selected_engine")
            defaults.set(effort, forKey: "cduyzh_reasoning_effort")
            defaults.set(true, forKey: "cduyzh_auto_translate_clipboard")
            defaults.set(0.9, forKey: "cduyzh_temperature")
            let settings = AppSettings(defaults: defaults, credentialStore: MemoryKeyStore())
            XCTAssertEqual(settings.selectedEngine, .deepseek)
            XCTAssertEqual(settings.reasoningEffort, .off)
            XCTAssertNil(defaults.object(forKey: "cduyzh_temperature"))
            XCTAssertNil(defaults.object(forKey: "cduyzh_auto_translate_clipboard"))
        }
    }

    func testRemovedMyMemoryPreferenceMigratesToGoogle() {
        let defaults = preferences()
        defaults.set("mymemory", forKey: "cduyzh_selected_engine")

        let settings = AppSettings(defaults: defaults, credentialStore: MemoryKeyStore())

        XCTAssertEqual(settings.selectedEngine, .google)
        XCTAssertEqual(defaults.string(forKey: "cduyzh_selected_engine"), "google")
    }

    func testLowEffortPreferenceIsPreserved() {
        let defaults = preferences()
        defaults.set("low", forKey: "cduyzh_reasoning_effort")
        let settings = AppSettings(defaults: defaults, credentialStore: MemoryKeyStore())
        XCTAssertEqual(settings.reasoningEffort, .low)
    }
}

private final class MemoryKeyStore: APIKeyStore {
    var key: String?
    var failSave = false
    var saveAttempts = 0

    init(key: String? = nil) { self.key = key }
    func load() throws -> String? { key }
    func save(_ key: String) throws {
        saveAttempts += 1
        if failSave { throw MemoryKeyStoreError.writeFailed }
        self.key = key
    }
}

private enum MemoryKeyStoreError: Error {
    case writeFailed
}
