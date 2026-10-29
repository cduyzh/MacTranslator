import SwiftUI

/// 行业与专业知识库设置面板
/// 遵循 Quiet Signal 设计语言与系统底层规范
struct DomainKnowledgeBaseSettingsView: View {
    @ObservedObject private var manager = DomainKnowledgeBaseManager.shared
    @ObservedObject private var settings = AppSettings.shared
    @Environment(\.colorScheme) private var colorScheme
    @Environment(\.accessibilityReduceMotion) private var reduceMotion

    @State private var selectedCategoryId: String = "all"
    @State private var searchText = ""
    @FocusState private var searchFocused: Bool
    @State private var presentation: Presentation?
    @State private var actionFeedback: String?
    @State private var actionError: String?

    private enum Presentation: Identifiable {
        case itemEditor(DomainGlossaryItem?, defaultCategory: String)
        case categoryEditor(DomainGlossaryCategory?)
        case agentChat(defaultCategory: String)
        case importFile
        case deleteCategory(DomainGlossaryCategory)
        case deleteItem(DomainGlossaryItem)
        case resetConfirm

        var id: String {
            switch self {
            case .itemEditor(let item, _): return "item:\(item?.id ?? "new")"
            case .categoryEditor(let cat): return "category:\(cat?.id ?? "new")"
            case .agentChat(let cat): return "agent-chat:\(cat)"
            case .importFile: return "import"
            case .deleteCategory(let cat): return "delete-cat:\(cat.id)"
            case .deleteItem(let item): return "delete-item:\(item.id)"
            case .resetConfirm: return "reset"
            }
        }
    }

    private var filteredItems: [DomainGlossaryItem] {
        manager.items.filter { item in
            if selectedCategoryId != "all" && item.categoryId != selectedCategoryId {
                return false
            }
            if !searchText.isEmpty {
                let query = searchText.trimmingCharacters(in: .whitespacesAndNewlines).lowercased()
                let matchSource = item.sourceTerm.lowercased().contains(query)
                let matchTarget = item.preferredTranslation.lowercased().contains(query)
                let matchNotes = item.notes.lowercased().contains(query)
                if !matchSource && !matchTarget && !matchNotes { return false }
            }
            return true
        }
    }

    var body: some View {
        VStack(spacing: 0) {
            headerControls
                .padding(.horizontal, 24)
                .padding(.top, 16)
                .padding(.bottom, 12)

            Divider()

            categorySelectorBar
                .padding(.horizontal, 24)
                .padding(.vertical, 10)

            Divider()

            if filteredItems.isEmpty {
                emptyStateView
            } else {
                ScrollView(.vertical) {
                    LazyVStack(spacing: 9) {
                        ForEach(filteredItems) { item in
                            itemCard(item)
                        }
                    }
                    .padding(.horizontal, 24)
                    .padding(.vertical, 14)
                }
            }
        }
        .sheet(item: $presentation) { presented in
            switch presented {
            case .itemEditor(let item, let defaultCat):
                GlossaryItemEditorSheet(item: item, defaultCategoryId: defaultCat, categories: manager.categories) { msg in
                    actionFeedback = msg
                    actionError = nil
                }
            case .agentChat(let defaultCat):
                AgentGlossaryChatSheet(defaultCategoryId: defaultCat) { msg in
                    actionFeedback = msg
                    actionError = nil
                }
            case .categoryEditor(let cat):
                GlossaryCategoryEditorSheet(category: cat) { msg in
                    actionFeedback = msg
                    actionError = nil
                }
            case .importFile:
                GlossaryImportSheet(categories: manager.categories, defaultCategoryId: selectedCategoryId == "all" ? (manager.categories.first?.id ?? "") : selectedCategoryId) { msg in
                    actionFeedback = msg
                    actionError = nil
                }
            case .deleteCategory(let cat):
                ConfirmDialogSheet(
                    title: "删除知识库分类？",
                    message: "将删除分类「\(cat.name)」及其名下所有 \(manager.items.filter { $0.categoryId == cat.id }.count) 条专业词汇。此操作无法撤销。",
                    confirmTitle: "确认删除分类",
                    isDestructive: true
                ) {
                    try manager.deleteCategory(id: cat.id)
                    if selectedCategoryId == cat.id { selectedCategoryId = "all" }
                    actionFeedback = "已删除分类「\(cat.name)」"
                }
            case .deleteItem(let item):
                ConfirmDialogSheet(
                    title: "删除词条？",
                    message: "确定要删除词条「\(item.sourceTerm) → \(item.preferredTranslation)」吗？",
                    confirmTitle: "确认删除",
                    isDestructive: true
                ) {
                    try manager.deleteItem(id: item.id)
                    actionFeedback = "已删除词条"
                }
            case .resetConfirm:
                ConfirmDialogSheet(
                    title: "恢复内置官方词库？",
                    message: "将重置知识库为官方默认热梗与俚语领域（网络热梗词、网络俚语，包含中英双向高频词）。自定义添加的内容将被覆盖。",
                    confirmTitle: "确认恢复",
                    isDestructive: false
                ) {
                    try manager.resetToSeeds()
                    actionFeedback = "已恢复默认网络热梗与俚语词库"
                }
            }
        }
        .animation(reduceMotion ? nil : .easeOut(duration: 0.16), value: selectedCategoryId)
        .animation(reduceMotion ? nil : .easeOut(duration: 0.16), value: presentation?.id)
    }

    // MARK: - 头部总览与 Token 管控

    private var headerControls: some View {
        VStack(alignment: .leading, spacing: 14) {
            overviewBanner
            tokenGatekeeperCard
        }
    }

    private var overviewBanner: some View {
        HStack(spacing: 14) {
            Image(systemName: "books.vertical.fill")
                .font(.system(size: 24, weight: .medium))
                .foregroundStyle(TransBarInspectorDesign.accent(for: colorScheme))
                .frame(width: 48, height: 48)
                .background(TransBarInspectorDesign.accent(for: colorScheme).opacity(0.12), in: RoundedRectangle(cornerRadius: 12, style: .continuous))

            VStack(alignment: .leading, spacing: 3) {
                HStack(spacing: 8) {
                    Text("行业与专业知识库")
                        .font(.system(size: 15, weight: .bold))
                    Text("AI Agent 专属")
                        .font(.system(size: 10, weight: .semibold))
                        .padding(.horizontal, 6)
                        .padding(.vertical, 2)
                        .foregroundStyle(TransBarInspectorDesign.accent(for: colorScheme))
                        .background(TransBarInspectorDesign.accent(for: colorScheme).opacity(0.1), in: Capsule())
                }
                Text("导入各行业词库（AI、医学、法律等）。翻译时仅当原文命中时按需提取，杜绝全库填充与 Token 膨胀。")
                    .font(.system(size: 11))
                    .foregroundStyle(.secondary)
                    .fixedSize(horizontal: false, vertical: true)
            }

            Spacer(minLength: 16)

            HStack(spacing: 18) {
                metricCol(title: "领域分类", value: "\(manager.categories.count)")
                metricCol(title: "总词条数", value: "\(manager.items.count)")
                metricCol(title: "有效启用", value: "\(manager.items.filter { item in manager.categories.first(where: { $0.id == item.categoryId })?.isEnabled == true && item.isEnabled }.count)", tint: TransBarInspectorDesign.success(for: colorScheme))
            }
        }
        .padding(14)
        .background(TransBarInspectorDesign.accent(for: colorScheme).opacity(colorScheme == .dark ? 0.10 : 0.045), in: RoundedRectangle(cornerRadius: 12, style: .continuous))
        .overlay(RoundedRectangle(cornerRadius: 12, style: .continuous).strokeBorder(TransBarInspectorDesign.accent(for: colorScheme).opacity(colorScheme == .dark ? 0.22 : 0.12), lineWidth: 0.8))
    }

