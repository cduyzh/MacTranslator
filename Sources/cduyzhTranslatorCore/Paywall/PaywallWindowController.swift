import AppKit
import SwiftUI

@MainActor
public final class PaywallWindowController: NSObject, NSWindowDelegate {
    public static let shared = PaywallWindowController()

    private var window: NSWindow?

    private override init() {
        super.init()
    }

    /// 弹出付费墙
    /// - Parameter reason: 触发付费墙的原因提示（例如“解锁无限历史记录”、“AI Agent 高级功能”）
    public func show(reason: String? = nil) {
        if let existing = window {
            existing.makeKeyAndOrderFront(nil)
            NSApp.activate(ignoringOtherApps: true)
            return
        }

        let paywallView = PaywallView(onDismiss: { [weak self] in
            self?.close()
        })

        let hostingView = NSHostingView(rootView: paywallView)

        let newWindow = NSWindow(
            contentRect: NSRect(x: 0, y: 0, width: 660, height: 740),
            styleMask: [.titled, .closable, .miniaturizable, .fullSizeContentView],
            backing: .buffered,
            defer: false
        )

        newWindow.title = "TransBar Pro 商业许可"
        newWindow.titlebarAppearsTransparent = true
        newWindow.titleVisibility = .hidden
        newWindow.isMovableByWindowBackground = true
        newWindow.contentView = hostingView
        newWindow.center()
        newWindow.delegate = self
        newWindow.isReleasedWhenClosed = false

        self.window = newWindow
        newWindow.makeKeyAndOrderFront(nil)
        NSApp.activate(ignoringOtherApps: true)
    }

    public func close() {
        window?.close()
        window = nil
        LicenseManager.shared.refreshState()
    }

    public func windowWillClose(_ notification: Notification) {
        window = nil
        LicenseManager.shared.refreshState()
    }
}
