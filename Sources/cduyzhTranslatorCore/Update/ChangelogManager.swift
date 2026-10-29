import Foundation

/// 单个版本的更新日志条目
public struct ReleaseNoteItem: Identifiable, Codable, Hashable {
    public var id: String { version }
    
    public let version: String
    public let buildNumber: Int
    public let releaseDate: String
    public let title: String
    public let summary: String
    public let highlights: [String]
    public let features: [String]
    public let improvements: [String]
    public let bugFixes: [String]
    public let downloadUrl: String?

    public init(
        version: String,
        buildNumber: Int,
        releaseDate: String,
        title: String,
        summary: String,
        highlights: [String] = [],
        features: [String] = [],
        improvements: [String] = [],
        bugFixes: [String] = [],
        downloadUrl: String? = nil
    ) {
        self.version = version
        self.buildNumber = buildNumber
        self.releaseDate = releaseDate
        self.title = title
        self.summary = summary
        self.highlights = highlights
        self.features = features
        self.improvements = improvements
        self.bugFixes = bugFixes
        self.downloadUrl = downloadUrl
    }

    /// 格式化为精美的 Markdown 文本
    public var markdownRepresentation: String {
        var lines: [String] = []
        lines.append("## \(version) (\(releaseDate)) - \(title)")
        lines.append("")
        if !summary.isEmpty {
            lines.append(summary)
            lines.append("")
        }
        if !highlights.isEmpty {
            lines.append("### 🌟 核心亮点")
            for h in highlights {
                lines.append("- \(h)")
            }
            lines.append("")
        }
        if !features.isEmpty {
            lines.append("### ✨ 新增功能")
            for f in features {
                lines.append("- \(f)")
            }
            lines.append("")
        }
        if !improvements.isEmpty {
            lines.append("### ⚡️ 体验与性能优化")
            for i in improvements {
                lines.append("- \(i)")
            }
            lines.append("")
        }
        if !bugFixes.isEmpty {
            lines.append("### 🐞 问题修复")
            for b in bugFixes {
                lines.append("- \(b)")
            }
            lines.append("")
        }
        return lines.joined(separator: "\n")
    }
}

/// 更新日志与发版记录管理器
public final class ChangelogManager {
    public static let shared = ChangelogManager()

    /// 内置历史版本全量更新日志
    public private(set) var releases: [ReleaseNoteItem] = []

    private init() {
        self.releases = Self.loadDefaultReleases()
    }

    /// 重置为初始内置发布历史 (用于状态重置与单元测试隔离)
    public func resetToDefaults() {
        self.releases = Self.loadDefaultReleases()
    }

    /// 获取最新版本更新日志
    public var latestRelease: ReleaseNoteItem? {
        return releases.first
    }

    /// 获取对应版本的更新日志
    public func release(for version: String) -> ReleaseNoteItem? {
        let clean = version.trimmingCharacters(in: CharacterSet(charactersIn: "vV "))
        return releases.first { $0.version == clean }
    }

    /// 导出为完整 Markdown 文档
    public func exportFullChangelogMarkdown() -> String {
        var doc = "# 译栏 TransBar 更新日志与发布历史\n\n"
        for release in releases {
            doc += release.markdownRepresentation + "\n---\n\n"
        }
        return doc
    }

    /// 导出为 JSON 字符串
    public func exportAsJSON() -> String {
        let encoder = JSONEncoder()
        encoder.outputFormatting = [.prettyPrinted, .sortedKeys]
        guard let data = try? encoder.encode(releases),
              let string = String(data: data, encoding: .utf8) else {
            return "[]"
        }
        return string
    }

    /// 注入/合并来自远端更新源的新版更新日志
    public func registerRemoteRelease(_ item: ReleaseNoteItem) {
        if let idx = releases.firstIndex(where: { $0.version == item.version }) {
            releases[idx] = item
        } else {
            // 按版本号逆序插入
            releases.insert(item, at: 0)
            releases.sort { (r1, r2) -> Bool in
                let v1 = AppVersion(string: r1.version) ?? AppVersion(major: 0, minor: 0, patch: 0)
                let v2 = AppVersion(string: r2.version) ?? AppVersion(major: 0, minor: 0, patch: 0)
                return v1 > v2
            }
        }
    }

    // MARK: - 内置发布历史数据
    private static func loadDefaultReleases() -> [ReleaseNoteItem] {
        return [
            ReleaseNoteItem(
                version: "1.0.0",
                buildNumber: 1,
                releaseDate: "2026-10-29",
                title: "译栏 TransBar 初始版本正式发布",
                summary: "极速极简的 macOS 原生状态栏划词翻译工具，深度集成 Google 与 DeepSeek 思考模型，支持本地自学习记忆库与全局热键。",
                highlights: [
                    "极速极简的 macOS 原生状态栏划词翻译工具，深度集成 Google 与 DeepSeek 思考模型，支持本地自学习记忆库与全局热键。"
                ],
                features: [
                    "Google 免费 RPC 与 DeepSeek 双引擎快速切换",
                    "Command+C+C 双击划词极速秒翻与全局热键支持",
                    "本地自学习个人翻译记忆库与专业知识库管理",
                    "毛玻璃悬浮状态控制面板与 API 连通性健康检测"
                ],
                improvements: [
                    "纯原生 SwiftUI + AppKit 架构，启动速度低于 200ms",
                    "所有数据与 API 密钥仅保存在本机权限受限文件，本地优先绝不上传"
                ],
                bugFixes: []
            )
        ]
    }
}
