import SwiftUI
import AppKit

public extension TransBarAppearanceMode {
    var colorScheme: ColorScheme? {
        switch self {
        case .system: return nil
        case .light: return .light
        case .dark: return .dark
        }
    }
}

/// TransBar 的双主题设计令牌：浅色模式沿用 Quiet Native，深色模式沿用 Ink Signal。
public enum TransBarDesign {
    public static func accent(for colorScheme: ColorScheme) -> Color {
        colorScheme == .dark
            ? Color(red: 0.29, green: 0.61, blue: 1.0)
            : Color(red: 0.11, green: 0.39, blue: 0.78)
    }

    public static func success(for colorScheme: ColorScheme) -> Color {
        colorScheme == .dark
            ? Color(red: 0.71, green: 0.89, blue: 0.37)
            : Color(red: 0.10, green: 0.55, blue: 0.35)
    }

    public static func surface(for colorScheme: ColorScheme, emphasized: Bool = false) -> Color {
        if colorScheme == .dark {
            return emphasized
                ? Color(red: 0.11, green: 0.15, blue: 0.20)
                : Color(red: 0.09, green: 0.12, blue: 0.16)
        }
        return emphasized ? Color.white.opacity(0.88) : Color.white.opacity(0.72)
    }

    public static func field(for colorScheme: ColorScheme) -> Color {
        colorScheme == .dark
            ? Color(red: 0.10, green: 0.14, blue: 0.18)
            : Color(red: 0.97, green: 0.98, blue: 1.0)
    }

    public static func border(for colorScheme: ColorScheme, emphasized: Bool = false) -> Color {
        if colorScheme == .dark {
            return emphasized ? Color(red: 0.30, green: 0.61, blue: 0.92).opacity(0.74) : Color.white.opacity(0.13)
        }
        return emphasized ? Color(red: 0.30, green: 0.58, blue: 0.92).opacity(0.74) : Color.primary.opacity(0.10)
    }

    public static func secondaryText(for colorScheme: ColorScheme) -> Color {
        colorScheme == .dark ? Color(red: 0.64, green: 0.71, blue: 0.80) : Color(red: 0.34, green: 0.41, blue: 0.49)
    }
}

/// Quiet teal inspector tokens used by the settings surface.
/// The settings page follows the supplied reference: a calm green canvas, flat cards and
/// a single cyan focus signal. It deliberately avoids material blur and glow effects.
public enum TransBarInspectorDesign {
    public static func accent(for colorScheme: ColorScheme) -> Color {
        colorScheme == .dark
            ? Color(red: 0.38, green: 0.70, blue: 1.0)
            : Color(red: 0.12, green: 0.39, blue: 0.78)
    }

    public static func canvas(for colorScheme: ColorScheme) -> Color {
        colorScheme == .dark
            ? Color(red: 0.055, green: 0.10, blue: 0.15)
            : Color(red: 0.95, green: 0.97, blue: 0.995)
    }

    /// The A-structure palette keeps a quiet C-style color drift without turning the
    /// settings surface into a glossy material card.
    public static func canvasGradient(for colorScheme: ColorScheme) -> LinearGradient {
        colorScheme == .dark
            ? LinearGradient(
                colors: [Color(red: 0.12, green: 0.20, blue: 0.30), Color(red: 0.035, green: 0.075, blue: 0.12)],
                startPoint: .topLeading,
                endPoint: .bottomTrailing
            )
            : LinearGradient(
                colors: [Color(red: 0.995, green: 0.998, blue: 1.0), Color(red: 0.90, green: 0.95, blue: 0.995)],
                startPoint: .topLeading,
                endPoint: .bottomTrailing
            )
    }

    public static func sidebar(for colorScheme: ColorScheme) -> Color {
        colorScheme == .dark
            ? Color(red: 0.025, green: 0.055, blue: 0.09)
            : Color(red: 0.90, green: 0.94, blue: 0.985)
    }

    public static func sidebarGradient(for colorScheme: ColorScheme) -> LinearGradient {
        colorScheme == .dark
            ? LinearGradient(
                colors: [Color(red: 0.055, green: 0.12, blue: 0.19), Color(red: 0.015, green: 0.035, blue: 0.06)],
                startPoint: .top,
                endPoint: .bottom
            )
            : LinearGradient(
                colors: [Color(red: 0.95, green: 0.98, blue: 1.0), Color(red: 0.86, green: 0.92, blue: 0.98)],
                startPoint: .top,
                endPoint: .bottom
            )
    }

