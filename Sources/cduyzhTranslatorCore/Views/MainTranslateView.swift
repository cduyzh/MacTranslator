import SwiftUI
import AppKit

/// 原生菜单栏翻译面板。界面任务独立于 Agent 请求，避免旧请求覆盖当前内容。
public struct MainTranslateView: View {
    @ObservedObject private var settings = AppSettings.shared
    @ObservedObject private var updateChecker = AppUpdateChecker.shared
    @StateObject private var speech = TranslationSpeechController()
    @Environment(\.accessibilityReduceMotion) private var reduceMotion
    @Environment(\.colorScheme) private var colorScheme
    @FocusState private var isInputFocused: Bool

    @State private var inputText = ""
    @State private var sourceLanguage: String
    @State private var targetLanguage: String
    @State private var result: TranslationResult?
    @State private var errorMessage: String?
    @State private var isTranslating = false
    @State private var translationTask: Task<Void, Never>?
    @State private var requestID = UUID()
    @State private var requestText: String?
    @State private var copyTask: Task<Void, Never>?
    @State private var copyFeedback = false
    @State private var showSettingsSheet = false
    @State private var clipboardMessage: String?
    @State private var isEditingMemory = false

    public init() {
        _sourceLanguage = State(initialValue: AppSettings.shared.lastSourceLanguage)
        _targetLanguage = State(initialValue: AppSettings.shared.lastTargetLanguage)
    }

    public var body: some View {
        VStack(spacing: 12) {
            topBar
            engineBar
                .disabled(isEditingMemory)
            languageBar
                .disabled(isEditingMemory)
            HStack(alignment: .top, spacing: 12) {
                sourceInputArea
                    .frame(maxWidth: .infinity, maxHeight: .infinity, alignment: .topLeading)
                resultArea
                    .frame(maxWidth: .infinity, maxHeight: .infinity, alignment: .topLeading)
            }
            .frame(maxWidth: .infinity, maxHeight: .infinity, alignment: .topLeading)
            footer
        }
        .padding(20)
        .frame(width: 780, height: 680)
        .modifier(TranslatorPanelSurface())
        .preferredColorScheme(settings.appearanceMode.colorScheme)
        .sheet(isPresented: $showSettingsSheet) { SettingsView() }
        .onAppear { isInputFocused = true }
        .onDisappear { cancelTranslation(); speech.stop(); copyTask?.cancel() }
        .onChange(of: inputText) { _ in
            clipboardMessage = nil
            errorMessage = nil
            copyFeedback = false
            speech.stop()
            // 输入发生变化时立即作废请求；保留已完成译文，并明确标记待更新。
            if isTranslating, requestText != trimmedInput { cancelTranslation() }
        }
        .onChange(of: settings.selectedEngine) { _ in configurationChanged() }
        .onChange(of: settings.selectedModel) { _ in modelConfigurationChanged() }
        .onChange(of: settings.reasoningEffort) { _ in modelConfigurationChanged() }
        .onChange(of: settings.customApiBaseUrl) { _ in modelConfigurationChanged() }
        .onChange(of: settings.deepSeekApiKey) { _ in modelConfigurationChanged() }
        .onChange(of: settings.translationPromptTemplate) { _ in modelConfigurationChanged() }
        .onChange(of: settings.translationInstructions) { _ in modelConfigurationChanged() }
        .onReceive(PersonalTranslationMemoryManager.shared.$items) { _ in
            if isTranslating && settings.selectedEngine == .deepseek { modelConfigurationChanged() }
        }
        .onChange(of: showSettingsSheet) { shown in
            NotificationCenter.default.post(name: NSNotification.Name("SettingsPresentationChanged"), object: shown)
            if shown { cancelTranslation() } else { isInputFocused = true }
        }
        .onChange(of: isEditingMemory) { editing in
            NotificationCenter.default.post(name: NSNotification.Name("MemoryEditingChanged"), object: editing)
        }
        .onReceive(NotificationCenter.default.publisher(for: NSNotification.Name("TriggerTranslateNotification"))) { notification in
            if let text = notification.object as? String, !text.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty {
                inputText = text
                executeTranslation()
            } else { isInputFocused = true }
        }
        .onReceive(NotificationCenter.default.publisher(for: NSNotification.Name("ExecuteTranslateNotification"))) { _ in
            guard !showSettingsSheet, !isEditingMemory else { return }
            executeTranslation()
        }
        .onReceive(NotificationCenter.default.publisher(for: NSNotification.Name("OpenSettingsNotification"))) { _ in showSettingsSheet = true }
        .onReceive(NotificationCenter.default.publisher(for: NSNotification.Name("CloseSettingsNotification"))) { _ in showSettingsSheet = false }
    }

