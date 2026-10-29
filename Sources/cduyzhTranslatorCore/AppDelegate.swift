import AppKit
import SwiftUI
import Combine

/// macOS 应用程序代理类，管理状态栏图标、悬浮窗以及全局生命周期
@MainActor
public final class AppDelegate: NSObject, NSApplicationDelegate {
    public static var shared: AppDelegate?

    private var statusItem: NSStatusItem?
    private var popover: NSPopover?
    private var popoverAnchorWindow: NSWindow?
    private var eventMonitor: Any?
    private var localKeyMonitor: Any?
    private var lastTranslatedText: String = ""
    private var settingsPresented = false
    private var isEditingMemory = false
    private var subscriptions = Set<AnyCancellable>()

    public func applicationDidFinishLaunching(_ notification: Notification) {
        AppDelegate.shared = self

        // 0. 安装系统主菜单 (提供 Cmd+C, Cmd+V, Cmd+A, Cmd+X, Cmd+Z 等标准编辑快捷键通道)
        setupMainMenu()

        // 1. 设置系统状态栏图标 (NSStatusItem)
        setupStatusItem()

        // 2. 初始化 Popover 悬浮弹窗
        setupPopover()

        // 3. 启动 Command+C+C 与兼容的 Option+Z / Control+Z 全局快捷键
        setupGlobalHotkey()
        setupSelectionTranslation()

        // 4. 启动本地 Agent Gateway HTTP 服务 (端口 11899)
        if AppSettings.shared.agentServerEnabled {
            AgentGatewayServer.shared.start()
        }

        // 5. 监听点击应用外自动关闭弹窗 (当未处于 Pin 固定状态时)
        setupEventMonitor()

        // 6. 执行启动时自动存储空间健康检查与清理策略
        Task { @MainActor in
            CacheStorageManager.shared.performAutoCleanupIfNeeded()
        }

        // 7. 启动时执行版本更新检测 (若用户启用了自动检查)
        Task { @MainActor in
            AppUpdateChecker.shared.performAutoCheckIfNeeded()
        }

        // 8. 注册面板操作广播 (一键关闭、一键重启等)
        NotificationCenter.default.addObserver(self, selector: #selector(closePopoverAction), name: NSNotification.Name("ClosePopoverNotification"), object: nil)
        NotificationCenter.default.addObserver(self, selector: #selector(restartAppAction), name: NSNotification.Name("RestartAppNotification"), object: nil)
        NotificationCenter.default.addObserver(self, selector: #selector(reloadHotkeyAction), name: NSNotification.Name("ReloadHotkeyNotification"), object: nil)
        NotificationCenter.default.publisher(for: NSNotification.Name("SettingsPresentationChanged"))
            .sink { [weak self] notification in
                self?.settingsPresented = notification.object as? Bool ?? false
            }
            .store(in: &subscriptions)
        NotificationCenter.default.publisher(for: NSNotification.Name("MemoryEditingChanged"))
            .sink { [weak self] notification in
                self?.isEditingMemory = notification.object as? Bool ?? false
            }
            .store(in: &subscriptions)
        AppSettings.shared.$windowPinned
            .receive(on: RunLoop.main)
            .sink { [weak self] pinned in
                self?.popover?.behavior = pinned ? .applicationDefined : .transient
            }
            .store(in: &subscriptions)
        NotificationCenter.default.publisher(for: NSApplication.didBecomeActiveNotification)
            .receive(on: RunLoop.main)
            .sink { _ in
                let wasTrusted = GlobalHotkeyManager.shared.hasAccessibilityPermission
                let isTrusted = GlobalHotkeyManager.shared.checkPermission(prompt: false)
                if isTrusted, !wasTrusted, AppSettings.shared.hotkeyEnabled,
                   AppSettings.shared.hotkeyMode.usesCommandDoubleTap {
                    GlobalHotkeyManager.shared.restartMonitoring()
                }
                if AppSettings.shared.selectionTranslationEnabled {
                    Task { @MainActor in
                        SelectionTranslationManager.shared.updateEnabled(true)
                        SelectionTranslationManager.shared.start()
                    }
                }
            }
            .store(in: &subscriptions)

        print("[AppDelegate] cduyzhTranslator 已成功启动并在状态栏常驻")
    }

    @objc public func closePopoverAction() {
        closePopover()
    }

    // MARK: - 主菜单与系统标准编辑操作 (彻底解决无主菜单导致无法使用 Cmd+V 粘贴、Cmd+C 复制、Cmd+A 全选等问题)
    private func setupMainMenu() {
        let mainMenu = NSMenu()

        // 1. 应用菜单
        let appMenuItem = NSMenuItem()
        let appMenu = NSMenu()
        appMenu.addItem(withTitle: "关于 译栏 TransBar", action: #selector(NSApplication.orderFrontStandardAboutPanel(_:)), keyEquivalent: "")
        appMenu.addItem(withTitle: "检查更新与更新日志...", action: #selector(openUpdateAction), keyEquivalent: "u")
        appMenu.addItem(NSMenuItem.separator())
        appMenu.addItem(withTitle: "隐藏 译栏 TransBar", action: #selector(NSApplication.hide(_:)), keyEquivalent: "h")
        appMenu.addItem(withTitle: "隐藏其他", action: #selector(NSApplication.hideOtherApplications(_:)), keyEquivalent: "h")
        appMenu.addItem(NSMenuItem.separator())
        appMenu.addItem(withTitle: "退出 译栏 TransBar", action: #selector(NSApplication.terminate(_:)), keyEquivalent: "q")
        appMenuItem.submenu = appMenu
        mainMenu.addItem(appMenuItem)

        // 2. 编辑菜单 (关键系统 Edit 菜单，提供标准快捷键通道)
        let editMenuItem = NSMenuItem()
        let editMenu = NSMenu(title: "编辑")
        editMenu.addItem(withTitle: "撤销", action: #selector(UndoManager.undo), keyEquivalent: "z")
        editMenu.addItem(withTitle: "重做", action: #selector(UndoManager.redo), keyEquivalent: "Z")
        editMenu.addItem(NSMenuItem.separator())
        editMenu.addItem(withTitle: "剪切", action: #selector(NSText.cut(_:)), keyEquivalent: "x")
        editMenu.addItem(withTitle: "复制", action: #selector(NSText.copy(_:)), keyEquivalent: "c")
        editMenu.addItem(withTitle: "粘贴", action: #selector(NSText.paste(_:)), keyEquivalent: "v")
        editMenu.addItem(withTitle: "全选", action: #selector(NSText.selectAll(_:)), keyEquivalent: "a")
        editMenuItem.submenu = editMenu
        mainMenu.addItem(editMenuItem)

        // 3. 窗口菜单
        let windowMenuItem = NSMenuItem()
        let windowMenu = NSMenu(title: "窗口")
        windowMenu.addItem(withTitle: "关闭窗口", action: #selector(NSWindow.performClose(_:)), keyEquivalent: "w")
        windowMenuItem.submenu = windowMenu
        mainMenu.addItem(windowMenuItem)

        NSApp.mainMenu = mainMenu
    }

    // MARK: - 状态栏图标设置
    private func setupStatusItem() {
        statusItem = NSStatusBar.system.statusItem(withLength: NSStatusItem.variableLength)

        guard let button = statusItem?.button else { return }

        // 使用专属自适应 Template 矢量图标
        button.image = StatusBarIconFactory.makeTemplateIcon()
        button.setAccessibilityLabel("译栏：翻译面板与状态")
        button.toolTip = "译栏 TransBar (左键翻译 · 右键状态)"
        button.action = #selector(handleStatusItemClick)
        button.target = self
        button.sendAction(on: [.leftMouseUp, .rightMouseUp])
    }

    // MARK: - 悬浮弹窗设置
    private func setupPopover() {
        let popover = NSPopover()
        // Keep the popover frame aligned with the Quiet Native double-column panel.
        popover.contentSize = NSSize(width: 780, height: 680)
        popover.behavior = .transient
        popover.animates = !NSWorkspace.shared.accessibilityDisplayShouldReduceMotion

        let mainView = MainTranslateView()
        popover.contentViewController = NSHostingController(rootView: mainView)
        self.popover = popover
    }

    // MARK: - 全局快捷键绑定
    private func setupGlobalHotkey() {
        let hotkeyManager = GlobalHotkeyManager.shared

        hotkeyManager.onOpenPanel = { [weak self] in
            guard let self, let button = self.statusItem?.button else { return }
            self.showPopover(button: button)
        }
        hotkeyManager.onTriggerTranslation = { [weak self] capturedText in
            guard let self = self else { return }
            self.showPopoverWithText(capturedText)
        }

        if AppSettings.shared.hotkeyEnabled {
            // 启动时不主动弹系统授权框；需要时由设置页明确发起授权。
            hotkeyManager.startMonitoring(requestPermission: false)
        }
    }

    private func setupSelectionTranslation() {
        Task { @MainActor [weak self] in
            SelectionTranslationManager.shared.onTranslateSelection = { [weak self] text in
                self?.showPopoverWithText(text)
            }
            SelectionTranslationManager.shared.updateEnabled(AppSettings.shared.selectionTranslationEnabled)
            SelectionTranslationManager.shared.start()
        }
        AppSettings.shared.$selectionTranslationEnabled
            .receive(on: RunLoop.main)
            .sink { enabled in
                Task { @MainActor in
                    SelectionTranslationManager.shared.updateEnabled(enabled)
                    if enabled { SelectionTranslationManager.shared.start() }
                }
            }
            .store(in: &subscriptions)
    }

    // MARK: - 鼠标点击分流 (左键弹窗，右键状态控制面板)
    @objc public func handleStatusItemClick() {
        guard let button = statusItem?.button else { return }
        guard let event = NSApp.currentEvent else {
            togglePopover()
            return
        }

        if event.type == .rightMouseUp || event.modifierFlags.contains(.control) {
            // 右键点击：展示 SnapScreen / TouchFlow 风格的毛玻璃悬浮状态控制面板
            closePopover()
            StatusPanelController.shared.toggle(relativeTo: button)
        } else {
            // 左键点击：打开翻译主面板
            StatusPanelController.shared.close()
            togglePopover()
        }
    }

    private func showContextMenu() {
        guard let button = statusItem?.button else { return }
        closePopover()
        StatusPanelController.shared.show(relativeTo: button)
    }

    @objc func openPanelAction() {
        guard let button = statusItem?.button else { return }
        showPopover(button: button)
    }

    @objc func openSettingsAction() {
        openSettings()
    }

    /// 打开设置面板并支持无缝跳转至指定 Tab
    public func openSettings(tab: Int? = nil) {
        guard let button = statusItem?.button else { return }
        showPopover(button: button)
        NotificationCenter.default.post(name: NSNotification.Name("OpenSettingsNotification"), object: nil)
        if let tab = tab {
            DispatchQueue.main.asyncAfter(deadline: .now() + 0.1) {
                NotificationCenter.default.post(name: NSNotification.Name("SwitchSettingsTabNotification"), object: tab)
            }
        }
    }

    @objc public func openUpdateAction() {
        guard let button = statusItem?.button else { return }
        showPopover(button: button)
        NotificationCenter.default.post(name: NSNotification.Name("OpenSettingsNotification"), object: nil)
        DispatchQueue.main.asyncAfter(deadline: .now() + 0.1) {
            NotificationCenter.default.post(name: NSNotification.Name("SwitchSettingsTabNotification"), object: 7)
        }
        Task { @MainActor in
            await AppUpdateChecker.shared.checkForUpdates(isManual: true)
        }
    }

    @objc func cleanupSpaceAction() {
        Task { @MainActor in
            let res = CacheStorageManager.shared.performAutoCleanupIfNeeded(force: true)
            print("[CacheStorage] " + res.message)
        }
    }

    @objc public func reloadHotkeyAction() {
        GlobalHotkeyManager.shared.checkAndRefreshMonitoring()
    }

    @objc public func restartAppAction() {
        AppDelegate.restartApplication()
    }

    @objc func quitAppAction() {
        NSApplication.shared.terminate(nil)
    }

    /// 一键优雅重启当前应用程序
    public static func restartApplication() {
        print("[AppDelegate] 正在执行应用一键重启...")
        let bundleURL = Bundle.main.bundleURL
        let isAppBundle = bundleURL.pathExtension == "app"

        let task = Process()
        if isAppBundle {
            task.executableURL = URL(fileURLWithPath: "/usr/bin/open")
            task.arguments = ["-n", bundleURL.path]
        } else {
            let execURL = Bundle.main.executableURL ?? URL(fileURLWithPath: CommandLine.arguments[0])
            task.executableURL = execURL
            task.arguments = Array(CommandLine.arguments.dropFirst())
        }

        do {
            try task.run()
            DispatchQueue.main.asyncAfter(deadline: .now() + 0.1) {
                NSApp.terminate(nil)
            }
        } catch {
            print("[AppDelegate] 重启应用程序失败: \(error)")
        }
    }

    // MARK: - 弹窗开关控制
    @objc public func togglePopover() {
        guard let popover = popover, let button = statusItem?.button else { return }

        if popover.isShown {
            closePopover()
        } else {
            showPopover(button: button)
        }
    }

    public func showPopover(button: NSStatusBarButton) {
        StatusPanelController.shared.close()
        guard let popover, let anchorView = centeredPopoverAnchorView() else { return }

        // 激活当前应用到前台
        NSApp.activate(ignoringOtherApps: true)

        // 检查是否 Pin 固定
        popover.behavior = AppSettings.shared.windowPinned ? .applicationDefined : .transient

        popover.show(relativeTo: anchorView.bounds, of: anchorView, preferredEdge: .minY)

        // 确保悬浮窗成为系统焦点 Key Window，使文本输入和键盘事件立即可用
        DispatchQueue.main.async {
            if let window = popover.contentViewController?.view.window {
                window.makeKeyAndOrderFront(nil)
            }
        }
    }

    /// Anchor the translating panel below the center of the primary screen's visible area.
    private func centeredPopoverAnchorView() -> NSView? {
        guard let screen = NSScreen.main ?? NSScreen.screens.first else { return nil }
        let size = NSSize(width: 1, height: 1)
        let origin = PopoverAnchorPlacement.origin(visibleFrame: screen.visibleFrame, anchorSize: size)
        let frame = NSRect(origin: origin, size: size)
        let anchor: NSWindow
        if let existing = popoverAnchorWindow {
            anchor = existing
            anchor.setFrame(frame, display: false)
        } else {
            anchor = NSWindow(contentRect: frame, styleMask: [.borderless], backing: .buffered, defer: false)
            anchor.isReleasedWhenClosed = false
            anchor.isOpaque = false
            anchor.backgroundColor = .clear
            anchor.alphaValue = 0
            anchor.hasShadow = false
            anchor.ignoresMouseEvents = true
            anchor.collectionBehavior = [.canJoinAllSpaces, .fullScreenAuxiliary, .ignoresCycle]
            popoverAnchorWindow = anchor
        }
        anchor.orderFrontRegardless()
        return anchor.contentView
    }

    public func closePopover() {
        if settingsPresented {
            NotificationCenter.default.post(name: NSNotification.Name("CloseSettingsNotification"), object: nil)
        }
        popover?.performClose(nil)
    }

    public func applicationShouldHandleReopen(_ sender: NSApplication, hasVisibleWindows flag: Bool) -> Bool {
        if let button = statusItem?.button { showPopover(button: button) }
        return true
    }

    /// Command+C+C 或用户点击划词按钮时，填入捕获文本并翻译。
    public func showPopoverWithText(_ text: String) {
        guard let button = statusItem?.button else { return }

        let targetText = text
        let cleanText = targetText.trimmingCharacters(in: .whitespacesAndNewlines)

        // 智能 Toggle：若弹窗已在前台显示，且剪贴板内容与上次完全一致（用户未复制新文本），再次按下热键则优雅收起
        if let pop = popover, pop.isShown, NSApp.isActive, cleanText == lastTranslatedText && !cleanText.isEmpty {
            closePopover()
            return
        }

        lastTranslatedText = cleanText

        if popover?.isShown == false {
            showPopover(button: button)
        } else {
            NSApp.activate(ignoringOtherApps: true)
            DispatchQueue.main.async {
                self.popover?.contentViewController?.view.window?.makeKeyAndOrderFront(nil)
            }
        }

        // 发送广播触发自动翻译
        NotificationCenter.default.post(
            name: NSNotification.Name("TriggerTranslateNotification"),
            object: targetText
        )
    }

    // MARK: - 点击外部关闭与键盘全局监视器 (ESC 退出、⌘⏎ 快速翻译)
    private func setupEventMonitor() {
        // 点击外部关闭弹窗 (当未处于 Pin 固定状态时)
        eventMonitor = NSEvent.addGlobalMonitorForEvents(matching: [.leftMouseDown, .rightMouseDown]) { [weak self] _ in
            guard let self = self, let popover = self.popover, popover.isShown else { return }
            if !AppSettings.shared.windowPinned {
                self.closePopover()
            }
        }

        // 浮窗内键盘快捷键拦截 (ESC 一键收起、⌘+Return 快速翻译)
        localKeyMonitor = NSEvent.addLocalMonitorForEvents(matching: [.keyDown]) { [weak self] event in
            guard let self = self, let popover = self.popover, popover.isShown else { return event }
            guard let panelWindow = popover.contentViewController?.view.window,
                  event.window === panelWindow || event.window?.sheetParent === panelWindow else { return event }

            // ESC 键 (keyCode 53)：一键收起浮窗或关闭设置
            if event.keyCode == 53 {
                // 原生 sheet/alert 处理自己的取消，避免同时收起背后的翻译面板。
                if panelWindow.attachedSheet != nil || self.isEditingMemory { return event }
                if self.settingsPresented {
                    NotificationCenter.default.post(name: NSNotification.Name("CloseSettingsNotification"), object: nil)
                    return nil
                }
                self.closePopover()
                return nil
            }

            // Command + Return (keyCode 36 且包含 command)：快速发起翻译
            if event.keyCode == 36 && event.modifierFlags.contains(.command) {
                guard !self.settingsPresented, !self.isEditingMemory, panelWindow.attachedSheet == nil else { return event }
                NotificationCenter.default.post(name: NSNotification.Name("ExecuteTranslateNotification"), object: nil)
                return nil
            }

            // Command + , (keyCode 43)：快捷打开偏好设置
            if event.keyCode == 43 && event.modifierFlags.contains(.command) {
                NotificationCenter.default.post(name: NSNotification.Name("OpenSettingsNotification"), object: nil)
                return nil
            }

            // Command + 1..6：快捷切换设置 Tab
            if event.modifierFlags.contains(.command), self.settingsPresented {
                let tabMap: [UInt16: Int] = [18: 0, 19: 1, 20: 2, 21: 3, 23: 4, 22: 5]
                if let tabIndex = tabMap[event.keyCode] {
                    NotificationCenter.default.post(name: NSNotification.Name("SwitchSettingsTabNotification"), object: tabIndex)
                    return nil
                }
            }

            return event
        }
    }

    public func applicationWillTerminate(_ notification: Notification) {
        MainActor.assumeIsolated { SelectionTranslationManager.shared.stop() }
        subscriptions.removeAll()
        NotificationCenter.default.removeObserver(self)
        GlobalHotkeyManager.shared.stopMonitoring()
        AgentGatewayServer.shared.stop()
        if let monitor = eventMonitor {
            NSEvent.removeMonitor(monitor)
        }
        if let keyMonitor = localKeyMonitor {
            NSEvent.removeMonitor(keyMonitor)
        }
    }
}

enum PopoverAnchorPlacement {
    static func origin(visibleFrame: NSRect, anchorSize: NSSize) -> NSPoint {
        NSPoint(
            x: visibleFrame.midX - anchorSize.width / 2,
            y: visibleFrame.maxY - anchorSize.height
        )
    }
}
