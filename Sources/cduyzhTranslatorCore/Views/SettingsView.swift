import SwiftUI

/// 应用设置。分组展示连接、个人翻译偏好与数据管理。
public struct SettingsView: View {
    @Environment(\.accessibilityReduceMotion) private var reduceMotion
    @Environment(\.colorScheme) private var colorScheme
    @ObservedObject var settings = AppSettings.shared
    @ObservedObject var hotkeyManager = GlobalHotkeyManager.shared
    @ObservedObject var agentServer = AgentGatewayServer.shared
    @ObservedObject var cacheManager = CacheStorageManager.shared
    @ObservedObject var updateChecker = AppUpdateChecker.shared

    @State private var selectedTab = 0
    @State private var isTestingKey = false
    @State private var keyValidationResult: APIKeyValidationResult?
    @State private var isKeyVisible = false
    @State private var apiKeyDraft = AppSettings.shared.deepSeekApiKey
    @State private var apiKeySaved = false
    @State private var isUpdatingModels = false
    @State private var updateModelStatus: String?
    @State private var updateModelFailed = false
    @State private var isCleaningCache = false
    @State private var activeCleanup: CleanupAction?
    @State private var pendingCleanup: CleanupAction?
    @State private var cleanupToast: String?
    @State private var promptTemplateDraft = AppSettings.shared.translationPromptTemplate
    @State private var instructionsDraft = AppSettings.shared.translationInstructions
    @State private var instructionsFeedback: String?
    @State private var promptFeedback: String?
    @State private var contextFeedback: String?

    private let timeFormatter: DateFormatter = {
        let df = DateFormatter()
        df.dateFormat = "HH:mm:ss"
        return df
    }()
    @State private var clipboardFeedback: String?
    @State private var clipboardFeedbackID = UUID()
    @State private var isSharedPromptPreviewExpanded = false
    @State private var isAgentPromptPreviewExpanded = false
    @FocusState private var focusedField: FocusedField?

    private enum FocusedField: Hashable {
        case apiBaseURL
        case apiKey
        case promptTemplate
        case instructions
    }

    private let tabs: [(title: String, icon: String, subtitle: String)] = [
        ("模型与 API", "key", "连接服务并调整翻译模型。"),
        ("存储空间", "internaldrive", "管理本地记录与自动清理策略。"),
        ("快捷键与交互", "keyboard", "让翻译更贴合你的工作习惯。"),
        ("翻译历史记录", "clock.arrow.circlepath", "查看与管理本地翻译历史，支持无上限解锁。"),
        ("行业知识库", "books.vertical", "管理专业词库，按需精准注入 AI 上下文。"),
        ("调用统计", "chart.bar", "了解翻译用量与响应表现。"),
        ("Agent 对接", "network", "通过本地接口连接其他工具。"),
        ("版本与更新", "arrow.triangle.2.circlepath.circle", "检查应用更新与发版演进历史。")
    ]

    private enum CleanupAction: String, Identifiable {
        case followPolicy, resetAll
        var id: String { rawValue }

        var title: String {
            switch self {
            case .followPolicy: return "清理临时缓存？"
            case .resetAll: return "清空缓存与统计？"
            }
        }

        var message: String {
            switch self {
            case .followPolicy:
                return "将清理临时网络缓存。个人翻译记忆、前置翻译说明与调用统计会保留。"
            case .resetAll:
                return "将删除调用统计与临时缓存。个人翻译记忆、前置翻译说明、API 与偏好设置会保留。"
            }
        }

        var buttonTitle: String {
            switch self {
            case .followPolicy: return "清理缓存"
            case .resetAll: return "清空缓存与统计"
            }
        }
    }

    public init() {}

    public var body: some View {
        HStack(spacing: 0) {
            sidebar
            Divider()
            VStack(spacing: 0) {
                HStack(alignment: .top, spacing: 18) {
                    VStack(alignment: .leading, spacing: 5) {
                        Text("TRANSLATION SERVICE")
                            .font(.system(size: 10, weight: .medium, design: .rounded))
                            .tracking(1.5)
                            .foregroundStyle(TransBarInspectorDesign.secondaryText(for: colorScheme))
                        Text(tabs[selectedTab].title)
                            .font(.system(size: 28, weight: .bold))
                        Text(tabs[selectedTab].subtitle)
                            .font(.system(size: 13))
                            .foregroundStyle(TransBarInspectorDesign.secondaryText(for: colorScheme))
                    }
                    Spacer(minLength: 12)
                    Button(action: closeSettings) {
                        Image(systemName: "xmark")
                            .font(.system(size: 11, weight: .semibold))
                            .foregroundStyle(.secondary)
                            .frame(width: 16, height: 16)
                    }
                    .buttonStyle(TransBarInspectorButtonStyle(variant: .ghost, size: .mini))
                    .accessibilityLabel("关闭设置")
                    .help("完成并返回翻译面板（Esc）")
                }
                .padding(.horizontal, 30)
                .padding(.vertical, 24)

                Divider()

                Group {
                    switch selectedTab {
                    case 0: modelAndKeyTab
                    case 1: storageAndCacheTab
                    case 2: hotkeySettingsTab
                    case 3: TranslationHistorySettingsView()
                    case 4: DomainKnowledgeBaseSettingsView()
                    case 5: StatisticsView()
                    case 6: agentIntegrationTab
                    case 7: VersionUpdateView()
                    default: EmptyView()
                    }
                }
                .frame(maxWidth: .infinity, maxHeight: .infinity)

                Divider()
                HStack {
                    Text("偏好自动保存 · 文本离开时保存")
                        .font(.system(size: 11))
                        .foregroundStyle(.secondary)

                    Spacer()
                    Button("完成", action: closeSettings)
                        .buttonStyle(TransBarInspectorButtonStyle(variant: .primary))
                        .help("保存设置并返回翻译面板")
                }
                .padding(.horizontal, 30)
                .padding(.vertical, 16)
            }
        .background(TransBarInspectorDesign.canvasGradient(for: colorScheme))
        }
        .font(.system(size: 13))
        .frame(width: 1040, height: 760)
        .preferredColorScheme(settings.appearanceMode.colorScheme)
        .onAppear {
            cacheManager.refreshUsage()
            hotkeyManager.checkPermission(prompt: false)
        }
        .onDisappear {
            saveAPIKeyDraft()
            savePromptTemplateDraft()
            saveInstructionsDraft()
            isKeyVisible = false
            focusedField = nil
        }
        .onExitCommand(perform: closeSettings)
        .onChange(of: selectedTab) { _ in
            saveAPIKeyDraft()
            savePromptTemplateDraft()
            saveInstructionsDraft()
            isKeyVisible = false
            focusedField = nil
            cleanupToast = nil
        }
        .onChange(of: settings.deepSeekApiKey) { key in
            apiKeyDraft = key
            keyValidationResult = nil
        }
        .onChange(of: apiKeyDraft) { _ in
            keyValidationResult = nil
            updateModelStatus = nil
            if apiKeyHasUnsavedChanges { apiKeySaved = false }
        }
        .onChange(of: settings.translationInstructions) { instructions in
            instructionsDraft = instructions
        }
        .onChange(of: settings.translationPromptTemplate) { prompt in
            promptTemplateDraft = prompt
        }
        .onChange(of: instructionsDraft) { _ in
            if instructionsDraft != settings.translationInstructions { instructionsFeedback = nil }
        }
        .onChange(of: promptTemplateDraft) { _ in
            if promptTemplateDraft != settings.translationPromptTemplate { promptFeedback = nil }
        }
        .onChange(of: settings.customApiBaseUrl) { _ in
            keyValidationResult = nil
            updateModelStatus = nil
        }
        .onReceive(NotificationCenter.default.publisher(for: NSNotification.Name("SwitchSettingsTabNotification"))) { notification in
            if let tab = notification.object as? Int, tabs.indices.contains(tab) {
                selectedTab = tab
            }
        }
        .alert(item: $pendingCleanup) { action in
            Alert(
                title: Text(action.title),
                message: Text(action.message),
                primaryButton: .destructive(Text(action.buttonTitle)) { performCleanup(action) },
                secondaryButton: .cancel(Text("取消"))
            )
        }
    }