    private var topBar: some View {
        HStack(spacing: 10) {
            appIcon
            VStack(alignment: .leading, spacing: 2) {
                Text("译栏").font(.system(size: 17, weight: .semibold))
                Text("CDUYZH TRANSLATE")
                    .font(.system(size: 9, weight: .medium))
                    .tracking(1.2)
                    .foregroundStyle(.secondary)
            }
            Spacer()
            Button { settings.windowPinned.toggle() } label: {
                Image(systemName: settings.windowPinned ? "pin.fill" : "pin")
                    .foregroundStyle(settings.windowPinned ? TransBarInspectorDesign.accent(for: colorScheme) : .secondary)
                    .frame(width: 28, height: 28)
            }
            .buttonStyle(TransBarInspectorButtonStyle(variant: .ghost, size: .mini))
            .accessibilityLabel(settings.windowPinned ? "取消固定窗口" : "固定窗口")
            .help(settings.windowPinned ? "取消固定，点击面板外即可收起" : "固定窗口，切换应用时保持显示")
            Button { showSettingsSheet = true } label: {
                Image(systemName: "gearshape").frame(width: 28, height: 28)
            }
            .buttonStyle(TransBarInspectorButtonStyle(variant: .ghost, size: .mini))
            .accessibilityLabel("设置")
            .help("设置与用量统计 · ⌘,")
            HStack(spacing: 2) {
                StatusMenuButton().frame(width: 28, height: 28)
                if updateChecker.hasUpdate {
                    Circle().fill(Color.orange).frame(width: 5, height: 5).offset(y: -5)
                }
            }
            .help("更多操作，与状态栏右键菜单一致")
            Button { closePanel() } label: {
                Image(systemName: "xmark").frame(width: 28, height: 28)
            }
            .buttonStyle(TransBarInspectorButtonStyle(variant: .ghost, size: .mini))
            .accessibilityLabel("关闭翻译面板")
            .help("收起面板 · Esc")
        }
    }

    private var engineBar: some View {
        HStack(spacing: 10) {
            Image(systemName: "bolt.horizontal.circle")
                .font(.system(size: 13, weight: .medium))
                .foregroundStyle(TransBarInspectorDesign.accent(for: colorScheme))
            Text("翻译引擎")
                .font(.system(size: 12, weight: .semibold))
                .foregroundStyle(TransBarInspectorDesign.secondaryText(for: colorScheme))
            Spacer(minLength: 8)
            HStack(spacing: 2) {
                engineButton("Google", engine: .google)
                engineButton("DeepSeek", engine: .deepseek)
            }
            .padding(3)
            .background(TransBarInspectorDesign.field(for: colorScheme), in: Capsule())
            .overlay(Capsule().strokeBorder(TransBarInspectorDesign.border(for: colorScheme), lineWidth: 0.8))
        }
        .padding(.horizontal, 11)
        .padding(.vertical, 8)
        .transBarInspectorSurface(emphasized: true, cornerRadius: 12)
    }

    private func engineButton(_ title: String, engine: TranslationEngineType) -> some View {
        let selected = settings.selectedEngine == engine
        return Button {
            settings.selectedEngine = engine
        } label: {
            Text(title)
                .font(.system(size: 12, weight: .semibold))
                .frame(minWidth: 82)
                .padding(.horizontal, 10)
                .padding(.vertical, 7)
        }
        .buttonStyle(TransBarInspectorButtonStyle(variant: selected ? .primary : .ghost, size: .small))
        .accessibilityAddTraits(selected ? .isSelected : [])
    }

    private var languageBar: some View {
        HStack(spacing: 8) {
            languageMenu(isSource: true)
            Button { swapLanguages() } label: {
                Image(systemName: "arrow.left.arrow.right")
                    .font(.system(size: 13, weight: .medium))
                    .frame(width: 28, height: 30)
            }
            .buttonStyle(TransBarInspectorButtonStyle(variant: .ghost, size: .mini))
            .disabled(swappableSource == nil || isTranslating)
            .accessibilityLabel("交换原文与译文语言")
            .help(swappableSource == nil ? "翻译并识别原文语言后即可交换" : "交换原文与译文语言")
            languageMenu(isSource: false)
        }
        .animation(reduceMotion ? nil : .easeOut(duration: 0.16), value: swappableSource)
    }