    private func metricCol(title: String, value: String, tint: Color = .primary) -> some View {
        VStack(alignment: .trailing, spacing: 1) {
            Text(value)
                .font(.system(size: 17, weight: .bold, design: .rounded))
                .foregroundStyle(tint)
                .monospacedDigit()
            Text(title)
                .font(.system(size: 10))
                .foregroundStyle(.secondary)
        }
    }

    private var tokenGatekeeperCard: some View {
        VStack(alignment: .leading, spacing: 9) {
            HStack(alignment: .center, spacing: 12) {
                Toggle("启用行业知识库动态注入", isOn: $settings.knowledgeBaseEnabled)
                    .toggleStyle(.switch)
                    .font(.system(size: 12, weight: .semibold))

                Spacer()

                HStack(spacing: 10) {
                    TransBarOptionMenu(
                        title: "注入条数上限",
                        selection: $settings.knowledgeBaseMaxTerms,
                        options: [5, 10, 15, 20].map { ($0, "最多 \($0) 条") }
                    )
                    TransBarOptionMenu(
                        title: "字符预算上限",
                        selection: $settings.knowledgeBaseMaxCharacters,
                        options: [400, 800, 1200, 1600].map { ($0, "\($0) 字符上限") }
                    )
                }
            }

            HStack(spacing: 6) {
                Image(systemName: "shield.lefthalf.filled")
                    .font(.system(size: 11))
                    .foregroundStyle(TransBarInspectorDesign.accent(for: colorScheme))
                Text("上下文管控机制：仅支持配置 API Key 的 AI Agent；原文未包含专词时不注入；长词特异性优先；Google 免费翻译保持纯净零注入。")
                    .font(.system(size: 10.5))
                    .foregroundStyle(.secondary)
            }
        }
        .padding(.horizontal, 14)
        .padding(.vertical, 10)
        .background(colorScheme == .dark ? Color.white.opacity(0.03) : Color.black.opacity(0.02), in: RoundedRectangle(cornerRadius: 10, style: .continuous))
        .overlay(RoundedRectangle(cornerRadius: 10, style: .continuous).strokeBorder(Color.primary.opacity(0.08), lineWidth: 0.8))
    }

    // MARK: - 分类选择与工具栏

    private var categorySelectorBar: some View {
        VStack(alignment: .leading, spacing: 10) {
            HStack(spacing: 8) {
                // 搜索框
                HStack(spacing: 6) {
                    Image(systemName: "magnifyingglass")
                        .foregroundStyle(TransBarInspectorDesign.secondaryText(for: colorScheme))
                    TextField("搜索原文、译文或行业备注", text: $searchText)
                        .textFieldStyle(.plain)
                        .focused($searchFocused)
                    if !searchText.isEmpty {
                        Button { searchText = "" } label: {
                            Image(systemName: "xmark.circle.fill")
                        }
                        .buttonStyle(TransBarInspectorButtonStyle(variant: .ghost, size: .mini))
                    }
                }
                .padding(.horizontal, 8)
                .frame(height: 30)
                .transBarInspectorSurface(isFocused: searchFocused, cornerRadius: 7)

                Spacer(minLength: 4)

                Button {
                    let defaultCat = selectedCategoryId == "all" ? "auto" : selectedCategoryId
                    presentation = .agentChat(defaultCategory: defaultCat)
                } label: {
                    HStack(spacing: 5) {
                        Image(systemName: "sparkles")
                        Text("Agent 对话新建")
                    }
                }
                .buttonStyle(TransBarInspectorButtonStyle(variant: .primary, size: .small))

                Button {
                    let defaultCat = selectedCategoryId == "all" ? (manager.categories.first?.id ?? "") : selectedCategoryId
                    presentation = .itemEditor(nil, defaultCategory: defaultCat)
                } label: {
                    Label("手动录入", systemImage: "plus")
                }
                .buttonStyle(TransBarInspectorButtonStyle(variant: .secondary, size: .small))

                Button {
                    presentation = .categoryEditor(nil)
                } label: {
                    Label("新建分类", systemImage: "folder.badge.plus")
                }
                .buttonStyle(TransBarInspectorButtonStyle(variant: .secondary, size: .small))

                Menu {
                    Button {
                        presentation = .importFile
                    } label: {
                        Label("从文件导入 (JSON/CSV/TSV/TXT)...", systemImage: "square.and.arrow.down")
                    }

                    Button {
                        exportCurrentCategory(asJSON: false)
                    } label: {
                        Label("导出当前词库 (CSV)", systemImage: "square.and.arrow.up")
                    }

                    Button {
                        exportCurrentCategory(asJSON: true)
                    } label: {
                        Label("导出当前词库 (JSON)", systemImage: "curlybraces")
                    }

                    Divider()

                    Button(role: .destructive) {
                        presentation = .resetConfirm
                    } label: {
                        Label("重置为内置官方词库 (热梗与俚语)...", systemImage: "arrow.counterclockwise")
                    }
                } label: {
                    Image(systemName: "ellipsis.circle")
                        .font(.system(size: 13))
                }
                .buttonStyle(TransBarInspectorButtonStyle(variant: .ghost, size: .small))
            }

            // 分类胶囊选择区
            ScrollView(.horizontal, showsIndicators: false) {
                HStack(spacing: 6) {
                    categoryPill(
                        id: "all",
                        name: "全部",
                        count: manager.items.count,
                        isEnabled: true,
                        isSelected: selectedCategoryId == "all"
                    )

                    ForEach(manager.categories) { cat in
                        let catItemCount = manager.items.filter { $0.categoryId == cat.id }.count
                        categoryPill(
                            id: cat.id,
                            name: cat.name,
                            count: catItemCount,
                            isEnabled: cat.isEnabled,
                            isSelected: selectedCategoryId == cat.id,
                            onEdit: { presentation = .categoryEditor(cat) },
                            onDelete: { presentation = .deleteCategory(cat) }
                        )
                    }
                }
            }

            if let feedback = actionFeedback {
                HStack {
                    Label(feedback, systemImage: "checkmark.circle.fill")
                        .font(.system(size: 11))
                        .foregroundStyle(TransBarInspectorDesign.success(for: colorScheme))
                    Spacer()
                    Button("清除") { actionFeedback = nil }
                        .buttonStyle(TransBarInspectorButtonStyle(variant: .ghost, size: .mini))
                }
            } else if let error = actionError ?? manager.persistenceError {
                HStack {
                    Label(error, systemImage: "exclamationmark.triangle.fill")
                        .font(.system(size: 11))
                        .foregroundStyle(.red)
                    Spacer()
                    Button("清除") { actionError = nil }
                        .buttonStyle(TransBarInspectorButtonStyle(variant: .ghost, size: .mini))
                }
            }
        }
    }

