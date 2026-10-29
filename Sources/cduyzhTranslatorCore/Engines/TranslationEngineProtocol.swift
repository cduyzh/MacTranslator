import Foundation

/// 统一翻译引擎协议
public protocol TranslationEngineProtocol {
    var engineType: TranslationEngineType { get }
    func translate(request: TranslationRequest) async throws -> TranslationResult
}

public enum TranslationError: LocalizedError {
    case emptyInput
    case networkError(String)
    case invalidResponse(String)
    case rateLimited
    case apiKeyMissing
    case unsupportedLanguage(String)
    
    public var errorDescription: String? {
        switch self {
        case .emptyInput:
            return "待翻译文本为空"
        case .networkError(let msg):
            return "网络连接异常: \(msg)"
        case .invalidResponse(let msg):
            return "接口回包解析失败: \(msg)"
        case .rateLimited:
            return "请求频率过高，触发限流保护"
        case .apiKeyMissing:
            return "缺少 API Key，请在设置中配置"
        case .unsupportedLanguage(let lang):
            return "暂不支持该语言代码: \(lang)"
        }
    }
}