    private func languageMenu(isSource: Bool) -> some View {
        LanguageSelectionMenu(
            title: isSource ? "原文语言" : "译文语言",
            selection: isSource ? sourceLanguage : targetLanguage,
            includesAuto: isSource
        ) { code in
            if isSource { sourceLanguage = code } else { targetLanguage = code }
            configurationChanged()
        }
    }

    private var sourceInputArea: some View {
        VStack(spacing: 10) {
            HStack {
                Label("原文", systemImage: "text.alignleft")
                    .font(.system(size: 12, weight: .semibold))
                    .foregroundStyle(TransBarInspectorDesign.secondaryText(for: colorScheme))
                Spacer()
                Text("\(inputText.count) 字符")
                    .font(.system(size: 11).monospacedDigit())
                    .foregroundStyle(.tertiary)
                Button { clearInput() } label: { Image(systemName: "xmark.circle.fill") }
                    .buttonStyle(TransBarInspectorButtonStyle(variant: .ghost, size: .mini))
                    .foregroundStyle(.secondary)
                    .disabled(inputText.isEmpty)
                    .accessibilityLabel("清空原文和译文")
                    .help("清空原文和译文")
            }
            ZStack(alignment: .topLeading) {
                TextEditor(text: $inputText)
                    .font(.system(size: 14))
                    .lineSpacing(4)
                    .scrollContentBackground(.hidden)
                    .focused($isInputFocused)
                    .accessibilityLabel("待翻译原文")
                if inputText.isEmpty {
                    Text("输入或粘贴文本，让意思自然传达。")
                        .font(.system(size: 14))
                        .foregroundStyle(.tertiary)
                        .padding(.leading, 5)
                        .padding(.top, 1)
                        .allowsHitTesting(false)
                }
            }
            .frame(minHeight: 145)
            HStack(spacing: 8) {
                Button { pasteAndTranslate() } label: { Label("粘贴并翻译", systemImage: "doc.on.clipboard") }
                    .buttonStyle(TransBarInspectorButtonStyle(variant: .secondary, size: .small))
                    .disabled(isEditingMemory)
                    .help("读取剪贴板文本并翻译")
                Spacer()
                if isTranslating {
                    Button("停止") { cancelTranslation() }
                        .buttonStyle(TransBarInspectorButtonStyle(variant: .secondary, size: .small))
                } else {
                    Text("⌘ ↩").font(.system(size: 11, design: .monospaced)).foregroundStyle(.tertiary)
                }
                Button { executeTranslation() } label: {
                    HStack(spacing: 6) {
                        Text(isTranslating ? "翻译中" : "翻译")
                        Image(systemName: "arrow.right")
                    }
                    .frame(minWidth: 54)
                }
                .buttonStyle(TransBarInspectorButtonStyle(variant: .primary, size: .regular))
                .disabled(trimmedInput.isEmpty || isTranslating || isEditingMemory)
                .help(isEditingMemory ? "请先保存或取消译文修正" : "翻译 · Command + Return")
            }
        }
        .padding(12)
        .transBarInspectorSurface(emphasized: true, isFocused: isInputFocused, cornerRadius: 14)
        .animation(reduceMotion ? nil : .easeOut(duration: 0.16), value: isInputFocused)
    }

