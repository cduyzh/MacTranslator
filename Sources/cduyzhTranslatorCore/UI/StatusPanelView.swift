import AppKit
import SwiftUI
import ServiceManagement

/// 状态栏悬浮控制面板的数据快照，完全解耦自真实系统状态，支持预览与独立单元测试。
public struct StatusPanelSnapshot: Equatable, Sendable {
    public var version: String = "1.2.1"
    public var build: Int = 10
    public var isAccessibilityGranted: Bool = false
    public var isHotkeyMonitoring: Bool = true
    public var engineName: String = "DeepSeek"
    public var engineType: TranslationEngineType = .deepseek
    public var engineSummary: String = "DeepSeek-V3"
    public var hasApiKey: Bool = false
    public var hotkeyDisplay: String = "⌘C C"
    public var memoryCount: Int = 0
    public var totalRequests: Int = 0
    public var totalTokens: Int = 0
    public var isAgentGatewayRunning: Bool = true
    public var agentGatewayPort: UInt16 = 11899
    public var autoStartAtLogin: Bool = false
    public var hasUnreadUpdate: Bool = false
    public var cacheSizeFormatted: String = "0 KB"

    public init(
        version: String = "1.2.1",
        build: Int = 10,
        isAccessibilityGranted: Bool = false,
        isHotkeyMonitoring: Bool = true,
        engineName: String = "DeepSeek",
        engineType: TranslationEngineType = .deepseek,
        engineSummary: String = "DeepSeek-V3",
        hasApiKey: Bool = false,
        hotkeyDisplay: String = "⌘C C",
        memoryCount: Int = 0,
        totalRequests: Int = 0,
        totalTokens: Int = 0,
        isAgentGatewayRunning: Bool = true,
        agentGatewayPort: UInt16 = 11899,
        autoStartAtLogin: Bool = false,
        hasUnreadUpdate: Bool = false,
        cacheSizeFormatted: String = "0 KB"
    ) {
        self.version = version
        self.build = build
        self.isAccessibilityGranted = isAccessibilityGranted
        self.isHotkeyMonitoring = isHotkeyMonitoring
        self.engineName = engineName
        self.engineType = engineType
        self.engineSummary = engineSummary
        self.hasApiKey = hasApiKey
        self.hotkeyDisplay = hotkeyDisplay
        self.memoryCount = memoryCount
        self.totalRequests = totalRequests
        self.totalTokens = totalTokens
        self.isAgentGatewayRunning = isAgentGatewayRunning
        self.agentGatewayPort = agentGatewayPort
        self.autoStartAtLogin = autoStartAtLogin
        self.hasUnreadUpdate = hasUnreadUpdate
        self.cacheSizeFormatted = cacheSizeFormatted
    }

    public var statusTitle: String {
        if !isAccessibilityGranted {
            return "需要辅助功能权限"
        }
        return "划词就绪 · 连按 ⌘C C 快速翻译"
    }

    public var statusColor: Color {
        if !isAccessibilityGranted {
            return Color.orange
        }
        return Color(red: 0.0, green: 0.85, blue: 0.70)
    }

    public var engineCapsuleTitle: String {
        switch engineType {
        case .deepseek:
            return hasApiKey ? "AI 智能增强" : "待配密钥"
        case .google:
            return "免密直连"
        }
    }

    public var engineCapsuleColor: Color {
        switch engineType {
        case .deepseek:
            return hasApiKey ? Color(red: 0.10, green: 0.65, blue: 0.40) : Color.orange
        case .google:
            return Color(red: 0.0, green: 0.72, blue: 0.88)
        }
    }

    public static var preview: StatusPanelSnapshot {
        StatusPanelSnapshot(
            version: "1.2.1",
            build: 10,
            isAccessibilityGranted: true,
            isHotkeyMonitoring: true,
            engineName: "DeepSeek",
            engineType: .deepseek,
            engineSummary: "DeepSeek-V3 (AI 润色)",
            hasApiKey: true,
            hotkeyDisplay: "⌘C C",
            memoryCount: 38,
            totalRequests: 126,
            totalTokens: 3820,
            isAgentGatewayRunning: true,
            agentGatewayPort: 11899,
            autoStartAtLogin: false,
            hasUnreadUpdate: false,
            cacheSizeFormatted: "1.2 MB"
        )
    }
}

