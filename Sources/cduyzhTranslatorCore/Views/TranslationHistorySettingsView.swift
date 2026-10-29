import SwiftUI
import AppKit

/// 翻译历史记录面板
/// 遵循 Quiet Signal 原生工业设计规范与商业化配额限制：
/// - 免费用户：最多存储 50 条记录，超额自动淘汰最早记录
/// - Pro 会员 / 试用用户：无限制存储全部记录
public struct TranslationHistorySettingsView: View {
    @ObservedObject private var historyManager = TranslationHistoryManager.shared
    @ObservedObject private var licenseManager = LicenseManager.shared
    @Environment(\.colorScheme) private var colorScheme
    @Environment(\.accessibilityReduceMotion) private var reduceMotion

    @State private var searchText: String = ""
    @State private var selectedEngine: String = "all"
    @State private var showClearConfirm: Bool = false
    @State private var copiedItemId: UUID? = nil
    @State private var feedbackMessage: String? = nil

    private var filteredItems: [TranslationHistoryItem] {
        historyManager.items.filter { item in
            if selectedEngine != "all" && item.engine.lowercased() != selectedEngine.lowercased() {
                return false
            }
            if !searchText.isEmpty {
                let query = searchText.trimmingCharacters(in: .whitespacesAndNewlines).lowercased()
                let matchSource = item.sourceText.lowercased().contains(query)
                let matchTarget = item.translatedText.lowercased().contains(query)
                if !matchSource && !matchTarget { return false }
            }
            return true
        }
    }

    public init() {}

    public var body: some View {
        VStack(spacing: 0) {
            // 头部概览与商业化配额栏
            headerSection
                .padding(.horizontal, 24)
                .padding(.top, 16)
                .padding(.bottom, 12)

            Divider()

            // 搜索与控制过滤栏
            filterControlsBar
                .padding(.horizontal, 24)
                .padding(.vertical, 10)

            Divider()

            // 历史记录列表区
            if filteredItems.isEmpty {
                emptyStateView
            } else {
                ScrollView(.vertical) {
                    LazyVStack(spacing: 9) {
                        ForEach(filteredItems) { item in
                            historyCard(item)
                        }
                    }
                    .padding(.horizontal, 24)
                    .padding(.vertical, 12)
                }
            }
        }
        .confirmationDialog("确定要清空全部翻译历史记录吗？", isPresented: $showClearConfirm, titleVisibility: .visible) {
            Button("清空全部记录", role: .destructive) {
                historyManager.clearAll()
                feedbackMessage = "已清空全部翻译历史"
            }
            Button("取消", role: .cancel) {}
        } message: {
            Text("此操作将永久删除当前保存在本地的所有翻译历史记录，无法撤销。")
        }
    }

    // MARK: - 头部总览与配额卡片
    private var headerSection: some View {
        VStack(alignment: .leading, spacing: 12) {
            HStack(spacing: 14) {
                Image(systemName: "clock.arrow.circlepath")
                    .font(.system(size: 24, weight: .medium))
                    .foregroundStyle(TransBarInspectorDesign.accent(for: colorScheme))
                    .frame(width: 48, height: 48)
                    .background(TransBarInspectorDesign.accent(for: colorScheme).opacity(0.12), in: RoundedRectangle(cornerRadius: 12, style: .continuous))

                VStack(alignment: .leading, spacing: 3) {
                    Text("翻译历史记录")
                        .font(.system(size: 16, weight: .bold))
                        .foregroundStyle(.primary)

                    Text("按时间保存本地翻译记录。专业术语已迁移至行业知识库统一管理。")
                        .font(.system(size: 11.5))
                        .foregroundStyle(.secondary)
                }

                Spacer()
            }
        }
    }

    // MARK: - 搜索与过滤控制
    private var filterControlsBar: some View {
        HStack(spacing: 10) {
            // 搜索框
            HStack(spacing: 6) {
                Image(systemName: "magnifyingglass")
                    .font(.system(size: 11))
                    .foregroundStyle(.secondary)
                TextField("搜索历史原文或译文...", text: $searchText)
                    .textFieldStyle(.plain)
                    .font(.system(size: 11.5))
                if !searchText.isEmpty {
                    Button { searchText = "" } label: {
                        Image(systemName: "xmark.circle.fill")
                            .font(.system(size: 11))
                    }
                    .buttonStyle(.plain)
                }
            }
            .padding(.horizontal, 8)
            .frame(height: 28)
            .background(Color(NSColor.controlBackgroundColor), in: RoundedRectangle(cornerRadius: 6, style: .continuous))
            .overlay(RoundedRectangle(cornerRadius: 6).strokeBorder(Color.primary.opacity(0.1), lineWidth: 0.8))

            Spacer()

            // 数量提示
            Text("共 \(filteredItems.count) 条记录")
                .font(.system(size: 11).monospacedDigit())
                .foregroundStyle(.secondary)

            // 清空按钮
            if !historyManager.items.isEmpty {
                Button {
                    showClearConfirm = true
                } label: {
                    Label("清空历史", systemImage: "trash")
                }
                .buttonStyle(TransBarInspectorButtonStyle(variant: .secondary, size: .small))
            }
        }
    }

