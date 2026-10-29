import SwiftUI

/// The translation panel adopts Liquid Glass on macOS 26/27 while keeping
/// the existing AppKit popover material for macOS 13–25.
struct TranslatorPanelSurface: ViewModifier {
    @Environment(\.colorScheme) private var colorScheme

    func body(content: Content) -> some View {
        if #available(macOS 26.0, *) {
            content
                .background(TransBarInspectorDesign.surfaceGradient(for: colorScheme, emphasized: true), in: RoundedRectangle(cornerRadius: 18, style: .continuous))
                .glassEffect(.regular, in: RoundedRectangle(cornerRadius: 18, style: .continuous))
                .overlay {
                    RoundedRectangle(cornerRadius: 18, style: .continuous)
                        .strokeBorder(Color.white.opacity(colorScheme == .dark ? 0.10 : 0.48), lineWidth: 0.8)
                }
        } else {
            content
                .background(VisualEffectView(material: .popover, blendingMode: .behindWindow))
                .background(TransBarInspectorDesign.surfaceGradient(for: colorScheme, emphasized: true))
                .overlay {
                    RoundedRectangle(cornerRadius: 18, style: .continuous)
                        .strokeBorder(Color.primary.opacity(colorScheme == .dark ? 0.14 : 0.08), lineWidth: 0.8)
                }
        }
    }
}