/// 状态栏面板交互动作枚举
public enum StatusPanelAction: Hashable, Sendable {
    case settings
    case engineCapsule
    case quickTranslate
    case openTranslatePanel
    case switchEngine
    case personalMemory
    case usageStatistics
    case accessibilityPerm
    case agentGateway
    case more
    case quit
}

/// 状态栏悬浮控制面板的数据响应模型
public final class StatusPanelModel: ObservableObject {
    @Published public var snapshot: StatusPanelSnapshot = StatusPanelSnapshot()
    @Published public var focusedAction: StatusPanelAction? = nil

    public init() {}
}

public struct StatusPanelContent: View {
    @ObservedObject public var model: StatusPanelModel
    public let onAction: (StatusPanelAction) -> Void

    public init(model: StatusPanelModel, onAction: @escaping (StatusPanelAction) -> Void) {
        self.model = model
        self.onAction = onAction
    }

    public var body: some View {
        StatusPanelView(
            snapshot: model.snapshot,
            focusedAction: model.focusedAction,
            onAction: onAction,
            onFocusChange: { model.focusedAction = $0 }
        )
    }
}

/// 状态栏右键悬浮面板：严格遵循 cduyzh-mac-app-design (v2026-10-28.2) 五大黄金功能分区架构与双行解耦头栏标准。
public struct StatusPanelView: View {
    public let snapshot: StatusPanelSnapshot
    public var focusedAction: StatusPanelAction? = nil
    public var onAction: (StatusPanelAction) -> Void = { _ in }
    public var onFocusChange: (StatusPanelAction?) -> Void = { _ in }
    @FocusState private var nativeFocus: StatusPanelAction?

    private let secondary = Color(nsColor: .secondaryLabelColor)

    public init(
        snapshot: StatusPanelSnapshot,
        focusedAction: StatusPanelAction? = nil,
        onAction: @escaping (StatusPanelAction) -> Void = { _ in },
        onFocusChange: @escaping (StatusPanelAction?) -> Void = { _ in }
    ) {
        self.snapshot = snapshot
        self.focusedAction = focusedAction
        self.onAction = onAction
        self.onFocusChange = onFocusChange
    }

    public var body: some View {
        VStack(spacing: 0) {
            header
                .padding(.bottom, 14)

            primaryActionCards

            secondaryActionGrid
                .padding(.top, 10)

            permissionInspector
                .padding(.top, 14)

            Divider()
                .padding(.top, 12)
                .padding(.bottom, 8)

            footer
        }
        .padding(16)
        .frame(width: 368)
        .modifier(StatusPanelGlassSurface())
        .onAppear {
            nativeFocus = focusedAction
        }
        .onChange(of: focusedAction) { _, newAction in
            nativeFocus = newAction
        }
        .onChange(of: nativeFocus) { _, newFocus in
            onFocusChange(newFocus)
        }
    }

