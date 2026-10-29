import SwiftUI

/// 个人偏好由用户明确创建和管理，与临时缓存分开保存。
struct PersonalTranslationMemorySettingsView: View {
    @ObservedObject private var manager = PersonalTranslationMemoryManager.shared
    @Environment(\.colorScheme) private var colorScheme
    @Environment(\.accessibilityReduceMotion) private var reduceMotion
    @State private var searchText = ""
    @FocusState private var searchFocused: Bool
    @State private var sourceFilter = "all"
    @State private var targetFilter = "all"
    @State private var kindFilter = "all"
    @State private var presentation: Presentation?
    @State private var actionFeedback: String?
    @State private var actionError: String?

    private enum Presentation: Identifiable {
        case editor(PersonalTranslationMemoryItem?)
        case deletion(PersonalTranslationMemoryItem)

        var id: String {
            switch self {
            case .editor(let item): return "editor:\(item?.id ?? "new")"
            case .deletion(let item): return "delete:\(item.id)"
            }
        }
    }

    var body: some View {
        VStack(spacing: 0) {
            controls
                .padding(20)
            Divider()
            if filteredItems.isEmpty {
                emptyState
            } else {
                ScrollView(.vertical) {
                    LazyVStack(spacing: 10) {
                        ForEach(filteredItems) { item in memoryRow(item) }
                    }
                    .padding(20)
                }
            }
        }
        .sheet(item: $presentation) { presented in
            Group {
                switch presented {
                case .editor(let item):
                    PersonalMemoryEditorView(item: item) { message in
                        actionFeedback = message
                        actionError = nil
                    }
                case .deletion(let item):
                    PersonalMemoryDeleteConfirmationView(item: item, onDelete: {
                        try manager.delete(id: item.id)
                    }, onDeleted: {
                        actionFeedback = "已删除个人记忆"
                        actionError = nil
                    })
                }
            }
            .onExitCommand { presentation = nil }
        }
        .animation(reduceMotion ? nil : .easeOut(duration: 0.18), value: presentation?.id)
    }

    private var controls: some View {
        VStack(alignment: .leading, spacing: 12) {
            memoryOverview
            HStack(spacing: 9) {
                HStack(spacing: 7) {
                    Image(systemName: "magnifyingglass")
                        .foregroundStyle(TransBarInspectorDesign.secondaryText(for: colorScheme))
                    TextField("搜索术语、译法或备注", text: $searchText)
                        .textFieldStyle(.plain)
                        .focused($searchFocused)
                        .accessibilityLabel("搜索个人翻译记忆")
                    if !searchText.isEmpty {
                        Button { searchText = "" } label: {
                            Image(systemName: "xmark.circle.fill")
                        }
                        .buttonStyle(TransBarInspectorButtonStyle(variant: .ghost, size: .mini))
                        .accessibilityLabel("清除搜索")
                    }
                }
                .padding(.leading, 10)
                .padding(.trailing, searchText.isEmpty ? 10 : 3)
                .frame(height: 34)
                .transBarInspectorSurface(isFocused: searchFocused, cornerRadius: 9)
                Button { presentation = .editor(nil) } label: {
                    Label("新增", systemImage: "plus")
                }
                .buttonStyle(TransBarInspectorButtonStyle(variant: .primary, size: .small))
                .help("创建术语映射或修正样例")
            }
            HStack(spacing: 8) {
                languageFilter("全部源语言", selection: $sourceFilter, includeAuto: true)
                languageFilter("全部目标语言", selection: $targetFilter, includeAuto: false)
                TransBarOptionMenu(
                    title: "全部类型",
                    selection: $kindFilter,
                    options: [
                        ("all", "全部类型"),
                        (PersonalTranslationMemoryKind.term.rawValue, "术语映射"),
                        (PersonalTranslationMemoryKind.example.rawValue, "修正样例")
                    ]
                )
            }
            Divider()
            HStack {
                Text("\(filteredItems.count) 条\(hasFilters ? "匹配结果" : "个人记忆")  共启用 \(manager.items.filter(\.isEnabled).count) 条")
                    .font(.system(size: 12))
                    .foregroundStyle(.secondary)
                Spacer()
                if hasFilters {
                    Button("重置筛选", action: resetFilters)
                        .buttonStyle(TransBarInspectorButtonStyle(variant: .ghost, size: .mini))
                }
            }
            if let error = actionError ?? manager.persistenceError {
                Label(error, systemImage: "exclamationmark.circle")
                    .font(.system(size: 12))
                    .foregroundStyle(.red)
                    .fixedSize(horizontal: false, vertical: true)
            } else if let feedback = actionFeedback {
                Label(feedback, systemImage: "checkmark.circle")
                    .font(.system(size: 11))
                .foregroundStyle(TransBarInspectorDesign.success(for: colorScheme))
            }
        }
    }