    private var sidebar: some View {
        VStack(alignment: .leading, spacing: 6) {
            productBrandHeader
            .padding(.horizontal, 16)
            .padding(.top, 26)
            .padding(.bottom, 24)

            Text("设置")
                .font(.system(size: 11, weight: .medium, design: .rounded))
                .tracking(0.8)
                .foregroundStyle(TransBarInspectorDesign.secondaryText(for: colorScheme).opacity(0.76))
                .padding(.horizontal, 16)
                .padding(.bottom, 8)

            ForEach(tabs.indices, id: \.self) { index in
                Button {
                    selectedTab = index
                } label: {
                    HStack(spacing: 9) {
                        Image(systemName: tabs[index].icon)
                            .font(.system(size: 13, weight: .medium))
                            .frame(width: 20)
                            .foregroundStyle(selectedTab == index ? TransBarInspectorDesign.accent(for: colorScheme) : TransBarInspectorDesign.secondaryText(for: colorScheme).opacity(0.75))
                        Text(tabs[index].title)
                            .font(.system(size: 13, weight: selectedTab == index ? .semibold : .regular))
                        Spacer(minLength: 0)
                        if index == 6 && updateChecker.hasUpdate {
                            Circle()
                                .fill(Color.orange)
                                .frame(width: 6, height: 6)
                        }
                    }
                    .foregroundStyle(.primary)
                    .padding(.horizontal, 13)
                    .padding(.vertical, 11)
                    .contentShape(RoundedRectangle(cornerRadius: 8))
                }
                .buttonStyle(SettingsNavigationButtonStyle(isSelected: selectedTab == index))
                .accessibilityValue(selectedTab == index ? "已选中" : "")
                .help(tabs[index].subtitle)
            }
            Spacer()
            VStack(alignment: .leading, spacing: 3) {
                Text("译栏")
                    .font(.system(size: 11, weight: .medium))
                Text("本机设置")
                    .font(.system(size: 10))
                    .foregroundStyle(TransBarInspectorDesign.secondaryText(for: colorScheme).opacity(0.7))
            }
            .foregroundStyle(TransBarInspectorDesign.secondaryText(for: colorScheme).opacity(0.86))
            .padding(16)
        }
        .padding(.horizontal, 8)
        .frame(width: 190)
        .background(TransBarInspectorDesign.sidebarGradient(for: colorScheme))
    }

    private var productBrandHeader: some View {
        HStack(spacing: 11) {
            Group {
                if let iconPath = Bundle.main.path(forResource: "AppIcon_1024", ofType: "png"),
                   let icon = NSImage(contentsOfFile: iconPath) {
                    Image(nsImage: icon)
                        .resizable()
                        .scaledToFit()
                } else {
                    Image(systemName: "character.bubble.fill")
                        .resizable()
                        .scaledToFit()
                        .foregroundStyle(TransBarInspectorDesign.accent(for: colorScheme))
                        .padding(9)
                        .background(TransBarInspectorDesign.accent(for: colorScheme).opacity(0.12))
                }
            }
            .frame(width: 44, height: 44)
            .clipShape(RoundedRectangle(cornerRadius: 11, style: .continuous))
            .accessibilityHidden(true)

            Text("译栏")
                .font(.system(size: 17, weight: .semibold))
                .foregroundStyle(colorScheme == .dark ? Color.white.opacity(0.96) : Color(red: 0.12, green: 0.22, blue: 0.34))
        }
        .accessibilityElement(children: .combine)
        .accessibilityLabel("译栏")
    }

    // MARK: - 模型与 API

