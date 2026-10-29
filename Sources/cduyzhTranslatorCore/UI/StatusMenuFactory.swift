import AppKit
import SwiftUI

/// 保留原生菜单的键盘、选中态和辅助功能，常用入口与维护操作分层呈现。
enum StatusMenuFactory {
    static func makeMenu(target: AppDelegate, engineName: String, updateAvailable: Bool) -> NSMenu {
        let menu = NSMenu()
        menu.minimumWidth = 260
        let header = NSMenuItem()
        header.view = StatusMenuHeader(engineName: engineName)
        menu.addItem(header)
        menu.addItem(.separator())

        func item(_ title: String, _ symbol: String, _ action: Selector, _ key: String = "") -> NSMenuItem {
            let row = NSMenuItem(title: title, action: action, keyEquivalent: key)
            row.target = target
            row.image = NSImage(systemSymbolName: symbol, accessibilityDescription: nil)
            return row
        }
        menu.addItem(item("打开翻译面板", "character.bubble", #selector(AppDelegate.openPanelAction), "t"))
        menu.addItem(item("设置…", "slider.horizontal.3", #selector(AppDelegate.openSettingsAction), ","))
        menu.addItem(item(updateAvailable ? "发现新版本…" : "检查更新…", "arrow.down.circle", #selector(AppDelegate.openUpdateAction), "u"))
        menu.addItem(.separator())
        let maintenance = NSMenuItem(title: "维护", action: nil, keyEquivalent: "")
        maintenance.image = NSImage(systemSymbolName: "wrench.and.screwdriver", accessibilityDescription: nil)
        let submenu = NSMenu()
        submenu.addItem(item("按保留策略清理缓存", "externaldrive", #selector(AppDelegate.cleanupSpaceAction)))
        submenu.addItem(item("重新加载快捷键", "keyboard", #selector(AppDelegate.reloadHotkeyAction)))
        submenu.addItem(item("重新启动译栏", "arrow.clockwise", #selector(AppDelegate.restartAppAction)))
        maintenance.submenu = submenu
        menu.addItem(maintenance)
        menu.addItem(.separator())
        menu.addItem(item("退出译栏", "power", #selector(AppDelegate.quitAppAction), "q"))
        return menu
    }
}

private final class StatusMenuHeader: NSView {
    init(engineName: String) {
        super.init(frame: NSRect(x: 0, y: 0, width: 268, height: 64))
        let icon = NSImageView(frame: NSRect(x: 17, y: 22, width: 28, height: 28))
        icon.image = StatusBarIconFactory.makeTemplateIcon()
        icon.contentTintColor = .labelColor
        addSubview(icon)
        let title = NSTextField(labelWithString: "译栏")
        title.font = .systemFont(ofSize: 14, weight: .semibold)
        title.textColor = .labelColor
        title.frame = NSRect(x: 56, y: 35, width: 196, height: 20)
        addSubview(title)
        let subtitle = NSTextField(labelWithString: "\(engineName) · ⌘C C 快速翻译")
        subtitle.font = .systemFont(ofSize: 11)
        subtitle.textColor = .secondaryLabelColor
        subtitle.frame = NSRect(x: 56, y: 15, width: 202, height: 16)
        addSubview(subtitle)
        setAccessibilityElement(true)
        setAccessibilityLabel("译栏，\(engineName)。按住 Command 连按两次 C 自动翻译；点击图标打开面板。")
    }
    required init?(coder: NSCoder) { nil }
}

/// 面板“更多”与状态栏右键共用同一个原生菜单，保持入口和交互一致。
struct StatusMenuButton: NSViewRepresentable {
    func makeNSView(context: Context) -> NSButton {
        let button = NSButton(image: NSImage(systemSymbolName: "ellipsis", accessibilityDescription: "更多操作")!, target: context.coordinator, action: #selector(Coordinator.showMenu(_:)))
        button.isBordered = false
        button.imagePosition = .imageOnly
        button.setAccessibilityLabel("更多操作")
        button.toolTip = "更多操作，与状态栏右键菜单一致"
        return button
    }
    func updateNSView(_ button: NSButton, context: Context) {}
    func makeCoordinator() -> Coordinator { Coordinator() }
    @MainActor
    final class Coordinator: NSObject {
        @objc func showMenu(_ button: NSButton) {
            guard let delegate = AppDelegate.shared else { return }
            let menu = StatusMenuFactory.makeMenu(target: delegate, engineName: AppSettings.shared.selectedEngine.displayName,
                                                 updateAvailable: AppSettings.shared.hasNewUpdateAvailable)
            // 先返回按钮的辅助功能动作，再进入菜单跟踪循环。
            DispatchQueue.main.async {
                menu.popUp(positioning: nil, at: NSPoint(x: 0, y: button.bounds.minY), in: button)
            }
        }
    }
}