    public static func field(for colorScheme: ColorScheme) -> Color {
        colorScheme == .dark
            ? Color(red: 0.035, green: 0.085, blue: 0.14)
            : Color.white.opacity(0.88)
    }

    public static func surfaceGradient(for colorScheme: ColorScheme, emphasized: Bool = false) -> LinearGradient {
        if colorScheme == .dark {
            return emphasized
                ? LinearGradient(
                    colors: [Color(red: 0.16, green: 0.29, blue: 0.43), Color(red: 0.08, green: 0.19, blue: 0.27)],
                    startPoint: .topLeading,
                    endPoint: .bottomTrailing
                )
                : LinearGradient(
                    colors: [Color(red: 0.10, green: 0.22, blue: 0.33), Color(red: 0.045, green: 0.13, blue: 0.21)],
                    startPoint: .topLeading,
                    endPoint: .bottomTrailing
                )
        }
        return emphasized
            ? LinearGradient(
                colors: [Color.white.opacity(0.94), Color(red: 0.88, green: 0.95, blue: 1.0)],
                startPoint: .topLeading,
                endPoint: .bottomTrailing
            )
            : LinearGradient(
                colors: [Color.white.opacity(0.84), Color(red: 0.90, green: 0.95, blue: 0.995)],
                startPoint: .topLeading,
                endPoint: .bottomTrailing
            )
    }

    public static func secondaryText(for colorScheme: ColorScheme) -> Color {
        colorScheme == .dark
            ? Color(red: 0.70, green: 0.78, blue: 0.88)
            : Color(red: 0.29, green: 0.38, blue: 0.49)
    }

    public static func success(for colorScheme: ColorScheme) -> Color {
        colorScheme == .dark
            ? Color(red: 0.72, green: 0.90, blue: 0.50)
            : Color(red: 0.07, green: 0.48, blue: 0.30)
    }

    public static func surface(for colorScheme: ColorScheme, emphasized: Bool = false) -> Color {
        colorScheme == .dark
            ? (emphasized ? Color(red: 0.10, green: 0.21, blue: 0.32) : Color(red: 0.06, green: 0.14, blue: 0.22))
            : (emphasized ? Color.white.opacity(0.90) : Color.white.opacity(0.72))
    }

    public static func border(for colorScheme: ColorScheme, emphasized: Bool = false) -> Color {
        let accent = accent(for: colorScheme)
        return emphasized
            ? accent.opacity(colorScheme == .dark ? 0.68 : 0.34)
            : accent.opacity(colorScheme == .dark ? 0.32 : 0.18)
    }
}

/// A flat inspector layer for settings modules and controls.
public struct TransBarInspectorSurfaceModifier: ViewModifier {
    public let emphasized: Bool
    public let isFocused: Bool
    public let cornerRadius: CGFloat
    @Environment(\.colorScheme) private var colorScheme
    @Environment(\.accessibilityReduceMotion) private var reduceMotion

    public init(emphasized: Bool = false, isFocused: Bool = false, cornerRadius: CGFloat = 14) {
        self.emphasized = emphasized
        self.isFocused = isFocused
        self.cornerRadius = cornerRadius
    }

    public func body(content: Content) -> some View {
        let shape = RoundedRectangle(cornerRadius: cornerRadius, style: .continuous)

        content
            .background(TransBarInspectorDesign.surfaceGradient(for: colorScheme, emphasized: emphasized), in: shape)
            .overlay {
                shape
                    .strokeBorder(
                        TransBarInspectorDesign.border(for: colorScheme, emphasized: emphasized || isFocused),
                        lineWidth: isFocused ? 1.4 : (emphasized ? 1.0 : 0.8)
                    )
                    .allowsHitTesting(false)
            }
            .animation(reduceMotion ? nil : .easeOut(duration: 0.16), value: isFocused)
    }
}

public extension View {
    func transBarInspectorSurface(emphasized: Bool = false, isFocused: Bool = false, cornerRadius: CGFloat = 14) -> some View {
        modifier(TransBarInspectorSurfaceModifier(emphasized: emphasized, isFocused: isFocused, cornerRadius: cornerRadius))
    }
}

