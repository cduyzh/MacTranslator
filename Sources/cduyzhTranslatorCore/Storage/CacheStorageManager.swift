import Foundation

/// 存储与缓存使用详情信息
public struct StorageUsageInfo: Codable, Equatable {
    public var memoryBytes: Int64
    public var statsBytes: Int64
    public var cacheDirBytes: Int64
    public var totalBytes: Int64
    public var totalRecordsCount: Int
    public var favoriteCount: Int
    public var userModifiedCount: Int
    
    public init(
        memoryBytes: Int64 = 0,
        statsBytes: Int64 = 0,
        cacheDirBytes: Int64 = 0,
        totalBytes: Int64 = 0,
        totalRecordsCount: Int = 0,
        favoriteCount: Int = 0,
        userModifiedCount: Int = 0
    ) {
        self.memoryBytes = memoryBytes
        self.statsBytes = statsBytes
        self.cacheDirBytes = cacheDirBytes
        self.totalBytes = totalBytes
        self.totalRecordsCount = totalRecordsCount
        self.favoriteCount = favoriteCount
        self.userModifiedCount = userModifiedCount
    }
    
    public var formattedTotalSize: String {
        return CacheStorageManager.formatBytes(totalBytes)
    }
    
    public var formattedMemorySize: String {
        return CacheStorageManager.formatBytes(memoryBytes)
    }
    
    public var formattedStatsSize: String {
        return CacheStorageManager.formatBytes(statsBytes)
    }
}

/// 自动清理只管理临时文件。个人术语和修正示例由用户在个人记忆页管理。
@MainActor
public final class CacheStorageManager: ObservableObject {
    public static let shared = CacheStorageManager()
    @Published public var usageInfo = StorageUsageInfo()
    @Published public var lastCleanupMessage: String?

    private let fileManager = FileManager.default
    public let appSupportDirectory: URL
    public let appCachesDirectory: URL
    private let personalMemoryCounts: () -> (total: Int, enabled: Int)
    private let resetStatistics: () -> Void
    private let settings: AppSettings

    private convenience init() {
        let fm = FileManager.default
        self.init(
            supportDirectory: fm.urls(for: .applicationSupportDirectory, in: .userDomainMask).first!.appendingPathComponent("cduyzhTranslator"),
            cachesDirectory: fm.urls(for: .cachesDirectory, in: .userDomainMask).first!.appendingPathComponent("cduyzhTranslator"),
            personalMemoryCounts: {
                let items = PersonalTranslationMemoryManager.shared.items
                return (items.count, items.filter(\.isEnabled).count)
            },
            resetStatistics: { UsageStatisticsManager.shared.resetStats() },
            settings: .shared
        )
    }

    init(supportDirectory: URL, cachesDirectory: URL,
         personalMemoryCounts: @escaping () -> (total: Int, enabled: Int) = { (0, 0) },
         resetStatistics: @escaping () -> Void = {}, settings: AppSettings) {
        appSupportDirectory = supportDirectory
        appCachesDirectory = cachesDirectory
        self.personalMemoryCounts = personalMemoryCounts
        self.resetStatistics = resetStatistics
        self.settings = settings
        try? fileManager.createDirectory(at: supportDirectory, withIntermediateDirectories: true)
        try? fileManager.createDirectory(at: cachesDirectory, withIntermediateDirectories: true)
        refreshUsage()
    }

    @discardableResult
    public func refreshUsage() -> StorageUsageInfo {
        let counts = personalMemoryCounts()
        let memory = fileSize(at: appSupportDirectory.appendingPathComponent("personal-memory.json"))
        let stats = fileSize(at: appSupportDirectory.appendingPathComponent("stats.json"))
        let caches = directorySize(at: appCachesDirectory)
        usageInfo = StorageUsageInfo(memoryBytes: memory, statsBytes: stats, cacheDirBytes: caches,
                                     totalBytes: memory + stats + caches, totalRecordsCount: counts.total,
                                     favoriteCount: counts.enabled, userModifiedCount: counts.total)
        return usageInfo
    }

    /// 不访问 Application Support，避免缓存清理删除个人记忆和旧版迁移备份。
    public func cleanTemporaryCaches() -> Int64 {
        let size = directorySize(at: appCachesDirectory)
        if let files = try? fileManager.contentsOfDirectory(at: appCachesDirectory, includingPropertiesForKeys: nil) {
            for file in files { try? fileManager.removeItem(at: file) }
        }
        refreshUsage()
        return max(0, size - directorySize(at: appCachesDirectory))
    }

    @discardableResult
    public func performAutoCleanupIfNeeded(force: Bool = false) -> (cleaned: Bool, freedBytes: Int64, message: String) {
        guard settings.autoCleanupEnabled || force else { return (false, 0, "自动清理未启用") }
        if !force, let last = settings.lastAutoCleanupDate, Date().timeIntervalSince(last) < 86_400 {
            return (false, 0, "今日已完成自动清理")
        }
        let freed = cleanTemporaryCaches()
        settings.lastAutoCleanupDate = Date()
        let message = "已释放临时缓存 \(Self.formatBytes(freed))，个人翻译记忆保持完整"
        lastCleanupMessage = message
        return (true, freed, message)
    }

    /// 设置中的重置只重置统计和临时缓存，个人记忆须在专用页面明确删除。
    public func resetAllStorage() {
        resetStatistics()
        _ = cleanTemporaryCaches()
        refreshUsage()
    }

    private func fileSize(at url: URL) -> Int64 {
        ((try? fileManager.attributesOfItem(atPath: url.path)[.size]) as? NSNumber)?.int64Value ?? 0
    }

    private func directorySize(at url: URL) -> Int64 {
        guard let entries = fileManager.enumerator(at: url, includingPropertiesForKeys: [.isRegularFileKey, .fileSizeKey]) else { return 0 }
        return entries.compactMap { $0 as? URL }.reduce(Int64(0)) { total, file in
            guard let values = try? file.resourceValues(forKeys: [.isRegularFileKey, .fileSizeKey]), values.isRegularFile == true else { return total }
            return total + Int64(values.fileSize ?? 0)
        }
    }

    nonisolated public static func formatBytes(_ bytes: Int64) -> String {
        let formatter = ByteCountFormatter()
        formatter.allowedUnits = [.useBytes, .useKB, .useMB, .useGB]
        formatter.countStyle = .file
        return formatter.string(fromByteCount: bytes)
    }
}