    private var modelAndKeyTab: some View {
        ScrollView(.vertical) {
            VStack(alignment: .leading, spacing: 18) {
                settingsSection("界面外观") {
                    HStack(alignment: .center, spacing: 12) {
                        Spacer(minLength: 12)
                        TransBarOptionMenu(
                            title: "界面主题",
                            selection: $settings.appearanceMode,
                            options: TransBarAppearanceMode.allCases.map { ($0, $0.displayName) }
                        )
                        .frame(width: 300)
                    }
                    caption("跟随系统会随 macOS 外观变化；明亮模式使用 Quiet Native，深色模式使用 Ink Signal。")
                }

                settingsSection("服务连接") {
                    caption("API 地址和密钥只保存在本机；保存后才会启用连接测试。")
                    VStack(alignment: .leading, spacing: 7) {
                        HStack {
                            Text("API Base URL").fontWeight(.medium)
                            Spacer()
                            if settings.customApiBaseUrl != "https://api.deepseek.com" {
                                Button("恢复默认") { settings.customApiBaseUrl = "https://api.deepseek.com" }
                                    .buttonStyle(TransBarInspectorButtonStyle(variant: .ghost, size: .mini))
                                    .font(.system(size: 11))
                            }
                        }
                        TextField("https://api.deepseek.com", text: $settings.customApiBaseUrl)
                            .textFieldStyle(TransBarTextFieldStyle(isFocused: focusedField == .apiBaseURL))
                            .font(.system(size: 12, design: .monospaced))
                            .focused($focusedField, equals: .apiBaseURL)
                            .accessibilityLabel("API 服务地址")
                        caption("默认使用 DeepSeek 官方接口，也支持兼容的服务端点。")
                    }
                    Divider()
                    VStack(alignment: .leading, spacing: 8) {
                        HStack {
                            Text("API Key").fontWeight(.medium)
                            Spacer()
                            Text("安全输入")
                                .font(.system(size: 11, weight: .medium))
                                .foregroundStyle(TransBarInspectorDesign.secondaryText(for: colorScheme))
                        }
                        HStack(spacing: 10) {
                            Group {
                                if isKeyVisible {
                                    TextField("输入 API Key", text: $apiKeyDraft)
                                        .focused($focusedField, equals: .apiKey)
                                } else {
                                    SecureField("输入 API Key", text: $apiKeyDraft)
                                        .focused($focusedField, equals: .apiKey)
                                }
                            }
                            .textFieldStyle(TransBarTextFieldStyle(isFocused: focusedField == .apiKey))
                            .font(.system(size: 12, design: .monospaced))
                            .privacySensitive()
                            .accessibilityLabel("API Key")
                            .onSubmit { saveAPIKeyDraft() }
                            Button { isKeyVisible.toggle() } label: {
                                Label(isKeyVisible ? "隐藏" : "显示", systemImage: isKeyVisible ? "eye.slash" : "eye")
                            }
                            .buttonStyle(TransBarInspectorButtonStyle(variant: .outline, size: .small))
                            .accessibilityLabel(isKeyVisible ? "隐藏 API Key" : "显示 API Key")
                        }
                        HStack(alignment: .center, spacing: 8) {
                            Button(action: testKeyAvailability) {
                                HStack(spacing: 5) {
                                    if isTestingKey { ProgressView().controlSize(.small) }
                                    Text(isTestingKey ? "测试中" : "测试连接")
                                }
                            }
                            .buttonStyle(TransBarInspectorButtonStyle(variant: .primary, size: .small))
                            .help("验证当前服务地址与 API Key 是否可用")
                            .disabled(isTestingKey || apiKeyIsEmpty || settings.customApiBaseUrl.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty)
                            Button(action: { saveAPIKeyDraft() }) {
                                Label(apiKeySaved ? "已保存" : "保存密钥", systemImage: apiKeySaved ? "checkmark" : "checkmark.shield")
                            }
                            .buttonStyle(TransBarInspectorButtonStyle(variant: .secondary, size: .small))
                            .disabled(!apiKeyHasUnsavedChanges && settings.apiKeyStorageError == nil)
                            .help("将 API Key 保存到本机权限受限文件，不请求钥匙串授权")
                            Spacer(minLength: 0)
                            Link(destination: URL(string: "https://platform.deepseek.com/api_keys")!) {
                                Label("前往 DeepSeek 获取", systemImage: "arrow.up.right")
                            }
                            .buttonStyle(TransBarInspectorButtonStyle(variant: .outline, size: .small))
                            .help("在浏览器中打开 DeepSeek 官方 API Key 管理页面")
                            .accessibilityLabel("前往 DeepSeek 官方平台获取 API Key")
                        }
                        if let error = settings.apiKeyStorageError {
                            statusMessage(error, success: false)
                        } else if apiKeySaved && !isTestingKey && settings.lastApiHealth == nil {
                            statusMessage(apiKeyIsEmpty ? "已移除本机 API Key" : "API Key 已保存到本机私有数据目录", success: true)
                        }
                        apiKeyHealthBanner
                    }
                }

                settingsSection("翻译模型") {
                    HStack {
                        Text("当前模型").fontWeight(.medium)
                        Spacer()
                        Button(action: updateModels) {
                            HStack(spacing: 5) {
                                if isUpdatingModels { ProgressView().controlSize(.small) }
                                else { Image(systemName: "arrow.clockwise") }
                                Text(isUpdatingModels ? "刷新中" : "刷新列表")
                            }
                        }
                        .buttonStyle(TransBarInspectorButtonStyle(variant: .secondary, size: .small))
                        .disabled(isUpdatingModels || apiKeyIsEmpty)
                    }
                    TransBarOptionMenu(
                        title: "当前模型",
                        selection: $settings.selectedModel,
                        options: settings.availableModels.map { ($0, $0) }
                    )
                    if let status = updateModelStatus {
                        statusMessage(status, success: !updateModelFailed)
                    }
                    Divider()
                    VStack(alignment: .leading, spacing: 8) {
                        Text("翻译模式").fontWeight(.medium)
                        TransBarOptionMenu(
                            title: "翻译模式",
                            selection: $settings.reasoningEffort,
                            options: ReasoningEffortLevel.allCases.map { ($0, $0.displayName) }
                        )
                        caption("不思考：更快输出译文，适合日常翻译。Low：先做轻量推敲，适合复杂表达。两种模式都只展示译文。")
                    }
                }
                settingsSection("可视化提示词") {
                    caption("通用规则保存在本机设置中；源语言、目标语言和术语按请求动态加入。稳定提示词放在前面，有助于兼容服务复用缓存。")
                    Text("通用翻译规则").fontWeight(.medium)
                    ZStack(alignment: .topLeading) {
                        if promptTemplateDraft.isEmpty {
                            Text("通用规则为空。动态语言参数与个人要求仍会单独加入请求。")
                                .font(.system(size: 12))
                                .foregroundStyle(.tertiary)
                                .padding(.horizontal, 11)
                                .padding(.vertical, 11)
                                .allowsHitTesting(false)
                        }
                        TextEditor(text: $promptTemplateDraft)
                            .font(.system(size: 12, design: .monospaced))
                            .scrollContentBackground(.hidden)
                            .padding(8)
                            .frame(minHeight: 105, maxHeight: 145)
                            .focused($focusedField, equals: .promptTemplate)
                            .accessibilityLabel("通用翻译规则提示词")
                    }
                    .transBarInspectorSurface(isFocused: focusedField == .promptTemplate, cornerRadius: 9)
                    HStack(spacing: 8) {
                        if let promptFeedback { statusMessage(promptFeedback, success: true) }
                        else { caption("DeepSeek 与 Agent 共用 · 离开此页自动保存") }
                        Spacer(minLength: 0)
                        Button("恢复默认") { promptTemplateDraft = TranslationPromptDefaults.standard }
                            .buttonStyle(TransBarInspectorButtonStyle(variant: .secondary, size: .small))
                            .disabled(promptTemplateDraft == TranslationPromptDefaults.standard)
                        Button("保存规则") { savePromptTemplateDraft() }
                            .buttonStyle(TransBarInspectorButtonStyle(variant: .primary, size: .small))
                            .disabled(promptTemplateDraft == settings.translationPromptTemplate)
                    }
                    Divider()
                    Text("我的翻译要求").fontWeight(.medium)
                    caption("例如：产品名保留英文；使用简洁的商务语气；保留 Markdown 格式。")
                    ZStack(alignment: .topLeading) {
                        if instructionsDraft.isEmpty {
                            Text("例如：产品名保留英文；使用简洁的商务语气；保留 Markdown 格式。")
                                .font(.system(size: 12))
                                .foregroundStyle(.tertiary)
                                .padding(.horizontal, 11)
                                .padding(.vertical, 11)
                                .allowsHitTesting(false)
                        }
                        TextEditor(text: $instructionsDraft)
                            .font(.system(size: 12))
                            .scrollContentBackground(.hidden)
                            .padding(8)
                            .frame(minHeight: 104, maxHeight: 140)
                            .focused($focusedField, equals: .instructions)
                            .accessibilityLabel("前置翻译说明")
                    }
                    .transBarInspectorSurface(isFocused: focusedField == .instructions, cornerRadius: 9)
                    HStack(spacing: 8) {
                        if let feedback = instructionsFeedback {
                            statusMessage(feedback, success: true)
                        } else {
                            caption("DeepSeek 与 Agent 共用 · 离开此页自动保存")
                        }
                        Spacer(minLength: 0)
                        Button("清空") {
                            instructionsDraft = ""
                            saveInstructionsDraft(feedback: "已清空翻译说明")
                        }
                        .buttonStyle(TransBarInspectorButtonStyle(variant: .secondary, size: .small))
                        .disabled(instructionsDraft.isEmpty && settings.translationInstructions.isEmpty)
                        Button("保存说明") { saveInstructionsDraft() }
                            .buttonStyle(TransBarInspectorButtonStyle(variant: .primary, size: .small))
                            .disabled(instructionsDraft == settings.translationInstructions)
                    }
                    DisclosureGroup(isExpanded: $isSharedPromptPreviewExpanded) {
                        ScrollView {
                            Text(currentPromptPreview)
                                .font(.system(size: 10, design: .monospaced))
                                .textSelection(.enabled)
                                .frame(maxWidth: .infinity, alignment: .leading)
                                .padding(10)
                        }
                        .frame(maxHeight: 150)
                        .background(TransBarInspectorDesign.field(for: colorScheme), in: RoundedRectangle(cornerRadius: 7))
                        HStack {
                            caption("动态语言：\(languageLabel(settings.lastSourceLanguage)) → \(languageLabel(settings.lastTargetLanguage))")
                            Spacer()
                            Button("复制预览") { copyToClipboard(currentPromptPreview, feedback: "prompt") }
                                .buttonStyle(TransBarInspectorButtonStyle(variant: .secondary, size: .small))
                        }
                    } label: {
                        promptPreviewLabel("查看完整提示词预览", isExpanded: isSharedPromptPreviewExpanded)
                    }
                    .padding(10)
                    .background(TransBarInspectorDesign.accent(for: colorScheme).opacity(isSharedPromptPreviewExpanded ? 0.055 : 0.025), in: RoundedRectangle(cornerRadius: 9, style: .continuous))
                    .overlay(RoundedRectangle(cornerRadius: 9, style: .continuous).strokeBorder(TransBarInspectorDesign.accent(for: colorScheme).opacity(isSharedPromptPreviewExpanded ? 0.16 : 0.08)))
                }
            }
            .padding(.horizontal, 26)
            .padding(.vertical, 24)
        }
    }

