import SwiftUI
import AppKit

/// 版本更新与更新日志视图
public struct VersionUpdateView: View {
    @ObservedObject var settings = AppSettings.shared
    @ObservedObject var updateChecker = AppUpdateChecker.shared
    @State private var changelogManager = ChangelogManager.shared
    @State private var copyFeedback: String?
    @State private var copyFeedbackID = UUID()
    @Environment(\.accessibilityReduceMotion) private var reduceMotion
    @Environment(\.colorScheme) private var colorScheme

    private let dateFormatter: DateFormatter = {
        let df = DateFormatter()
        df.dateStyle = .medium
        df.timeStyle = .short
        return df
    }()

    public init() {}

    public var body: some View {
        ScrollView(.vertical) {
            VStack(alignment: .leading, spacing: 16) {
                // 1. 当前版本与检查卡片
                versionStatusCard

                // 2. 自动检查偏好设置卡片
                updateSettingsCard

                // 3. 更新日志与发版历史
                changelogSection
            }
            .padding(20)
        }
    }

    // MARK: - 当前版本状态卡片
    private var versionStatusCard: some View {
        VStack(alignment: .leading, spacing: 12) {
            HStack(spacing: 14) {
                // 应用图标
                if let appIcon = NSImage(named: NSImage.applicationIconName) {
                    Image(nsImage: appIcon)
                        .resizable()
                        .frame(width: 48, height: 48)
                        .clipShape(RoundedRectangle(cornerRadius: 10, style: .continuous))
                        .shadow(color: .black.opacity(0.12), radius: 3, x: 0, y: 1)
                } else {
                    ZStack {
                        RoundedRectangle(cornerRadius: 10, style: .continuous)
                            .fill(TransBarInspectorDesign.accent(for: colorScheme).opacity(0.15))
                        Image(systemName: "globe")
                            .font(.system(size: 24))
                            .foregroundStyle(TransBarInspectorDesign.accent(for: colorScheme))
                    }
                    .frame(width: 48, height: 48)
                }

                VStack(alignment: .leading, spacing: 3) {
                    HStack(alignment: .firstTextBaseline, spacing: 8) {
                        Text(AppVersion.appName)
                            .font(.system(size: 16, weight: .bold))
                        Text(AppVersion.current.fullDisplayString)
                            .font(.system(size: 13, weight: .medium, design: .monospaced))
                            .foregroundStyle(.secondary)
                    }

                    HStack(spacing: 6) {
                        statusBadgeView
                    }
                }

                Spacer()

                // 检查更新主按钮
                Button(action: triggerCheck) {
                    HStack(spacing: 6) {
                        if updateChecker.isChecking {
                            ProgressView()
                                .controlSize(.small)
                        } else {
                            Image(systemName: "arrow.triangle.2.circlepath")
                                .font(.system(size: 12, weight: .semibold))
                        }
                        Text(updateChecker.isChecking ? "正在检查…" : "检查更新")
                    }
                }
                .buttonStyle(TransBarInspectorButtonStyle(variant: updateChecker.hasUpdate ? .secondary : .primary, size: .regular))
                .disabled(updateChecker.isChecking)
                .accessibilityLabel("检查更新")
            }

            // 新版本可用行动呼吁卡片
            if updateChecker.hasUpdate, let latest = updateChecker.latestVersion {
                HStack(spacing: 12) {
                    Image(systemName: "sparkles")
                        .font(.system(size: 16, weight: .semibold))
                        .foregroundStyle(TransBarInspectorDesign.accent(for: colorScheme))

                    VStack(alignment: .leading, spacing: 2) {
                        Text("发现新版本 v\(latest.description)")
                            .font(.system(size: 13, weight: .semibold))
                        if let note = updateChecker.latestReleaseNote {
                            Text(note.title)
                                .font(.system(size: 12))
                                .foregroundStyle(.secondary)
                                .lineLimit(1)
                        }
                    }

                    Spacer()

                    Button("前往下载更新") {
                        updateChecker.openDownloadPage()
                    }
                    .buttonStyle(TransBarInspectorButtonStyle(variant: .primary, size: .small))
                }
                .padding(12)
                .background(TransBarInspectorDesign.accent(for: colorScheme).opacity(0.08), in: RoundedRectangle(cornerRadius: 10, style: .continuous))
                .overlay(RoundedRectangle(cornerRadius: 10, style: .continuous).strokeBorder(TransBarInspectorDesign.accent(for: colorScheme).opacity(0.2), lineWidth: 0.75))
            }

            // 错误提示
            if let err = updateChecker.errorMessage {
                HStack(spacing: 6) {
                    Image(systemName: "exclamationmark.triangle.fill")
                        .foregroundStyle(Color.orange)
                        .font(.system(size: 12))
                    Text(err)
                        .font(.system(size: 11))
                        .foregroundStyle(.secondary)
                }
            }

            Divider()

            HStack {
                Text(lastCheckSummary)
                    .font(.system(size: 11))
                    .foregroundStyle(.secondary)
                Spacer()
                Button {
                    updateChecker.openDownloadPage()
                } label: {
                    Label("GitHub Releases", systemImage: "arrow.up.right")
                }
                .buttonStyle(TransBarInspectorButtonStyle(variant: .ghost, size: .mini))
                .help("在浏览器中查看 GitHub 版本与安装包")
            }
        }
        .padding(14)
        .background(TransBarInspectorDesign.surfaceGradient(for: colorScheme), in: RoundedRectangle(cornerRadius: 12, style: .continuous))
        .overlay(RoundedRectangle(cornerRadius: 12, style: .continuous).strokeBorder(Color.primary.opacity(0.06), lineWidth: 0.75))
    }

