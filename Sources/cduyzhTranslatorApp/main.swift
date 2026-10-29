import AppKit
import Foundation
import cduyzhTranslatorCore

// MARK: - 主入口与模式分流
@MainActor
func main() async {
    let args = CommandLine.arguments
    if args.count > 1 {
        await handleCommandLineMode(args: args)
    } else {
        let app = NSApplication.shared
        let delegate = AppDelegate()
        app.delegate = delegate
        app.setActivationPolicy(.accessory) // 纯状态栏无 Dock 图标常驻
        app.run()
    }
}

@MainActor
func handleCommandLineMode(args: [String]) async {
    if args.contains("--help") || args.contains("-h") {
        print("""
        译栏 TransBar - macOS 智能翻译工具 CLI & GUI
        
        用法:
          cduyzhTranslator                           以状态栏图形界面启动
          cduyzhTranslator --translate "文本"        命令行即时翻译
          cduyzhTranslator --translate "文本" --target ja --engine deepseek
          cduyzhTranslator --models                  列出可用 DeepSeek 模型
          cduyzhTranslator --memory                  查看并导出个人翻译记忆
          cduyzhTranslator --prompt                  导出适合注入 Agent 的提示词上下文
          cduyzhTranslator --stats                   输出调用量与 Token 统计
          cduyzhTranslator --version / -v            查看当前应用版本与构建号
          cduyzhTranslator --changelog               查看应用完整更新日志与发布历史
          cduyzhTranslator --check-update            在线检测新版本更新
        """)
        exit(0)
    }

    if args.contains("--version") || args.contains("-v") {
        let curr = AppVersion.current
        print("\(AppVersion.appName) \(curr.fullDisplayString)")
        exit(0)
    }

    if args.contains("--changelog") {
        print(ChangelogManager.shared.exportFullChangelogMarkdown())
        exit(0)
    }

    if args.contains("--check-update") {
        print("正在检查 \(AppVersion.appName) 版本更新...")
        let result = await AppUpdateChecker.shared.checkForUpdates(isManual: true)
        switch result {
        case .upToDate(let curr):
            print("✅ 当前已是最新版本: v\(curr.description) (Build \(curr.buildNumber ?? 1))")
        case .updateAvailable(let latest, let curr, let note, let download):
            print("🚀 发现新版本: v\(latest.description) (当前版本: v\(curr.description))")
            if let n = note {
                print("【更新标题】: \(n.title)")
                if !n.summary.isEmpty {
                    print("【版本概述】: \(n.summary)")
                }
                if !n.highlights.isEmpty {
                    print("【核心亮点】:")
                    for h in n.highlights {
                        print("  * \(h)")
                    }
                }
            }
            if let dl = download {
                print("【下载链接】: \(dl.absoluteString)")
            }
        case .failed(let err):
            print("❌ 检查更新失败: \(err)")
        }
        exit(0)
    }
    
    if args.contains("--models") {
        let key = AppSettings.shared.deepSeekApiKey
        do {
            let models = try await DeepSeekTranslatorEngine.shared.fetchAvailableModels(apiKey: key)
            print("DeepSeek 官方可用模型列表:")
            for m in models {
                print("- ID: \(m.id), 名称: \(m.name ?? "N/A"), 思考程度支持: \(m.effort?.supportedLevels?.joined(separator: ", ") ?? "无")")
            }
        } catch {
            print("拉取模型失败: \(error.localizedDescription)")
        }
        exit(0)
    }
    
    if args.contains("--memory") {
        print(PersonalTranslationMemoryManager.shared.exportJSON())
        exit(0)
    }
    
    if args.contains("--prompt") {
        print(AgentTranslationContext.currentPrompt())
        exit(0)
    }
    
    if args.contains("--stats") {
        let stats = UsageStatisticsManager.shared.stats
        let encoder = JSONEncoder()
        encoder.outputFormatting = .prettyPrinted
        if let data = try? encoder.encode(stats), let str = String(data: data, encoding: .utf8) {
            print(str)
        }
        exit(0)
    }
    
    if let transIndex = args.firstIndex(of: "--translate"), transIndex + 1 < args.count {
        let text = args[transIndex + 1]
        var targetLang = "zh-CN"
        var engineType = AppSettings.shared.selectedEngine
        
        if let tIndex = args.firstIndex(of: "--target"), tIndex + 1 < args.count {
            targetLang = args[tIndex + 1]
        }
        if let eIndex = args.firstIndex(of: "--engine"), eIndex + 1 < args.count {
            let engineName = args[eIndex + 1]
            guard let parsed = TranslationEngineType(rawValue: engineName) else {
                fputs("错误：--engine 仅支持 google 或 deepseek\n", stderr)
                exit(2)
            }
            engineType = parsed
        }
        
        do {
            let result = try await TranslationCoordinator.shared.translate(
                text: text,
                targetLang: targetLang,
                engine: engineType
            )
            print("=== 翻译结果 ===")
            print("原文: \(result.sourceText)")
            print("译文: \(result.targetText)")
            print("引擎: \(result.engineUsed) (耗时: \(result.latencyMs)ms)")
            if result.totalTokens > 0 {
                print("Tokens: \(result.totalTokens) (思考: \(result.reasoningTokens))")
            }
        } catch {
            print("翻译失败: \(error.localizedDescription)")
        }
        exit(0)
    }
    
    print("未识别的参数，请执行 cduyzhTranslator --help 查看帮助。")
    exit(1)
}

await main()