    // MARK: - 历史记录卡片
    private func historyCard(_ item: TranslationHistoryItem) -> some View {
        VStack(alignment: .leading, spacing: 7) {
            // 顶部信息：语言方向 + 引擎微标 + 时间
            HStack(spacing: 6) {
                Text("\(item.sourceLang) → \(item.targetLang)")
                    .font(.system(size: 10, weight: .bold, design: .monospaced))
                    .foregroundStyle(Color.accentColor)
                    .padding(.horizontal, 5)
                    .padding(.vertical, 1.5)
                    .background(Color.accentColor.opacity(0.10), in: RoundedRectangle(cornerRadius: 4, style: .continuous))

                Text(item.engine)
                    .font(.system(size: 10, weight: .medium, design: .monospaced))
                    .foregroundStyle(.secondary)
                    .padding(.horizontal, 4)
                    .padding(.vertical, 1.5)
                    .background(Color.primary.opacity(0.04), in: RoundedRectangle(cornerRadius: 4, style: .continuous))

                Spacer()

                Text(formatTimestamp(item.timestamp))
                    .font(.system(size: 10, design: .monospaced))
                    .foregroundStyle(.tertiary)
            }

            // 原文
            Text(item.sourceText)
                .font(.system(size: 12))
                .foregroundStyle(.primary)
                .lineLimit(3)

            // 译文
            HStack(alignment: .bottom, spacing: 8) {
                Text(item.translatedText)
                    .font(.system(size: 12, weight: .medium))
                    .foregroundStyle(colorScheme == .dark ? Color(red: 0.40, green: 0.80, blue: 1.0) : Color(red: 0.05, green: 0.35, blue: 0.80))
                    .lineLimit(4)

                Spacer(minLength: 4)

                // 复制按钮
                Button {
                    copyToClipboard(item.translatedText, id: item.id)
                } label: {
                    HStack(spacing: 3) {
                        Image(systemName: copiedItemId == item.id ? "checkmark" : "doc.on.doc")
                        Text(copiedItemId == item.id ? "已复制" : "复制")
                    }
                    .font(.system(size: 10.5))
                }
                .buttonStyle(TransBarInspectorButtonStyle(variant: .ghost, size: .mini))

                // 删除按钮
                Button {
                    historyManager.delete(id: item.id)
                } label: {
                    Image(systemName: "xmark")
                        .font(.system(size: 9))
                }
                .buttonStyle(TransBarInspectorButtonStyle(variant: .ghost, size: .mini))
                .help("删除此条记录")
            }
        }
        .padding(11)
        .background(Color(NSColor.controlBackgroundColor).opacity(0.85), in: RoundedRectangle(cornerRadius: 10, style: .continuous))
        .overlay(
            RoundedRectangle(cornerRadius: 10, style: .continuous)
                .strokeBorder(Color.primary.opacity(0.06), lineWidth: 0.8)
        )
    }

    // MARK: - 空状态
    private var emptyStateView: some View {
        VStack(spacing: 12) {
            Spacer()
            Image(systemName: "clock.arrow.circlepath")
                .font(.system(size: 36, weight: .light))
                .foregroundStyle(.tertiary)

            Text("暂无翻译历史记录")
                .font(.system(size: 14, weight: .medium))
                .foregroundStyle(.secondary)

            Text("使用快捷键划词翻译或在主窗口翻译后，记录将自动按时间保存在这里。")
                .font(.system(size: 11.5))
                .foregroundStyle(.tertiary)
                .multilineTextAlignment(.center)
                .frame(maxWidth: 320)
            Spacer()
        }
        .padding(32)
    }

    // MARK: - 辅助方法
    private func copyToClipboard(_ text: String, id: UUID) {
        let pasteboard = NSPasteboard.general
        pasteboard.clearContents()
        pasteboard.setString(text, forType: .string)
        copiedItemId = id
        DispatchQueue.main.asyncAfter(deadline: .now() + 1.5) {
            if self.copiedItemId == id {
                self.copiedItemId = nil
            }
        }
    }

    private func formatTimestamp(_ date: Date) -> String {
        let interval = Date().timeIntervalSince(date)
        if interval < 60 {
            return "刚刚"
        } else if interval < 3600 {
            let minutes = Int(interval / 60)
            return "\(minutes) 分钟前"
        } else if Calendar.current.isDateInToday(date) {
            let formatter = DateFormatter()
            formatter.dateFormat = "HH:mm"
            return "今天 \(formatter.string(from: date))"
        } else if Calendar.current.isDateInYesterday(date) {
            let formatter = DateFormatter()
            formatter.dateFormat = "HH:mm"
            return "昨天 \(formatter.string(from: date))"
        } else {
            let formatter = DateFormatter()
            formatter.dateFormat = "yyyy-MM-dd HH:mm"
            return formatter.string(from: date)
        }
    }
}