    // MARK: - Zone 1: 品牌识别与运行状态头栏 (Brand & Status Header)
    // 规范要求：双行解耦排版（Dual-line Decoupled Hierarchy）
    // Row 1: 品牌主英文名（.lineLimit(1)）+ 中文副标题 + 弹性间距 + Quiet Signal 半透微光胶囊徽标
    // Row 2: 6pt 呼吸状态指示灯 + 状态描述 + 中圆点 + 等宽版本号
    private var header: some View {
        HStack(spacing: 11) {
            // 1. App 品牌图标 (40×40 平滑超椭圆)
            ZStack {
                RoundedRectangle(cornerRadius: 11, style: .continuous)
                    .fill(LinearGradient(
                        colors: [Color(red: 0.08, green: 0.44, blue: 0.94), Color(red: 0.0, green: 0.72, blue: 0.88)],
                        startPoint: .topLeading,
                        endPoint: .bottomTrailing
                    ))
                    .frame(width: 40, height: 40)
                    .overlay(
                        RoundedRectangle(cornerRadius: 11, style: .continuous)
                            .strokeBorder(Color.white.opacity(0.35), lineWidth: 0.6)
                    )
                    .shadow(color: Color.blue.opacity(0.35), radius: 6, x: 0, y: 2)

                Image(systemName: "character.bubble.fill")
                    .font(.system(size: 20, weight: .bold))
                    .foregroundStyle(.white)
            }

            // 2. 双行解耦排版主信息区 (杜绝单行横向拥挤与断字截断)
            VStack(alignment: .leading, spacing: 4) {
                // Row 1: 英文产品名 + 中文副标题 + 弹性间距 + 微光胶囊徽标
                HStack(alignment: .center, spacing: 6) {
                    Text("TransBar")
                        .font(.system(size: 15, weight: .bold))
                        .lineLimit(1)

                    Text("译栏")
                        .font(.system(size: 11, weight: .medium))
                        .foregroundStyle(.secondary)
                        .lineLimit(1)

                    Spacer(minLength: 4)

                    // Quiet Signal 微光胶囊 (Plateau Capsule)
                    Button {
                        onAction(.engineCapsule)
                    } label: {
                        HStack(spacing: 3.5) {
                            Circle()
                                .fill(snapshot.engineCapsuleColor)
                                .frame(width: 4.5, height: 4.5)
                            Text(snapshot.engineCapsuleTitle)
                                .font(.system(size: 9.5, weight: .semibold, design: .rounded))
                                .foregroundStyle(snapshot.engineCapsuleColor)
                        }
                        .padding(.horizontal, 6)
                        .padding(.vertical, 2.5)
                        .background(snapshot.engineCapsuleColor.opacity(0.12))
                        .clipShape(Capsule())
                        .overlay(
                            Capsule().strokeBorder(snapshot.engineCapsuleColor.opacity(0.28), lineWidth: 0.8)
                        )
                    }
                    .buttonStyle(.plain)
                    .help("查看与配置当前翻译引擎")
                    .accessibilityLabel("引擎状态：\(snapshot.engineCapsuleTitle)")
                }

                // Row 2: 状态指示呼吸灯 + 状态文案 + 弱化分隔符 + 等宽版本号
                HStack(alignment: .center, spacing: 5) {
                    Circle()
                        .fill(snapshot.statusColor)
                        .frame(width: 6, height: 6)
                        .shadow(color: snapshot.statusColor.opacity(0.6), radius: 3)

                    Text(snapshot.statusTitle)
                        .font(.system(size: 11))
                        .foregroundStyle(secondary)
                        .lineLimit(1)

                    Text("·")
                        .font(.system(size: 10))
                        .foregroundStyle(.tertiary)

                    Text("v\(snapshot.version)")
                        .font(.system(size: 10, design: .monospaced))
                        .foregroundStyle(.tertiary)
                        .lineLimit(1)
                }
            }

            Spacer(minLength: 0)

            // 3. 右侧操作区：静音齿轮设置按钮 (28×28)
            iconButton(.settings, symbol: "gearshape.fill", label: "打开设置（⌘,）")
        }
    }

    // MARK: - Zone 2: 核心功能大卡片流 (Primary Action Plateau Cards)
    private var primaryActionCards: some View {
        VStack(spacing: 4) {
            actionRow(
                .quickTranslate,
                title: "双击 ⌘C 划词翻译",
                detail: "任意界面连按两次 ⌘C 极速识别并弹出翻译",
                symbol: "bolt.fill",
                color: Color.blue,
                shortcut: "⌘C C"
            )
            actionRow(
                .openTranslatePanel,
                title: "打开翻译主面板",
                detail: "多引擎对照、AI 深度润色、国旗语种与朗读",
                symbol: "character.bubble.fill",
                color: Color(red: 0.10, green: 0.65, blue: 0.40),
                shortcut: snapshot.hotkeyDisplay
            )
            actionRow(
                .switchEngine,
                title: "当前引擎：\(snapshot.engineName)",
                detail: "\(snapshot.engineSummary) · 点击快速轮换",
                symbol: "cpu.fill",
                color: Color.purple,
                shortcut: "⌥E"
            )
        }
        .padding(5)
        .background(Color(nsColor: .controlBackgroundColor).opacity(0.55), in: RoundedRectangle(cornerRadius: 13, style: .continuous))
    }