/// Flat buttons used by the settings inspector.
public struct TransBarInspectorButtonStyle: ButtonStyle {
    public enum Variant { case primary, secondary, outline, destructive, ghost }
    public let variant: Variant
    public let size: ControlSize
    @Environment(\.colorScheme) private var colorScheme
    @Environment(\.isEnabled) private var isEnabled
    @Environment(\.accessibilityReduceMotion) private var reduceMotion
    @State private var isHovered = false

    public init(variant: Variant = .secondary, size: ControlSize = .regular) {
        self.variant = variant
        self.size = size
    }

    public func makeBody(configuration: Configuration) -> some View {
        configuration.label
            .font(font)
            .padding(insets)
            .frame(minHeight: minimumHeight)
            .foregroundStyle(foreground)
            .background {
                RoundedRectangle(cornerRadius: radius, style: .continuous)
                    .fill(background(pressed: configuration.isPressed))
            }
            .overlay {
                RoundedRectangle(cornerRadius: radius, style: .continuous)
                    .strokeBorder(border, lineWidth: 0.8)
                    .allowsHitTesting(false)
            }
            .contentShape(RoundedRectangle(cornerRadius: radius, style: .continuous))
            .opacity(isEnabled ? 1 : 0.42)
            .scaleEffect(!reduceMotion && isEnabled && configuration.isPressed ? 0.975 : 1)
            .animation(reduceMotion ? nil : .easeOut(duration: 0.12), value: configuration.isPressed)
            .animation(reduceMotion ? nil : .easeOut(duration: 0.12), value: isHovered)
            .onHover { isHovered = $0 && isEnabled }
    }

    private var font: Font {
        switch size {
        case .mini: return .system(size: 11, weight: .medium)
        case .small: return .system(size: 12, weight: .medium)
        default: return .system(size: 13, weight: .medium)
        }
    }

    private var insets: EdgeInsets {
        switch size {
        case .mini: return EdgeInsets(top: 4, leading: 7, bottom: 4, trailing: 7)
        case .small: return EdgeInsets(top: 5, leading: 10, bottom: 5, trailing: 10)
        case .large, .extraLarge: return EdgeInsets(top: 9, leading: 16, bottom: 9, trailing: 16)
        default: return EdgeInsets(top: 7, leading: 12, bottom: 7, trailing: 12)
        }
    }

    private var minimumHeight: CGFloat {
        switch size {
        case .mini: return 24
        case .small: return 30
        case .large, .extraLarge: return 40
        default: return 34
        }
    }

    private var radius: CGFloat { size == .mini ? 8 : 10 }

    private var foreground: Color {
        switch variant {
        case .primary: return colorScheme == .dark ? Color(red: 0.02, green: 0.20, blue: 0.17) : .white
        case .destructive: return colorScheme == .dark ? Color(red: 1, green: 0.56, blue: 0.50) : .red
        case .ghost, .secondary: return TransBarInspectorDesign.secondaryText(for: colorScheme)
        case .outline: return .primary
        }
    }

    private var border: Color {
        switch variant {
        case .primary: return TransBarInspectorDesign.accent(for: colorScheme).opacity(0.72)
        case .destructive: return (colorScheme == .dark ? Color.orange : Color.red).opacity(0.35)
        case .outline: return TransBarInspectorDesign.border(for: colorScheme, emphasized: isHovered)
        case .secondary: return TransBarInspectorDesign.border(for: colorScheme, emphasized: isHovered)
        case .ghost: return .clear
        }
    }

    private func background(pressed: Bool) -> Color {
        let active = isEnabled && (pressed || isHovered)
        switch variant {
        case .primary: return TransBarInspectorDesign.accent(for: colorScheme).opacity(active ? 0.92 : 0.78)
        case .secondary: return TransBarInspectorDesign.accent(for: colorScheme).opacity(active ? 0.26 : 0.14)
        case .outline: return TransBarInspectorDesign.accent(for: colorScheme).opacity(active ? 0.16 : 0.06)
        case .destructive: return (colorScheme == .dark ? Color.red : Color.red).opacity(active ? 0.15 : 0.07)
        case .ghost: return TransBarInspectorDesign.accent(for: colorScheme).opacity(active ? 0.10 : 0)
        }
    }
}

/// 输入、Picker 和文本编辑区域共用的材质边界。
public struct TransBarSurfaceModifier: ViewModifier {
    public let emphasized: Bool
    public let isFocused: Bool
    public let cornerRadius: CGFloat
    @Environment(\.colorScheme) private var colorScheme
    @Environment(\.accessibilityReduceMotion) private var reduceMotion

