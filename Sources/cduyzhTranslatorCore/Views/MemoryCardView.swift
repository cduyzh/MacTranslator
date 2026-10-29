import SwiftUI

/// 修正当前译文；只有用户勾选并确认的内容才进入个人翻译记忆。
public struct MemoryCardView: View {
    @Environment(\.colorScheme) private var colorScheme
    let sourceText: String
    let currentTranslation: String
    let sourceLang: String
    let targetLang: String
    let isFromMemory: Bool
    let onEditingChanged: ((Bool) -> Void)?
    let onSave: ((String) -> Void)?

    @State private var isEditing = false
    @State private var customTranslation = ""
    @State private var rememberCorrection = false
    @State private var sourceTerm = ""
    @State private var preferredTranslation = ""
    @State private var memorySourceLang = "auto"
    @State private var memoryTargetLang = "zh-CN"
    @State private var saveFullExample = false
    @State private var mappingWasEdited = false
    @State private var saveError: String?
    @State private var savedMessage: String?
    @State private var lastSavedTranslation = ""
    @FocusState private var isEditorFocused: Bool
    @FocusState private var focusedMappingField: MappingField?

    private enum MappingField: Hashable {
        case sourceTerm
        case preferredTranslation
    }

    public init(
        sourceText: String,
        currentTranslation: String,
        sourceLang: String = "auto",
        targetLang: String = "zh-CN",
        isFromMemory: Bool = false,
        onEditingChanged: ((Bool) -> Void)? = nil,
        onSave: ((String) -> Void)? = nil
    ) {
        self.sourceText = sourceText
        self.currentTranslation = currentTranslation
        self.sourceLang = sourceLang
        self.targetLang = targetLang
        self.isFromMemory = isFromMemory
        self.onEditingChanged = onEditingChanged
        self.onSave = onSave
    }

    public var body: some View {
        VStack(alignment: .leading, spacing: 10) {
            if isEditing {
                correctionEditor
            } else {
                HStack(spacing: 8) {
                    if let message = savedMessage {
                        Label(message, systemImage: "checkmark.circle")
                            .foregroundStyle(.secondary)
                    } else if isFromMemory {
                        Label("来自即时缓存", systemImage: "bolt")
                            .foregroundStyle(.secondary)
                    }
                    Spacer(minLength: 0)
                    Button(action: beginEditing) {
                        Label("修正译文", systemImage: "square.and.pencil")
                    }
                    .buttonStyle(TransBarInspectorButtonStyle(variant: .ghost, size: .small))
                    .help("修改当前译文，也可选择记住术语或完整修正样例")
                }
                .font(.system(size: 11))
            }
        }
        .onChange(of: isEditing) { onEditingChanged?($0) }
        .onExitCommand { if isEditing { cancelEditing() } }
        .onChange(of: sourceText) { _ in resetState() }
        .onChange(of: currentTranslation) { value in
            if savedMessage == nil || value != lastSavedTranslation { resetState() }
        }
        .onChange(of: sourceLang) { _ in resetState() }
        .onChange(of: targetLang) { _ in resetState() }
        .onChange(of: rememberCorrection) { remember in
            saveError = nil
            if remember && !mappingWasEdited { suggestMapping() }
        }
        .onChange(of: customTranslation) { _ in
            saveError = nil
            if rememberCorrection && !mappingWasEdited { suggestMapping() }
        }
        .onDisappear { onEditingChanged?(false) }
        .task(id: savedMessage) {
            guard savedMessage != nil else { return }
            do {
                try await Task.sleep(nanoseconds: 3_000_000_000)
                savedMessage = nil
            } catch {}
        }
    }