    private var resultArea: some View {
        VStack(alignment: .leading, spacing: 10) {
            HStack(spacing: 8) {
                Label("译文", systemImage: "text.bubble")
                    .font(.system(size: 12, weight: .semibold))
                    .foregroundStyle(TransBarInspectorDesign.secondaryText(for: colorScheme))
                if isResultOutdated { Text("原文已更改").font(.system(size: 10)).foregroundStyle(.secondary) }
                Spacer()
                if let result, !isTranslating, errorMessage == nil {
                    Button { speech.toggle(text: result.targetText, language: result.targetLang) } label: {
                        Image(systemName: speech.isSpeaking ? "stop.fill" : "speaker.wave.2").frame(width: 20, height: 20)
                    }
                    .buttonStyle(TransBarInspectorButtonStyle(variant: .ghost, size: .mini))
                    .accessibilityLabel(speech.isSpeaking ? "停止朗读" : "朗读译文")
                    .help(speech.isSpeaking ? "停止朗读" : "朗读译文")
                    Button { copyTranslation(result.targetText) } label: {
                        Label(copyFeedback ? "已复制" : "复制", systemImage: copyFeedback ? "checkmark" : "doc.on.doc")
                            .foregroundStyle(copyFeedback ? Color.green : .primary)
                            .frame(minWidth: 52)
                    }
                    .buttonStyle(TransBarInspectorButtonStyle(variant: .secondary, size: .small))
                    .accessibilityLabel(copyFeedback ? "译文已复制" : "复制译文")
                }
            }
            if isTranslating {
                statusPlaceholder(icon: nil, title: "正在翻译", detail: "正在整理语言，让表达更自然。")
            } else if let errorMessage {
                VStack(alignment: .leading, spacing: 10) {
                    Label("暂时无法完成翻译", systemImage: "exclamationmark.circle").font(.system(size: 13, weight: .medium))
                    Text(errorMessage).font(.system(size: 12)).foregroundStyle(.secondary).textSelection(.enabled)
                    if settings.selectedEngine == .deepseek && settings.deepSeekApiKey.isEmpty {
                        Button("配置 DeepSeek API Key") { showSettingsSheet = true }
                            .buttonStyle(TransBarInspectorButtonStyle(variant: .primary, size: .small))
                    } else {
                        Button("重试") { executeTranslation() }
                            .buttonStyle(TransBarInspectorButtonStyle(variant: .secondary, size: .small))
                    }
                }
                .frame(maxWidth: .infinity, maxHeight: .infinity, alignment: .leading)
            } else if let result {
                ScrollView(.vertical, showsIndicators: true) {
                    VStack(alignment: .leading, spacing: 12) {
                        if TranslationPromptBuilder.isSingleTerm(result.sourceText), result.engineUsed.contains("DeepSeek") {
                            singleTermModeHint(for: result)
                        }
                        Text(result.targetText)
                            .font(.system(size: 15))
                            .lineSpacing(5)
                            .textSelection(.enabled)
                            .frame(maxWidth: .infinity, alignment: .leading)
                            .fixedSize(horizontal: false, vertical: true)
                        MemoryCardView(sourceText: result.sourceText, currentTranslation: result.targetText,
                                       sourceLang: result.detectedSourceLang, targetLang: result.targetLang, isFromMemory: result.fromMemory,
                                       onEditingChanged: { isEditingMemory = $0 },
                                       onSave: { corrected in
                                           self.result?.targetText = corrected
                                           speech.stop()
                                           copyFeedback = false
                                       })
                            .id(result.id)
                    }
                    .padding(.trailing, 4)
                }
                .id(result.id)
                HStack(spacing: 5) {
                    Image(systemName: result.fromMemory ? "internaldrive" : "checkmark.circle")
                    Text(engineLabel(result))
                    Text("· \(result.latencyMs) ms").monospacedDigit()
                    if result.totalTokens > 0 { Text("· \(result.totalTokens) tokens").monospacedDigit() }
                    Spacer(minLength: 0)
                }
                .font(.system(size: 10))
                .foregroundStyle(.secondary)
                .lineLimit(1)

                let matchedKB = matchedKnowledgeTerms(for: result)
                if !matchedKB.isEmpty {
                    HStack(spacing: 4) {
                        Image(systemName: "books.vertical.fill")
                            .font(.system(size: 9))
                            .foregroundStyle(TransBarInspectorDesign.accent(for: colorScheme))
                        Text("专业词库参考:")
                            .font(.system(size: 9.5, weight: .medium))
                            .foregroundStyle(.secondary)
                        ForEach(matchedKB.prefix(2), id: \.id) { item in
                            Text("\(item.sourceTerm)=\(item.preferredTranslation)")
                                .font(.system(size: 9.5))
                                .padding(.horizontal, 5)
                                .padding(.vertical, 1.5)
                                .background(TransBarInspectorDesign.accent(for: colorScheme).opacity(0.08), in: RoundedRectangle(cornerRadius: 4, style: .continuous))
                                .foregroundStyle(TransBarInspectorDesign.accent(for: colorScheme))
                        }
                        if matchedKB.count > 2 {
                            Text("+\(matchedKB.count - 2)")
                                .font(.system(size: 9))
                                .foregroundStyle(.secondary)
                        }
                        Spacer(minLength: 0)
                    }
                    .padding(.top, 2)
                }
            } else {
                statusPlaceholder(icon: "character.bubble", title: "跨越语言，保留本意", detail: clipboardMessage ?? "译文会显示在这里。可在设置中管理个人术语与翻译要求。")
            }
        }
        .padding(14)
        .frame(maxWidth: .infinity, maxHeight: .infinity, alignment: .topLeading)
        .transBarInspectorSurface(cornerRadius: 14)
        .animation(reduceMotion ? nil : .easeOut(duration: 0.18), value: result?.id)
    }

