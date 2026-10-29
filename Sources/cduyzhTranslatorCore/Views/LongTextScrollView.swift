import SwiftUI

/// 保持自然换行、文本选择与单一纵向滚动的长文容器。
public struct LongTextScrollView: View {
    let text: String
    let placeholder: String
    let isSelectable: Bool
    let showsBackground: Bool
    var maxHeight: CGFloat = 220
    var minHeight: CGFloat = 70

    @State private var contentHeight: CGFloat = 0

    public init(
        text: String,
        placeholder: String = "翻译结果将显示在这里",
        isSelectable: Bool = true,
        maxHeight: CGFloat = 220,
        minHeight: CGFloat = 70,
        showsBackground: Bool = true
    ) {
        self.text = text
        self.placeholder = placeholder
        self.isSelectable = isSelectable
        self.maxHeight = maxHeight
        self.minHeight = minHeight
        self.showsBackground = showsBackground
    }

    public var body: some View {
        ScrollViewReader { proxy in
            ScrollView(.vertical, showsIndicators: true) {
                textContent
                    .font(.system(size: 13))
                    .lineSpacing(4)
                    .fixedSize(horizontal: false, vertical: true)
                    .frame(maxWidth: .infinity, alignment: .leading)
                    .padding(.horizontal, showsBackground ? 12 : 0)
                    .padding(.vertical, showsBackground ? 12 : 4)
                    .background {
                        GeometryReader { geometry in
                            Color.clear.preference(key: LongTextHeightKey.self, value: geometry.size.height)
                        }
                    }
                    .id("longTextStart")
            }
            .onChange(of: text) { _ in
                proxy.scrollTo("longTextStart", anchor: .top)
            }
        }
        .frame(height: min(max(contentHeight, lowerHeight), upperHeight))
        .frame(maxWidth: .infinity)
        .background(Color(NSColor.textBackgroundColor).opacity(showsBackground ? 0.7 : 0), in: RoundedRectangle(cornerRadius: 10))
        .overlay {
            RoundedRectangle(cornerRadius: 10)
                .strokeBorder(Color.secondary.opacity(showsBackground ? 0.12 : 0))
        }
        .onPreferenceChange(LongTextHeightKey.self) { height in
            if abs(contentHeight - height) > 0.5 {
                contentHeight = height
            }
        }
    }

    @ViewBuilder
    private var textContent: some View {
        if text.isEmpty {
            Text(placeholder)
                .foregroundStyle(.secondary)
        } else if isSelectable {
            Text(text)
                .foregroundStyle(.primary)
                .textSelection(.enabled)
        } else {
            Text(text)
                .foregroundStyle(.primary)
        }
    }

    private var lowerHeight: CGFloat { max(0, minHeight) }
    private var upperHeight: CGFloat { max(lowerHeight, maxHeight) }
}

private struct LongTextHeightKey: PreferenceKey {
    static var defaultValue: CGFloat = 0

    static func reduce(value: inout CGFloat, nextValue: () -> CGFloat) {
        value = max(value, nextValue())
    }
}