    private var correctionEditor: some View {
        VStack(alignment: .leading, spacing: 10) {
            HStack(spacing: 8) {
                Text("修正译文")
                    .font(.system(size: 12, weight: .medium))
                Spacer(minLength: 0)
                Button("取消", action: cancelEditing)
                    .buttonStyle(TransBarInspectorButtonStyle(variant: .secondary, size: .small))
                Button(rememberCorrection ? "保存并记住" : "应用修正", action: saveTranslation)
                    .buttonStyle(TransBarInspectorButtonStyle(variant: .primary, size: .small))
                    .disabled(!canSave)
            }
            if TranslationPromptBuilder.isSingleTerm(sourceText) {
                hint("这是单词、缩写或网络用语。确认你的译法后勾选“记住这次修正”，以后相同词会优先使用你的固定译法。")
            }
            TextEditor(text: $customTranslation)
                .font(.system(size: 13))
                .scrollContentBackground(.hidden)
                .padding(6)
                .frame(height: 76)
                .transBarInspectorSurface(isFocused: isEditorFocused, cornerRadius: 9)
                .focused($isEditorFocused)
                .accessibilityLabel("修正后的译文")
            Toggle("记住这次修正", isOn: $rememberCorrection)
                .toggleStyle(.checkbox)
                .font(.system(size: 12, weight: .medium))
            if rememberCorrection {
                mappingEditor
            } else {
                hint("仅更新当前译文；勾选后可保存术语映射或完整修正样例。")
            }
            if let error = saveError {
                Label(error, systemImage: "exclamationmark.circle")
                    .font(.system(size: 11))
                    .foregroundStyle(.red)
                    .fixedSize(horizontal: false, vertical: true)
            } else if let validationMessage {
                hint(validationMessage)
            }
        }
    }

    private var mappingEditor: some View {
        VStack(alignment: .leading, spacing: 9) {
            HStack {
                Text("原文术语 → 固定译法")
                    .font(.system(size: 11, weight: .medium))
                Spacer(minLength: 0)
                Button("重新识别改动") {
                    mappingWasEdited = false
                    suggestMapping()
                }
                .buttonStyle(TransBarInspectorButtonStyle(variant: .ghost, size: .mini))
                .help("识别译文中的变化；句内术语仍需你确认对应的原文")
            }
            PersonalMemoryLanguagePairPicker(sourceLang: $memorySourceLang, targetLang: $memoryTargetLang)
            HStack(spacing: 7) {
                TextField("原文术语（请确认）", text: Binding(
                    get: { sourceTerm },
                    set: { sourceTerm = $0; mappingWasEdited = true; saveError = nil }
                ))
                .textFieldStyle(TransBarTextFieldStyle(isFocused: focusedMappingField == .sourceTerm))
                .focused($focusedMappingField, equals: .sourceTerm)
                .accessibilityLabel("要记住的原文术语")
                Image(systemName: "arrow.right")
                    .font(.system(size: 10))
                    .foregroundStyle(.secondary)
                TextField("固定译法", text: Binding(
                    get: { preferredTranslation },
                    set: { preferredTranslation = $0; mappingWasEdited = true; saveError = nil }
                ))
                .textFieldStyle(TransBarTextFieldStyle(isFocused: focusedMappingField == .preferredTranslation))
                .focused($focusedMappingField, equals: .preferredTranslation)
                .accessibilityLabel("术语的固定译法")
            }
            .font(.system(size: 12))
            hint("只填写需要固定翻译的词或短语。可从下方原文复制；句内改动不会擅自猜测对应的源词。")
            Text(sourceText)
                .font(.system(size: 11))
                .foregroundStyle(.secondary)
                .textSelection(.enabled)
                .lineLimit(3)
                .frame(maxWidth: .infinity, alignment: .leading)
                .padding(8)
                .background(Color.primary.opacity(0.025), in: RoundedRectangle(cornerRadius: 6))
            Toggle("同时保存完整修正样例供参考", isOn: $saveFullExample)
                .toggleStyle(.checkbox)
                .font(.system(size: 11))
            hint("也可留空术语映射，只勾选完整样例。保存的内容可在设置 → 个人翻译记忆中编辑、停用或删除。")
        }
        .padding(11)
        .background(TransBarInspectorDesign.surfaceGradient(for: colorScheme), in: RoundedRectangle(cornerRadius: 9))
        .overlay(RoundedRectangle(cornerRadius: 9).strokeBorder(TransBarInspectorDesign.border(for: colorScheme)))
    }