    private func categoryPill(
        id: String,
        name: String,
        count: Int,
        isEnabled: Bool,
        isSelected: Bool,
        onEdit: (() -> Void)? = nil,
        onDelete: (() -> Void)? = nil
    ) -> some View {
        Button {
            selectedCategoryId = id
        } label: {
            HStack(spacing: 5) {
                if !isEnabled {
                    Circle()
                        .fill(Color.secondary.opacity(0.6))
                        .frame(width: 5, height: 5)
                }
                Text(name)
                    .font(.system(size: 11, weight: isSelected ? .semibold : .regular))
                Text("\(count)")
                    .font(.system(size: 9.5, weight: .medium, design: .rounded))
                    .foregroundStyle(isSelected ? Color.white : Color.secondary)
                    .monospacedDigit()
                    .padding(.horizontal, 4)
                    .padding(.vertical, 1)
                    .background(isSelected ? Color.white.opacity(0.25) : Color.primary.opacity(0.06), in: Capsule())
            }
            .padding(.horizontal, 9)
            .padding(.vertical, 5)
            .background(
                isSelected ? TransBarInspectorDesign.accent(for: colorScheme) : (colorScheme == .dark ? Color.white.opacity(0.06) : Color.black.opacity(0.04)),
                in: RoundedRectangle(cornerRadius: 7, style: .continuous)
            )
            .foregroundStyle(isSelected ? Color.white : (isEnabled ? Color.primary : Color.secondary))
            .overlay(
                RoundedRectangle(cornerRadius: 7, style: .continuous)
                    .strokeBorder(isSelected ? Color.clear : Color.primary.opacity(0.08), lineWidth: 0.8)
            )
        }
        .buttonStyle(.plain)
        .contextMenu {
            if id != "all" {
                Button("编辑分类...") { onEdit?() }
                Divider()
                Button("删除分类", role: .destructive) { onDelete?() }
            }
        }
    }

    // MARK: - 词条卡片

    private func itemCard(_ item: DomainGlossaryItem) -> some View {
        let categoryName = manager.categories.first(where: { $0.id == item.categoryId })?.name ?? "未分类"
        let isCatEnabled = manager.categories.first(where: { $0.id == item.categoryId })?.isEnabled ?? true

        return HStack(alignment: .center, spacing: 12) {
            VStack(alignment: .leading, spacing: 4) {
                HStack(spacing: 7) {
                    Text(categoryName)
                        .font(.system(size: 9.5, weight: .semibold))
                        .padding(.horizontal, 6)
                        .padding(.vertical, 2)
                        .foregroundStyle(TransBarInspectorDesign.accent(for: colorScheme))
                        .background(TransBarInspectorDesign.accent(for: colorScheme).opacity(0.09), in: Capsule())

                    Text("\(item.sourceLang) → \(item.targetLang)")
                        .font(.system(size: 9.5))
                        .foregroundStyle(.secondary)

                    if !isCatEnabled {
                        Text("(所属分类已禁用)")
                            .font(.system(size: 9.5))
                            .foregroundStyle(.secondary)
                    }

                    Spacer()
                }

                HStack(alignment: .firstTextBaseline, spacing: 8) {
                    Text(item.sourceTerm)
                        .font(.system(size: 13, weight: .bold))
                        .foregroundStyle(item.isEnabled && isCatEnabled ? .primary : .secondary)

                    Image(systemName: "arrow.right")
                        .font(.system(size: 10, weight: .bold))
                        .foregroundStyle(.secondary)

                    Text(item.preferredTranslation)
                        .font(.system(size: 13, weight: .semibold))
                        .foregroundStyle(TransBarInspectorDesign.accent(for: colorScheme))

                    if !item.notes.isEmpty {
                        Text("• \(item.notes)")
                            .font(.system(size: 11))
                            .foregroundStyle(.secondary)
                            .lineLimit(1)
                    }
                }
            }

            Spacer(minLength: 8)

            HStack(spacing: 8) {
                Toggle("", isOn: Binding(
                    get: { item.isEnabled },
                    set: { enabled in
                        try? manager.setItemEnabled(id: item.id, isEnabled: enabled)
                    }
                ))
                .toggleStyle(.switch)
                .labelsHidden()
                .help(item.isEnabled ? "点击禁用词条" : "点击启用词条")

                Button {
                    presentation = .itemEditor(item, defaultCategory: item.categoryId)
                } label: {
                    Image(systemName: "pencil")
                        .font(.system(size: 11))
                }
                .buttonStyle(TransBarInspectorButtonStyle(variant: .ghost, size: .mini))
                .help("编辑词条")

                Button {
                    presentation = .deleteItem(item)
                } label: {
                    Image(systemName: "trash")
                        .font(.system(size: 11))
                        .foregroundStyle(.red.opacity(0.8))
                }
                .buttonStyle(TransBarInspectorButtonStyle(variant: .ghost, size: .mini))
                .help("删除词条")
            }
        }
        .padding(.horizontal, 14)
        .padding(.vertical, 10)
        .background(colorScheme == .dark ? Color.white.opacity(0.025) : Color.black.opacity(0.018), in: RoundedRectangle(cornerRadius: 9, style: .continuous))
        .overlay(RoundedRectangle(cornerRadius: 9, style: .continuous).strokeBorder(Color.primary.opacity(0.07), lineWidth: 0.8))
    }

    private var emptyStateView: some View {
        VStack(spacing: 12) {
            Spacer()
            Image(systemName: "text.book.closed")
                .font(.system(size: 36))
                .foregroundStyle(.secondary.opacity(0.5))
            Text(searchText.isEmpty ? "当前分类暂无词条" : "未找到匹配「\(searchText)」的专业词汇")
                .font(.system(size: 13, weight: .medium))
                .foregroundStyle(.secondary)
            Button {
                let defaultCat = selectedCategoryId == "all" ? (manager.categories.first?.id ?? "") : selectedCategoryId
                presentation = .itemEditor(nil, defaultCategory: defaultCat)
            } label: {
                Label("新增词条", systemImage: "plus")
            }
            .buttonStyle(TransBarInspectorButtonStyle(variant: .primary, size: .small))
            Spacer()
        }
        .frame(maxWidth: .infinity, maxHeight: .infinity)
    }