    // MARK: - Zone 3: 次级紧凑动作网格 (Secondary Action Grid, 2-Col)
    private var secondaryActionGrid: some View {
        HStack(spacing: 8) {
            compactAction(
                .personalMemory,
                title: "术语记忆库",
                symbol: "book.closed.fill",
                hint: "\(snapshot.memoryCount) 条",
                shortcut: "⌥M"
            )
            compactAction(
                .usageStatistics,
                title: "翻译用量统计",
                symbol: "chart.bar.xaxis",
                hint: "\(snapshot.totalRequests) 次",
                shortcut: "⌥S"
            )
        }
    }

    // MARK: - Zone 4: 权限与系统健康巡检栏 (Permission Inspector)
    private var permissionInspector: some View {
        VStack(spacing: 6) {
            HStack {
                Text("权限与服务状态")
                    .font(.system(size: 11, weight: .medium))
                    .foregroundStyle(secondary)
                Spacer()
                Text("点击前往配置")
                    .font(.system(size: 10))
                    .foregroundStyle(.tertiary)
            }

            VStack(spacing: 1) {
                statusInspectionRow(
                    .accessibilityPerm,
                    title: "辅助功能权限",
                    detail: "用于 Command+C+C 全局按键检测与划词",
                    symbol: "hand.raised.fill",
                    isGood: snapshot.isAccessibilityGranted,
                    statusText: snapshot.isAccessibilityGranted ? "已授权" : "未授权 · 点击配置",
                    showChevron: !snapshot.isAccessibilityGranted
                )

                statusInspectionRow(
                    .agentGateway,
                    title: "本地 Agent 网关",
                    detail: "端口 \(snapshot.agentGatewayPort) · 外部 Agent 联动",
                    symbol: "network",
                    isGood: snapshot.isAgentGatewayRunning,
                    statusText: snapshot.isAgentGatewayRunning ? "已就绪" : "未启动",
                    showChevron: true
                )
            }
            .padding(.horizontal, 7)
            .padding(.vertical, 4)
            .background(Color.primary.opacity(0.035), in: RoundedRectangle(cornerRadius: 11, style: .continuous))
        }
    }

    // MARK: - Zone 5: 底部全局工具栏与状态条 (Global Utility & Footer)
    private var footer: some View {
        HStack {
            Button {
                onAction(.more)
            } label: {
                HStack(spacing: 5) {
                    Image(systemName: "ellipsis.circle")
                    Text("更多")
                    if snapshot.hasUnreadUpdate {
                        Circle().fill(Color.blue).frame(width: 5, height: 5)
                    }
                    Image(systemName: "chevron.down").font(.system(size: 8, weight: .semibold))
                }
                .font(.system(size: 12))
                .padding(.horizontal, 8)
                .padding(.vertical, 6)
            }
            .buttonStyle(StatusControlStyle(isFocused: focusedAction == .more))
            .focused($nativeFocus, equals: .more)
            .focusEffectDisabled()
            .help("更多操作：开机自启、检查更新、清理缓存与重启")
            .accessibilityLabel("更多操作")

            Spacer()

            Text("左键翻译 · 右键状态")
                .font(.system(size: 10))
                .foregroundStyle(.tertiary)

            Spacer()

            Button {
                onAction(.quit)
            } label: {
                Label("退出", systemImage: "power")
                    .font(.system(size: 12))
                    .padding(.horizontal, 8)
                    .padding(.vertical, 6)
            }
            .buttonStyle(StatusControlStyle(isFocused: focusedAction == .quit, isDestructive: true))
            .focused($nativeFocus, equals: .quit)
            .focusEffectDisabled()
            .help("退出译栏")
            .accessibilityLabel("退出译栏")
        }
    }