    private func hint(_ text: String) -> some View {
        Text(text)
            .font(.system(size: 11))
            .foregroundStyle(.secondary)
            .fixedSize(horizontal: false, vertical: true)
    }

    private var trimmedTranslation: String { customTranslation.trimmingCharacters(in: .whitespacesAndNewlines) }
    private var trimmedSourceTerm: String { sourceTerm.trimmingCharacters(in: .whitespacesAndNewlines) }
    private var trimmedPreferredTranslation: String { preferredTranslation.trimmingCharacters(in: .whitespacesAndNewlines) }
    private var hasCompleteMapping: Bool { !trimmedSourceTerm.isEmpty && !trimmedPreferredTranslation.isEmpty }
    private var hasPartialMapping: Bool { trimmedSourceTerm.isEmpty != trimmedPreferredTranslation.isEmpty }

    private var validationMessage: String? {
        if trimmedTranslation.isEmpty { return "译文不能为空。" }
        guard rememberCorrection else { return nil }
        if hasPartialMapping { return "请补齐原文术语与固定译法；若只保存完整样例，请将两个术语输入框都留空。" }
        if hasCompleteMapping && !sourceText.localizedCaseInsensitiveContains(trimmedSourceTerm) { return "请确认原文术语确实出现在本次原文中。" }
        if !hasCompleteMapping && !saveFullExample { return "填写术语映射，或勾选保存完整修正样例。" }
        return nil
    }

    private var canSave: Bool {
        !sourceText.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty && validationMessage == nil
    }

    private func beginEditing() {
        customTranslation = currentTranslation
        savedMessage = nil
        rememberCorrection = false
        sourceTerm = ""
        preferredTranslation = ""
        memorySourceLang = sourceLang
        memoryTargetLang = targetLang == "auto" ? "zh-CN" : targetLang
        saveFullExample = false
        mappingWasEdited = false
        saveError = nil
        isEditing = true
        isEditorFocused = true
    }

    private func suggestMapping() {
        guard let suggestion = suggestTerms(sourceText: sourceText, originalTranslation: currentTranslation, correctedTranslation: customTranslation).first else {
            sourceTerm = ""
            preferredTranslation = ""
            return
        }
        sourceTerm = suggestion.sourceTerm
        preferredTranslation = suggestion.preferredTranslation
    }

    private func saveTranslation() {
        guard canSave else { return }
        let translation = trimmedTranslation
        if rememberCorrection {
            var savedMapping = false
            do {
                if hasCompleteMapping {
                    try PersonalTranslationMemoryManager.shared.upsert(
                        sourceTerm: trimmedSourceTerm,
                        preferredTranslation: trimmedPreferredTranslation,
                        sourceLang: memorySourceLang,
                        targetLang: memoryTargetLang,
                        notes: "由译文修正确认",
                        kind: .term
                    )
                    savedMapping = true
                }
                if saveFullExample {
                    try PersonalTranslationMemoryManager.shared.upsert(
                        sourceTerm: sourceText,
                        preferredTranslation: translation,
                        sourceLang: memorySourceLang,
                        targetLang: memoryTargetLang,
                        notes: "用户确认的完整修正样例",
                        kind: .example
                    )
                }
            } catch {
                saveError = savedMapping ? "术语已保存，完整样例保存失败：\(error.localizedDescription)" : "个人记忆保存失败：\(error.localizedDescription)"
                return
            }
        }
        isEditorFocused = false
        isEditing = false
        lastSavedTranslation = translation
        savedMessage = rememberCorrection ? "已更新译文并保存个人记忆" : "已更新当前译文"
        onSave?(translation)
    }

    private func cancelEditing() {
        isEditorFocused = false
        isEditing = false
        customTranslation = ""
        saveError = nil
    }

    private func resetState() {
        cancelEditing()
        savedMessage = nil
    }
}