    private var memoryOverview: some View {
        HStack(spacing: 13) {
            Image(systemName: "text.book.closed.fill")
                .font(.system(size: 22, weight: .medium))
                .foregroundStyle(TransBarInspectorDesign.accent(for: colorScheme))
                .frame(width: 46, height: 46)
                .background(TransBarInspectorDesign.accent(for: colorScheme).opacity(0.1), in: RoundedRectangle(cornerRadius: 13, style: .continuous))
            VStack(alignment: .leading, spacing: 4) {
                Text("把你的专业表达保存下来")
                    .font(.system(size: 14, weight: .semibold))
                Text("术语映射会固定译法，修正样例会作为参考。只保存你主动确认的内容。")
                    .font(.system(size: 11))
                    .foregroundStyle(.secondary)
                    .fixedSize(horizontal: false, vertical: true)
            }
            Spacer(minLength: 16)
            HStack(spacing: 18) {
                memoryMetric("全部", value: manager.items.count)
                memoryMetric("已启用", value: manager.items.filter(\.isEnabled).count, tint: TransBarInspectorDesign.success(for: colorScheme))
            }
        }
        .padding(15)
        .background(TransBarInspectorDesign.accent(for: colorScheme).opacity(colorScheme == .dark ? 0.12 : 0.055), in: RoundedRectangle(cornerRadius: 14, style: .continuous))
        .overlay(RoundedRectangle(cornerRadius: 14, style: .continuous).strokeBorder(TransBarInspectorDesign.accent(for: colorScheme).opacity(colorScheme == .dark ? 0.24 : 0.12)))
    }

    private func memoryMetric(_ title: String, value: Int, tint: Color = .primary) -> some View {
        VStack(alignment: .trailing, spacing: 2) {
            Text("\(value)")
                .font(.system(size: 18, weight: .semibold, design: .rounded))
                .foregroundStyle(tint)
                .monospacedDigit()
            Text(title)
                .font(.system(size: 10))
                .foregroundStyle(.secondary)
        }
    }

    private func languageFilter(_ title: String, selection: Binding<String>, includeAuto: Bool) -> some View {
        let storedCodes = Set(manager.items.map { includeAuto ? $0.sourceLang : $0.targetLang })
        let extraCodes = storedCodes.filter { SupportedLanguages.find(by: $0) == nil }.sorted()
        var options: [(String, String)] = [("all", title)]
        options += SupportedLanguages.all
            .filter { includeAuto || $0.code != "auto" }
            .map { ($0.code, $0.code == "auto" ? "不限源语言" : $0.name) }
        options += extraCodes.map { ($0, $0) }
        return TransBarOptionMenu(title: title, selection: selection, options: options)
    }