    private func statusPlaceholder(icon: String?, title: String, detail: String) -> some View {
        VStack(spacing: 10) {
            if let icon { Image(systemName: icon).font(.system(size: 26, weight: .light)).foregroundStyle(.tertiary) }
            else { ProgressView().controlSize(.small).padding(4) }
            Text(title).font(.system(size: 13, weight: .medium)).foregroundStyle(.secondary)
            Text(detail).font(.system(size: 11)).foregroundStyle(.tertiary).multilineTextAlignment(.center)
        }
        .frame(maxWidth: .infinity, maxHeight: .infinity)
        .accessibilityElement(children: .combine)
    }

    private func singleTermModeHint(for result: TranslationResult) -> some View {
        let glossaryEntry = result.targetLang.lowercased().hasPrefix("zh") ? ChineseInternetMemeGlossary.entry(for: result.sourceText) : nil
        return HStack(alignment: .top, spacing: 8) {
            Image(systemName: "text.book.closed")
                .foregroundStyle(TransBarInspectorDesign.accent(for: colorScheme))
            VStack(alignment: .leading, spacing: 3) {
                Text("单词 / 网络用语释义模式")
                    .font(.system(size: 11, weight: .semibold))
                Text(glossaryEntry == nil
                    ? "已补充首选译法、含义、语气和常见用法；确认修正后可保存为该词的固定译法。"
                    : "已优先参考中文梗词“\(glossaryEntry!.preferredTranslation)”，并补充含义、语气和常见用法；确认修正后可保存为固定译法。")
                    .font(.system(size: 10))
                    .foregroundStyle(.secondary)
                    .fixedSize(horizontal: false, vertical: true)
            }
        }
        .padding(9)
        .frame(maxWidth: .infinity, alignment: .leading)
        .background(TransBarInspectorDesign.accent(for: colorScheme).opacity(0.06), in: RoundedRectangle(cornerRadius: 8, style: .continuous))
        .overlay(RoundedRectangle(cornerRadius: 8, style: .continuous).strokeBorder(TransBarInspectorDesign.accent(for: colorScheme).opacity(0.12)))
    }

    private var footer: some View {
        HStack(spacing: 5) {
            Image(systemName: "keyboard").font(.system(size: 11))
            Text(hotkeyHint).font(.system(size: 10))
            Spacer()
            if let clipboardMessage, result != nil { Text(clipboardMessage).font(.system(size: 10)) }
            else { Text(settings.windowPinned ? "窗口已固定" : "随用随译").font(.system(size: 10)) }
        }
        .foregroundStyle(.secondary)
        .lineLimit(1)
    }

    private var appIcon: some View {
        Group {
            if let iconPath = Bundle.main.path(forResource: "AppIcon_1024", ofType: "png"), let nsImage = NSImage(contentsOfFile: iconPath) {
                Image(nsImage: nsImage).resizable().scaledToFit()
            } else {
                Image(systemName: "character.bubble.fill").resizable().scaledToFit().foregroundStyle(TransBarInspectorDesign.accent(for: colorScheme)).padding(3)
            }
        }
        .frame(width: 32, height: 32)
        .clipShape(RoundedRectangle(cornerRadius: 8, style: .continuous))
        .accessibilityHidden(true)
    }