    // MARK: - API 连通性健康度与状态展示
    @ViewBuilder
    private var apiKeyHealthBanner: some View {
        let currentKey = apiKeyDraft.trimmingCharacters(in: .whitespacesAndNewlines)
        let currentUrl = settings.customApiBaseUrl.trimmingCharacters(in: .whitespacesAndNewlines)

        if isTestingKey {
            HStack(spacing: 8) {
                ProgressView().controlSize(.small)
                Text("正在验证 DeepSeek API 连通性与模型列表…")
                    .font(.system(size: 12))
                    .foregroundStyle(.secondary)
            }
            .padding(.horizontal, 12)
            .padding(.vertical, 8)
            .frame(maxWidth: .infinity, alignment: .leading)
            .background(Color.primary.opacity(0.04), in: RoundedRectangle(cornerRadius: 8, style: .continuous))
        } else if let health = settings.lastApiHealth, health.testedKey == currentKey, health.testedBaseUrl == currentUrl {
            if health.isValid {
                VStack(alignment: .leading, spacing: 4) {
                    HStack(spacing: 6) {
                        Image(systemName: "checkmark.circle.fill")
                            .font(.system(size: 13, weight: .semibold))
                            .foregroundStyle(Color.green)
                        Text("测试 API 接口调用成功")
                            .font(.system(size: 12.5, weight: .semibold))
                            .foregroundStyle(Color.green)
                        Spacer()
                        Text("已验证 · 无需重复测试")
                            .font(.system(size: 11))
                            .foregroundStyle(.secondary)
                    }
                    HStack(spacing: 8) {
                        if health.latencyMs > 0 {
                            Text("往返响应 \(health.latencyMs) ms")
                        }
                        if health.modelsCount > 0 {
                            Text("•")
                            Text("包含 \(health.modelsCount) 个可用模型")
                        }
                        Text("•")
                        Text("校验于 \(timeFormatter.string(from: health.testedAt))")
                    }
                    .font(.system(size: 11, design: .monospaced))
                    .foregroundStyle(.secondary)
                }
                .padding(.horizontal, 12)
                .padding(.vertical, 8)
                .frame(maxWidth: .infinity, alignment: .leading)
                .background(Color.green.opacity(0.08), in: RoundedRectangle(cornerRadius: 8, style: .continuous))
                .overlay(RoundedRectangle(cornerRadius: 8, style: .continuous).strokeBorder(Color.green.opacity(0.24), lineWidth: 0.8))
            } else {
                VStack(alignment: .leading, spacing: 4) {
                    HStack(spacing: 6) {
                        Image(systemName: "exclamationmark.triangle.fill")
                            .font(.system(size: 13, weight: .semibold))
                            .foregroundStyle(Color.orange)
                        Text("测试 API 接口连接失败")
                            .font(.system(size: 12.5, weight: .semibold))
                            .foregroundStyle(Color.orange)
                    }
                    Text(health.message)
                        .font(.system(size: 11))
                        .foregroundStyle(.secondary)
                }
                .padding(.horizontal, 12)
                .padding(.vertical, 8)
                .frame(maxWidth: .infinity, alignment: .leading)
                .background(Color.orange.opacity(0.08), in: RoundedRectangle(cornerRadius: 8, style: .continuous))
                .overlay(RoundedRectangle(cornerRadius: 8, style: .continuous).strokeBorder(Color.orange.opacity(0.24), lineWidth: 0.8))
            }
        } else if apiKeyHasUnsavedChanges {
            caption("API Key 已修改，点击保存或离开此页时会保存到本机私有数据目录。")
        } else if !apiKeyIsEmpty {
            caption("API Key 已配置。点击上方「测试连接」验证接口连通性。")
        } else {
            caption("还没有 API Key？前往 DeepSeek 官方平台创建后粘贴到这里。")
        }
    }

    // MARK: - 存储空间

    private var storageAndCacheTab: some View {
        ScrollView(.vertical) {
            VStack(alignment: .leading, spacing: 16) {
                HStack(spacing: 12) {
                    storageMetric("本地空间", value: cacheManager.usageInfo.formattedTotalSize, detail: "个人记忆 \(cacheManager.usageInfo.formattedMemorySize) · 统计 \(cacheManager.usageInfo.formattedStatsSize)", icon: "internaldrive")
                    storageMetric("个人翻译记忆", value: "\(cacheManager.usageInfo.totalRecordsCount)", detail: "已启用 \(cacheManager.usageInfo.favoriteCount) 条", icon: "text.book.closed")
                }
                settingsSection("自动管理") {
                    Toggle("自动释放空间", isOn: $settings.autoCleanupEnabled)
                        .toggleStyle(.switch)
                    caption("个人翻译记忆单独保存，不参与缓存清理。")
                    caption("开启后定期释放临时网络缓存。术语映射与修正样例只在个人翻译记忆页手动删除。")
                }
                settingsSection("手动清理") {
                    actionRow("清理临时缓存", detail: "释放临时网络缓存，保留个人翻译记忆和统计。", button: "立即清理", isBusy: activeCleanup == .followPolicy) {
                        pendingCleanup = .followPolicy
                    }
                    .disabled(isCleaningCache)
                    Divider()
                    actionRow("清空缓存与统计", detail: "删除调用统计与临时缓存；保留个人翻译记忆。", button: "清空…", destructive: true, isBusy: activeCleanup == .resetAll) {
                        pendingCleanup = .resetAll
                    }
                    if let message = cleanupToast { statusMessage(message, success: true) }
                }
            }
            .padding(20)
        }
    }

