import Foundation

/// API Key 连通性与有效性验证结果
public struct APIKeyValidationResult: Codable, Equatable {
    public enum Status: String, Codable {
        case valid = "valid"
        case invalid = "invalid"
        case rateLimited = "rate_limited"
        case networkError = "network_error"
    }
    
    public let status: Status
    public let message: String
    public let latencyMs: Int
    public let modelsFound: [String]
    public let testedAt: Date
    
    public var isValid: Bool {
        return status == .valid
    }
}

/// API Key 自动化健康检查与连通性验证器
public final class APIKeyValidator {
    public static let shared = APIKeyValidator()
    
    private init() {}
    
    /// 测试指定的 API Key 是否可用
    public func validateKey(apiKey: String, baseUrl: String = "https://api.deepseek.com") async -> APIKeyValidationResult {
        let trimmedKey = apiKey.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !trimmedKey.isEmpty else {
            return APIKeyValidationResult(
                status: .invalid,
                message: "API Key 不能为空",
                latencyMs: 0,
                modelsFound: [],
                testedAt: Date()
            )
        }
        
        let cleanedUrl = baseUrl.trimmingCharacters(in: .whitespacesAndNewlines)
        guard let url = URL(string: "\(cleanedUrl)/models") else {
            return APIKeyValidationResult(
                status: .networkError,
                message: "API Base URL 格式无效: \(cleanedUrl)",
                latencyMs: 0,
                modelsFound: [],
                testedAt: Date()
            )
        }
        
        var request = URLRequest(url: url)
        request.httpMethod = "GET"
        request.setValue("Bearer \(trimmedKey)", forHTTPHeaderField: "Authorization")
        request.setValue("application/json", forHTTPHeaderField: "Accept")
        request.timeoutInterval = 7.0
        
        let startTime = CFAbsoluteTimeGetCurrent()
        
        do {
            let (data, response) = try await URLSession.shared.data(for: request)
            let latency = Int((CFAbsoluteTimeGetCurrent() - startTime) * 1000)
            
            guard let httpResponse = response as? HTTPURLResponse else {
                return APIKeyValidationResult(
                    status: .networkError,
                    message: "非 HTTP 协议回包",
                    latencyMs: latency,
                    modelsFound: [],
                    testedAt: Date()
                )
            }
            
            switch httpResponse.statusCode {
            case 200...299:
                if let decoded = try? JSONDecoder().decode(DeepSeekModelListResponse.self, from: data) {
                    let modelIds = decoded.data.map { $0.id }
                    return APIKeyValidationResult(
                        status: .valid,
                        message: "✅ Key 鉴权有效！成功连接 DeepSeek API，当前包含 \(modelIds.count) 个可用模型",
                        latencyMs: latency,
                        modelsFound: modelIds,
                        testedAt: Date()
                    )
                } else {
                    return APIKeyValidationResult(
                        status: .valid,
                        message: "✅ Key 有效且连接成功，但回包格式为非标准模型列表",
                        latencyMs: latency,
                        modelsFound: [],
                        testedAt: Date()
                    )
                }
                
            case 401:
                return APIKeyValidationResult(
                    status: .invalid,
                    message: "❌ 鉴权失败 (401 Unauthorized)：API Key 错误或未生效，请核对密钥",
                    latencyMs: latency,
                    modelsFound: [],
                    testedAt: Date()
                )
                
            case 402, 429:
                return APIKeyValidationResult(
                    status: .rateLimited,
                    message: "⚠️ 账户受限 (\(httpResponse.statusCode))：账户余额不足或触发 API 频次流控限制",
                    latencyMs: latency,
                    modelsFound: [],
                    testedAt: Date()
                )
                
            default:
                let errorBody = String(data: data, encoding: .utf8) ?? "无详细错误"
                return APIKeyValidationResult(
                    status: .networkError,
                    message: "服务返回状态码 \(httpResponse.statusCode): \(errorBody)",
                    latencyMs: latency,
                    modelsFound: [],
                    testedAt: Date()
                )
            }
        } catch {
            let latency = Int((CFAbsoluteTimeGetCurrent() - startTime) * 1000)
            return APIKeyValidationResult(
                status: .networkError,
                message: "连接超时或网络异常: \(error.localizedDescription)",
                latencyMs: latency,
                modelsFound: [],
                testedAt: Date()
            )
        }
    }
}