    private func exportCurrentCategory(asJSON: Bool) {
        let itemsToExport = selectedCategoryId == "all" ? manager.items : manager.items.filter { $0.categoryId == selectedCategoryId }
        let category = manager.categories.first(where: { $0.id == selectedCategoryId })
        let fileContent = asJSON ? DomainKnowledgeBaseImporter.exportJSON(items: itemsToExport, category: category) : DomainKnowledgeBaseImporter.exportCSV(items: itemsToExport)
        let savePanel = NSSavePanel()
        savePanel.allowedContentTypes = asJSON ? [.json] : [.commaSeparatedText]
        savePanel.nameFieldStringValue = (category?.name ?? "domain-glossary") + (asJSON ? ".json" : ".csv")

        if savePanel.runModal() == .OK, let url = savePanel.url {
            do {
                try fileContent.write(to: url, atomically: true, encoding: .utf8)
                actionFeedback = "已导出 \(itemsToExport.count) 条词汇到文件"
            } catch {
                actionError = "导出失败：\(error.localizedDescription)"
            }
        }
    }
}

// MARK: - 词条编辑弹窗

struct GlossaryItemEditorSheet: View {
    @Environment(\.dismiss) private var dismiss
    @Environment(\.colorScheme) private var colorScheme
    @ObservedObject private var manager = DomainKnowledgeBaseManager.shared

    let item: DomainGlossaryItem?
    let defaultCategoryId: String
    let categories: [DomainGlossaryCategory]
    let onSave: (String) -> Void

    @State private var categoryId: String = ""
    @State private var sourceTerm = ""
    @State private var preferredTranslation = ""
    @State private var sourceLang = "auto"
    @State private var targetLang = "zh-CN"
    @State private var notes = ""
    @State private var isEnabled = true
    @State private var errorMessage: String?
    @State private var isEnriching = false

    init(item: DomainGlossaryItem?, defaultCategoryId: String, categories: [DomainGlossaryCategory], onSave: @escaping (String) -> Void) {
        self.item = item
        self.defaultCategoryId = defaultCategoryId
        self.categories = categories
        self.onSave = onSave
        _categoryId = State(initialValue: item?.categoryId ?? defaultCategoryId)
        _sourceTerm = State(initialValue: item?.sourceTerm ?? "")
        _preferredTranslation = State(initialValue: item?.preferredTranslation ?? "")
        _sourceLang = State(initialValue: item?.sourceLang ?? "auto")
        _targetLang = State(initialValue: item?.targetLang ?? "zh-CN")
        _notes = State(initialValue: item?.notes ?? "")
        _isEnabled = State(initialValue: item?.isEnabled ?? true)
    }

    var body: some View {
        VStack(spacing: 0) {
            HStack {
                Text(item == nil ? "新增专业词条" : "编辑词条")
                    .font(.system(size: 15, weight: .bold))
                Spacer()
                Button { dismiss() } label: {
                    Image(systemName: "xmark")
                        .font(.system(size: 11, weight: .semibold))
                }
                .buttonStyle(TransBarInspectorButtonStyle(variant: .ghost, size: .mini))
            }
            .padding(.horizontal, 20)
            .padding(.vertical, 16)

            Divider()

            ScrollView {
                VStack(alignment: .leading, spacing: 14) {
                    if let error = errorMessage {
                        Label(error, systemImage: "exclamationmark.circle.fill")
                            .font(.system(size: 12))
                            .foregroundStyle(.red)
                    }

                    VStack(alignment: .leading, spacing: 5) {
                        Text("所属领域分类")
                            .font(.system(size: 11, weight: .semibold))
                            .foregroundStyle(.secondary)
                        TransBarOptionMenu(
                            title: "分类",
                            selection: $categoryId,
                            options: categories.map { ($0.id, $0.name) }
                        )
                    }

                    VStack(alignment: .leading, spacing: 5) {
                        HStack {
                            Text("原文专业词汇 / 缩写")
                                .font(.system(size: 11, weight: .semibold))
                                .foregroundStyle(.secondary)
                            Spacer()
                            Button {
                                enrichWithAgent()
                            } label: {
                                HStack(spacing: 3) {
                                    if isEnriching {
                                        ProgressView().scaleEffect(0.55).frame(width: 12, height: 12)
                                    } else {
                                        Image(systemName: "sparkles")
                                            .font(.system(size: 10))
                                    }
                                    Text("AI 智能分析")
                                        .font(.system(size: 10.5, weight: .medium))
                                }
                            }
                            .buttonStyle(TransBarInspectorButtonStyle(variant: .ghost, size: .mini))
                            .disabled(isEnriching || sourceTerm.trimmingCharacters(in: .whitespaces).isEmpty)
                        }
                        TextField("例如：fine-tuning, context window, general practitioner", text: $sourceTerm)
                            .textFieldStyle(.roundedBorder)
                    }

                    VStack(alignment: .leading, spacing: 5) {
                        Text("推荐译法 (Target)")
                            .font(.system(size: 11, weight: .semibold))
                            .foregroundStyle(.secondary)
                        TextField("例如：微调, 上下文窗口, 全科医生", text: $preferredTranslation)
                            .textFieldStyle(.roundedBorder)
                    }

                    HStack(spacing: 12) {
                        VStack(alignment: .leading, spacing: 5) {
                            Text("源语言")
                                .font(.system(size: 11, weight: .semibold))
                                .foregroundStyle(.secondary)
                            TransBarOptionMenu(
                                title: "源语言",
                                selection: $sourceLang,
                                options: SupportedLanguages.all.map { ($0.code, $0.code == "auto" ? "自动识别" : $0.name) }
                            )
                        }

                        VStack(alignment: .leading, spacing: 5) {
                            Text("目标语言")
                                .font(.system(size: 11, weight: .semibold))
                                .foregroundStyle(.secondary)
                            TransBarOptionMenu(
                                title: "目标语言",
                                selection: $targetLang,
                                options: SupportedLanguages.all.filter { $0.code != "auto" }.map { ($0.code, $0.name) }
                            )
                        }
                    }

                    VStack(alignment: .leading, spacing: 5) {
                        Text("行业备注 (选填)")
                            .font(.system(size: 11, weight: .semibold))
                            .foregroundStyle(.secondary)
                        TextField("例如：机器学习专属；医疗临床试验术语", text: $notes)
                            .textFieldStyle(.roundedBorder)
                    }

                    Toggle("启用此词条", isOn: $isEnabled)
                        .toggleStyle(.switch)
                        .font(.system(size: 12))
                }
                .padding(20)
            }

            Divider()

            HStack {
                Button("取消") { dismiss() }
                    .buttonStyle(TransBarInspectorButtonStyle(variant: .ghost))
                Spacer()
                Button("保存") { save() }
                    .buttonStyle(TransBarInspectorButtonStyle(variant: .primary))
            }
            .padding(.horizontal, 20)
            .padding(.vertical, 14)
        }
        .frame(width: 440, height: 490)
    }