    private var trimmedInput: String { inputText.trimmingCharacters(in: .whitespacesAndNewlines) }
    private var isResultOutdated: Bool { result.map { $0.sourceText != trimmedInput } ?? false }
    private var swappableSource: String? {
        if sourceLanguage != "auto" { return sourceLanguage }
        guard let result, !isResultOutdated, SupportedLanguages.find(by: result.detectedSourceLang) != nil,
              result.detectedSourceLang != "auto" else { return nil }
        return result.detectedSourceLang
    }
    private var hotkeyHint: String {
        guard settings.hotkeyEnabled else { return "全局快捷键已关闭" }
        switch settings.hotkeyMode {
        case .commandCC: return "⌘C C 唤起"
        case .both: return "⌘C C / ⌥Z / ⌃Z 唤起"
        case .optionZ: return "⌥ Z 唤起"
        case .controlZ: return "⌃ Z 唤起"
        }
    }
    private func engineLabel(_ result: TranslationResult) -> String {
        if result.fromMemory { return "即时缓存" }
        if result.engineUsed.contains("Google") { return "Google" }
        if result.engineUsed.contains("DeepSeek") { return "DeepSeek" }
        return result.engineUsed
    }

    private func executeTranslation() {
        let text = trimmedInput
        guard !text.isEmpty, !showSettingsSheet, !isEditingMemory,
              !isTranslating || requestText != text else { return }
        cancelTranslation()
        result = nil
        errorMessage = nil
        clipboardMessage = nil
        copyFeedback = false
        let identity = UUID()
        requestID = identity
        requestText = text
        let source = sourceLanguage, target = targetLanguage, engine = settings.selectedEngine
        isTranslating = true
        translationTask = Task { @MainActor in
            do {
                let translated = try await TranslationCoordinator.shared.translate(text: text, sourceLang: source, targetLang: target, engine: engine, updatesPresentation: false)
                guard !Task.isCancelled, requestID == identity else { return }
                result = translated
            } catch {
                guard !Task.isCancelled, requestID == identity else { return }
                errorMessage = error.localizedDescription
            }
            guard requestID == identity else { return }
            isTranslating = false
            translationTask = nil
        }
    }

    private func cancelTranslation() {
        requestID = UUID()
        translationTask?.cancel()
        translationTask = nil
        requestText = nil
        isTranslating = false
        speech.stop()
    }

    private func configurationChanged() {
        settings.lastSourceLanguage = sourceLanguage
        settings.lastTargetLanguage = targetLanguage
        cancelTranslation()
        result = nil
        errorMessage = nil
    }

    private func modelConfigurationChanged() {
        guard settings.selectedEngine == .deepseek else { return }
        cancelTranslation()
        result = nil
        errorMessage = nil
    }

    private func clearInput() {
        cancelTranslation()
        inputText = ""
        result = nil
        errorMessage = nil
        clipboardMessage = nil
        copyTask?.cancel()
        copyFeedback = false
        isInputFocused = true
    }

    private func pasteAndTranslate() {
        let text = GlobalHotkeyManager.shared.extractCurrentPasteboardText()
        guard !text.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty else {
            clipboardMessage = "剪贴板中没有可翻译的文本"
            return
        }
        inputText = text
        executeTranslation()
    }

    private func swapLanguages() {
        guard let source = swappableSource, !isTranslating else { return }
        let previousTarget = targetLanguage
        if let result, !isResultOutdated { inputText = result.targetText }
        sourceLanguage = previousTarget
        targetLanguage = source
        configurationChanged()
    }

    private func copyTranslation(_ text: String) {
        NSPasteboard.general.clearContents()
        guard NSPasteboard.general.setString(text, forType: .string) else { return }
        if settings.soundFeedbackEnabled { NSSound(named: "Pop")?.play() }
        copyTask?.cancel()
        copyFeedback = true
        copyTask = Task { @MainActor in
            try? await Task.sleep(nanoseconds: 1_800_000_000)
            guard !Task.isCancelled else { return }
            copyFeedback = false
        }
    }

    private func closePanel() {
        NotificationCenter.default.post(name: NSNotification.Name("ClosePopoverNotification"), object: nil)
    }

    private func matchedKnowledgeTerms(for result: TranslationResult) -> [DomainGlossaryItem] {
        guard settings.selectedEngine == .deepseek, settings.knowledgeBaseEnabled else { return [] }
        let match = DomainKnowledgeBaseManager.shared.queryContext(
            text: result.sourceText,
            sourceLang: result.detectedSourceLang,
            targetLang: result.targetLang,
            maxTerms: 4,
            maxCharacters: 200
        )
        return match.matchedItems
    }
}