    public init(emphasized: Bool = false, isFocused: Bool = false, cornerRadius: CGFloat = 10) {
        self.emphasized = emphasized
        self.isFocused = isFocused
        self.cornerRadius = cornerRadius
    }

    public func body(content: Content) -> some View {
        content
            .background(TransBarDesign.field(for: colorScheme), in: RoundedRectangle(cornerRadius: cornerRadius, style: .continuous))
            .overlay {
                RoundedRectangle(cornerRadius: cornerRadius, style: .continuous)
                    .strokeBorder(TransBarDesign.border(for: colorScheme, emphasized: emphasized || isFocused), lineWidth: isFocused ? 1.25 : 0.8)
                    .allowsHitTesting(false)
            }
            .shadow(color: .black.opacity(colorScheme == .dark ? (isFocused ? 0.18 : 0.08) : (isFocused ? 0.10 : 0.035)), radius: isFocused ? 6 : 2, y: isFocused ? 2 : 1)
            .animation(reduceMotion ? nil : .easeOut(duration: 0.16), value: isFocused)
    }
}

public extension View {
    func transBarSurface(emphasized: Bool = false, isFocused: Bool = false, cornerRadius: CGFloat = 10) -> some View {
        modifier(TransBarSurfaceModifier(emphasized: emphasized, isFocused: isFocused, cornerRadius: cornerRadius))
    }
}

/// 统一的菜单式选项框，避免设置页回退到系统默认灰色 Picker。
public struct TransBarOptionMenu<Value: Hashable>: View {
    public let title: String
    @Binding public var selection: Value
    public let options: [(Value, String)]
    @Environment(\.colorScheme) private var colorScheme
    @Environment(\.isEnabled) private var isEnabled
    @Environment(\.accessibilityReduceMotion) private var reduceMotion
    @State private var isHovered = false
    @State private var isPresented = false

    public init(title: String, selection: Binding<Value>, options: [(Value, String)]) {
        self.title = title
        self._selection = selection
        self.options = options
    }

    private var selectedLabel: String {
        options.first(where: { $0.0 == selection })?.1 ?? title
    }

    public var body: some View {
        Button {
            guard isEnabled else { return }
            isPresented.toggle()
        } label: {
            HStack(spacing: 8) {
                VStack(alignment: .leading, spacing: 2) {
                    Text(title)
                        .font(.system(size: 10, weight: .medium))
                        .foregroundStyle(TransBarInspectorDesign.secondaryText(for: colorScheme))
                    Text(selectedLabel)
                        .font(.system(size: 12, weight: .medium))
                        .foregroundStyle(.primary)
                        .lineLimit(1)
                }
                Spacer(minLength: 4)
                Image(systemName: "chevron.down")
                    .font(.system(size: 9, weight: .semibold))
                    .foregroundStyle(TransBarInspectorDesign.secondaryText(for: colorScheme))
            }
            .padding(.horizontal, 11)
            .padding(.vertical, 10)
            .frame(minHeight: 56, alignment: .leading)
            .frame(maxWidth: .infinity, alignment: .leading)
            .transBarInspectorSurface(emphasized: isHovered || isPresented, isFocused: isPresented, cornerRadius: 10)
        }
        .buttonStyle(.plain)
        .contentShape(RoundedRectangle(cornerRadius: 9, style: .continuous))
        .opacity(isEnabled ? 1 : 0.48)
        .onHover { isHovered = $0 && isEnabled }
        .animation(reduceMotion ? nil : .easeOut(duration: 0.14), value: isHovered || isPresented)
        .accessibilityLabel(title)
        .accessibilityValue(selectedLabel)
        .accessibilityHint(isPresented ? "选项列表已展开" : "点击展开选项列表")
        .popover(isPresented: $isPresented, arrowEdge: .bottom) {
            optionPopover
        }
    }

