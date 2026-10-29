import SwiftUI

/// 调用量统计与费用监控视图。
public struct StatisticsView: View {
    @ObservedObject var statsManager = UsageStatisticsManager.shared
    @Environment(\.colorScheme) private var colorScheme
    @State private var showResetConfirmation = false

    public init() {}

    public var body: some View {
        ScrollView(.vertical, showsIndicators: true) {
            VStack(alignment: .leading, spacing: 16) {
                VStack(alignment: .leading, spacing: 4) {
                    Text("使用概览")
                        .font(.system(size: 15, weight: .semibold))
                    Text("查看此设备上的翻译调用与用量。")
                        .font(.system(size: 12))
                        .foregroundStyle(.secondary)
                }

                LazyVGrid(columns: [GridItem(.flexible()), GridItem(.flexible())], spacing: 12) {
                    statCard(
                        title: "翻译调用",
                        value: statsManager.stats.totalRequests.formatted(),
                        subtitle: statsManager.stats.totalRequests > 0
                            ? "成功率 \(String(format: "%.1f", statsManager.stats.successRate))%"
                            : "尚无调用记录",
                        icon: "arrow.left.arrow.right"
                    )
                    statCard(
                        title: "平均耗时",
                        value: statsManager.stats.successRequests > 0
                            ? "\(statsManager.stats.averageLatencyMs.formatted()) ms"
                            : "—",
                        subtitle: "仅统计成功调用",
                        icon: "clock"
                    )
                    statCard(
                        title: "Token 用量",
                        value: statsManager.stats.totalTokens.formatted(),
                        subtitle: "思考 Token \(statsManager.stats.reasoningTokens.formatted())",
                        icon: "number"
                    )
                    statCard(
                        title: "预估费用",
                        value: "$\(String(format: "%.4f", statsManager.stats.estimatedCostUSD))",
                        subtitle: "美元，按 Token 用量估算",
                        icon: "dollarsign"
                    )
                }

                ModernGlassCard {
                    VStack(alignment: .leading, spacing: 14) {
                        Text("引擎分布")
                            .font(.system(size: 13, weight: .semibold))

                        if statsManager.stats.engineRequests.isEmpty {
                            VStack(spacing: 8) {
                                Image(systemName: "chart.bar")
                                    .font(.system(size: 24, weight: .light))
                                    .foregroundStyle(.tertiary)
                                    .accessibilityHidden(true)
                                Text("还没有翻译记录")
                                    .font(.system(size: 13, weight: .medium))
                                Text("完成一次翻译后，这里会显示各引擎的调用次数。")
                                    .font(.system(size: 12))
                                    .foregroundStyle(.secondary)
                                    .multilineTextAlignment(.center)
                            }
                            .frame(maxWidth: .infinity)
                            .padding(.vertical, 16)
                        } else {
                            ForEach(engineKeys, id: \.self) { key in
                                let count = statsManager.stats.engineRequests[key] ?? 0
                                VStack(spacing: 7) {
                                    HStack {
                                        Text(key)
                                            .font(.system(size: 13))
                                            .lineLimit(1)
                                            .help(key)
                                        Spacer(minLength: 12)
                                        Text("\(count.formatted()) 次")
                                            .font(.system(size: 12, weight: .medium))
                                            .monospacedDigit()
                                            .foregroundStyle(.secondary)
                                    }
                                    GeometryReader { geometry in
                                        ZStack(alignment: .leading) {
                                            Capsule().fill(Color.secondary.opacity(0.08))
                                            Capsule()
                                                .fill(TransBarInspectorDesign.accent(for: colorScheme).opacity(0.7))
                                                .frame(width: geometry.size.width * engineFraction(count))
                                        }
                                    }
                                    .frame(height: 4)
                                    .accessibilityHidden(true)
                                }
                                .accessibilityElement(children: .combine)
                            }
                        }
                    }
                    .frame(maxWidth: .infinity, alignment: .leading)
                }

                HStack(alignment: .center, spacing: 16) {
                    Text("费用为本地估算，请以服务商账单为准。")
                        .font(.system(size: 11))
                        .foregroundStyle(.secondary)
                        .fixedSize(horizontal: false, vertical: true)
                    Spacer(minLength: 0)
                    Button("清空统计", role: .destructive) {
                        showResetConfirmation = true
                    }
                    .buttonStyle(TransBarInspectorButtonStyle(variant: .destructive, size: .small))
                    .disabled(statsManager.stats.totalRequests == 0)
                }
            }
            .padding(20)
        }
        .alert("清空统计数据？", isPresented: $showResetConfirmation) {
            Button("取消", role: .cancel) {}
            Button("清空统计", role: .destructive) {
                statsManager.resetStats()
            }
        } message: {
            Text("将移除此设备上保存的调用次数、Token 用量和费用统计。此操作无法撤销。")
        }
    }

    private var engineKeys: [String] {
        statsManager.stats.engineRequests.keys.sorted {
            let left = statsManager.stats.engineRequests[$0] ?? 0
            let right = statsManager.stats.engineRequests[$1] ?? 0
            return left == right ? $0 < $1 : left > right
        }
    }

    private func engineFraction(_ count: Int) -> CGFloat {
        let total = statsManager.stats.engineRequests.values.reduce(0, +)
        guard total > 0 else { return 0 }
        return CGFloat(count) / CGFloat(total)
    }

    private func statCard(title: String, value: String, subtitle: String, icon: String) -> some View {
        ModernGlassCard {
            VStack(alignment: .leading, spacing: 9) {
                Label(title, systemImage: icon)
                    .font(.system(size: 12))
                    .foregroundStyle(.secondary)
                Text(value)
                    .font(.system(size: 23, weight: .semibold))
                    .monospacedDigit()
                    .lineLimit(1)
                    .minimumScaleFactor(0.75)
                Text(subtitle)
                    .font(.system(size: 11))
                    .foregroundStyle(.secondary)
                    .lineLimit(1)
            }
            .frame(maxWidth: .infinity, alignment: .leading)
        }
        .accessibilityElement(children: .combine)
    }
}
