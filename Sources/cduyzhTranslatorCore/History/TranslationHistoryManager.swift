import Foundation
import Combine

/// 单条翻译历史记录
public struct TranslationHistoryItem: Identifiable, Codable, Equatable, Sendable {
    public let id: UUID
    public let sourceText: String
    public let translatedText: String
    public let sourceLang: String
    public let targetLang: String
    public let engine: String
    public let timestamp: Date
    public let characterCount: Int

    public init(
        id: UUID = UUID(),
        sourceText: String,
        translatedText: String,
        sourceLang: String = "auto",
        targetLang: String = "zh-CN",
        engine: String = "Google",
        timestamp: Date = Date(),
        characterCount: Int? = nil
    ) {
        self.id = id
        self.sourceText = sourceText
        self.translatedText = translatedText
        self.sourceLang = sourceLang
        self.targetLang = targetLang
        self.engine = engine
        self.timestamp = timestamp
        self.characterCount = characterCount ?? sourceText.count
    }
}

/// 翻译历史记录管理器
/// 商业化限制策略：
/// - 免费用户：最多存储 50 条记录。达到 50 条后新增记录时，自动淘汰（删除）时间最早的一条记录 (FIFO)。
/// - Pro / 试用用户：无限制永久存储所有记录。
@MainActor
public final class TranslationHistoryManager: ObservableObject {
    public static let shared = TranslationHistoryManager()
    public static let maxFreeHistoryCount: Int = 50

    @Published public private(set) var items: [TranslationHistoryItem] = []
    @Published public private(set) var persistenceError: String?

    public let storageFileURL: URL
    private let isProProvider: () -> Bool

    private struct StoredHistory: Codable {
        var version: Int = 1
        var items: [TranslationHistoryItem]
    }

    public convenience init(directoryURL: URL? = nil) {
        self.init(directoryURL: directoryURL, isProProvider: { LicenseManager.shared.isPro })
    }

    public init(directoryURL: URL?, isProProvider: @escaping () -> Bool) {
        self.isProProvider = isProProvider
        let directory = directoryURL ?? FileManager.default.urls(for: .applicationSupportDirectory, in: .userDomainMask)[0]
            .appendingPathComponent("cduyzhTranslator", isDirectory: true)
        try? FileManager.default.createDirectory(at: directory, withIntermediateDirectories: true)
        self.storageFileURL = directory.appendingPathComponent("translation-history.json")

        loadFromDisk()
    }

    // MARK: - 核心记录与上限淘汰

    /// 记录一条翻译结果
    @discardableResult
    public func record(
        sourceText: String,
        translatedText: String,
        sourceLang: String,
        targetLang: String,
        engine: String
    ) -> TranslationHistoryItem {
        let cleanSource = sourceText.trimmingCharacters(in: .whitespacesAndNewlines)
        let cleanTarget = translatedText.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !cleanSource.isEmpty, !cleanTarget.isEmpty else {
            return TranslationHistoryItem(sourceText: sourceText, translatedText: translatedText)
        }

        let newItem = TranslationHistoryItem(
            id: UUID(),
            sourceText: cleanSource,
            translatedText: cleanTarget,
            sourceLang: sourceLang,
            targetLang: targetLang,
            engine: engine,
            timestamp: Date(),
            characterCount: cleanSource.count
        )

        // 插入到首位（按时间倒序）
        var currentItems = items
        currentItems.insert(newItem, at: 0)

        // 商业化配额管控：免费用户最多存 50 条记录，超额自动移除最早的一条
        let isPro = isProProvider()
        if !isPro && currentItems.count > Self.maxFreeHistoryCount {
            // 移除尾部（即时间最早的记录）
            currentItems.removeLast()
        }

        self.items = currentItems
        persistToDisk()
        return newItem
    }

    /// 删除单条历史记录
    public func delete(id: UUID) {
        items.removeAll { $0.id == id }
        persistToDisk()
    }

    /// 清空所有历史记录
    public func clearAll() {
        items.removeAll()
        persistToDisk()
    }

    /// 导出为 JSON 字符串
    public func exportJSON() -> String {
        let encoder = JSONEncoder()
        encoder.outputFormatting = [.prettyPrinted, .sortedKeys]
        encoder.dateEncodingStrategy = .iso8601
        guard let data = try? encoder.encode(items),
              let json = String(data: data, encoding: .utf8) else {
            return "[]"
        }
        return json
    }

    // MARK: - 持久化存储
    private func loadFromDisk() {
        guard FileManager.default.fileExists(atPath: storageFileURL.path) else {
            return
        }
        do {
            let data = try Data(contentsOf: storageFileURL)
            let stored = try JSONDecoder().decode(StoredHistory.self, from: data)
            // 按时间倒序排列
            self.items = stored.items.sorted { $0.timestamp > $1.timestamp }
        } catch {
            self.persistenceError = error.localizedDescription
        }
    }

    private func persistToDisk() {
        do {
            let stored = StoredHistory(version: 1, items: items)
            let encoder = JSONEncoder()
            encoder.outputFormatting = [.prettyPrinted]
            let data = try encoder.encode(stored)
            try data.write(to: storageFileURL, options: .atomic)
            try? FileManager.default.setAttributes([.posixPermissions: 0o600], ofItemAtPath: storageFileURL.path)
            self.persistenceError = nil
        } catch {
            self.persistenceError = error.localizedDescription
        }
    }
}