    private var optionPopover: some View {
        VStack(alignment: .leading, spacing: 7) {
            HStack(spacing: 8) {
                VStack(alignment: .leading, spacing: 2) {
                    Text(title)
                        .font(.system(size: 11, weight: .semibold))
                        .foregroundStyle(TransBarInspectorDesign.secondaryText(for: colorScheme))
                    Text("选择后立即应用")
                        .font(.system(size: 10))
                        .foregroundStyle(.secondary)
                }
                Spacer(minLength: 10)
                Text("\(options.count) 项")
                    .font(.system(size: 10, weight: .medium))
                    .foregroundStyle(.tertiary)
            }
            .padding(.horizontal, 6)
            .padding(.top, 3)

            Divider()

            ScrollView {
                LazyVStack(spacing: 3) {
                    ForEach(Array(options.enumerated()), id: \.offset) { _, option in
                        optionRow(option)
                    }
                }
            }
            .frame(maxHeight: min(CGFloat(max(options.count, 1) * 42 + 2), 300))
        }
        .padding(9)
        .frame(width: 300)
        .background(TransBarInspectorDesign.surfaceGradient(for: colorScheme, emphasized: true))
        .onExitCommand { isPresented = false }
        .accessibilityElement(children: .contain)
    }

    private func optionRow(_ option: (Value, String)) -> some View {
        let isSelected = option.0 == selection
        return Button {
            selection = option.0
            isPresented = false
        } label: {
            HStack(spacing: 9) {
                Image(systemName: isSelected ? "checkmark.circle.fill" : "circle")
                    .font(.system(size: 14, weight: .medium))
                    .foregroundStyle(isSelected ? TransBarInspectorDesign.accent(for: colorScheme) : Color.secondary.opacity(0.52))
                Text(option.1)
                    .font(.system(size: 13, weight: isSelected ? .semibold : .regular))
                    .foregroundStyle(.primary)
                    .lineLimit(1)
                Spacer(minLength: 8)
            }
            .padding(.horizontal, 9)
            .frame(minHeight: 38, alignment: .leading)
            .background(
                isSelected ? TransBarInspectorDesign.accent(for: colorScheme).opacity(colorScheme == .dark ? 0.20 : 0.10) : .clear,
                in: RoundedRectangle(cornerRadius: 8, style: .continuous)
            )
            .contentShape(RoundedRectangle(cornerRadius: 8, style: .continuous))
        }
        .buttonStyle(.plain)
        .accessibilityLabel(option.1)
        .accessibilityAddTraits(isSelected ? .isSelected : [])
        .accessibilityHint(isSelected ? "当前已选中" : "点击选择此项")
    }
}

/// 设置页与个人记忆编辑器使用的统一单行输入框。
public struct TransBarTextFieldStyle: TextFieldStyle {
    public let isFocused: Bool
    @Environment(\.colorScheme) private var colorScheme
    @Environment(\.isEnabled) private var isEnabled

    public init(isFocused: Bool = false) {
        self.isFocused = isFocused
    }

    public func _body(configuration: TextField<Self._Label>) -> some View {
        configuration
            .textFieldStyle(.plain)
            .font(.system(size: 13))
            .foregroundStyle(.primary)
            .padding(.horizontal, 11)
            .frame(minHeight: 44)
            .transBarInspectorSurface(isFocused: isFocused, cornerRadius: 10)
            .opacity(isEnabled ? 1 : 0.48)
    }
}

/// 轻量原生按钮：完整的不可用状态与减少动态效果支持。
public struct ModernButtonStyle: ButtonStyle {
    public enum Variant { case primary, secondary, outline, destructive, ghost }
    public let variant: Variant
    public let size: ControlSize
    @Environment(\.isEnabled) private var isEnabled
    @Environment(\.accessibilityReduceMotion) private var reduceMotion
    @Environment(\.colorScheme) private var colorScheme
    @State private var isHovered = false

    public init(variant: Variant = .secondary, size: ControlSize = .regular) {
        self.variant = variant
        self.size = size
    }

    public func makeBody(configuration: Configuration) -> some View {
        configuration.label
            .font(font)
            .padding(insets)
            .frame(minHeight: minimumHeight)
            .foregroundStyle(foreground)
            .background {
                RoundedRectangle(cornerRadius: radius, style: .continuous)
                    .fill(background(pressed: configuration.isPressed))
                    .overlay {
                        RoundedRectangle(cornerRadius: radius, style: .continuous)
                            .fill(LinearGradient(colors: [.white.opacity(highlightOpacity), .clear], startPoint: .top, endPoint: .bottom))
                    }
            }
            .overlay(RoundedRectangle(cornerRadius: radius, style: .continuous).strokeBorder(border, lineWidth: 0.75).allowsHitTesting(false))
            .shadow(color: .black.opacity(shadowOpacity(pressed: configuration.isPressed)), radius: isHovered ? 3 : 1, x: 0, y: 1)
            .contentShape(RoundedRectangle(cornerRadius: radius, style: .continuous))
            .opacity(isEnabled ? 1 : 0.42)
            .scaleEffect(!reduceMotion && isEnabled && configuration.isPressed ? 0.975 : 1)
            .animation(reduceMotion ? nil : .easeOut(duration: 0.12), value: configuration.isPressed)
            .animation(reduceMotion ? nil : .easeOut(duration: 0.12), value: isHovered)
            .animation(reduceMotion ? nil : .easeOut(duration: 0.12), value: isEnabled)
            .onHover { isHovered = $0 && isEnabled }
    }