/// 自定义触发器保留两层语言信息，列表可按中文名、英文名或语言代码搜索。
private struct LanguageSelectionMenu: View {
    let title: String
    let selection: String
    let includesAuto: Bool
    let onSelect: (String) -> Void
    @State private var isPresented = false
    @State private var query = ""
    @FocusState private var searchFocused: Bool
    @Environment(\.colorScheme) private var colorScheme
    @Environment(\.accessibilityReduceMotion) private var reduceMotion

    private var selectedName: String { SupportedLanguages.find(by: selection)?.name ?? selection }
    private var languages: [LanguageItem] {
        let term = query.trimmingCharacters(in: .whitespacesAndNewlines)
        return SupportedLanguages.all.filter {
            (includesAuto || $0.code != "auto") &&
            (term.isEmpty || $0.name.localizedCaseInsensitiveContains(term) ||
             $0.englishName.localizedCaseInsensitiveContains(term) || $0.code.localizedCaseInsensitiveContains(term))
        }
    }
    var body: some View {
        Button { query = ""; isPresented.toggle() } label: {
            HStack(spacing: 10) {
                CountryFlagView(code: selection, size: 24)
                VStack(alignment: .leading, spacing: 3) {
                    Text(title).font(.system(size: 12, weight: .medium)).foregroundStyle(TransBarInspectorDesign.secondaryText(for: colorScheme))
                    Text(selectedName).font(.system(size: 15, weight: .semibold))
                }
                Spacer(minLength: 4)
                Image(systemName: "chevron.down")
                    .font(.system(size: 9, weight: .semibold))
                    .foregroundStyle(TransBarInspectorDesign.secondaryText(for: colorScheme))
                    .rotationEffect(.degrees(isPresented ? 180 : 0))
            }
            .padding(.horizontal, 12)
            .padding(.vertical, 11)
            .frame(maxWidth: .infinity)
            .background(TransBarInspectorDesign.field(for: colorScheme), in: RoundedRectangle(cornerRadius: 10, style: .continuous))
            .overlay {
                RoundedRectangle(cornerRadius: 10, style: .continuous)
                    .strokeBorder(TransBarInspectorDesign.border(for: colorScheme, emphasized: isPresented), lineWidth: isPresented ? 1.15 : 0.8)
            }
            .contentShape(RoundedRectangle(cornerRadius: 10))
        }
        .buttonStyle(.plain)
        .animation(reduceMotion ? nil : .easeOut(duration: 0.16), value: isPresented)
        .accessibilityLabel(title)
        .accessibilityValue(selectedName)
        .popover(isPresented: $isPresented, arrowEdge: .bottom) {
            VStack(spacing: 8) {
                HStack(spacing: 7) {
                    Image(systemName: "magnifyingglass").foregroundStyle(.secondary)
                    TextField("搜索语言", text: $query)
                        .textFieldStyle(.plain)
                        .focused($searchFocused)
                        .onSubmit { if let first = languages.first { choose(first.code) } }
                    if !query.isEmpty {
                        Button { query = ""; searchFocused = true } label: { Image(systemName: "xmark.circle.fill") }
                            .buttonStyle(.plain).foregroundStyle(.secondary).accessibilityLabel("清除语言搜索")
                    }
                }
                .padding(.horizontal, 14)
                .frame(height: 52)
                .font(.system(size: 16, weight: .medium))
                .transBarInspectorSurface(isFocused: searchFocused, cornerRadius: 12)
                ScrollView {
                    VStack(spacing: 3) {
                        ForEach(languages) { language in
                            LanguageOptionRowView(
                                language: language,
                                isSelected: language.code == selection,
                                onSelect: { choose(language.code) }
                            )
                        }
                        if languages.isEmpty {
                            Text("没有匹配的语言")
                                .font(.system(size: 14))
                                .foregroundStyle(.secondary)
                                .padding(.vertical, 28)
                        }
                    }
                    .padding(.vertical, 2)
                }
                .frame(maxHeight: 360)
            }
            .font(.system(size: 14))
            .padding(13)
            .frame(minWidth: 360, idealWidth: 360, maxWidth: 360, minHeight: 260, maxHeight: 470)
            .background(TransBarInspectorDesign.surfaceGradient(for: colorScheme, emphasized: true))
            .onExitCommand { isPresented = false }
        }
    }

    private func choose(_ code: String) {
        onSelect(code)
        DispatchQueue.main.async {
            isPresented = false
        }
    }
}

