import Foundation
import Combine

/// 全局快捷键模式配置
public enum HotkeyMode: String, CaseIterable, Identifiable, Hashable {
    case commandCC = "commandCC" // 按住 Command 连按两次 C
    case both = "both" // Command+C+C、Option+Z 或 Control+Z
    case optionZ = "optionZ" // 仅 Option+Z (⌥Z / Alt+Z)
    case controlZ = "controlZ" // 仅 Control+Z (⌃Z)
    
    public var id: String { rawValue }

    /// ⌘C⌘C 通过全局键盘事件识别，需要 macOS 辅助功能权限。
    public var usesCommandDoubleTap: Bool {
        self == .commandCC || self == .both
    }

    /// Carbon 热键无需辅助功能授权，可继续作为备用方案。
    public var usesCarbonHotkey: Bool {
        self != .commandCC
    }
    
    public var displayName: String {
        switch self {
        case .commandCC:
            return "Command+C+C（严格按下 Command 并连按两次 C，推荐）"
        case .both:
            return "Command+C+C、Option+Z 或 Control+Z（全部启用）"
        case .optionZ:
            return "Option+Z (⌥Z / Alt+Z)"
        case .controlZ:
            return "Control+Z (⌃Z)"
        }
    }
}

/// TransBar 的外观选择。系统模式跟随 macOS，明亮和深色模式对应 Quiet Native 与 Ink Signal。
public enum TransBarAppearanceMode: String, CaseIterable, Identifiable, Codable, Hashable {
    case system
    case light
    case dark

    public var id: String { rawValue }

    public var displayName: String {
        switch self {
        case .system: return "跟随系统"
        case .light: return "明亮模式"
        case .dark: return "深色模式"
        }
    }

    public var icon: String {
        switch self {
        case .system: return "circle.lefthalf.filled"
        case .light: return "sun.max.fill"
        case .dark: return "moon.fill"
        }
    }
}

/// 用户配置与持久化偏好管理器
public final class AppSettings: ObservableObject {
    public static let shared = AppSettings()
    
    private let defaults: UserDefaults
    private let apiKeyStore: APIKeyStore
    private var isRevertingAPIKey = false
    
    // 键值定义
    private enum Keys {
        static let deepSeekApiKey = "cduyzh_deepseek_api_key"
        static let customApiBaseUrl = "cduyzh_custom_api_base_url"
        static let selectedModel = "cduyzh_selected_model"
        static let availableModels = "cduyzh_available_models"
        static let reasoningEffort = "cduyzh_reasoning_effort"
        static let selectedEngine = "cduyzh_selected_engine"
        static let appearanceMode = "cduyzh_appearance_mode"
        static let lastSourceLanguage = "cduyzh_last_source_lang"
        static let lastTargetLanguage = "cduyzh_last_target_lang"
        static let hotkeyEnabled = "cduyzh_hotkey_enabled"
        static let hotkeyMode = "cduyzh_hotkey_mode"
        static let selectionTranslationEnabled = "cduyzh_selection_translation_enabled"
        static let translationPromptTemplate = "cduyzh_translation_prompt_template"
        static let translationInstructions = "cduyzh_translation_instructions"
        static let agentContextEnabled = "cduyzh_agent_context_enabled"
        static let agentContextMaxTurns = "cduyzh_agent_context_max_turns"
        static let agentContextMaxCharacters = "cduyzh_agent_context_max_characters"
        static let agentContextRetentionDays = "cduyzh_agent_context_retention_days"
        static let knowledgeBaseEnabled = "cduyzh_knowledge_base_enabled"
        static let knowledgeBaseMaxTerms = "cduyzh_knowledge_base_max_terms"
        static let knowledgeBaseMaxCharacters = "cduyzh_knowledge_base_max_characters"
        static let agentServerEnabled = "cduyzh_agent_server_enabled"
        static let windowPinned = "cduyzh_window_pinned"
        static let autoCleanupEnabled = "cduyzh_auto_cleanup_enabled"
        static let retentionDays = "cduyzh_retention_days"
        static let maxStorageLimitMB = "cduyzh_max_storage_limit_mb"
        static let soundFeedbackEnabled = "cduyzh_sound_feedback_enabled"
        static let lastAutoCleanupDate = "cduyzh_last_auto_cleanup_date"
        static let autoCheckUpdateEnabled = "cduyzh_auto_check_update_enabled"
        static let lastUpdateCheckDate = "cduyzh_last_update_check_date"
        static let hasNewUpdateAvailable = "cduyzh_has_new_update_available"
        static let latestAvailableVersion = "cduyzh_latest_available_version"
        static let lastApiHealthStatus = "cduyzh_last_api_health_status"
    }