    private func memoryRow(_ item: PersonalTranslationMemoryItem) -> some View {
        VStack(alignment: .leading, spacing: 10) {
            HStack(spacing: 7) {
                Text(item.kind == .term ? "术语映射" : "修正样例")
                    .font(.system(size: 10, weight: .semibold))
                    .padding(.horizontal, 7)
                    .padding(.vertical, 3)
                    .foregroundStyle(item.kind == .term ? TransBarInspectorDesign.accent(for: colorScheme) : .secondary)
                    .background((item.kind == .term ? TransBarInspectorDesign.accent(for: colorScheme) : .secondary).opacity(0.08), in: Capsule())
                Text("\(personalMemoryLanguageName(item.sourceLang)) → \(personalMemoryLanguageName(item.targetLang))")
                    .font(.system(size: 10))
                    .foregroundStyle(.secondary)
                    .lineLimit(1)
                Spacer(minLength: 0)
                Toggle("启用", isOn: Binding(
                    get: { manager.items.first(where: { $0.id == item.id })?.isEnabled ?? false },
                    set: { enabled in
                        performAction(success: enabled ? "已启用个人记忆" : "已停用个人记忆") {
                            try manager.setEnabled(id: item.id, enabled: enabled)
                        }
                    }
                ))
                .toggleStyle(.switch)
                .controlSize(.mini)
                .labelsHidden()
                .accessibilityLabel("\(item.isEnabled ? "停用" : "启用")个人记忆：\(item.sourceTerm)")
                .help(item.isEnabled ? "已启用，翻译时可应用" : "已停用，翻译时不应用")
            }
            HStack(alignment: .top, spacing: 12) {
                memoryTextColumn(title: "原文", text: item.sourceTerm, weight: .medium)
                Image(systemName: "arrow.right")
                    .font(.system(size: 11))
                    .foregroundStyle(.tertiary)
                    .padding(.top, 20)
                memoryTextColumn(title: "你的译法", text: item.preferredTranslation, weight: .regular)
            }
            .textSelection(.enabled)
            .lineLimit(item.kind == .term ? 3 : 4)
            .opacity(item.isEnabled ? 1 : 0.55)
            .padding(11)
            .background(Color.primary.opacity(0.028), in: RoundedRectangle(cornerRadius: 9, style: .continuous))
            HStack(alignment: .bottom, spacing: 8) {
                if !item.notes.isEmpty {
                    Text(item.notes)
                        .font(.system(size: 11))
                        .foregroundStyle(.secondary)
                        .lineLimit(2)
                        .textSelection(.enabled)
                }
                Spacer(minLength: 0)
                Button { presentation = .editor(item) } label: {
                    Label("编辑", systemImage: "square.and.pencil")
                }
                .buttonStyle(TransBarInspectorButtonStyle(variant: .ghost, size: .mini))
                .accessibilityLabel("编辑个人记忆：\(item.sourceTerm)")
                Button(role: .destructive) { presentation = .deletion(item) } label: {
                    Image(systemName: "trash")
                }
                .buttonStyle(TransBarInspectorButtonStyle(variant: .destructive, size: .mini))
                .accessibilityLabel("删除个人记忆：\(item.sourceTerm)")
            }
        }
        .padding(13)
        .frame(maxWidth: .infinity, alignment: .leading)
        .transBarInspectorSurface(cornerRadius: 11)
    }

    private func memoryTextColumn(title: String, text: String, weight: Font.Weight) -> some View {
        VStack(alignment: .leading, spacing: 5) {
            Text(title.uppercased())
                .font(.system(size: 10, weight: .semibold))
                .foregroundStyle(.tertiary)
            Text(text)
                .font(.system(size: 13, weight: weight))
                .frame(maxWidth: .infinity, alignment: .leading)
        }
        .frame(maxWidth: .infinity, alignment: .leading)
    }

    private var emptyState: some View {
        VStack(spacing: 10) {
            Spacer()
            Image(systemName: hasFilters ? "magnifyingglass" : "text.book.closed")
                .font(.system(size: 30, weight: .light))
                .foregroundStyle(.tertiary)
            Text(hasFilters ? "没有匹配的个人记忆" : "为你的专业表达留一份对照")
                .font(.system(size: 14, weight: .medium))
            Text(hasFilters ? "试试更短的关键词，或重置语言与类型筛选。" : "新增术语映射，或在修正译文时勾选“记住这次修正”。")
                .font(.system(size: 12))
                .foregroundStyle(.secondary)
                .multilineTextAlignment(.center)
            if hasFilters {
                Button("重置筛选", action: resetFilters)
                    .buttonStyle(TransBarInspectorButtonStyle(variant: .secondary, size: .small))
            }
            Spacer()
        }
        .padding(20)
        .frame(maxWidth: .infinity)
    }

    private var filteredItems: [PersonalTranslationMemoryItem] {
        let query = searchText.trimmingCharacters(in: .whitespacesAndNewlines)
        return manager.items.filter { item in
            (sourceFilter == "all" || item.sourceLang == sourceFilter)
                && (targetFilter == "all" || item.targetLang == targetFilter)
                && (kindFilter == "all" || item.kind.rawValue == kindFilter)
                && (query.isEmpty || [item.sourceTerm, item.preferredTranslation, item.notes].contains { $0.localizedCaseInsensitiveContains(query) })
        }
        .sorted { $0.updatedAt > $1.updatedAt }
    }

    private var hasFilters: Bool {
        !searchText.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty
            || sourceFilter != "all" || targetFilter != "all" || kindFilter != "all"
    }

