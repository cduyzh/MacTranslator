import Foundation
import AppKit
import Carbon

/// C 函数指针，响应 Carbon 全局系统热键回调 (无需 macOS 辅助功能权限)
private func carbonHotKeyEventHandler(
    nextHandler: EventHandlerCallRef?,
    theEvent: EventRef?,
    userData: UnsafeMutableRawPointer?
) -> OSStatus {
    guard let theEvent = theEvent else { return noErr }
    var hotKeyID = EventHotKeyID()
    let status = GetEventParameter(
        theEvent,
        EventParamName(kEventParamDirectObject),
        EventParamType(typeEventHotKeyID),
        nil,
        MemoryLayout<EventHotKeyID>.size,
        nil,
        &hotKeyID
    )
    if status == noErr {
        DispatchQueue.main.async {
            GlobalHotkeyManager.shared.handleCarbonHotKeyTriggered(id: hotKeyID.id)
        }
    }
    return noErr
}

/// 全局快捷键管理器：支持 Command+C+C 连击，以及免授权的 Option+Z / Control+Z。
public final class GlobalHotkeyManager: ObservableObject {
    public static let shared = GlobalHotkeyManager()
    
    @Published public var hasAccessibilityPermission: Bool = false
    @Published public var isMonitoring: Bool = false
    @Published public var activeHotkeyTitle: String = "Command+C+C (⌘C⌘C)"
    
    // Carbon 全局热键句柄引用
    private var eventHandlerRef: EventHandlerRef?
    private var registeredHotKeys: [EventHotKeyRef] = []
    
    // NSEvent 本地监视器 (本应用聚焦时)
    private var localMonitor: Any?

    // NSEvent 全局监视器 (其他应用聚焦时，识别 ⌘C⌘C)
    private var globalCommandCMonitor: Any?
    private var commandCDetector = CommandCShortcutDetector()
    
    // 防抖去重
    private var lastTriggerTime: TimeInterval = 0
    private let debounceInterval: TimeInterval = 0.35 // 350毫秒防抖窗口
    
    // 快捷键回调闭包 (传递捕获到的剪贴板内容)
    public var onTriggerTranslation: ((String) -> Void)?
    public var onOpenPanel: (() -> Void)?
    
    // 热键标识常量 (Key: 'Z' = 6)
    private let hotKeySignature = OSType(0x4344555A) // 'CDUZ'
    private let idOptionZ: UInt32 = 1001 // Option+Z (Alt+Z)
    private let idControlZ: UInt32 = 1002 // Control+Z
    private let idCtrlOptionZ: UInt32 = 1003 // Control+Option+Z
    
    private init() {
        checkPermission(prompt: false)
    }
    
    deinit {
        stopMonitoring()
    }
    
    // MARK: - 权限检测与引导 (兼容保留)
    
    /// 检查 macOS 辅助功能权限；全局 Command+C+C 识别需要该权限。
    @discardableResult
    public func checkPermission(prompt: Bool = false) -> Bool {
        let trusted: Bool
        if prompt {
            let options = [kAXTrustedCheckOptionPrompt.takeUnretainedValue() as String: true] as CFDictionary
            trusted = AXIsProcessTrustedWithOptions(options)
        } else {
            trusted = AXIsProcessTrusted()
        }
        
        let updateState = {
            self.hasAccessibilityPermission = trusted
        }
        if Thread.isMainThread {
            updateState()
        } else {
            DispatchQueue.main.async(execute: updateState)
        }
        return trusted
    }
    
    /// 引导打开系统辅助功能偏好设置
    public func promptOpenAccessibilitySettings() {
        checkPermission(prompt: true)
        if let url = URL(string: "x-apple.systempreferences:com.apple.preference.security?Privacy_Accessibility") {
            NSWorkspace.shared.open(url)
        }
    }

    /// 用户从系统设置返回后重新检测；授权成功时重装监视器，无需重启应用。
    @discardableResult
    public func refreshPermissionAndRestartIfNeeded() -> Bool {
        let trusted = checkPermission(prompt: false)
        if trusted, isMonitoring {
            restartMonitoring()
        }
        return trusted
    }
    
    // MARK: - 监听启动与销毁
    
    /// 启动全局快捷键监听。⌘C⌘C 依赖辅助功能权限，⌥Z / ⌃Z 仍免授权可用。
    public func startMonitoring(requestPermission: Bool = false) {
        guard !isMonitoring else { return }

        let mode = AppSettings.shared.hotkeyMode
        let trusted = checkPermission(prompt: requestPermission && mode.usesCommandDoubleTap)
        
        if mode.usesCarbonHotkey {
            // Carbon 热键作为免授权备用方案。
            setupCarbonEventHandler()
            registerHotKeys()
            setupLocalMonitor()
        }

        if mode.usesCommandDoubleTap {
            setupGlobalCommandCMonitor()
        }
        
        isMonitoring = true
        updateActiveHotkeyTitle()
        if mode.usesCommandDoubleTap && !trusted {
            print("[GlobalHotkeyManager] ⚠️ 已启用 [\(activeHotkeyTitle)]，但 ⌘C⌘C 等待辅助功能授权")
        } else {
            print("[GlobalHotkeyManager] ✅ 已启用全局快捷键 [\(activeHotkeyTitle)]")
        }
    }
    