    // MARK: - API Key 连通性测试持久化状态
    public struct ApiHealthStatus: Codable, Equatable {
        public var isValid: Bool
        public var message: String
        public var latencyMs: Int
        public var modelsCount: Int
        public var testedKey: String
        public var testedBaseUrl: String
        public var testedAt: Date

        public init(isValid: Bool, message: String, latencyMs: Int, modelsCount: Int, testedKey: String, testedBaseUrl: String, testedAt: Date = Date()) {
            self.isValid = isValid
            self.message = message
            self.latencyMs = latencyMs
            self.modelsCount = modelsCount
            self.testedKey = testedKey
            self.testedBaseUrl = testedBaseUrl
            self.testedAt = testedAt
        }
    }

    @Published public var lastApiHealth: ApiHealthStatus? {
        didSet {
            if let status = lastApiHealth,
               let data = try? JSONEncoder().encode(status) {
                defaults.set(data, forKey: Keys.lastApiHealthStatus)
            } else {
                defaults.removeObject(forKey: Keys.lastApiHealthStatus)
            }
        }
    }
    
    // API Key 仅保存在本机权限受限文件；不访问钥匙串或发行包。
    @Published public var deepSeekApiKey: String {
        didSet {
            // @Published 的赋值会重新进入 didSet；回滚时不能再次尝试写入。
            guard !isRevertingAPIKey else { return }
            do {
                try apiKeyStore.save(deepSeekApiKey)
                defaults.removeObject(forKey: Keys.deepSeekApiKey)
                apiKeyStorageError = nil
            } catch {
                isRevertingAPIKey = true
                defer { isRevertingAPIKey = false }
                deepSeekApiKey = oldValue
                apiKeyStorageError = "无法将 API Key 保存到本机安全文件：\(error.localizedDescription)"
            }
        }
    }

    @Published public private(set) var apiKeyStorageError: String?

    
    // 自定义 Base URL (默认官方 https://api.deepseek.com)
    @Published public var customApiBaseUrl: String {
        didSet { defaults.set(customApiBaseUrl, forKey: Keys.customApiBaseUrl) }
    }
    
    // 当前选中的模型
    @Published public var selectedModel: String {
        didSet { defaults.set(selectedModel, forKey: Keys.selectedModel) }
    }
    
    // 本地缓存的可用模型列表
    @Published public var availableModels: [String] {
        didSet { defaults.set(availableModels, forKey: Keys.availableModels) }
    }
    
    // 思考程度
    @Published public var reasoningEffort: ReasoningEffortLevel {
        didSet { defaults.set(reasoningEffort.rawValue, forKey: Keys.reasoningEffort) }
    }
    
    // 当前默认选中的翻译引擎
    @Published public var selectedEngine: TranslationEngineType {
        didSet { defaults.set(selectedEngine.rawValue, forKey: Keys.selectedEngine) }
    }

    /// 主面板与设置页的外观选择。
    @Published public var appearanceMode: TransBarAppearanceMode {
        didSet { defaults.set(appearanceMode.rawValue, forKey: Keys.appearanceMode) }
    }
    
    // 用户最后一次设置的源语言
    @Published public var lastSourceLanguage: String {
        didSet { defaults.set(lastSourceLanguage, forKey: Keys.lastSourceLanguage) }
    }
    
    // 用户最后一次设置的目标语言（默认中文）
    @Published public var lastTargetLanguage: String {
        didSet { defaults.set(lastTargetLanguage, forKey: Keys.lastTargetLanguage) }
    }
    