/// 语言项行视图：具备全宽命中判定、实体防穿透图层、悬停反馈与手势双保险
private struct LanguageOptionRowView: View {
    let language: LanguageItem
    let isSelected: Bool
    let onSelect: () -> Void
    @Environment(\.colorScheme) private var colorScheme
    @State private var isHovered: Bool = false

    var body: some View {
        Button(action: onSelect) {
            HStack(spacing: 10) {
                CountryFlagView(code: language.code, size: 22)
                Text(language.name)
                    .font(.system(size: 15, weight: isSelected ? .semibold : .medium))
                    .foregroundStyle(.primary)
                if !language.englishName.isEmpty && language.englishName != language.name {
                    Text(language.englishName)
                        .font(.system(size: 12))
                        .foregroundStyle(TransBarInspectorDesign.secondaryText(for: colorScheme))
                }
                Spacer(minLength: 8)
                if isSelected {
                    Image(systemName: "checkmark")
                        .font(.system(size: 15, weight: .semibold))
                        .foregroundStyle(TransBarInspectorDesign.accent(for: colorScheme))
                }
            }
            .padding(.horizontal, 14)
            .frame(maxWidth: .infinity, minHeight: 44, alignment: .leading)
            .contentShape(Rectangle())
            .background(
                isSelected
                    ? TransBarInspectorDesign.accent(for: colorScheme).opacity(colorScheme == .dark ? 0.22 : 0.12)
                    : (isHovered ? (colorScheme == .dark ? Color.white.opacity(0.08) : Color.black.opacity(0.05)) : Color.primary.opacity(0.001)),
                in: RoundedRectangle(cornerRadius: 8, style: .continuous)
            )
        }
        .buttonStyle(.plain)
        .contentShape(RoundedRectangle(cornerRadius: 8, style: .continuous))
        .onHover { hovering in
            isHovered = hovering
        }
        .simultaneousGesture(
            TapGesture().onEnded {
                onSelect()
            }
        )
        .accessibilityLabel(language.name)
        .accessibilityValue(isSelected ? "已选中" : "")
        .accessibilityAddTraits(isSelected ? .isSelected : [])
    }
}

/// 朗读器持有稳定生命周期，并在自然结束时恢复按钮状态。
private final class TranslationSpeechController: NSObject, ObservableObject, NSSpeechSynthesizerDelegate {
    @Published var isSpeaking = false
    private let synthesizer = NSSpeechSynthesizer()

    override init() {
        super.init()
        synthesizer.delegate = self
    }

    func toggle(text: String, language: String) {
        if isSpeaking { stop(); return }
        let prefix = language.split(separator: "-").first.map(String.init) ?? language
        let voices = NSSpeechSynthesizer.availableVoices
        let voice = voices.first { voice in
            let locale = (NSSpeechSynthesizer.attributes(forVoice: voice)[.localeIdentifier] as? String ?? "").replacingOccurrences(of: "_", with: "-")
            return locale.caseInsensitiveCompare(language) == .orderedSame
        } ?? voices.first { voice in
            let locale = NSSpeechSynthesizer.attributes(forVoice: voice)[.localeIdentifier] as? String ?? ""
            return locale.lowercased().hasPrefix(prefix.lowercased())
        }
        synthesizer.setVoice(voice)
        isSpeaking = synthesizer.startSpeaking(text)
    }

    func stop() { synthesizer.stopSpeaking(); isSpeaking = false }
    func speechSynthesizer(_ sender: NSSpeechSynthesizer, didFinishSpeaking finishedSpeaking: Bool) {
        DispatchQueue.main.async { self.isSpeaking = sender.isSpeaking }
    }
}

/// 尊重系统减少透明度设置的原生材质。
struct VisualEffectView: NSViewRepresentable {
    let material: NSVisualEffectView.Material
    let blendingMode: NSVisualEffectView.BlendingMode
    @Environment(\.accessibilityReduceTransparency) private var reduceTransparency

    func makeNSView(context: Context) -> NSVisualEffectView {
        let view = NSVisualEffectView()
        updateNSView(view, context: context)
        return view
    }
    func updateNSView(_ nsView: NSVisualEffectView, context: Context) {
        nsView.material = material
        nsView.blendingMode = blendingMode
        nsView.state = .active
        nsView.wantsLayer = true
        nsView.layer?.backgroundColor = reduceTransparency ? NSColor.windowBackgroundColor.cgColor : nil
    }
}