    /// 停止全局按键监听
    public func stopMonitoring() {
        unregisterHotKeys()
        removeCarbonEventHandler()
        
        if let monitor = localMonitor {
            NSEvent.removeMonitor(monitor)
            localMonitor = nil
        }

        if let monitor = globalCommandCMonitor {
            NSEvent.removeMonitor(monitor)
            globalCommandCMonitor = nil
        }

        commandCDetector.reset()
        lastTriggerTime = 0
        
        isMonitoring = false
        print("[GlobalHotkeyManager] ⏹️ 已注销全局热键监听")
    }
    
    /// 重启或刷新快捷键监听服务
    public func restartMonitoring(requestPermission: Bool = false) {
        stopMonitoring()
        startMonitoring(requestPermission: requestPermission)
    }
    
    /// 手动刷新
    public func checkAndRefreshMonitoring() {
        checkPermission(prompt: false)
        restartMonitoring(requestPermission: AppSettings.shared.hotkeyMode.usesCommandDoubleTap)
    }
    
    // MARK: - Carbon 热键底层注册与解绑
    
    private func setupCarbonEventHandler() {
        guard eventHandlerRef == nil else { return }
        var eventType = EventTypeSpec(
            eventClass: OSType(kEventClassKeyboard),
            eventKind: UInt32(kEventHotKeyPressed)
        )
        
        let status = InstallEventHandler(
            GetEventDispatcherTarget(),
            carbonHotKeyEventHandler,
            1,
            &eventType,
            nil,
            &eventHandlerRef
        )
        
        if status != noErr {
            print("[GlobalHotkeyManager] ❌ InstallEventHandler 失败，错误码: \(status)")
        }
    }
    
    private func removeCarbonEventHandler() {
        if let handler = eventHandlerRef {
            RemoveEventHandler(handler)
            eventHandlerRef = nil
        }
    }
    
    private func registerHotKeys() {
        unregisterHotKeys()
        
        let mode = AppSettings.shared.hotkeyMode
        let keyCodeZ = UInt32(kVK_ANSI_Z) // 物理键 'Z' (键码 6)
        
        // 1. 注册 Option + Z (Alt + Z)
        if mode == .both || mode == .optionZ {
            var hotKeyRef1: EventHotKeyRef?
            let hotKeyID1 = EventHotKeyID(signature: hotKeySignature, id: idOptionZ)
            let status1 = RegisterEventHotKey(
                keyCodeZ,
                UInt32(optionKey),
                hotKeyID1,
                GetEventDispatcherTarget(),
                0,
                &hotKeyRef1
            )
            if status1 == noErr, let ref = hotKeyRef1 {
                registeredHotKeys.append(ref)
            } else {
                print("[GlobalHotkeyManager] ⚠️ 注册 Option+Z 失败: \(status1)")
            }
        }
        
        // 2. 注册 Control + Z
        if mode == .both || mode == .controlZ {
            var hotKeyRef2: EventHotKeyRef?
            let hotKeyID2 = EventHotKeyID(signature: hotKeySignature, id: idControlZ)
            let status2 = RegisterEventHotKey(
                keyCodeZ,
                UInt32(controlKey),
                hotKeyID2,
                GetEventDispatcherTarget(),
                0,
                &hotKeyRef2
            )
            if status2 == noErr, let ref = hotKeyRef2 {
                registeredHotKeys.append(ref)
            } else {
                print("[GlobalHotkeyManager] ⚠️ 注册 Control+Z 失败: \(status2)")
            }
        }
        
        // 3. 兼容注册 Control + Option + Z
        if mode == .both {
            var hotKeyRef3: EventHotKeyRef?
            let hotKeyID3 = EventHotKeyID(signature: hotKeySignature, id: idCtrlOptionZ)
            let status3 = RegisterEventHotKey(
                keyCodeZ,
                UInt32(controlKey | optionKey),
                hotKeyID3,
                GetEventDispatcherTarget(),
                0,
                &hotKeyRef3
            )
            if status3 == noErr, let ref = hotKeyRef3 {
                registeredHotKeys.append(ref)
            }
        }
    }
    
    private func unregisterHotKeys() {
        for ref in registeredHotKeys {
            UnregisterEventHotKey(ref)
        }
        registeredHotKeys.removeAll()
    }
    