    private func save() {
        guard !sourceTerm.trimmingCharacters(in: .whitespaces).isEmpty else {
            errorMessage = "请输入原文词汇"
            return
        }
        guard !preferredTranslation.trimmingCharacters(in: .whitespaces).isEmpty else {
            errorMessage = "请输入推荐译法"
            return
        }
        let targetCat = categoryId.isEmpty ? (categories.first?.id ?? "") : categoryId
        guard !targetCat.isEmpty else {
            errorMessage = "请选择分类"
            return
        }

        do {
            try manager.upsertItem(
                categoryId: targetCat,
                sourceTerm: sourceTerm,
                preferredTranslation: preferredTranslation,
                sourceLang: sourceLang,
                targetLang: targetLang,
                notes: notes,
                isEnabled: isEnabled,
                id: item?.id
            )
            onSave(item == nil ? "已添加词条「\(sourceTerm)」" : "已更新词条「\(sourceTerm)」")
            dismiss()
        } catch {
            errorMessage = error.localizedDescription
        }
    }

    private func enrichWithAgent() {
        let term = sourceTerm.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !term.isEmpty else { return }

        isEnriching = true
        errorMessage = nil

        let currentCatName = categories.first(where: { $0.id == categoryId })?.name

        Task { @MainActor in
            do {
                let enriched = try await AgentGlossaryAssistant.shared.analyzeAndEnrichTerm(
                    term: term,
                    preferredCategoryName: currentCatName,
                    existingCategories: categories
                )
                self.preferredTranslation = enriched.preferredTranslation
                self.sourceLang = enriched.sourceLang
                self.targetLang = enriched.targetLang
                if !enriched.notes.isEmpty {
                    self.notes = enriched.notes
                }
                if let matchedCat = categories.first(where: {
                    DomainKnowledgeBaseManager.normalized($0.name) == DomainKnowledgeBaseManager.normalized(enriched.suggestedCategoryName)
                }) {
                    self.categoryId = matchedCat.id
                }
                self.isEnriching = false
            } catch {
                self.isEnriching = false
                self.errorMessage = error.localizedDescription
            }
        }
    }
}

// MARK: - 分类编辑弹窗

struct GlossaryCategoryEditorSheet: View {
    @Environment(\.dismiss) private var dismiss
    @ObservedObject private var manager = DomainKnowledgeBaseManager.shared

    let category: DomainGlossaryCategory?
    let onSave: (String) -> Void

    @State private var name: String = ""
    @State private var description: String = ""
    @State private var isEnabled: Bool = true
    @State private var errorMessage: String?

    init(category: DomainGlossaryCategory?, onSave: @escaping (String) -> Void) {
        self.category = category
        self.onSave = onSave
        _name = State(initialValue: category?.name ?? "")
        _description = State(initialValue: category?.description ?? "")
        _isEnabled = State(initialValue: category?.isEnabled ?? true)
    }

    var body: some View {
        VStack(spacing: 0) {
            HStack {
                Text(category == nil ? "新建领域分类" : "编辑分类")
                    .font(.system(size: 15, weight: .bold))
                Spacer()
                Button { dismiss() } label: {
                    Image(systemName: "xmark")
                        .font(.system(size: 11, weight: .semibold))
                }
                .buttonStyle(TransBarInspectorButtonStyle(variant: .ghost, size: .mini))
            }
            .padding(.horizontal, 20)
            .padding(.vertical, 16)

            Divider()

            VStack(alignment: .leading, spacing: 14) {
                if let error = errorMessage {
                    Label(error, systemImage: "exclamationmark.circle.fill")
                        .font(.system(size: 12))
                        .foregroundStyle(.red)
                }

                VStack(alignment: .leading, spacing: 5) {
                    Text("分类名称")
                        .font(.system(size: 11, weight: .semibold))
                        .foregroundStyle(.secondary)
                    TextField("例如：半导体芯片、跨境电商、游戏动漫", text: $name)
                        .textFieldStyle(.roundedBorder)
                }

                VStack(alignment: .leading, spacing: 5) {
                    Text("分类描述 (选填)")
                        .font(.system(size: 11, weight: .semibold))
                        .foregroundStyle(.secondary)
                    TextField("简述该领域的适用范围或专业背景", text: $description)
                        .textFieldStyle(.roundedBorder)
                }

                Toggle("启用此分类（停用后该分类下所有词汇暂不注入 Prompt）", isOn: $isEnabled)
                    .toggleStyle(.switch)
                    .font(.system(size: 12))

                Spacer()
            }
            .padding(20)

            Divider()

            HStack {
                Button("取消") { dismiss() }
                    .buttonStyle(TransBarInspectorButtonStyle(variant: .ghost))
                Spacer()
                Button("保存") { save() }
                    .buttonStyle(TransBarInspectorButtonStyle(variant: .primary))
            }
            .padding(.horizontal, 20)
            .padding(.vertical, 14)
        }
        .frame(width: 420, height: 320)
    }

    private func save() {
        guard !name.trimmingCharacters(in: .whitespaces).isEmpty else {
            errorMessage = "分类名称不能为空"
            return
        }
        do {
            if let existing = category {
                try manager.updateCategory(id: existing.id, name: name, description: description, isEnabled: isEnabled)
                onSave("已更新分类「\(name)」")
            } else {
                try manager.addCategory(name: name, description: description, isEnabled: isEnabled)
                onSave("已创建分类「\(name)」")
            }
            dismiss()
        } catch {
            errorMessage = error.localizedDescription
        }
    }
}

// MARK: - 文件导入弹窗

struct GlossaryImportSheet: View {
    @Environment(\.dismiss) private var dismiss
    @ObservedObject private var manager = DomainKnowledgeBaseManager.shared

    let categories: [DomainGlossaryCategory]
    let defaultCategoryId: String
    let onImported: (String) -> Void

    @State private var selectedCategoryId: String = ""
    @State private var pastedText = ""
    @State private var statusMessage: String?
    @State private var errorMessage: String?

    init(categories: [DomainGlossaryCategory], defaultCategoryId: String, onImported: @escaping (String) -> Void) {
        self.categories = categories
        self.defaultCategoryId = defaultCategoryId
        self.onImported = onImported
        _selectedCategoryId = State(initialValue: defaultCategoryId)
    }

