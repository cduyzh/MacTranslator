import XCTest
@testable import cduyzhTranslatorCore

final class GoogleTranslatorEngineTests: XCTestCase {
    
    func testEmptyInputThrowsError() async {
        let engine = GoogleTranslatorEngine.shared
        let req = TranslationRequest(text: "", sourceLang: "auto", targetLang: "zh-CN")
        
        do {
            _ = try await engine.translate(request: req)
            XCTFail("空文本输入应当抛出错误")
        } catch {
            XCTAssertTrue(error is TranslationError)
        }
    }
    
    func testGoogleReverseEngineeredTranslation() async throws {
        let engine = GoogleTranslatorEngine.shared
        let req = TranslationRequest(text: "Good morning", sourceLang: "auto", targetLang: "zh-CN")
        
        let result = try await engine.translate(request: req)
        
        XCTAssertFalse(result.targetText.isEmpty)
        XCTAssertEqual(result.detectedSourceLang.lowercased(), "en")
        XCTAssertEqual(result.targetLang, "zh-CN")
        XCTAssertTrue(result.engineUsed.contains("Google Free"))
        XCTAssertGreaterThan(result.latencyMs, 0)
    }
    
    func testMultiLanguageTranslation() async throws {
        let engine = GoogleTranslatorEngine.shared
        // 翻译至日语
        let req = TranslationRequest(text: "Thank you very much", sourceLang: "en", targetLang: "ja")
        
        let result = try await engine.translate(request: req)
        XCTAssertFalse(result.targetText.isEmpty)
        XCTAssertEqual(result.targetLang, "ja")
    }
}
