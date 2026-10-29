import XCTest
@testable import cduyzhTranslatorCore

@MainActor
final class UsageStatisticsManagerTests: XCTestCase {
    
    override func setUp() async throws {
        UsageStatisticsManager.shared.resetStats()
    }
    
    func testRecordCallStats() {
        let statsManager = UsageStatisticsManager.shared
        
        statsManager.record(
            engine: "DeepSeek (deepseek-flash)",
            success: true,
            promptTokens: 100,
            completionTokens: 200,
            reasoningTokens: 150,
            latencyMs: 500
        )
        
        let stats = statsManager.stats
        XCTAssertEqual(stats.totalRequests, 1)
        XCTAssertEqual(stats.successRequests, 1)
        XCTAssertEqual(stats.failedRequests, 0)
        XCTAssertEqual(stats.promptTokens, 100)
        XCTAssertEqual(stats.completionTokens, 200)
        XCTAssertEqual(stats.reasoningTokens, 150)
        XCTAssertEqual(stats.totalTokens, 300)
        XCTAssertEqual(stats.averageLatencyMs, 500)
        XCTAssertGreaterThan(stats.estimatedCostUSD, 0)
    }
    
    func testResetStats() {
        let statsManager = UsageStatisticsManager.shared
        statsManager.record(engine: "google", success: true, latencyMs: 200)
        XCTAssertEqual(statsManager.stats.totalRequests, 1)
        
        statsManager.resetStats()
        XCTAssertEqual(statsManager.stats.totalRequests, 0)
        XCTAssertEqual(statsManager.stats.totalTokens, 0)
    }
}