    // MARK: - 快捷键与交互

    private var hotkeySettingsTab: some View {
        ScrollView(.vertical) {
            VStack(alignment: .leading, spacing: 16) {
                settingsSection("全局快捷键") {
                    Toggle("使用快捷键唤起译栏", isOn: $settings.hotkeyEnabled)
                        .toggleStyle(.switch)
                        .onChange(of: settings.hotkeyEnabled) { enabled in
                            if enabled { hotkeyManager.startMonitoring(requestPermission: true) }
                            else { hotkeyManager.stopMonitoring() }
                        }
                    caption("在其他应用中选中文字后，按住 Command 连按两次 C，即可唤起面板并自动翻译。")
                    if settings.hotkeyEnabled {
                        Divider()
                        TransBarOptionMenu(
                            title: "快捷键组合",
                            selection: $settings.hotkeyMode,
                            options: HotkeyMode.allCases.map { ($0, hotkeyLabel($0)) }
                        )
                        .onChange(of: settings.hotkeyMode) { mode in
                            hotkeyManager.restartMonitoring(requestPermission: mode.usesCommandDoubleTap)
                        }
                        if settings.hotkeyMode.usesCommandDoubleTap {
                            Divider()
                            if hotkeyManager.hasAccessibilityPermission {
                                statusMessage("辅助功能权限已开启，⌘C⌘C 可以正常使用", success: true)
                            } else {
                                VStack(alignment: .leading, spacing: 10) {
                                    Label("⌘C⌘C 需要 macOS 辅助功能权限", systemImage: "exclamationmark.triangle.fill")
                                        .font(.system(size: 11))
                                        .foregroundStyle(.orange)
                                    HStack(spacing: 8) {
                                        Button("打开系统设置") {
                                            hotkeyManager.promptOpenAccessibilitySettings()
                                        }
                                        .buttonStyle(TransBarInspectorButtonStyle(variant: .secondary, size: .small))
                                        Button("重新检测") {
                                            hotkeyManager.refreshPermissionAndRestartIfNeeded()
                                        }
                                        .buttonStyle(TransBarInspectorButtonStyle(variant: .outline, size: .small))
                                    }
                                }
                                caption("在“隐私与安全性 → 辅助功能”中勾选译栏后返回这里点击“重新检测”。如果原本已勾选但仍提示授权，请先取消勾选再重新勾选。⌥Z / ⌃Z 始终无需该权限。")
                            }
                        }
                    }
                }
                settingsSection("划词翻译") {
                    Toggle("选中文字后显示翻译按钮", isOn: $settings.selectionTranslationEnabled)
                        .toggleStyle(.switch)
                    caption("在其他应用中选中文字后，译栏会显示翻译按钮。点击按钮才会把选中文字发送给当前翻译引擎。")
                    caption("需要 macOS 辅助功能权限；可随时关闭此功能。")
                    if settings.selectionTranslationEnabled {
                        if hotkeyManager.hasAccessibilityPermission {
                            statusMessage("辅助功能已授权，可在其他应用中拖选或双击选词", success: true)
                        } else {
                            HStack(spacing: 8) {
                                Button("打开辅助功能设置") { hotkeyManager.promptOpenAccessibilitySettings() }
                                    .buttonStyle(TransBarInspectorButtonStyle(variant: .secondary, size: .small))
                                Button("重新检测划词权限") {
                                    hotkeyManager.refreshPermissionAndRestartIfNeeded()
                                    Task { @MainActor in
                                        SelectionTranslationManager.shared.updateEnabled(settings.selectionTranslationEnabled)
                                        SelectionTranslationManager.shared.start()
                                    }
                                }
                                .buttonStyle(TransBarInspectorButtonStyle(variant: .outline, size: .small))
                            }
                        }
                    }
                }
                settingsSection("面板行为") {
                    HStack {
                        Label("自动翻译", systemImage: "text.bubble")
                        Spacer()
                        Text("仅 ⌘C⌘C")
                            .font(.system(size: 11, weight: .semibold, design: .monospaced))
                            .foregroundStyle(TransBarInspectorDesign.accent(for: colorScheme))
                            .padding(.horizontal, 8)
                            .padding(.vertical, 4)
                            .background(TransBarInspectorDesign.accent(for: colorScheme).opacity(0.08), in: Capsule())
                    }
                    caption("按住 Command 连按两次 C，会复制选中文字并自动翻译。点击状态栏图标或用其他快捷键唤起时，仅打开面板，点击“翻译”后开始。")
                    Divider()
                    Toggle("默认固定窗口", isOn: $settings.windowPinned)
                        .toggleStyle(.switch)
                    caption("固定后，切换到其他应用时面板仍保持显示。")
                    Divider()
                    Toggle("操作音效", isOn: $settings.soundFeedbackEnabled)
                        .toggleStyle(.switch)
                }
                HStack(alignment: .top, spacing: 9) {
                    Image(systemName: "keyboard")
                        .foregroundStyle(.secondary)
                    caption("输入框支持 ⌘C 复制、⌘V 粘贴、⌘A 全选、⌘Z 撤销，以及系统右键菜单。")
                }
                .padding(.horizontal, 2)
            }
            .padding(20)
        }
    }

    // MARK: - Agent 对接

    private var translationCommand: String {
        let payload = """
        {"text":"Hello world","source_lang":"\(settings.lastSourceLanguage)","target_lang":"\(settings.lastTargetLanguage)","engine":"deepseek","session_id":"article-1"}
        """
        return "curl -X POST http://127.0.0.1:\(agentServer.port)/v1/translate -H 'Content-Type: application/json' -d '\(payload)'"
    }

    private var knowledgeBaseImportCommand: String {
        let payload = """
        {"category":"计算机与AI","terms":[{"source":"zero-shot","target":"零样本","notes":"机器学习"},{"source":"fine-tuning","target":"微调"}]}
        """
        return "curl -X POST http://127.0.0.1:\(agentServer.port)/v1/knowledge-base/import -H 'Content-Type: application/json' -d '\(payload)'"
    }

    private var knowledgeBaseQueryCommand: String {
        return "curl http://127.0.0.1:\(agentServer.port)/v1/knowledge-base"
    }

    private var promptCommand: String {
        "curl 'http://127.0.0.1:\(agentServer.port)/v1/prompt?source_lang=\(settings.lastSourceLanguage)&target_lang=\(settings.lastTargetLanguage)'"
    }