    // MARK: - 辅助子视图构建方法

    private func actionRow(
        _ action: StatusPanelAction,
        title: String,
        detail: String,
        symbol: String,
        color: Color,
        shortcut: String
    ) -> some View {
        Button {
            onAction(action)
        } label: {
            HStack(spacing: 11) {
                Image(systemName: symbol)
                    .font(.system(size: 18, weight: .medium))
                    .foregroundStyle(color)
                    .frame(width: 37, height: 37)
                    .background(color.opacity(0.10), in: RoundedRectangle(cornerRadius: 9, style: .continuous))

                VStack(alignment: .leading, spacing: 3) {
                    Text(title)
                        .font(.system(size: 13, weight: .semibold))
                        .foregroundStyle(Color.primary)
                        .lineLimit(1)
                    Text(detail)
                        .font(.system(size: 10))
                        .foregroundStyle(secondary)
                        .lineLimit(1)
                }

                Spacer(minLength: 4)

                Text(shortcut)
                    .font(.system(size: 10.5, weight: .semibold, design: .monospaced))
                    .foregroundStyle(Color.primary.opacity(0.85))
                    .padding(.horizontal, 6)
                    .padding(.vertical, 3)
                    .background(Color.primary.opacity(0.06), in: RoundedRectangle(cornerRadius: 5, style: .continuous))
                    .overlay(
                        RoundedRectangle(cornerRadius: 5, style: .continuous)
                            .strokeBorder(Color.primary.opacity(0.12), lineWidth: 0.5)
                    )
            }
            .padding(.horizontal, 9)
            .padding(.vertical, 8)
            .contentShape(Rectangle())
        }
        .buttonStyle(StatusControlStyle(isFocused: focusedAction == action))
        .focused($nativeFocus, equals: action)
        .focusEffectDisabled()
        .accessibilityLabel("\(title)，\(detail)，快捷键 \(shortcut)")
    }

    private func compactAction(
        _ action: StatusPanelAction,
        title: String,
        symbol: String,
        hint: String,
        shortcut: String
    ) -> some View {
        Button {
            onAction(action)
        } label: {
            HStack(spacing: 6) {
                Image(systemName: symbol)
                    .font(.system(size: 12))
                    .foregroundStyle(.secondary)
                Text(title)
                    .font(.system(size: 11, weight: .medium))
                Spacer(minLength: 0)
                Text(hint)
                    .font(.system(size: 10, design: .monospaced))
                    .foregroundStyle(.tertiary)
            }
            .padding(.horizontal, 10)
            .padding(.vertical, 9)
            .frame(maxWidth: .infinity)
            .background(Color.primary.opacity(0.035), in: RoundedRectangle(cornerRadius: 9, style: .continuous))
        }
        .buttonStyle(StatusControlStyle(isFocused: focusedAction == action))
        .focused($nativeFocus, equals: action)
        .focusEffectDisabled()
        .help("\(title)（快捷键 \(shortcut)）")
        .accessibilityLabel("\(title)，\(hint)")
    }

    private func statusInspectionRow(
        _ action: StatusPanelAction,
        title: String,
        detail: String,
        symbol: String,
        isGood: Bool,
        statusText: String,
        showChevron: Bool
    ) -> some View {
        Button {
            onAction(action)
        } label: {
            HStack(spacing: 7) {
                Image(systemName: symbol)
                    .font(.system(size: 12))
                    .foregroundStyle(secondary)
                    .frame(width: 18)

                Text(title)
                    .font(.system(size: 11, weight: .medium))

                Text(detail)
                    .font(.system(size: 10))
                    .foregroundStyle(.tertiary)
                    .lineLimit(1)

                Spacer(minLength: 4)

                Image(systemName: isGood ? "checkmark.circle.fill" : "exclamationmark.triangle.fill")
                    .foregroundStyle(isGood ? Color(red: 0.10, green: 0.65, blue: 0.40) : Color.orange)
                    .font(.system(size: 10))

                Text(statusText)
                    .font(.system(size: 10, weight: isGood ? .regular : .medium))
                    .foregroundStyle(isGood ? secondary : Color.orange)

                if showChevron {
                    Image(systemName: "chevron.right")
                        .font(.system(size: 8, weight: .semibold))
                        .foregroundStyle(.tertiary)
                }
            }
            .padding(.horizontal, 6)
            .padding(.vertical, 7)
            .contentShape(Rectangle())
        }
        .buttonStyle(StatusControlStyle(isFocused: focusedAction == action))
        .focused($nativeFocus, equals: action)
        .focusEffectDisabled()
        .accessibilityLabel("\(title)，\(statusText)，\(detail)")
    }