    private var statusBadgeView: some View {
        Group {
            if updateChecker.hasUpdate {
                HStack(spacing: 4) {
                    Circle().fill(Color.orange).frame(width: 6, height: 6)
                    Text("有新版本可用")
                        .font(.system(size: 11, weight: .medium))
                        .foregroundStyle(Color.orange)
                }
                .padding(.horizontal, 6)
                .padding(.vertical, 2)
                .background(Color.orange.opacity(0.12), in: Capsule())
            } else if updateChecker.isChecking {
                HStack(spacing: 4) {
                    ProgressView().controlSize(.mini)
                    Text("检测中")
                        .font(.system(size: 11))
                        .foregroundStyle(.secondary)
                }
                .padding(.horizontal, 6)
                .padding(.vertical, 2)
                .background(Color.primary.opacity(0.05), in: Capsule())
            } else if updateChecker.errorMessage != nil {
                Label("检查失败，可重试", systemImage: "exclamationmark.circle")
                    .font(.system(size: 11, weight: .medium))
                    .foregroundStyle(.orange)
            } else if case .upToDate = updateChecker.checkResult {
                HStack(spacing: 4) {
                    Circle().fill(TransBarInspectorDesign.success(for: colorScheme)).frame(width: 6, height: 6)
                    Text("已是最新版本")
                        .font(.system(size: 11, weight: .medium))
                        .foregroundStyle(TransBarInspectorDesign.success(for: colorScheme))
                }
                .padding(.horizontal, 6)
                .padding(.vertical, 2)
                .background(TransBarInspectorDesign.success(for: colorScheme).opacity(0.12), in: Capsule())
            } else {
                Label("等待检查", systemImage: "clock")
                    .font(.system(size: 11))
                    .foregroundStyle(.secondary)
            }
        }
    }

    private var lastCheckSummary: String {
        if let date = updateChecker.lastCheckDate {
            return "上次检查时间: \(dateFormatter.string(from: date))"
        }
        return "尚未进行过检查"
    }

    // MARK: - 更新设置卡片
    private var updateSettingsCard: some View {
        VStack(alignment: .leading, spacing: 12) {
            Text("更新偏好")
                .font(.system(size: 12, weight: .semibold))
                .foregroundStyle(.secondary)

            Toggle(isOn: $settings.autoCheckUpdateEnabled) {
                VStack(alignment: .leading, spacing: 3) {
                    Text("启动与后台自动检查更新")
                        .font(.system(size: 13, weight: .medium))
                    Text("开启后将在应用启动或周期空闲时在后台轻量检测新版本，保持应用处于最佳状态。")
                        .font(.system(size: 11))
                        .foregroundStyle(.secondary)
                }
            }
            .toggleStyle(.checkbox)
        }
        .padding(14)
        .background(TransBarInspectorDesign.surfaceGradient(for: colorScheme), in: RoundedRectangle(cornerRadius: 12, style: .continuous))
        .overlay(RoundedRectangle(cornerRadius: 12, style: .continuous).strokeBorder(Color.primary.opacity(0.06), lineWidth: 0.75))
    }