    private func resetFilters() {
        searchText = ""
        sourceFilter = "all"
        targetFilter = "all"
        kindFilter = "all"
    }

    private func performAction(success: String, _ action: () throws -> Void) {
        do {
            try action()
            actionError = nil
            actionFeedback = success
        } catch {
            actionFeedback = nil
            actionError = error.localizedDescription
        }
    }
}

private struct PersonalMemoryDeleteConfirmationView: View {
    @Environment(\.dismiss) private var dismiss
    let item: PersonalTranslationMemoryItem
    let onDelete: () throws -> Void
    let onDeleted: () -> Void
    @State private var deleteError: String?

    var body: some View {
        VStack(alignment: .leading, spacing: 16) {
            Label(item.kind == .term ? "删除这条术语映射？" : "删除这条修正样例？", systemImage: "trash")
                .font(.system(size: 17, weight: .semibold))
            VStack(alignment: .leading, spacing: 9) {
                Text("\(personalMemoryLanguageName(item.sourceLang)) → \(personalMemoryLanguageName(item.targetLang))")
                    .font(.system(size: 11))
                    .foregroundStyle(.secondary)
                Text(item.sourceTerm)
                    .font(.system(size: 13, weight: .medium))
                    .lineLimit(3)
                Label(item.preferredTranslation, systemImage: "arrow.turn.down.right")
                    .font(.system(size: 13))
                    .foregroundStyle(.secondary)
                    .lineLimit(3)
            }
            .textSelection(.enabled)
            .frame(maxWidth: .infinity, alignment: .leading)
            .padding(13)
            .background(Color.primary.opacity(0.035), in: RoundedRectangle(cornerRadius: 9))
            Text("删除后，后续翻译将不再使用这条个人记忆。此操作无法撤销。")
                .font(.system(size: 12))
                .foregroundStyle(.secondary)
                .fixedSize(horizontal: false, vertical: true)
            if let error = deleteError {
                Label(error, systemImage: "exclamationmark.circle")
                    .font(.system(size: 11))
                    .foregroundStyle(.red)
                    .fixedSize(horizontal: false, vertical: true)
            }
            HStack(spacing: 9) {
                Spacer()
                Button("取消") { dismiss() }
                    .buttonStyle(TransBarInspectorButtonStyle(variant: .secondary, size: .small))
                    .keyboardShortcut(.cancelAction)
                Button("删除", role: .destructive, action: delete)
                    .buttonStyle(TransBarInspectorButtonStyle(variant: .destructive, size: .small))
            }
        }
        .padding(22)
        .frame(width: 420)
    }

    private func delete() {
        do {
            try onDelete()
            onDeleted()
            dismiss()
        } catch {
            deleteError = error.localizedDescription
        }
    }
}

private struct PersonalMemoryEditorView: View {
    @Environment(\.dismiss) private var dismiss
    private let itemID: String?
    private let onSaved: (String) -> Void
    @State private var kind: PersonalTranslationMemoryKind
    @State private var sourceTerm: String
    @State private var preferredTranslation: String
    @State private var sourceLang: String
    @State private var targetLang: String
    @State private var notes: String
    @State private var isEnabled: Bool
    @State private var saveError: String?
    @FocusState private var focusedField: EditorField?

    private enum EditorField: Hashable {
        case sourceTerm
        case preferredTranslation
        case notes
    }

    init(item: PersonalTranslationMemoryItem?, onSaved: @escaping (String) -> Void) {
        itemID = item?.id
        self.onSaved = onSaved
        _kind = State(initialValue: item?.kind ?? .term)
        _sourceTerm = State(initialValue: item?.sourceTerm ?? "")
        _preferredTranslation = State(initialValue: item?.preferredTranslation ?? "")
        _sourceLang = State(initialValue: item?.sourceLang ?? "auto")
        _targetLang = State(initialValue: item?.targetLang ?? AppSettings.shared.lastTargetLanguage)
        _notes = State(initialValue: item?.notes ?? "")
        _isEnabled = State(initialValue: item?.isEnabled ?? true)
    }