    private var font: Font {
        switch size {
        case .mini: return .system(size: 11, weight: .medium)
        case .small: return .system(size: 12, weight: .medium)
        default: return .system(size: 13, weight: .medium)
        }
    }
    private var insets: EdgeInsets {
        switch size {
        case .mini: return EdgeInsets(top: 4, leading: 6, bottom: 4, trailing: 6)
        case .small: return EdgeInsets(top: 5, leading: 9, bottom: 5, trailing: 9)
        case .large, .extraLarge: return EdgeInsets(top: 9, leading: 16, bottom: 9, trailing: 16)
        default: return EdgeInsets(top: 7, leading: 12, bottom: 7, trailing: 12)
        }
    }
    private var minimumHeight: CGFloat {
        switch size {
        case .mini: return 24
        case .small: return 28
        case .large, .extraLarge: return 38
        default: return 32
        }
    }
    private var radius: CGFloat { size == .mini ? 7 : 8 }
    private var foreground: Color {
        switch variant {
        case .primary: return .white
        case .destructive: return colorScheme == .dark ? Color(red: 1, green: 0.48, blue: 0.45) : .red
        case .ghost: return TransBarDesign.secondaryText(for: colorScheme)
        case .secondary: return TransBarDesign.secondaryText(for: colorScheme)
        default: return .primary
        }
    }
    private var border: Color {
        switch variant {
        case .primary: return Color.white.opacity(colorScheme == .dark ? 0.20 : 0.24)
        case .outline, .secondary: return Color.primary.opacity(isEnabled && isHovered ? 0.18 : 0.09)
        case .destructive: return (colorScheme == .dark ? Color.orange : Color.red).opacity(isEnabled && isHovered ? 0.2 : 0.1)
        default: return .clear
        }
    }
    private var highlightOpacity: Double {
        guard isEnabled else { return 0 }
        switch variant {
        case .primary: return isHovered ? 0.16 : 0.09
        case .secondary, .outline: return colorScheme == .dark ? 0.05 : 0.32
        default: return 0
        }
    }
    private func shadowOpacity(pressed: Bool) -> Double {
        guard isEnabled && !pressed else { return 0 }
        switch variant {
        case .primary: return isHovered ? 0.13 : 0.08
        case .secondary, .outline: return isHovered ? 0.045 : 0.025
        default: return 0
        }
    }
    private func background(pressed: Bool) -> Color {
        let active = isEnabled && (pressed || isHovered)
        switch variant {
        case .primary: return TransBarDesign.accent(for: colorScheme).opacity(active ? 0.86 : 1)
        case .secondary:
            return colorScheme == .dark
                ? Color(red: 0.13, green: 0.18, blue: 0.24).opacity(active ? 0.98 : 0.88)
                : Color(red: 0.94, green: 0.96, blue: 0.99).opacity(active ? 1 : 0.92)
        case .outline, .ghost: return Color.primary.opacity(active ? 0.065 : 0)
        case .destructive: return (colorScheme == .dark ? Color.red : Color.red).opacity(active ? 0.13 : 0.065)
        }
    }
}

/// 设置侧栏使用整行点击区域，并保持明确的选中、悬停和按下反馈。
public struct SettingsNavigationButtonStyle: ButtonStyle {
    public let isSelected: Bool
    @Environment(\.colorScheme) private var colorScheme
    @Environment(\.accessibilityReduceMotion) private var reduceMotion
    @State private var isHovered = false

    public init(isSelected: Bool) { self.isSelected = isSelected }

