import XCTest
@testable import cduyzhTranslatorCore

@MainActor
final class CacheStorageManagerTests: XCTestCase {
    func testFormatBytes() {
        XCTAssertTrue(CacheStorageManager.formatBytes(500).contains("500"))
        XCTAssertFalse(CacheStorageManager.formatBytes(5_000_000).isEmpty)
    }

    func testTemporaryCleanupNeverDeletesPersonalMemoryOrLegacyBackup() throws {
        try withStorage { cache, support, caches, _ in
            let memory = Data("confirmed-personal-preferences".utf8)
            let legacy = Data("legacy-correction-backup".utf8)
            let personalFile = support.appendingPathComponent("personal-memory.json")
            let legacyFile = support.appendingPathComponent("memory.json")
            try memory.write(to: personalFile)
            try legacy.write(to: legacyFile)
            try Data(repeating: 1, count: 1024).write(to: caches.appendingPathComponent("temporary.bin"))
            XCTAssertEqual(cache.cleanTemporaryCaches(), 1024)
            XCTAssertEqual(try Data(contentsOf: personalFile), memory)
            XCTAssertEqual(try Data(contentsOf: legacyFile), legacy)
            XCTAssertEqual(cache.usageInfo.totalRecordsCount, 2)
            XCTAssertEqual(cache.usageInfo.favoriteCount, 1)
        }
    }

    func testAutoCleanupIgnoresAgeAndSizeOfPersonalMemory() throws {
        try withStorage { cache, support, caches, settings in
            let personalFile = support.appendingPathComponent("personal-memory.json")
            let memory = Data(repeating: 2, count: 1_100_000)
            try memory.write(to: personalFile)
            try FileManager.default.setAttributes([.modificationDate: Date(timeIntervalSince1970: 0)], ofItemAtPath: personalFile.path)
            try Data(repeating: 1, count: 32).write(to: caches.appendingPathComponent("temporary.bin"))
            settings.retentionDays = 1
            settings.maxStorageLimitMB = 1
            let result = cache.performAutoCleanupIfNeeded(force: true)
            XCTAssertTrue(result.cleaned)
            XCTAssertEqual(result.freedBytes, 32)
            XCTAssertEqual(try Data(contentsOf: personalFile), memory)
        }
    }

    func testResetOnlyResetsStatisticsAndTemporaryCache() throws {
        let root = FileManager.default.temporaryDirectory.appendingPathComponent(UUID().uuidString)
        defer { try? FileManager.default.removeItem(at: root) }
        let preferencesName = "translator-storage-tests.\(UUID().uuidString)"
        let preferences = UserDefaults(suiteName: preferencesName)!
        defer { preferences.removePersistentDomain(forName: preferencesName) }
        let settings = AppSettings(defaults: preferences, credentialStore: StorageTestKeyStore())
        var resets = 0
        let cache = CacheStorageManager(supportDirectory: root.appendingPathComponent("support"),
                                        cachesDirectory: root.appendingPathComponent("cache"),
                                        resetStatistics: { resets += 1 }, settings: settings)
        let personal = cache.appSupportDirectory.appendingPathComponent("personal-memory.json")
        try Data("keep".utf8).write(to: personal)
        try Data("remove".utf8).write(to: cache.appCachesDirectory.appendingPathComponent("temporary.bin"))
        cache.resetAllStorage()
        XCTAssertEqual(resets, 1)
        XCTAssertEqual(try Data(contentsOf: personal), Data("keep".utf8))
        XCTAssertEqual(cache.usageInfo.cacheDirBytes, 0)
    }

    private func withStorage(_ body: (CacheStorageManager, URL, URL, AppSettings) throws -> Void) throws {
        let root = FileManager.default.temporaryDirectory.appendingPathComponent(UUID().uuidString)
        defer { try? FileManager.default.removeItem(at: root) }
        let preferencesName = "translator-storage-tests.\(UUID().uuidString)"
        let preferences = UserDefaults(suiteName: preferencesName)!
        defer { preferences.removePersistentDomain(forName: preferencesName) }
        let settings = AppSettings(defaults: preferences, credentialStore: StorageTestKeyStore())
        let cache = CacheStorageManager(supportDirectory: root.appendingPathComponent("support"),
                                        cachesDirectory: root.appendingPathComponent("cache"),
                                        personalMemoryCounts: { (2, 1) }, settings: settings)
        try body(cache, cache.appSupportDirectory, cache.appCachesDirectory, settings)
    }
}

private struct StorageTestKeyStore: APIKeyStore {
    func load() throws -> String? { nil }
    func save(_ key: String) throws {}
}