    private func updateActiveHotkeyTitle() {
        let mode = AppSettings.shared.hotkeyMode
        switch mode {
        case .commandCC:
            activeHotkeyTitle = "Command+C+C (⌘C⌘C)"
        case .both:
            activeHotkeyTitle = "Command+C+C / Option+Z / Control+Z"
        case .optionZ:
            activeHotkeyTitle = "Option+Z (⌥Z / Alt+Z)"
        case .controlZ:
            activeHotkeyTitle = "Control+Z (⌃Z)"
        }
    }

    // MARK: - Command+C+C 全局连击识别

    private func setupGlobalCommandCMonitor() {
        guard globalCommandCMonitor == nil else { return }
        globalCommandCMonitor = NSEvent.addGlobalMonitorForEvents(matching: [.keyDown]) { [weak self] event in
            guard let self else { return }
            let eventTime = event.timestamp
            DispatchQueue.main.async {
                self.handleCommandCKeyDown(
                    keyCode: event.keyCode,
                    isRepeat: event.isARepeat,
                    modifierFlags: event.modifierFlags,
                    at: eventTime
                )
            }
        }

        if globalCommandCMonitor == nil {
            print("[GlobalHotkeyManager] ⚠️ 无法安装 ⌘C⌘C 全局键盘监视器")
        }
    }

    /// 只观察按键，不拦截系统复制：第一次 ⌘C 仍由当前应用执行复制。
    func handleCommandCKeyDown(
        keyCode: UInt16,
        isRepeat: Bool,
        modifierFlags: NSEvent.ModifierFlags,
        at eventTime: TimeInterval
    ) {
        guard !isRepeat else { return }
        guard keyCode == UInt16(kVK_ANSI_C) else {
            commandCDetector.reset()
            return
        }

        let relevantModifiers = modifierFlags.intersection([.command, .option, .control, .shift])
        guard relevantModifiers == .command else {
            commandCDetector.reset()
            return
        }

        guard commandCDetector.registerPress(at: eventTime) else { return }
        print("[GlobalHotkeyManager] ⚡️ 识别到 Command+C+C")

        // 第二个 ⌘C 也可能刷新剪贴板，稍等系统完成写入后再读取并启动翻译。
        DispatchQueue.main.asyncAfter(deadline: .now() + 0.08) { [weak self] in
            self?.handleTriggerAction(origin: .commandDoubleCopy)
        }
    }
    
    // MARK: - 应用内本地按键监视
    
    private func setupLocalMonitor() {
        guard localMonitor == nil else { return }
        localMonitor = NSEvent.addLocalMonitorForEvents(matching: [.keyDown]) { [weak self] event in
            guard let self = self else { return event }
            
            // 键码 6 对应 'Z'
            if event.keyCode == 6 {
                let flags = event.modifierFlags.intersection(.deviceIndependentFlagsMask)
                let isOption = flags.contains(.option) && !flags.contains(.command) && !flags.contains(.shift)
                let isControl = flags.contains(.control) && !flags.contains(.command) && !flags.contains(.shift)
                
                if isOption || isControl {
                    self.handleTriggerAction(origin: .alternateHotkey)
                    return nil // 拦截事件，避免局部响音
                }
            }
            return event
        }
    }
    
    // MARK: - 热键分发与剪贴板捕获
    
    /// 当 Carbon 系统全局热键被按下时调用
    public func handleCarbonHotKeyTriggered(id: UInt32) {
        handleTriggerAction(origin: .alternateHotkey)
    }
    
    /// 统一防抖与动作执行
    func handleTriggerAction(origin: PanelOpenOrigin) {
        let now = CACurrentMediaTime()
        guard (now - lastTriggerTime) > debounceInterval else {
            return
        }
        lastTriggerTime = now
        
        guard origin.automaticallyTranslates else {
            onOpenPanel?()
            return
        }
        let copiedText = extractCurrentPasteboardText()
        print("[GlobalHotkeyManager] ⚡️ 全局热键触发！当前剪贴板内容长度: \(copiedText.count)")
        
        onTriggerTranslation?(copiedText)
    }
    
    /// 提取当前系统剪贴板文本 (支持纯文本、RTF 及 HTML 降级)
    public func extractCurrentPasteboardText() -> String {
        let pb = NSPasteboard.general
        if let string = pb.string(forType: .string), !string.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty {
            return string
        }
        
        // 尝试从富文本 RTF 提取纯文本
        if let rtfData = pb.data(forType: .rtf),
           let attrStr = NSAttributedString(rtf: rtfData, documentAttributes: nil),
           !attrStr.string.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty {
            return attrStr.string
        }
        
        // 尝试从 HTML 提取纯文本
        if let htmlData = pb.data(forType: .html),
           let attrStr = NSAttributedString(html: htmlData, documentAttributes: nil),
           !attrStr.string.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty {
            return attrStr.string
        }
        
        return ""
    }
    
    // MARK: - 测试辅助支持
    
    /// 便捷测试手动触发方法
    public func triggerManual(text: String) {
        DispatchQueue.main.async {
            self.onTriggerTranslation?(text)
        }
    }
}