    var body: some View {
        VStack(spacing: 0) {
            HStack {
                Text("导入专业词库")
                    .font(.system(size: 15, weight: .bold))
                Spacer()
                Button { dismiss() } label: {
                    Image(systemName: "xmark")
                        .font(.system(size: 11, weight: .semibold))
                }
                .buttonStyle(TransBarInspectorButtonStyle(variant: .ghost, size: .mini))
            }
            .padding(.horizontal, 20)
            .padding(.vertical, 16)

            Divider()

            VStack(alignment: .leading, spacing: 14) {
                HStack {
                    VStack(alignment: .leading, spacing: 4) {
                        Text("目标分类")
                            .font(.system(size: 11, weight: .semibold))
                            .foregroundStyle(.secondary)
                        TransBarOptionMenu(
                            title: "分类",
                            selection: $selectedCategoryId,
                            options: categories.map { ($0.id, $0.name) }
                        )
                    }
                    Spacer()
                    Button("选择本地文件...") {
                        selectLocalFile()
                    }
                    .buttonStyle(TransBarInspectorButtonStyle(variant: .secondary, size: .small))
                }

                VStack(alignment: .leading, spacing: 4) {
                    Text("或直接粘贴词库内容（支持 JSON / CSV / TSV / 纯文本每一行「原文 = 译文」）")
                        .font(.system(size: 11, weight: .semibold))
                        .foregroundStyle(.secondary)

                    TextEditor(text: $pastedText)
                        .font(.system(size: 12, design: .monospaced))
                        .frame(height: 200)
                        .padding(4)
                        .overlay(RoundedRectangle(cornerRadius: 6).strokeBorder(Color.primary.opacity(0.12), lineWidth: 0.8))
                }

                if let error = errorMessage {
                    Label(error, systemImage: "exclamationmark.circle.fill")
                        .font(.system(size: 11))
                        .foregroundStyle(.red)
                } else if let status = statusMessage {
                    Label(status, systemImage: "checkmark.circle.fill")
                        .font(.system(size: 11))
                        .foregroundStyle(.green)
                }

                Spacer()
            }
            .padding(20)

            Divider()

            HStack {
                Button("取消") { dismiss() }
                    .buttonStyle(TransBarInspectorButtonStyle(variant: .ghost))
                Spacer()
                Button("执行导入") {
                    performImport()
                }
                .buttonStyle(TransBarInspectorButtonStyle(variant: .primary))
                .disabled(pastedText.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty)
            }
            .padding(.horizontal, 20)
            .padding(.vertical, 14)
        }
        .frame(width: 520, height: 440)
    }

    private func selectLocalFile() {
        let panel = NSOpenPanel()
        panel.allowedContentTypes = [.json, .commaSeparatedText, .tabSeparatedText, .plainText]
        panel.allowsMultipleSelection = false
        panel.canChooseDirectories = false

        if panel.runModal() == .OK, let url = panel.url {
            if let content = try? String(contentsOf: url, encoding: .utf8) {
                pastedText = content
                statusMessage = "已读取文件：\(url.lastPathComponent)"
                errorMessage = nil
            }
        }
    }

    private func performImport() {
        let parsed = DomainKnowledgeBaseImporter.parse(content: pastedText)
        guard !parsed.isEmpty else {
            errorMessage = "未能解析出有效词条，请检查格式"
            return
        }

        let catId = selectedCategoryId.isEmpty ? (categories.first?.id ?? "") : selectedCategoryId
        guard !catId.isEmpty else {
            errorMessage = "请选择目标分类"
            return
        }

        var added = 0
        var updated = 0
        do {
            for t in parsed {
                let exists = manager.items.contains {
                    $0.categoryId == catId && DomainKnowledgeBaseManager.normalized($0.sourceTerm) == DomainKnowledgeBaseManager.normalized(t.source)
                }
                try manager.upsertItem(
                    categoryId: catId,
                    sourceTerm: t.source,
                    preferredTranslation: t.target,
                    sourceLang: t.sourceLang ?? "auto",
                    targetLang: t.targetLang ?? "zh-CN",
                    notes: t.notes ?? ""
                )
                if exists { updated += 1 } else { added += 1 }
            }
            onImported("成功导入 \(added) 条新增词条，\(updated) 条更新")
            dismiss()
        } catch {
            errorMessage = "导入失败：\(error.localizedDescription)"
        }
    }
}

// MARK: - 确认操作弹窗

struct ConfirmDialogSheet: View {
    @Environment(\.dismiss) private var dismiss

    let title: String
    let message: String
    let confirmTitle: String
    let isDestructive: Bool
    let onConfirm: () throws -> Void

    @State private var errorText: String?

    var body: some View {
        VStack(spacing: 0) {
            VStack(alignment: .leading, spacing: 12) {
                HStack(spacing: 10) {
                    Image(systemName: isDestructive ? "exclamationmark.triangle.fill" : "questionmark.circle.fill")
                        .font(.system(size: 20))
                        .foregroundStyle(isDestructive ? .red : .accentColor)
                    Text(title)
                        .font(.system(size: 15, weight: .bold))
                }

                Text(message)
                    .font(.system(size: 12))
                    .foregroundStyle(.secondary)
                    .fixedSize(horizontal: false, vertical: true)

                if let err = errorText {
                    Text(err)
                        .font(.system(size: 11))
                        .foregroundStyle(.red)
                }
            }
            .padding(22)

            Divider()

            HStack {
                Button("取消") { dismiss() }
                    .buttonStyle(TransBarInspectorButtonStyle(variant: .ghost))
                Spacer()
                Button(confirmTitle) {
                    do {
                        try onConfirm()
                        dismiss()
                    } catch {
                        errorText = error.localizedDescription
                    }
                }
                .buttonStyle(TransBarInspectorButtonStyle(variant: isDestructive ? .destructive : .primary))
            }
            .padding(.horizontal, 20)
            .padding(.vertical, 14)
        }
        .frame(width: 380)
    }
}

// MARK: - Agent 智能对话新建词条弹窗

struct AgentGlossaryChatSheet: View {
    @Environment(\.dismiss) private var dismiss
    @Environment(\.colorScheme) private var colorScheme
    @ObservedObject private var manager = DomainKnowledgeBaseManager.shared
    @ObservedObject private var assistant = AgentGlossaryAssistant.shared
    @ObservedObject private var settings = AppSettings.shared

    let defaultCategoryId: String
    let onCommit: (String) -> Void

    @State private var promptText: String = ""
    @State private var selectedTargetCategory: String = "auto"
    @State private var drafts: [AgentGeneratedGlossaryDraft] = []
    @State private var errorMessage: String?
    @State private var statusFeedback: String?
    @FocusState private var inputFocused: Bool

    private let suggestions = [
        "🔥 扩充 5 个近期火爆的双向网络热梗",
        "💬 提取 5 个日常社交网聊缩写与流行俚语",
        "💻 补充大语言模型 (LLM) 与微调核心专业术语",
        "💼 提取国际商贸涉外合同常见法律条款"
    ]

    init(defaultCategoryId: String = "auto", onCommit: @escaping (String) -> Void) {
        self.defaultCategoryId = defaultCategoryId
        self.onCommit = onCommit
        _selectedTargetCategory = State(initialValue: defaultCategoryId)
    }

    private var hasApiKey: Bool {
        !settings.deepSeekApiKey.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty
    }

    private var selectedCount: Int {
        drafts.filter(\.isSelected).count
    }

