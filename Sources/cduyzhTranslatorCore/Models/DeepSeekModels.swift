import Foundation

/// DeepSeek 模型列表响应
public struct DeepSeekModelListResponse: Codable {
    public let object: String?
    public let data: [DeepSeekModelInfo]
}

/// DeepSeek 单个模型信息
public struct DeepSeekModelInfo: Identifiable, Codable, Hashable {
    public var id: String
    public let name: String?
    public let contextWindow: Int?
    public let maxOutputTokens: Int?
    public let effort: DeepSeekEffortConfig?
    
    enum CodingKeys: String, CodingKey {
        case id
        case name
        case contextWindow = "context_window"
        case maxOutputTokens = "max_output_tokens"
        case effort
    }
}

/// 模型思考程度配置
public struct DeepSeekEffortConfig: Codable, Hashable {
    public let supportedLevels: [String]?
    public let defaultLevel: String?
    
    enum CodingKeys: String, CodingKey {
        case supportedLevels = "supported_levels"
        case defaultLevel = "default_level"
    }
}

/// 思考程度枚举
public enum ReasoningEffortLevel: String, CaseIterable, Identifiable, Codable, Hashable, Sendable {
    case off = "off"
    case low = "low"
    
    public var id: String { rawValue }
    
    public var displayName: String {
        switch self {
        case .off:
            return "关闭思考 (快速)"
        case .low:
            return "轻度思考 (Low)"
        }
    }
}

/// DeepSeek Chat 补全请求
public struct DeepSeekChatRequest: Codable {
    public let model: String
    public let messages: [DeepSeekMessage]
    public let reasoningEffort: String?
    public let thinking: DeepSeekThinkingConfig
    public let stream: Bool
    
    enum CodingKeys: String, CodingKey {
        case model
        case messages
        case reasoningEffort = "reasoning_effort"
        case thinking
        case stream
    }
}

public struct DeepSeekThinkingConfig: Codable {
    public let type: String
}

public struct DeepSeekMessage: Codable {
    public let role: String
    public let content: String
    
    public init(role: String, content: String) {
        self.role = role
        self.content = content
    }
}

/// DeepSeek Chat 补全非流式响应
public struct DeepSeekChatResponse: Codable {
    public let id: String?
    public let choices: [DeepSeekChoice]?
    public let usage: DeepSeekUsage?
}

public struct DeepSeekChoice: Codable {
    public let message: DeepSeekResponseMessage?
    public let finishReason: String?

    enum CodingKeys: String, CodingKey {
        case message
        case finishReason = "finish_reason"
    }
}

public struct DeepSeekResponseMessage: Codable {
    public let role: String?
    public let content: String?
    public let reasoningContent: String?
    
    enum CodingKeys: String, CodingKey {
        case role
        case content
        case reasoningContent = "reasoning_content"
    }
}

public struct DeepSeekUsage: Codable {
    public let promptTokens: Int?
    public let completionTokens: Int?
    public let totalTokens: Int?
    public let completionTokensDetails: DeepSeekCompletionDetails?
    
    enum CodingKeys: String, CodingKey {
        case promptTokens = "prompt_tokens"
        case completionTokens = "completion_tokens"
        case totalTokens = "total_tokens"
        case completionTokensDetails = "completion_tokens_details"
    }
}

public struct DeepSeekCompletionDetails: Codable {
    public let reasoningTokens: Int?
    
    enum CodingKeys: String, CodingKey {
        case reasoningTokens = "reasoning_tokens"
    }
}

/// 流式 SSE 块响应
public struct DeepSeekStreamChunk: Codable {
    public let id: String?
    public let choices: [DeepSeekStreamChoice]?
    public let usage: DeepSeekUsage?
}

public struct DeepSeekStreamChoice: Codable {
    public let delta: DeepSeekStreamDelta?
    public let finishReason: String?
    
    enum CodingKeys: String, CodingKey {
        case delta
        case finishReason = "finish_reason"
    }
}

public struct DeepSeekStreamDelta: Codable {
    public let role: String?
    public let content: String?
    public let reasoningContent: String?
    
    enum CodingKeys: String, CodingKey {
        case role
        case content
        case reasoningContent = "reasoning_content"
    }
}