    // 是否启用全局快捷键
    @Published public var hotkeyEnabled: Bool {
        didSet { defaults.set(hotkeyEnabled, forKey: Keys.hotkeyEnabled) }
    }
    
    // 全局快捷键模式 (默认 ⌘C⌘C；原有 Z 组合仍可在设置中启用)
    @Published public var hotkeyMode: HotkeyMode {
        didSet { defaults.set(hotkeyMode.rawValue, forKey: Keys.hotkeyMode) }
    }

    /// 选中文字后只展示按钮，点击后才发起翻译。
    @Published public var selectionTranslationEnabled: Bool {
        didSet { defaults.set(selectionTranslationEnabled, forKey: Keys.selectionTranslationEnabled) }
    }

    /// 每次 AI 翻译的用户要求；与文本、术语记忆一起快照进请求。
    @Published public var translationInstructions: String {
        didSet { defaults.set(translationInstructions, forKey: Keys.translationInstructions) }
    }

    /// 可编辑的通用翻译规则；源语言和目标语言在请求时动态注入。
    @Published public var translationPromptTemplate: String {
        didSet { defaults.set(translationPromptTemplate, forKey: Keys.translationPromptTemplate) }
    }

    /// Agent 只有在启用且请求带有相同 session_id 时才会使用短期上下文。
    @Published public var agentContextEnabled: Bool {
        didSet { defaults.set(agentContextEnabled, forKey: Keys.agentContextEnabled) }
    }

    @Published public var agentContextMaxTurns: Int {
        didSet { defaults.set(agentContextMaxTurns, forKey: Keys.agentContextMaxTurns) }
    }

    @Published public var agentContextMaxCharacters: Int {
        didSet { defaults.set(agentContextMaxCharacters, forKey: Keys.agentContextMaxCharacters) }
    }

    @Published public var agentContextRetentionDays: Int {
        didSet { defaults.set(agentContextRetentionDays, forKey: Keys.agentContextRetentionDays) }
    }

    /// 是否向 AI Agent 注入行业专业知识库（仅限配置 API Key 的 AI Agent）
    @Published public var knowledgeBaseEnabled: Bool {
        didSet { defaults.set(knowledgeBaseEnabled, forKey: Keys.knowledgeBaseEnabled) }
    }

    /// 单次 AI 翻译最大注入专业词条数上限（防 Token 膨胀）
    @Published public var knowledgeBaseMaxTerms: Int {
        didSet { defaults.set(knowledgeBaseMaxTerms, forKey: Keys.knowledgeBaseMaxTerms) }
    }

    /// 单次 AI 翻译最大注入字符数配额
    @Published public var knowledgeBaseMaxCharacters: Int {
        didSet { defaults.set(knowledgeBaseMaxCharacters, forKey: Keys.knowledgeBaseMaxCharacters) }
    }
    
    // 是否启用本地 Agent Gateway 端口 (11899)
    @Published public var agentServerEnabled: Bool {
        didSet { defaults.set(agentServerEnabled, forKey: Keys.agentServerEnabled) }
    }
    
    // 是否固定窗口 (Pin)
    @Published public var windowPinned: Bool {
        didSet { defaults.set(windowPinned, forKey: Keys.windowPinned) }
    }
    
    // 是否启用自动释放空间
    @Published public var autoCleanupEnabled: Bool {
        didSet { defaults.set(autoCleanupEnabled, forKey: Keys.autoCleanupEnabled) }
    }
    
    // 记录保留天数 (0 代表永久)
    @Published public var retentionDays: Int {
        didSet { defaults.set(retentionDays, forKey: Keys.retentionDays) }
    }
    
    // 缓存占用上限 MB (0 代表不限)
    @Published public var maxStorageLimitMB: Int {
        didSet { defaults.set(maxStorageLimitMB, forKey: Keys.maxStorageLimitMB) }
    }
    