    // MARK: - 更新日志与发版历史
    private var changelogSection: some View {
        VStack(alignment: .leading, spacing: 12) {
            HStack {
                VStack(alignment: .leading, spacing: 2) {
                    Text("更新日志与发版历史")
                        .font(.system(size: 12, weight: .semibold))
                        .foregroundStyle(.secondary)
                    Text("清晰掌握每一代版本的演进细节、新功能与底层优化。")
                        .font(.system(size: 11))
                        .foregroundStyle(.secondary)
                }
                Spacer()

                Button(action: copyAllChangelog) {
                    Label(copyFeedback == nil ? "复制日志" : "已复制", systemImage: copyFeedback == nil ? "doc.on.doc" : "checkmark")
                }
                .buttonStyle(TransBarInspectorButtonStyle(variant: .secondary, size: .small))
                .help("将全部更新日志复制为 Markdown")
                .disabled(changelogManager.releases.isEmpty)
            }

            VStack(spacing: 14) {
                ForEach(changelogManager.releases) { release in
                    releaseCard(release)
                }
            }
        }
    }

    private func releaseCard(_ release: ReleaseNoteItem) -> some View {
        let isCurrent = (AppVersion(string: release.version) == AppVersion.current)
        let isNewer = (AppVersion(string: release.version) ?? AppVersion(major: 0, minor: 0, patch: 0)) > AppVersion.current

        return VStack(alignment: .leading, spacing: 10) {
            // 版本头部
            HStack(alignment: .firstTextBaseline, spacing: 8) {
                Text("v\(release.version)")
                    .font(.system(size: 15, weight: .bold, design: .rounded))

                Text(release.releaseDate)
                    .font(.system(size: 12))
                    .foregroundStyle(.secondary)

                if isCurrent {
                    Text("当前版本")
                        .font(.system(size: 10, weight: .semibold))
                        .foregroundStyle(TransBarInspectorDesign.accent(for: colorScheme))
                        .padding(.horizontal, 6)
                        .padding(.vertical, 2)
                        .background(TransBarInspectorDesign.accent(for: colorScheme).opacity(0.12), in: Capsule())
                } else if isNewer {
                    Text("可升级")
                        .font(.system(size: 10, weight: .semibold))
                        .foregroundStyle(TransBarInspectorDesign.success(for: colorScheme))
                        .padding(.horizontal, 6)
                        .padding(.vertical, 2)
                        .background(TransBarInspectorDesign.success(for: colorScheme).opacity(0.12), in: Capsule())
                }

                Spacer()

                Text("Build \(release.buildNumber)")
                    .font(.system(size: 11, design: .monospaced))
                    .foregroundStyle(.tertiary)
            }

            // 一句话描述更新内容
            Text(release.summary.isEmpty ? release.title : release.summary)
                .font(.system(size: 12.5))
                .foregroundStyle(.primary.opacity(0.88))
                .lineSpacing(2.5)
                .fixedSize(horizontal: false, vertical: true)
        }
        .padding(13)
        .background(TransBarInspectorDesign.surfaceGradient(for: colorScheme), in: RoundedRectangle(cornerRadius: 12, style: .continuous))
        .overlay(
            RoundedRectangle(cornerRadius: 12, style: .continuous)
                .strokeBorder(isCurrent ? TransBarInspectorDesign.accent(for: colorScheme).opacity(0.35) : Color.primary.opacity(0.06), lineWidth: isCurrent ? 1.5 : 0.75)
        )
    }

    // MARK: - 操作方法
    private func triggerCheck() {
        Task {
            await updateChecker.checkForUpdates(isManual: true)
        }
    }

    private func copyAllChangelog() {
        let markdown = changelogManager.exportFullChangelogMarkdown()
        NSPasteboard.general.clearContents()
        NSPasteboard.general.setString(markdown, forType: .string)

        withAnimation(reduceMotion ? nil : .easeOut(duration: 0.15)) {
            copyFeedback = "已复制完整日志！"
        }
        let id = UUID()
        copyFeedbackID = id
        DispatchQueue.main.asyncAfter(deadline: .now() + 2) {
            if copyFeedbackID == id {
                withAnimation(reduceMotion ? nil : .easeOut(duration: 0.15)) {
                    copyFeedback = nil
                }
            }
        }
    }
}