    var body: some View {
        VStack(alignment: .leading, spacing: 14) {
            Text(itemID == nil ? "新增个人翻译记忆" : "编辑个人翻译记忆")
                .font(.system(size: 18, weight: .semibold))
            TransBarOptionMenu(
                title: "记忆类型",
                selection: $kind,
                options: [
                    (.term, "术语映射"),
                    (.example, "修正样例")
                ]
            )
            PersonalMemoryLanguagePairPicker(sourceLang: $sourceLang, targetLang: $targetLang)
            editorField(kind == .term ? "原文术语" : "完整原文", text: $sourceTerm, focus: .sourceTerm)
            editorField(kind == .term ? "固定译法" : "修正后的完整译文", text: $preferredTranslation, focus: .preferredTranslation)
            TextField("备注（可选，例如产品名、适用场景）", text: $notes)
                .textFieldStyle(TransBarTextFieldStyle(isFocused: focusedField == .notes))
                .focused($focusedField, equals: .notes)
                .accessibilityLabel("个人记忆备注")
            Toggle("启用这条个人记忆", isOn: $isEnabled)
                .toggleStyle(.switch)
            Text(kind == .term ? "DeepSeek 遇到这组语言中的原文术语时，使用你指定的译法。" : "完整样例供 DeepSeek 参考表达，不会成为所有文本的固定译文。")
                .font(.system(size: 12))
                .foregroundStyle(.secondary)
                .fixedSize(horizontal: false, vertical: true)
            if let error = saveError {
                Label(error, systemImage: "exclamationmark.circle")
                    .font(.system(size: 11))
                    .foregroundStyle(.red)
                    .fixedSize(horizontal: false, vertical: true)
            }
            HStack {
                Spacer()
                Button("取消") { dismiss() }
                    .buttonStyle(TransBarInspectorButtonStyle(variant: .secondary, size: .small))
                    .keyboardShortcut(.cancelAction)
                Button("保存", action: save)
                    .buttonStyle(TransBarInspectorButtonStyle(variant: .primary, size: .small))
                    .keyboardShortcut(.defaultAction)
                    .disabled(sourceTerm.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty || preferredTranslation.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty)
            }
        }
        .padding(22)
        .frame(width: 460)
    }

    private func editorField(_ title: String, text: Binding<String>, focus: EditorField) -> some View {
        VStack(alignment: .leading, spacing: 6) {
            Text(title).font(.system(size: 12, weight: .medium))
            if kind == .term {
                TextField(title, text: text)
                    .textFieldStyle(TransBarTextFieldStyle(isFocused: focusedField == focus))
                    .focused($focusedField, equals: focus)
                    .accessibilityLabel(title)
            } else {
                TextEditor(text: text)
                    .font(.system(size: 13))
                    .scrollContentBackground(.hidden)
                    .padding(8)
                    .frame(height: 65)
                    .focused($focusedField, equals: focus)
                    .transBarInspectorSurface(isFocused: focusedField == focus, cornerRadius: 9)
                    .accessibilityLabel(title)
            }
        }
    }

    private func save() {
        do {
            try PersonalTranslationMemoryManager.shared.upsert(
                sourceTerm: sourceTerm,
                preferredTranslation: preferredTranslation,
                sourceLang: sourceLang,
                targetLang: targetLang,
                notes: notes,
                isEnabled: isEnabled,
                id: itemID,
                kind: kind
            )
            onSaved(itemID == nil ? "已新增个人记忆" : "已保存个人记忆")
            dismiss()
        } catch {
            saveError = error.localizedDescription
        }
    }
}

/// 设置编辑器与译文修正共用相同的语言范围选择。
struct PersonalMemoryLanguagePairPicker: View {
    @Binding var sourceLang: String
    @Binding var targetLang: String

    var body: some View {
        HStack(spacing: 9) {
            TransBarOptionMenu(
                title: "源语言",
                selection: $sourceLang,
                options: SupportedLanguages.all.map { ($0.code, $0.code == "auto" ? "不限源语言" : $0.name) }
                    + (SupportedLanguages.find(by: sourceLang) == nil ? [(sourceLang, sourceLang)] : [])
            )
            Image(systemName: "arrow.right")
                .font(.system(size: 10))
                .foregroundStyle(.secondary)
            TransBarOptionMenu(
                title: "目标语言",
                selection: $targetLang,
                options: SupportedLanguages.all.filter { $0.code != "auto" }.map { ($0.code, $0.name) }
                    + (SupportedLanguages.find(by: targetLang) == nil ? [(targetLang, targetLang)] : [])
            )
        }
    }
}

private func personalMemoryLanguageName(_ code: String) -> String {
    code == "auto" ? "不限源语言" : SupportedLanguages.find(by: code)?.name ?? code
}