    var body: some View {
        VStack(spacing: 0) {
            headerBar
            Divider()

            if !hasApiKey {
                apiKeyWarningBanner
            }

            ScrollView {
                VStack(alignment: .leading, spacing: 14) {
                    promptInputSection

                    if !suggestions.isEmpty && drafts.isEmpty {
                        suggestionChipsSection
                    }

                    if assistant.isGenerating {
                        loadingIndicator
                    } else if !drafts.isEmpty {
                        draftsResultSection
                    }

                    if let error = errorMessage {
                        HStack(spacing: 6) {
                            Image(systemName: "exclamationmark.circle.fill")
                                .foregroundStyle(.red)
                            Text(error)
                                .font(.system(size: 11.5))
                                .foregroundStyle(.red)
                        }
                        .padding(.top, 4)
                    }

                    if let feedback = statusFeedback {
                        HStack(spacing: 6) {
                            Image(systemName: "checkmark.circle.fill")
                                .foregroundStyle(.green)
                            Text(feedback)
                                .font(.system(size: 11.5))
                                .foregroundStyle(.green)
                        }
                        .padding(.top, 4)
                    }
                }
                .padding(20)
            }

            Divider()
            bottomActionBar
        }
        .frame(width: 580, height: 600)
    }

    // MARK: - 头部栏

    private var headerBar: some View {
        HStack(spacing: 10) {
            Image(systemName: "sparkles")
                .font(.system(size: 15, weight: .bold))
                .foregroundStyle(TransBarInspectorDesign.accent(for: colorScheme))

            VStack(alignment: .leading, spacing: 2) {
                HStack(spacing: 6) {
                    Text("AI Agent 对话新建词条")
                        .font(.system(size: 15, weight: .bold))
                    Text(settings.selectedModel.isEmpty ? "DeepSeek" : settings.selectedModel)
                        .font(.system(size: 10, weight: .semibold, design: .monospaced))
                        .padding(.horizontal, 6)
                        .padding(.vertical, 2)
                        .foregroundStyle(TransBarInspectorDesign.accent(for: colorScheme))
                        .background(TransBarInspectorDesign.accent(for: colorScheme).opacity(0.12), in: Capsule())
                }
                Text("输入自然语言需求，AI Agent 将自主检索并结构化解析为专业词条，一键写入本地文件管理")
                    .font(.system(size: 11))
                    .foregroundStyle(.secondary)
            }

            Spacer()

            Button { dismiss() } label: {
                Image(systemName: "xmark")
                    .font(.system(size: 11, weight: .semibold))
            }
            .buttonStyle(TransBarInspectorButtonStyle(variant: .ghost, size: .mini))
        }
        .padding(.horizontal, 20)
        .padding(.vertical, 14)
    }

    // MARK: - 缺少 API Key 提示

    private var apiKeyWarningBanner: some View {
        HStack(spacing: 10) {
            Image(systemName: "key.fill")
                .font(.system(size: 13))
                .foregroundStyle(.orange)
            VStack(alignment: .leading, spacing: 2) {
                Text("尚未配置 AI Agent API Key")
                    .font(.system(size: 12, weight: .bold))
                Text("Agent 对话与智能建词功能需要有效的 DeepSeek API Key。请前往「设置 - API Key」配置。")
                    .font(.system(size: 11))
                    .foregroundStyle(.secondary)
            }
            Spacer()
        }
        .padding(12)
        .background(Color.orange.opacity(0.1), in: RoundedRectangle(cornerRadius: 8, style: .continuous))
        .overlay(RoundedRectangle(cornerRadius: 8, style: .continuous).strokeBorder(Color.orange.opacity(0.25), lineWidth: 0.8))
        .padding(.horizontal, 20)
        .padding(.top, 12)
    }

    // MARK: - 需求输入区

    private var promptInputSection: some View {
        VStack(alignment: .leading, spacing: 8) {
            HStack {
                Text("对话需求 / 词汇提取指令")
                    .font(.system(size: 12, weight: .semibold))
                    .foregroundStyle(.secondary)
                Spacer()
                // 目标归属分类选择
                HStack(spacing: 6) {
                    Text("存入分类:")
                        .font(.system(size: 11))
                        .foregroundStyle(.secondary)
                    TransBarOptionMenu(
                        title: "目标分类",
                        selection: $selectedTargetCategory,
                        options: [("auto", "✨ 智能建议或新建")] + manager.categories.map { ($0.id, $0.name) }
                    )
                }
            }

            HStack(alignment: .top, spacing: 8) {
                TextField("输入例如：生成 5 个最新的网络流行热梗与地道英译；或粘贴段落让 Agent 提炼专词...", text: $promptText, axis: .vertical)
                    .textFieldStyle(.plain)
                    .lineLimit(3...5)
                    .focused($inputFocused)
                    .padding(8)
                    .transBarInspectorSurface(isFocused: inputFocused, cornerRadius: 8)

                Button {
                    sendToAgent()
                } label: {
                    VStack(spacing: 4) {
                        Image(systemName: assistant.isGenerating ? "ellipsis" : "paperplane.fill")
                            .font(.system(size: 13))
                        Text("提炼")
                            .font(.system(size: 11, weight: .bold))
                    }
                    .frame(width: 48, height: 60)
                }
                .buttonStyle(TransBarInspectorButtonStyle(variant: .primary))
                .disabled(assistant.isGenerating || promptText.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty || !hasApiKey)
            }
        }
    }

    // MARK: - 快捷气泡推荐

    private var suggestionChipsSection: some View {
        VStack(alignment: .leading, spacing: 6) {
            Text("快捷指令推荐")
                .font(.system(size: 11, weight: .semibold))
                .foregroundStyle(.secondary)

            FlowLayout(spacing: 6) {
                ForEach(suggestions, id: \.self) { suggestion in
                    Button {
                        promptText = suggestion.replacingOccurrences(of: "🔥 ", with: "")
                            .replacingOccurrences(of: "💬 ", with: "")
                            .replacingOccurrences(of: "💻 ", with: "")
                            .replacingOccurrences(of: "💼 ", with: "")
                        sendToAgent()
                    } label: {
                        Text(suggestion)
                            .font(.system(size: 11))
                            .padding(.horizontal, 9)
                            .padding(.vertical, 5)
                            .background(colorScheme == .dark ? Color.white.opacity(0.06) : Color.black.opacity(0.04), in: Capsule())
                            .overlay(Capsule().strokeBorder(Color.primary.opacity(0.08), lineWidth: 0.6))
                    }
                    .buttonStyle(.plain)
                    .disabled(!hasApiKey || assistant.isGenerating)
                }
            }
        }
        .padding(.vertical, 4)
    }

    // MARK: - 加载指示器

    private var loadingIndicator: some View {
        HStack(spacing: 10) {
            ProgressView()
                .scaleEffect(0.8)
            VStack(alignment: .leading, spacing: 2) {
                Text("AI Agent 正在分析并结构化提炼词条...")
                    .font(.system(size: 12, weight: .semibold))
                Text("按照 TransBar 行业词库标准格式输出中，请稍候...")
                    .font(.system(size: 10.5))
                    .foregroundStyle(.secondary)
            }
            Spacer()
        }
        .padding(14)
        .background(TransBarInspectorDesign.accent(for: colorScheme).opacity(0.08), in: RoundedRectangle(cornerRadius: 10, style: .continuous))
    }