    // 是否启用操作音效反馈
    @Published public var soundFeedbackEnabled: Bool {
        didSet { defaults.set(soundFeedbackEnabled, forKey: Keys.soundFeedbackEnabled) }
    }
    
    // 上次自动清理日期
    public var lastAutoCleanupDate: Date? {
        get { defaults.object(forKey: Keys.lastAutoCleanupDate) as? Date }
        set { defaults.set(newValue, forKey: Keys.lastAutoCleanupDate) }
    }
    
    // 是否启用自动检查更新
    @Published public var autoCheckUpdateEnabled: Bool {
        didSet { defaults.set(autoCheckUpdateEnabled, forKey: Keys.autoCheckUpdateEnabled) }
    }
    
    // 上次检查更新日期
    public var lastUpdateCheckDate: Date? {
        get { defaults.object(forKey: Keys.lastUpdateCheckDate) as? Date }
        set { defaults.set(newValue, forKey: Keys.lastUpdateCheckDate) }
    }
    
    // 是否发现新版本可用
    @Published public var hasNewUpdateAvailable: Bool {
        didSet { defaults.set(hasNewUpdateAvailable, forKey: Keys.hasNewUpdateAvailable) }
    }
    
    // 检测到的最新可用版本号
    @Published public var latestAvailableVersion: String? {
        didSet { defaults.set(latestAvailableVersion, forKey: Keys.latestAvailableVersion) }
    }
    
    private static func normalizedChoice(_ value: Int?, choices: [Int], fallback: Int) -> Int {
        guard let value, choices.contains(value) else { return fallback }
        return value
    }