    private var agentIntegrationTab: some View {
        ScrollView(.vertical) {
            VStack(alignment: .leading, spacing: 16) {
                agentOverviewCard
                settingsSection("快速开始") {
                    HStack(alignment: .top, spacing: 12) {
                        agentCommandCard(
                            title: "调用翻译 API",
                            subtitle: "把一段文本交给本地翻译网关。",
                            icon: "arrow.triangle.2.circlepath",
                            command: translationCommand,
                            feedbackKey: "command",
                            buttonTitle: "复制翻译命令"
                        )
                        agentCommandCard(
                            title: "读取当前提示词",
                            subtitle: "在会话开始时同步语言、规则和术语。",
                            icon: "text.alignleft",
                            command: promptCommand,
                            feedbackKey: "prompt-command",
                            buttonTitle: "复制读取命令"
                        )
                    }
                }
                settingsSection("外部 Agent 知识库导入") {
                    HStack(alignment: .top, spacing: 12) {
                        agentCommandCard(
                            title: "导入行业词库 API",
                            subtitle: "外部 Agent 或脚本一键批量注入专业术语库。",
                            icon: "books.vertical",
                            command: knowledgeBaseImportCommand,
                            feedbackKey: "kb-import-command",
                            buttonTitle: "复制导入命令"
                        )
                        agentCommandCard(
                            title: "获取知识库总览",
                            subtitle: "查询当前分类统计、启用状态与 Token 配额。",
                            icon: "list.bullet.rectangle",
                            command: knowledgeBaseQueryCommand,
                            feedbackKey: "kb-query-command",
                            buttonTitle: "复制查询命令"
                        )
                    }
                }
                settingsSection("会话上下文") {
                    HStack(alignment: .top, spacing: 22) {
                        VStack(alignment: .leading, spacing: 8) {
                            Toggle("启用短期翻译上下文", isOn: $settings.agentContextEnabled)
                                .toggleStyle(.switch)
                            caption("只处理 Agent API 请求。启用后，Agent 需要在同一组翻译中重复传入相同 session_id。")
                        }
                        .frame(maxWidth: .infinity, alignment: .leading)

                        VStack(alignment: .leading, spacing: 9) {
                            Text("保留策略")
                                .font(.system(size: 11, weight: .semibold))
                                .foregroundStyle(.secondary)
                            HStack(spacing: 10) {
                                TransBarOptionMenu(
                                    title: "最近译文",
                                    selection: $settings.agentContextMaxTurns,
                                    options: [2, 4, 6, 8].map { ($0, "最近 \($0) 轮") }
                                )
                                TransBarOptionMenu(
                                    title: "字符上限",
                                    selection: $settings.agentContextMaxCharacters,
                                    options: [2_000, 4_000, 6_000, 8_000].map { ($0, "\($0.formatted()) 字符") }
                                )
                                TransBarOptionMenu(
                                    title: "清理期限",
                                    selection: $settings.agentContextRetentionDays,
                                    options: [1, 3, 7, 30].map { ($0, "\($0) 天") }
                                )
                            }
                            .disabled(!settings.agentContextEnabled)
                        }
                        .frame(maxWidth: .infinity, alignment: .leading)
                    }
                    if !settings.agentContextEnabled {
                        caption("当前关闭：不会读取或写入上下文。已有记录仍按清理期限保留，需要立即删除时使用下方按钮。")
                    } else {
                        caption("按最近时间顺序整轮保留，超出上限时丢弃更早的整轮；内容仅保存在本机，网关启动时和每小时清理过期记录。")
                    }
                    HStack {
                        if let contextFeedback { statusMessage(contextFeedback, success: true) }
                        Spacer()
                        Button("清除 Agent 上下文") {
                            AgentTranslationContextStore.shared.clearAll()
                            contextFeedback = "已清除本机保存的 Agent 上下文"
                        }
                        .buttonStyle(TransBarInspectorButtonStyle(variant: .secondary, size: .small))
                    }
                }
                settingsSection("当前提示词") {
                    DisclosureGroup(isExpanded: $isAgentPromptPreviewExpanded) {
                        VStack(alignment: .leading, spacing: 10) {
                            caption("预览包含通用规则、个人要求、当前语言和已启用术语。会话历史只在翻译请求带有相同 session_id 时加入。")
                            ScrollView {
                                Text(currentPromptPreview)
                                    .font(.system(size: 10, design: .monospaced))
                                    .textSelection(.enabled)
                                    .frame(maxWidth: .infinity, alignment: .leading)
                                    .padding(10)
                            }
                            .frame(maxHeight: 160)
                            .background(TransBarInspectorDesign.field(for: colorScheme), in: RoundedRectangle(cornerRadius: 7))
                            HStack {
                                caption("动态语言：\(languageLabel(settings.lastSourceLanguage)) → \(languageLabel(settings.lastTargetLanguage))")
                                Spacer()
                                Button("复制提示词") { copyToClipboard(currentPromptPreview, feedback: "prompt") }
                                    .buttonStyle(TransBarInspectorButtonStyle(variant: .secondary, size: .small))
                                Button("编辑提示词") { selectedTab = 0 }
                                    .buttonStyle(TransBarInspectorButtonStyle(variant: .secondary, size: .small))
                            }
                        }
                        .padding(.top, 9)
                    } label: {
                        promptPreviewLabel("查看当前 Agent 提示词", isExpanded: isAgentPromptPreviewExpanded)
                    }
                    .padding(10)
                    .background(TransBarInspectorDesign.accent(for: colorScheme).opacity(isAgentPromptPreviewExpanded ? 0.055 : 0.025), in: RoundedRectangle(cornerRadius: 9, style: .continuous))
                    .overlay(RoundedRectangle(cornerRadius: 9, style: .continuous).strokeBorder(TransBarInspectorDesign.accent(for: colorScheme).opacity(isAgentPromptPreviewExpanded ? 0.16 : 0.08)))
                }
                settingsSection("个人翻译记忆") {
                    HStack(spacing: 14) {
                        Image(systemName: "text.book.closed.fill")
                            .font(.system(size: 22))
                            .foregroundStyle(TransBarInspectorDesign.accent(for: colorScheme))
                            .frame(width: 42, height: 42)
                            .background(TransBarInspectorDesign.accent(for: colorScheme).opacity(0.1), in: RoundedRectangle(cornerRadius: 11, style: .continuous))
                        VStack(alignment: .leading, spacing: 4) {
                            Text("让 Agent 复用你的专业表达")
                                .font(.system(size: 13, weight: .semibold))
                            caption("DeepSeek 与 Agent 共用通用提示词、个人要求和已启用的术语记忆。")
                        }
                        Spacer(minLength: 10)
                        Button {
                            selectedTab = 3
                        } label: {
                            Label("管理记忆", systemImage: "arrow.right")
                        }
                        .buttonStyle(TransBarInspectorButtonStyle(variant: .secondary, size: .small))
                    }
                }
            }
            .padding(20)
        }
    }

