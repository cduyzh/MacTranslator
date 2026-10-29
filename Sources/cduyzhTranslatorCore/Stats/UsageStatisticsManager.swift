import Foundation

/// 调用量与用量统计管理器
@MainActor
public final class UsageStatisticsManager: ObservableObject {
    public static let shared = UsageStatisticsManager()
    
    @Published public var stats: UsageStatistics = UsageStatistics()
    
    private var statsFileURL: URL {
        let appSupport = FileManager.default.urls(for: .applicationSupportDirectory, in: .userDomainMask).first!
        let appDir = appSupport.appendingPathComponent("cduyzhTranslator", isDirectory: true)
        try? FileManager.default.createDirectory(at: appDir, withIntermediateDirectories: true)
        return appDir.appendingPathComponent("stats.json")
    }
    
    private init() {
        loadFromDisk()
    }
    
    /// 记录单次翻译调用结果与用量
    public func record(
        engine: String,
        success: Bool,
        promptTokens: Int = 0,
        completionTokens: Int = 0,
        reasoningTokens: Int = 0,
        latencyMs: Int = 0
    ) {
        self.stats.recordCall(
            engine: engine,
            success: success,
            promptTokens: promptTokens,
            completionTokens: completionTokens,
            reasoningTokens: reasoningTokens,
            latencyMs: latencyMs
        )
        self.saveToDisk()
    }
    
    public func resetStats() {
        self.stats = UsageStatistics()
        self.saveToDisk()
    }
    
    public func saveToDisk() {
        let encoder = JSONEncoder()
        encoder.outputFormatting = .prettyPrinted
        if let data = try? encoder.encode(self.stats) {
            try? data.write(to: self.statsFileURL, options: .atomic)
        }
    }
    
    private func loadFromDisk() {
        guard FileManager.default.fileExists(atPath: self.statsFileURL.path) else { return }
        if let data = try? Data(contentsOf: self.statsFileURL) {
            let decoder = JSONDecoder()
            if let loaded = try? decoder.decode(UsageStatistics.self, from: data) {
                self.stats = loaded
            }
        }
    }
}
