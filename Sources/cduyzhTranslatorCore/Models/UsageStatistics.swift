import Foundation

/// 每日调用统计子记录
public struct DailyUsage: Codable {
    public var dateString: String
    public var totalRequests: Int
    public var promptTokens: Int
    public var completionTokens: Int
    public var reasoningTokens: Int
    public var totalTokens: Int
    public var costUSD: Double
    
    public init(dateString: String) {
        self.dateString = dateString
        self.totalRequests = 0
        self.promptTokens = 0
        self.completionTokens = 0
        self.reasoningTokens = 0
        self.totalTokens = 0
        self.costUSD = 0.0
    }
}

/// 全局调用量与统计报表模型
public struct UsageStatistics: Codable {
    public var totalRequests: Int
    public var successRequests: Int
    public var failedRequests: Int
    public var promptTokens: Int
    public var completionTokens: Int
    public var reasoningTokens: Int
    public var totalTokens: Int
    public var estimatedCostUSD: Double
    public var engineRequests: [String: Int]
    public var dailyUsages: [String: DailyUsage]
    public var totalLatencyMs: Int
    
    public init() {
        self.totalRequests = 0
        self.successRequests = 0
        self.failedRequests = 0
        self.promptTokens = 0
        self.completionTokens = 0
        self.reasoningTokens = 0
        self.totalTokens = 0
        self.estimatedCostUSD = 0.0
        self.engineRequests = [:]
        self.dailyUsages = [:]
        self.totalLatencyMs = 0
    }
    
    public var averageLatencyMs: Int {
        guard successRequests > 0 else { return 0 }
        return totalLatencyMs / successRequests
    }
    
    public var successRate: Double {
        guard totalRequests > 0 else { return 100.0 }
        return (Double(successRequests) / Double(totalRequests)) * 100.0
    }
    
    public mutating func recordCall(
        engine: String,
        success: Bool,
        promptTokens: Int = 0,
        completionTokens: Int = 0,
        reasoningTokens: Int = 0,
        latencyMs: Int = 0
    ) {
        totalRequests += 1
        if success {
            successRequests += 1
            totalLatencyMs += latencyMs
        } else {
            failedRequests += 1
        }
        
        engineRequests[engine, default: 0] += 1
        
        self.promptTokens += promptTokens
        self.completionTokens += completionTokens
        self.reasoningTokens += reasoningTokens
        let tokens = promptTokens + completionTokens
        self.totalTokens += tokens
        
        // DeepSeek 官方定价估算 (标准为 $0.27/1M input, $1.10/1M output)
        let cost = (Double(promptTokens) / 1_000_000.0 * 0.27) + (Double(completionTokens) / 1_000_000.0 * 1.10)
        self.estimatedCostUSD += cost
        
        // 记录每日用量
        let formatter = DateFormatter()
        formatter.dateFormat = "yyyy-MM-dd"
        let todayStr = formatter.string(from: Date())
        var daily = dailyUsages[todayStr] ?? DailyUsage(dateString: todayStr)
        daily.totalRequests += 1
        daily.promptTokens += promptTokens
        daily.completionTokens += completionTokens
        daily.reasoningTokens += reasoningTokens
        daily.totalTokens += tokens
        daily.costUSD += cost
        dailyUsages[todayStr] = daily
    }
}