    private var agentOverviewCard: some View {
        HStack(spacing: 14) {
            Image(systemName: "network")
                .font(.system(size: 22, weight: .medium))
                .foregroundStyle(TransBarInspectorDesign.accent(for: colorScheme))
                .frame(width: 46, height: 46)
                .background(TransBarInspectorDesign.accent(for: colorScheme).opacity(0.1), in: RoundedRectangle(cornerRadius: 13, style: .continuous))
            VStack(alignment: .leading, spacing: 5) {
                Text("把译栏接入你的 Agent 工作流")
                    .font(.system(size: 15, weight: .semibold))
                caption("供 Cursor、Claude Desktop、终端和其他本地工具调用翻译与术语上下文。")
                if !agentServer.isRunning {
                    caption("网关当前未运行，下方命令需要服务启动后使用。")
                }
            }
            Spacer(minLength: 16)
            VStack(alignment: .trailing, spacing: 7) {
                HStack(spacing: 6) {
                    StatusDot(color: agentServer.isRunning ? .green : .secondary, pulsing: agentServer.isRunning)
                    Text(agentServer.isRunning ? "运行中" : "未运行")
                        .font(.system(size: 12, weight: .semibold))
                }
                Text("127.0.0.1:\(String(agentServer.port))")
                    .font(.system(size: 11, design: .monospaced))
                    .foregroundStyle(.secondary)
            }
        }
        .padding(16)
        .background(TransBarInspectorDesign.accent(for: colorScheme).opacity(0.055), in: RoundedRectangle(cornerRadius: 14, style: .continuous))
        .overlay(RoundedRectangle(cornerRadius: 14, style: .continuous).strokeBorder(TransBarInspectorDesign.accent(for: colorScheme).opacity(0.12)))
    }

    private func agentCommandCard(title: String, subtitle: String, icon: String, command: String, feedbackKey: String, buttonTitle: String) -> some View {
        VStack(alignment: .leading, spacing: 9) {
            Label(title, systemImage: icon)
                .font(.system(size: 12, weight: .semibold))
            caption(subtitle)
            codeSnippet(command)
                .frame(minHeight: 52, alignment: .topLeading)
            HStack {
                Spacer()
                Button {
                    copyToClipboard(command, feedback: feedbackKey)
                } label: {
                    Label(clipboardFeedback == feedbackKey ? "已复制" : buttonTitle,
                          systemImage: clipboardFeedback == feedbackKey ? "checkmark" : "doc.on.doc")
                }
                .buttonStyle(TransBarInspectorButtonStyle(variant: .secondary, size: .small))
            }
        }
        .padding(12)
        .frame(maxWidth: .infinity, alignment: .leading)
        .background(TransBarInspectorDesign.field(for: colorScheme), in: RoundedRectangle(cornerRadius: 10, style: .continuous))
        .overlay(RoundedRectangle(cornerRadius: 10, style: .continuous).strokeBorder(TransBarInspectorDesign.border(for: colorScheme)))
    }

    // MARK: - 共享样式

    private func settingsSection<Content: View>(_ title: String, @ViewBuilder content: () -> Content) -> some View {
        VStack(alignment: .leading, spacing: 14) {
            HStack(alignment: .top, spacing: 12) {
                VStack(alignment: .leading, spacing: 4) {
                    Text(title)
                        .font(.system(size: 11, weight: .medium, design: .rounded))
                        .tracking(0.7)
                        .foregroundStyle(TransBarInspectorDesign.secondaryText(for: colorScheme))
                    Text(sectionSubtitle(title))
                        .font(.system(size: 16, weight: .semibold))
                        .foregroundStyle(.primary)
                }
                Spacer(minLength: 12)
                Image(systemName: sectionIcon(title))
                    .font(.system(size: 13, weight: .medium))
                    .foregroundStyle(TransBarInspectorDesign.accent(for: colorScheme))
                    .frame(width: 34, height: 34)
                    .background(TransBarInspectorDesign.accent(for: colorScheme).opacity(0.12), in: RoundedRectangle(cornerRadius: 10, style: .continuous))
                    .overlay(RoundedRectangle(cornerRadius: 10, style: .continuous).strokeBorder(TransBarInspectorDesign.border(for: colorScheme), lineWidth: 0.8))
            }
            VStack(alignment: .leading, spacing: 14, content: content)
                .frame(maxWidth: .infinity, alignment: .leading)
        }
        .frame(maxWidth: .infinity, alignment: .leading)
        .padding(.horizontal, 22)
        .padding(.vertical, 20)
        .transBarInspectorSurface(emphasized: true, cornerRadius: 18)
    }

    private func sectionSubtitle(_ title: String) -> String {
        switch title {
        case "界面外观": return "界面主题"
        case "服务连接": return "服务连接"
        case "翻译模型": return "翻译模型"
        case "可视化提示词": return "通用翻译规则"
        case "自动管理": return "自动管理"
        case "手动清理": return "手动清理"
        default: return title
        }
    }

    private func sectionIcon(_ title: String) -> String {
        switch title {
        case "界面外观": return "circle.lefthalf.filled"
        case "服务连接": return "arrow.up.right"
        case "翻译模型": return "slider.horizontal.3"
        case "可视化提示词": return "sparkles"
        case "自动管理": return "wand.and.stars"
        case "手动清理": return "trash"
        default: return "square.grid.2x2"
        }
    }

    private func caption(_ text: String) -> some View {
        Text(text)
            .font(.system(size: 12))
            .foregroundStyle(TransBarInspectorDesign.secondaryText(for: colorScheme))
            .fixedSize(horizontal: false, vertical: true)
    }

    private func promptPreviewLabel(_ title: String, isExpanded: Bool) -> some View {
        HStack(spacing: 8) {
            Image(systemName: "text.alignleft")
                .foregroundStyle(TransBarInspectorDesign.accent(for: colorScheme))
            Text(title)
                .font(.system(size: 12, weight: .semibold))
            Spacer(minLength: 12)
            Text(isExpanded ? "收起预览" : "点击展开预览")
                .font(.system(size: 11, weight: .medium))
                .foregroundStyle(isExpanded ? TransBarInspectorDesign.accent(for: colorScheme) : Color.secondary)
        }
        .frame(maxWidth: .infinity, alignment: .leading)
        .contentShape(Rectangle())
        .accessibilityValue(isExpanded ? "已展开，点击收起" : "已收起，点击展开")
    }

    private func statusMessage(_ text: String, success: Bool) -> some View {
        Label(text, systemImage: success ? "checkmark.circle.fill" : "exclamationmark.circle.fill")
            .font(.system(size: 11))
            .foregroundStyle(success ? Color.green : Color.red)
            .fixedSize(horizontal: false, vertical: true)
    }

    private func storageMetric(_ title: String, value: String, detail: String, icon: String) -> some View {
        VStack(alignment: .leading, spacing: 7) {
            Label(title, systemImage: icon)
                .font(.system(size: 11))
                .foregroundStyle(.secondary)
            Text(value)
                .font(.system(size: 24, weight: .semibold, design: .rounded))
                .monospacedDigit()
            caption(detail)
        }
        .frame(maxWidth: .infinity, alignment: .leading)
        .padding(14)
        .background(TransBarInspectorDesign.surfaceGradient(for: colorScheme, emphasized: true), in: RoundedRectangle(cornerRadius: 12))
        .overlay(RoundedRectangle(cornerRadius: 12).strokeBorder(TransBarInspectorDesign.border(for: colorScheme)))
    }

    private func actionRow(_ title: String, detail: String, button: String, destructive: Bool = false, isBusy: Bool = false, action: @escaping () -> Void) -> some View {
        HStack(alignment: .center, spacing: 14) {
            VStack(alignment: .leading, spacing: 5) {
                Text(title)
                caption(detail)
            }
            Spacer(minLength: 0)
            Button(role: destructive ? .destructive : nil, action: action) {
                HStack(spacing: 5) {
                    if isBusy { ProgressView().controlSize(.small) }
                    Text(isBusy ? "处理中…" : button)
                }
            }
                .buttonStyle(TransBarInspectorButtonStyle(variant: destructive ? .destructive : .secondary, size: .small))
                .disabled(isCleaningCache)
                .fixedSize()
        }
    }