    public func makeBody(configuration: Configuration) -> some View {
        let accent = TransBarInspectorDesign.accent(for: colorScheme)
        configuration.label
            .background {
                RoundedRectangle(cornerRadius: 9, style: .continuous)
                    .fill(isSelected ? accent.opacity(configuration.isPressed ? 0.24 : 0.16) : accent.opacity(configuration.isPressed ? 0.11 : isHovered ? 0.06 : 0))
            }
            .overlay {
                RoundedRectangle(cornerRadius: 9, style: .continuous)
                    .strokeBorder(isSelected ? accent.opacity(0.34) : .clear, lineWidth: 0.8)
                    .allowsHitTesting(false)
            }
            .contentShape(RoundedRectangle(cornerRadius: 9, style: .continuous))
            .animation(reduceMotion ? nil : .easeOut(duration: 0.14), value: isHovered)
            .animation(reduceMotion ? nil : .easeOut(duration: 0.14), value: isSelected)
            .animation(reduceMotion ? nil : .easeOut(duration: 0.1), value: configuration.isPressed)
            .onHover { isHovered = $0 }
    }
}

/// 颜色仅作为辅助线索，状态文字由调用方提供。
public struct StatusDot: View {
    public let color: Color
    public let pulsing: Bool
    @Environment(\.accessibilityReduceMotion) private var reduceMotion
    @State private var isPulsing = false

    public init(color: Color = .green, pulsing: Bool = false) {
        self.color = color
        self.pulsing = pulsing
    }
    public var body: some View {
        ZStack {
            if pulsing && !reduceMotion {
                Circle().fill(color.opacity(isPulsing ? 0 : 0.22))
                    .scaleEffect(isPulsing ? 1.8 : 1)
                    .animation(.easeOut(duration: 1.4).repeatForever(autoreverses: false), value: isPulsing)
            }
            Circle().fill(color).frame(width: 6, height: 6)
        }
        .frame(width: 10, height: 10)
        .onAppear { isPulsing = pulsing && !reduceMotion }
        .onChange(of: pulsing) { isPulsing = $0 && !reduceMotion }
        .onChange(of: reduceMotion) { isPulsing = pulsing && !$0 }
        .accessibilityHidden(true)
    }
}

/// 系统语义底色在浅色与深色模式下保持一致的层级。
public struct ModernGlassCard<Content: View>: View {
    public let content: Content
    public init(@ViewBuilder content: () -> Content) { self.content = content() }
    public var body: some View {
        content
            .padding(14)
            .frame(maxWidth: .infinity, alignment: .leading)
            .background(Color(NSColor.controlBackgroundColor).opacity(0.55), in: RoundedRectangle(cornerRadius: 12, style: .continuous))
            .overlay(RoundedRectangle(cornerRadius: 12, style: .continuous).strokeBorder(Color.primary.opacity(0.07), lineWidth: 0.75))
    }
}

/// 中英双语卡片：在菜单栏小尺寸下直接表达翻译含义。
public struct StatusBarIconFactory {
    public static func makeTemplateIcon() -> NSImage {
        let image = NSImage(size: NSSize(width: 24, height: 18), flipped: false) { _ in
            NSColor.black.setStroke()
            let first = NSBezierPath(roundedRect: NSRect(x: 0.75, y: 3.5, width: 12.5, height: 13.5), xRadius: 2, yRadius: 2)
            first.lineWidth = 1.3
            first.stroke()
            // 重叠处留出透明间距，深色与浅色菜单栏均清晰可辨。
            let secondRect = NSRect(x: 10.5, y: 0.75, width: 12.75, height: 13.5)
            NSColor.clear.setFill()
            NSGraphicsContext.current?.cgContext.clear(secondRect.insetBy(dx: -0.8, dy: -0.8))
            NSColor.black.setStroke()
            let second = NSBezierPath(roundedRect: secondRect, xRadius: 2, yRadius: 2)
            second.lineWidth = 1.3
            second.stroke()
            let attrs: [NSAttributedString.Key: Any] = [.font: NSFont.systemFont(ofSize: 10, weight: .semibold), .foregroundColor: NSColor.black]
            ("A" as NSString).draw(at: NSPoint(x: 3.1, y: 4.9), withAttributes: attrs)
            ("文" as NSString).draw(at: NSPoint(x: 11.8, y: 1.8), withAttributes: [.font: NSFont.systemFont(ofSize: 9.5, weight: .medium), .foregroundColor: NSColor.black])
            return true
        }
        image.isTemplate = true
        image.accessibilityDescription = "中英翻译"
        return image
    }
}
