import XCTest
@testable import cduyzhTranslatorCore

final class APIKeyValidatorTests: XCTestCase {
    
    func testEmptyAPIKeyValidation() async {
        let validator = APIKeyValidator.shared
        let result = await validator.validateKey(apiKey: "")
        
        XCTAssertEqual(result.status, .invalid)
        XCTAssertFalse(result.isValid)
        XCTAssertEqual(result.message, "API Key 不能为空")
    }
    
    func testValidAPIKeyValidation() async throws {
        guard ProcessInfo.processInfo.environment["RUN_LIVE_API_TESTS"] == "1",
              let validKey = ProcessInfo.processInfo.environment["DEEPSEEK_API_KEY"], !validKey.isEmpty else {
            throw XCTSkip("需要显式启用 RUN_LIVE_API_TESTS 并通过环境变量提供 Key；不读取本机钥匙串")
        }
        let validator = APIKeyValidator.shared
        
        let result = await validator.validateKey(apiKey: validKey)
        
        XCTAssertEqual(result.status, .valid)
        XCTAssertTrue(result.isValid)
        XCTAssertFalse(result.modelsFound.isEmpty)
        XCTAssertGreaterThan(result.latencyMs, 0)
    }
    
    func testInvalidAPIKeyValidation() async throws {
        guard ProcessInfo.processInfo.environment["RUN_LIVE_API_TESTS"] == "1" else {
            throw XCTSkip("联网鉴权测试需要显式启用 RUN_LIVE_API_TESTS")
        }
        let validator = APIKeyValidator.shared
        let fakeKey = "sk-000000000000000000000000000000000000"
        
        let result = await validator.validateKey(apiKey: fakeKey)
        
        XCTAssertEqual(result.status, .invalid)
        XCTAssertFalse(result.isValid)
        XCTAssertTrue(result.message.contains("401"))
    }
}