    private func codeSnippet(_ text: String) -> some View {
        Text(text)
            .font(.system(size: 11, design: .monospaced))
            .textSelection(.enabled)
            .frame(maxWidth: .infinity, alignment: .leading)
            .padding(10)
        .background(TransBarInspectorDesign.field(for: colorScheme), in: RoundedRectangle(cornerRadius: 8))
    }

    private var apiKeyIsEmpty: Bool {
        apiKeyDraft.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty
    }

    private var currentPromptPreview: String {
        AgentTranslationContext.prompt(
            instructions: instructionsDraft,
            memory: PersonalTranslationMemoryManager.shared,
            sourceLang: settings.lastSourceLanguage,
            targetLang: settings.lastTargetLanguage,
            sharedPrompt: promptTemplateDraft
        )
    }

    private func languageLabel(_ code: String) -> String {
        SupportedLanguages.find(by: code)?.name ?? code
    }

    private var apiKeyHasUnsavedChanges: Bool {
        apiKeyDraft.trimmingCharacters(in: .whitespacesAndNewlines) != settings.deepSeekApiKey
    }

    private func hotkeyLabel(_ mode: HotkeyMode) -> String {
        switch mode {
        case .commandCC: return "⌘C⌘C（按住 Command 连按两次 C）"
        case .both: return "⌘C⌘C、⌥Z 或 ⌃Z"
        case .optionZ: return "⌥Z（Option + Z）"
        case .controlZ: return "⌃Z（Control + Z）"
        }
    }

    // MARK: - 操作

    private func closeSettings() {
        saveAPIKeyDraft()
        savePromptTemplateDraft()
        saveInstructionsDraft()
        isKeyVisible = false
        NotificationCenter.default.post(name: NSNotification.Name("CloseSettingsNotification"), object: nil)
    }

    private func copyToClipboard(_ text: String, feedback: String) {
        NSPasteboard.general.clearContents()
        NSPasteboard.general.setString(text, forType: .string)
        withAnimation(reduceMotion ? nil : .easeOut(duration: 0.15)) { clipboardFeedback = feedback }
        let id = UUID()
        clipboardFeedbackID = id
        DispatchQueue.main.asyncAfter(deadline: .now() + 2) {
            if clipboardFeedbackID == id {
                withAnimation(reduceMotion ? nil : .easeOut(duration: 0.15)) { clipboardFeedback = nil }
            }
        }
    }

    private func performCleanup(_ action: CleanupAction) {
        guard !isCleaningCache else { return }
        isCleaningCache = true
        activeCleanup = action
        cleanupToast = nil
        DispatchQueue.main.async {
            defer {
                isCleaningCache = false
                activeCleanup = nil
            }
            switch action {
            case .followPolicy:
                cleanupToast = cacheManager.performAutoCleanupIfNeeded(force: true).message
            case .resetAll:
                cacheManager.resetAllStorage()
                cleanupToast = "已清空缓存与统计，个人翻译记忆已保留"
            }
        }
    }

    private func saveAPIKeyDraft() {
        guard apiKeyHasUnsavedChanges || settings.apiKeyStorageError != nil else { return }
        let key = apiKeyDraft.trimmingCharacters(in: .whitespacesAndNewlines)
        settings.deepSeekApiKey = key
        apiKeyDraft = key
        apiKeySaved = settings.apiKeyStorageError == nil
    }

    private func saveInstructionsDraft(feedback: String = "已保存翻译说明") {
        let text = instructionsDraft.trimmingCharacters(in: .whitespacesAndNewlines)
        guard instructionsDraft != settings.translationInstructions else { return }
        settings.translationInstructions = text
        instructionsDraft = text
        instructionsFeedback = feedback
    }

    private func savePromptTemplateDraft() {
        let text = promptTemplateDraft.trimmingCharacters(in: .whitespacesAndNewlines)
        guard text != settings.translationPromptTemplate else { return }
        settings.translationPromptTemplate = text
        promptTemplateDraft = text
        promptFeedback = "已保存通用翻译规则"
    }

    private func testKeyAvailability() {
        saveAPIKeyDraft()
        let apiKey = settings.deepSeekApiKey
        let baseURL = settings.customApiBaseUrl
        isTestingKey = true
        keyValidationResult = nil
        Task {
            let result = await APIKeyValidator.shared.validateKey(apiKey: apiKey, baseUrl: baseURL)
            await MainActor.run {
                // 输入在请求期间发生变化时，不展示属于旧配置的连接结果。
                if settings.deepSeekApiKey == apiKey && settings.customApiBaseUrl == baseURL
                    && apiKeyDraft.trimmingCharacters(in: .whitespacesAndNewlines) == apiKey {
                    keyValidationResult = result
                    // 持久化记录到 AppSettings，保证退出重进或切换页面不丢失状态
                    settings.lastApiHealth = AppSettings.ApiHealthStatus(
                        isValid: result.isValid,
                        message: result.message,
                        latencyMs: result.latencyMs,
                        modelsCount: result.modelsFound.count,
                        testedKey: apiKey,
                        testedBaseUrl: baseURL,
                        testedAt: Date()
                    )
                    // 接口成功且获取到可用模型列表时，顺畅自动同步更新当前模型列表
                    if result.isValid && !result.modelsFound.isEmpty {
                        settings.availableModels = result.modelsFound
                        if !result.modelsFound.contains(settings.selectedModel), let first = result.modelsFound.first {
                            settings.selectedModel = first
                        }
                    }
                }
                isTestingKey = false
            }
        }
    }

    private func updateModels() {
        saveAPIKeyDraft()
        let apiKey = settings.deepSeekApiKey
        let baseURL = settings.customApiBaseUrl
        isUpdatingModels = true
        updateModelStatus = nil
        updateModelFailed = false
        Task {
            do {
                let models = try await DeepSeekTranslatorEngine.shared.fetchAvailableModels(apiKey: apiKey)
                let modelIDs = models.map { $0.id }
                await MainActor.run {
                    guard settings.deepSeekApiKey == apiKey && settings.customApiBaseUrl == baseURL
                        && apiKeyDraft.trimmingCharacters(in: .whitespacesAndNewlines) == apiKey else {
                        isUpdatingModels = false
                        updateModelFailed = true
                        updateModelStatus = "连接配置已更改，请重新刷新模型列表。"
                        return
                    }
                    if modelIDs.isEmpty {
                        updateModelStatus = "服务未返回模型，请检查接口配置。"
                        updateModelFailed = true
                    } else {
                        settings.availableModels = modelIDs
                        if !modelIDs.contains(settings.selectedModel), let first = modelIDs.first { settings.selectedModel = first }
                        updateModelStatus = "已更新 \(modelIDs.count) 个可用模型"
                    }
                    isUpdatingModels = false
                }
            } catch {
                await MainActor.run {
                    isUpdatingModels = false
                    updateModelFailed = true
                    updateModelStatus = "更新失败：\(error.localizedDescription)"
                }
            }
        }
    }
}