    private func iconButton(
        _ action: StatusPanelAction,
        symbol: String,
        label: String
    ) -> some View {
        Button {
            onAction(action)
        } label: {
            Image(systemName: symbol)
                .font(.system(size: 14))
                .frame(width: 28, height: 28)
                .contentShape(Rectangle())
        }
        .buttonStyle(StatusControlStyle(isFocused: focusedAction == action))
        .focused($nativeFocus, equals: action)
        .focusEffectDisabled()
        .help(label)
        .accessibilityLabel(label)
    }
}

// MARK: - 专属样式与修饰器

/// macOS 26/27 采用系统原生 Liquid Glass，向下兼容 macOS 14-25 的 regularMaterial
private struct StatusPanelGlassSurface: ViewModifier {
    func body(content: Content) -> some View {
        if #available(macOS 26.0, *) {
            content.glassEffect(.regular.interactive(), in: RoundedRectangle(cornerRadius: 16, style: .continuous))
        } else {
            content
                .background(.regularMaterial, in: RoundedRectangle(cornerRadius: 14, style: .continuous))
                .overlay(
                    RoundedRectangle(cornerRadius: 14, style: .continuous)
                        .strokeBorder(Color.primary.opacity(0.08), lineWidth: 0.8)
                )
        }
    }
}

/// 状态栏交互按钮样式：提供 0.12s 悬停微反馈与 0.975x 物理按压缩放，兼容 accessibilityReduceMotion
private struct StatusControlStyle: ButtonStyle {
    let isFocused: Bool
    var isDestructive: Bool = false

    func makeBody(configuration: Configuration) -> some View {
        StatusControlBody(configuration: configuration, isFocused: isFocused, isDestructive: isDestructive)
    }

    private struct StatusControlBody: View {
        let configuration: ButtonStyleConfiguration
        let isFocused: Bool
        let isDestructive: Bool
        @State private var hovering = false
        @Environment(\.isEnabled) private var enabled
        @Environment(\.accessibilityReduceMotion) private var reduceMotion

        var body: some View {
            let bgOpacity: Double = configuration.isPressed ? 0.12 : (hovering && enabled ? 0.06 : 0)
            let fgColor: Color = isDestructive && (hovering || configuration.isPressed) ? Color.red : Color.primary
            let borderColor: Color = isFocused
                ? Color.accentColor.opacity(0.85)
                : (hovering && enabled ? Color.primary.opacity(0.12) : Color.clear)

            configuration.label
                .foregroundStyle(fgColor)
                .background(
                    (isDestructive && hovering ? Color.red.opacity(0.08) : Color.primary.opacity(bgOpacity)),
                    in: RoundedRectangle(cornerRadius: 8, style: .continuous)
                )
                .overlay(
                    RoundedRectangle(cornerRadius: 8, style: .continuous)
                        .strokeBorder(borderColor, lineWidth: isFocused ? 1.4 : 0.8)
                )
                .scaleEffect(!reduceMotion && configuration.isPressed ? 0.975 : 1.0)
                .animation(reduceMotion ? nil : .easeOut(duration: 0.12), value: hovering)
                .animation(reduceMotion ? nil : .easeOut(duration: 0.12), value: configuration.isPressed)
                .opacity(enabled ? 1 : 0.42)
                .onHover { hovering = $0 }
        }
    }
}