    // MARK: - 生成结果草稿列表

    private var draftsResultSection: some View {
        VStack(alignment: .leading, spacing: 10) {
            HStack {
                Text("Agent 提炼草稿 (\(drafts.count) 条)")
                    .font(.system(size: 12, weight: .bold))

                Spacer()

                Button(drafts.allSatisfy(\.isSelected) ? "取消全选" : "全选") {
                    let next = !drafts.allSatisfy(\.isSelected)
                    for i in 0..<drafts.count { drafts[i].isSelected = next }
                }
                .buttonStyle(TransBarInspectorButtonStyle(variant: .ghost, size: .mini))
            }

            VStack(spacing: 8) {
                ForEach($drafts) { $draft in
                    draftCard(draft: $draft)
                }
            }
        }
    }

    private func draftCard(draft: Binding<AgentGeneratedGlossaryDraft>) -> some View {
        HStack(alignment: .top, spacing: 10) {
            Toggle("", isOn: draft.isSelected)
                .labelsHidden()
                .toggleStyle(.checkbox)
                .padding(.top, 2)

            VStack(alignment: .leading, spacing: 4) {
                HStack(spacing: 8) {
                    Text(draft.wrappedValue.sourceTerm)
                        .font(.system(size: 13, weight: .bold))
                        .foregroundStyle(.primary)

                    Image(systemName: "arrow.right")
                        .font(.system(size: 10, weight: .semibold))
                        .foregroundStyle(.secondary)

                    Text(draft.wrappedValue.preferredTranslation)
                        .font(.system(size: 13, weight: .semibold))
                        .foregroundStyle(TransBarInspectorDesign.accent(for: colorScheme))

                    Spacer()

                    // 分类标签
                    if !draft.wrappedValue.suggestedCategoryName.isEmpty {
                        Text(draft.wrappedValue.suggestedCategoryName)
                            .font(.system(size: 10, weight: .medium))
                            .padding(.horizontal, 6)
                            .padding(.vertical, 2)
                            .background(Color.primary.opacity(0.06), in: RoundedRectangle(cornerRadius: 4, style: .continuous))
                    }

                    // 语言流向
                    Text("\(draft.wrappedValue.sourceLang) ➔ \(draft.wrappedValue.targetLang)")
                        .font(.system(size: 9.5, weight: .medium, design: .monospaced))
                        .foregroundStyle(.secondary)
                }

                if !draft.wrappedValue.notes.isEmpty {
                    Text(draft.wrappedValue.notes)
                        .font(.system(size: 11))
                        .foregroundStyle(.secondary)
                        .fixedSize(horizontal: false, vertical: true)
                }
            }
        }
        .padding(10)
        .background(colorScheme == .dark ? Color.white.opacity(0.04) : Color.black.opacity(0.025), in: RoundedRectangle(cornerRadius: 8, style: .continuous))
        .overlay(RoundedRectangle(cornerRadius: 8, style: .continuous).strokeBorder(draft.wrappedValue.isSelected ? TransBarInspectorDesign.accent(for: colorScheme).opacity(0.4) : Color.primary.opacity(0.06), lineWidth: 0.8))
    }

    // MARK: - 底部操作栏

    private var bottomActionBar: some View {
        HStack {
            Button("取消") { dismiss() }
                .buttonStyle(TransBarInspectorButtonStyle(variant: .ghost))

            Spacer()

            if selectedCount > 0 {
                Text("已选 \(selectedCount) 条词汇")
                    .font(.system(size: 11))
                    .foregroundStyle(.secondary)
            }

            Button {
                commitDrafts()
            } label: {
                HStack(spacing: 5) {
                    Image(systemName: "square.and.arrow.down.fill")
                    Text("写入本地知识库 (\(selectedCount))")
                }
            }
            .buttonStyle(TransBarInspectorButtonStyle(variant: .primary))
            .disabled(selectedCount == 0 || assistant.isGenerating)
        }
        .padding(.horizontal, 20)
        .padding(.vertical, 12)
    }

    // MARK: - 交互操作

    private func sendToAgent() {
        let prompt = promptText.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !prompt.isEmpty else { return }

        errorMessage = nil
        statusFeedback = nil

        let preferredCategory = selectedTargetCategory == "auto" ? nil : manager.categories.first(where: { $0.id == selectedTargetCategory })?.name

        Task { @MainActor in
            do {
                let results = try await assistant.chatAndGenerate(
                    prompt: prompt,
                    contextCategoryName: preferredCategory,
                    existingCategories: manager.categories
                )
                self.drafts = results
                if results.isEmpty {
                    self.errorMessage = "未能提炼出有效词条，请尝试更详细的指令或关键词"
                }
            } catch {
                self.errorMessage = error.localizedDescription
            }
        }
    }

    private func commitDrafts() {
        guard selectedCount > 0 else { return }
        errorMessage = nil

        let targetCatId = selectedTargetCategory == "auto" ? nil : selectedTargetCategory

        do {
            let result = try assistant.commitToKnowledgeBase(
                drafts: drafts,
                defaultCategoryId: targetCatId,
                manager: manager
            )
            let catStr = result.categoryNames.joined(separator: "、")
            onCommit("成功通过 Agent 对话新增 \(result.savedCount) 条词汇到本地词库 [\(catStr)]")
            dismiss()
        } catch {
            errorMessage = "写入本地知识库失败：\(error.localizedDescription)"
        }
    }
}

/// 简易流式布局容器
private struct FlowLayout: Layout {
    var spacing: CGFloat = 6

    func sizeThatFits(proposal: ProposedViewSize, subviews: Subviews, cache: inout ()) -> CGSize {
        let width = proposal.width ?? 500
        var height: CGFloat = 0
        var currentX: CGFloat = 0
        var currentY: CGFloat = 0
        var rowHeight: CGFloat = 0

        for subview in subviews {
            let size = subview.sizeThatFits(.unspecified)
            if currentX + size.width > width && currentX > 0 {
                currentX = 0
                currentY += rowHeight + spacing
                rowHeight = 0
            }
            rowHeight = max(rowHeight, size.height)
            currentX += size.width + spacing
        }
        height = currentY + rowHeight
        return CGSize(width: width, height: height)
    }

    func placeSubviews(in bounds: CGRect, proposal: ProposedViewSize, subviews: Subviews, cache: inout ()) {
        var currentX: CGFloat = bounds.minX
        var currentY: CGFloat = bounds.minY
        var rowHeight: CGFloat = 0

        for subview in subviews {
            let size = subview.sizeThatFits(.unspecified)
            if currentX + size.width > bounds.maxX && currentX > bounds.minX {
                currentX = bounds.minX
                currentY += rowHeight + spacing
                rowHeight = 0
            }
            subview.place(at: CGPoint(x: currentX, y: currentY), proposal: .unspecified)
            rowHeight = max(rowHeight, size.height)
            currentX += size.width + spacing
        }
    }
}