    init(defaults: UserDefaults = .standard, credentialStore: APIKeyStore = LocalAPIKeyStore()) {
        self.defaults = defaults
        self.apiKeyStore = credentialStore
        do {
            self.deepSeekApiKey = try APIKeyMigration.load(
                defaults: defaults, legacyKey: Keys.deepSeekApiKey, store: credentialStore
            )
            self.apiKeyStorageError = nil
        } catch {
            // 保留迁移失败时的旧配置，避免钥匙文件暂时不可写导致用户丢失 Key。
            self.deepSeekApiKey = defaults.string(forKey: Keys.deepSeekApiKey) ?? ""
            self.apiKeyStorageError = "无法读取或迁移本机安全文件：\(error.localizedDescription)"
        }
        defaults.removeObject(forKey: "cduyzh_temperature")
        defaults.removeObject(forKey: "cduyzh_auto_translate_clipboard")

        let savedUrl = defaults.string(forKey: Keys.customApiBaseUrl)
        self.customApiBaseUrl = (savedUrl != nil && !savedUrl!.isEmpty) ? savedUrl! : "https://api.deepseek.com"
        
        self.selectedModel = defaults.string(forKey: Keys.selectedModel) ?? "deepseek-flash"
        
        let savedModels = defaults.stringArray(forKey: Keys.availableModels)
        self.availableModels = (savedModels != nil && !savedModels!.isEmpty) ? savedModels! : ["deepseek-flash", "deepseek-v4-pro"]
        
        if let effortRaw = defaults.string(forKey: Keys.reasoningEffort), ["off", "low"].contains(effortRaw),
           let effort = ReasoningEffortLevel(rawValue: effortRaw) {
            self.reasoningEffort = effort
        } else {
            self.reasoningEffort = .off
        }
        
        let savedEngine = defaults.string(forKey: Keys.selectedEngine)
        let engine: TranslationEngineType
        if savedEngine == "mymemory" {
            // The retired free fallback is replaced by Google to keep the selection key-free.
            engine = .google
            defaults.set(engine.rawValue, forKey: Keys.selectedEngine)
        } else if let savedEngine, savedEngine != "smart",
                  let savedEngineType = TranslationEngineType(rawValue: savedEngine) {
            engine = savedEngineType
        } else {
            engine = .deepseek
        }
        self.selectedEngine = engine

        if let appearanceRaw = defaults.string(forKey: Keys.appearanceMode),
           let appearance = TransBarAppearanceMode(rawValue: appearanceRaw) {
            self.appearanceMode = appearance
        } else {
            self.appearanceMode = .system
        }
        
        self.lastSourceLanguage = defaults.string(forKey: Keys.lastSourceLanguage) ?? "auto"
        self.lastTargetLanguage = defaults.string(forKey: Keys.lastTargetLanguage) ?? "zh-CN"
        
        self.hotkeyEnabled = defaults.object(forKey: Keys.hotkeyEnabled) != nil ? defaults.bool(forKey: Keys.hotkeyEnabled) : true
        if let modeRaw = defaults.string(forKey: Keys.hotkeyMode), let mode = HotkeyMode(rawValue: modeRaw) {
            self.hotkeyMode = mode
        } else {
            self.hotkeyMode = .commandCC
        }
        self.agentServerEnabled = defaults.object(forKey: Keys.agentServerEnabled) != nil ? defaults.bool(forKey: Keys.agentServerEnabled) : true
        self.selectionTranslationEnabled = defaults.object(forKey: Keys.selectionTranslationEnabled) != nil ? defaults.bool(forKey: Keys.selectionTranslationEnabled) : true
        self.translationInstructions = defaults.string(forKey: Keys.translationInstructions) ?? ""
        self.translationPromptTemplate = defaults.string(forKey: Keys.translationPromptTemplate) ?? TranslationPromptDefaults.standard
        self.agentContextEnabled = defaults.bool(forKey: Keys.agentContextEnabled)
        self.agentContextMaxTurns = Self.normalizedChoice(defaults.object(forKey: Keys.agentContextMaxTurns) as? Int, choices: [2, 4, 6, 8], fallback: 4)
        self.agentContextMaxCharacters = Self.normalizedChoice(defaults.object(forKey: Keys.agentContextMaxCharacters) as? Int, choices: [2_000, 4_000, 6_000, 8_000], fallback: 4_000)
        self.agentContextRetentionDays = Self.normalizedChoice(defaults.object(forKey: Keys.agentContextRetentionDays) as? Int, choices: [1, 3, 7, 30], fallback: 1)
        self.knowledgeBaseEnabled = defaults.object(forKey: Keys.knowledgeBaseEnabled) != nil ? defaults.bool(forKey: Keys.knowledgeBaseEnabled) : true
        self.knowledgeBaseMaxTerms = Self.normalizedChoice(defaults.object(forKey: Keys.knowledgeBaseMaxTerms) as? Int, choices: [5, 10, 15, 20], fallback: 10)
        self.knowledgeBaseMaxCharacters = Self.normalizedChoice(defaults.object(forKey: Keys.knowledgeBaseMaxCharacters) as? Int, choices: [400, 800, 1200, 1600], fallback: 800)
        self.windowPinned = defaults.bool(forKey: Keys.windowPinned)
        
        self.autoCleanupEnabled = defaults.object(forKey: Keys.autoCleanupEnabled) != nil ? defaults.bool(forKey: Keys.autoCleanupEnabled) : true
        self.retentionDays = defaults.object(forKey: Keys.retentionDays) != nil ? defaults.integer(forKey: Keys.retentionDays) : 30
        self.maxStorageLimitMB = defaults.object(forKey: Keys.maxStorageLimitMB) != nil ? defaults.integer(forKey: Keys.maxStorageLimitMB) : 50
        self.soundFeedbackEnabled = defaults.object(forKey: Keys.soundFeedbackEnabled) != nil ? defaults.bool(forKey: Keys.soundFeedbackEnabled) : true
        
        self.autoCheckUpdateEnabled = defaults.object(forKey: Keys.autoCheckUpdateEnabled) != nil ? defaults.bool(forKey: Keys.autoCheckUpdateEnabled) : true
        self.hasNewUpdateAvailable = defaults.bool(forKey: Keys.hasNewUpdateAvailable)
        self.latestAvailableVersion = defaults.string(forKey: Keys.latestAvailableVersion)

        if let data = defaults.data(forKey: Keys.lastApiHealthStatus),
           let status = try? JSONDecoder().decode(ApiHealthStatus.self, from: data) {
            self.lastApiHealth = status
        }
    }
}
