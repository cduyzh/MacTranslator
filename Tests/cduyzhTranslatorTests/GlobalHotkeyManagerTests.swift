import XCTest
import AppKit
@testable import cduyzhTranslatorCore

final class GlobalHotkeyManagerTests: XCTestCase {

    func testOnlyCommandDoubleCopyAutomaticallyTranslates() {
        for origin in PanelOpenOrigin.allCases {
            XCTAssertEqual(origin.automaticallyTranslates, origin == .commandDoubleCopy)
        }
    }

    func testAlternateHotkeyOpensWithoutReadingOrTranslatingClipboard() {
        let manager = GlobalHotkeyManager.shared
        let opened = expectation(description: "只打开面板")
        let translated = expectation(description: "不自动翻译")
        translated.isInverted = true
        manager.onOpenPanel = { opened.fulfill() }
        manager.onTriggerTranslation = { _ in translated.fulfill() }
        defer { manager.onOpenPanel = nil; manager.onTriggerTranslation = nil }
        manager.handleTriggerAction(origin: .alternateHotkey)
        wait(for: [opened, translated], timeout: 0.1)
    }

    func testCommandCHandlerCapturesClipboardAndInvokesTranslation() {
        let manager = GlobalHotkeyManager.shared
        manager.stopMonitoring()
        let restore = preserveClipboard()
        let pb = NSPasteboard.general
        pb.clearContents()
        pb.setString("Shortcut fixture", forType: .string)
        let translated = expectation(description: "连击复制后翻译剪贴板")
        manager.onTriggerTranslation = { text in
            XCTAssertEqual(text, "Shortcut fixture")
            translated.fulfill()
        }
        defer {
            manager.onTriggerTranslation = nil
            manager.stopMonitoring()
            restore()
        }
        manager.handleCommandCKeyDown(keyCode: 8, isRepeat: false, modifierFlags: .command, at: 100)
        manager.handleCommandCKeyDown(keyCode: 8, isRepeat: false, modifierFlags: .command, at: 100.2)
        wait(for: [translated], timeout: 1)
    }

    func testCommandCDoubleTapWithinWindowTriggers() {
        var detector = CommandCShortcutDetector(interval: 0.45)

        XCTAssertFalse(detector.registerPress(at: 10.0))
        XCTAssertTrue(detector.registerPress(at: 10.30))
        XCTAssertNil(detector.lastPressTime)
    }

    func testCommandCDoubleTapOutsideWindowStartsNewSequence() {
        var detector = CommandCShortcutDetector(interval: 0.45)

        XCTAssertFalse(detector.registerPress(at: 5.0))
        XCTAssertFalse(detector.registerPress(at: 5.46))
        XCTAssertTrue(detector.registerPress(at: 5.70))
    }

    func testCommandCKeyRepeatDoesNotCountAsSecondPress() {
        var detector = CommandCShortcutDetector(interval: 0.45)

        XCTAssertFalse(detector.registerPress(at: 20.0))
        XCTAssertFalse(detector.registerPress(at: 20.10, isRepeat: true))
        XCTAssertEqual(detector.lastPressTime, 20.0)
    }

    func testDetectorResetClearsPendingPress() {
        var detector = CommandCShortcutDetector(interval: 0.45)

        XCTAssertFalse(detector.registerPress(at: 30.0))
        detector.reset()
        XCTAssertNil(detector.lastPressTime)
        XCTAssertFalse(detector.registerPress(at: 30.10))
    }
    
    func testManualTriggerCallback() {
        let manager = GlobalHotkeyManager.shared
        let expectation = expectation(description: "触发快捷键回调")
        
        let testString = "Unit test text for Alt+Z translation"
        
        manager.onTriggerTranslation = { text in
            XCTAssertEqual(text, testString)
            expectation.fulfill()
        }
        
        manager.triggerManual(text: testString)
        
        wait(for: [expectation], timeout: 1.0)
    }
    
    func testPermissionCheckDoesNotCrash() {
        let manager = GlobalHotkeyManager.shared
        let trusted = manager.checkPermission(prompt: false)
        // 校验读取系统权限状态 API 正常返回
        XCTAssertEqual(trusted, manager.hasAccessibilityPermission)
    }
    
    func testRestartMonitoringDoesNotCrash() {
        let manager = GlobalHotkeyManager.shared
        defer { manager.stopMonitoring() }
        manager.restartMonitoring()
        XCTAssertTrue(manager.isMonitoring)
        
        manager.stopMonitoring()
        XCTAssertFalse(manager.isMonitoring)
        
        manager.startMonitoring()
        XCTAssertTrue(manager.isMonitoring)
    }
    
    func testHotkeyModesSwitching() {
        let settings = AppSettings.shared
        let manager = GlobalHotkeyManager.shared
        let originalMode = settings.hotkeyMode
        defer {
            settings.hotkeyMode = originalMode
            manager.stopMonitoring()
        }

        settings.hotkeyMode = .commandCC
        manager.restartMonitoring()
        XCTAssertEqual(manager.activeHotkeyTitle, "Command+C+C (⌘C⌘C)")
        
        settings.hotkeyMode = .optionZ
        manager.restartMonitoring()
        XCTAssertEqual(manager.activeHotkeyTitle, "Option+Z (⌥Z / Alt+Z)")
        
        settings.hotkeyMode = .controlZ
        manager.restartMonitoring()
        XCTAssertEqual(manager.activeHotkeyTitle, "Control+Z (⌃Z)")
        
        settings.hotkeyMode = .both
        manager.restartMonitoring()
        XCTAssertEqual(manager.activeHotkeyTitle, "Command+C+C / Option+Z / Control+Z")

        settings.hotkeyMode = .commandCC
        XCTAssertTrue(settings.hotkeyMode.usesCommandDoubleTap)
        XCTAssertFalse(settings.hotkeyMode.usesCarbonHotkey)
    }
    
    func testPasteboardExtraction() {
        let manager = GlobalHotkeyManager.shared
        let restore = preserveClipboard()
        defer { restore() }
        let pb = NSPasteboard.general
        let testContent = "Test clipboard automated extraction \(UUID().uuidString)"
        
        pb.clearContents()
        pb.setString(testContent, forType: .string)
        
        let extracted = manager.extractCurrentPasteboardText()
        XCTAssertEqual(extracted, testContent)
    }
    
    func testClosePopoverAndRestartNotifications() {
        let expectationClose = expectation(description: "收到关闭面板通知")
        let expectationRestart = expectation(description: "收到重启通知")
        
        let observer1 = NotificationCenter.default.addObserver(
            forName: NSNotification.Name("ClosePopoverNotification"),
            object: nil,
            queue: .main
        ) { _ in
            expectationClose.fulfill()
        }
        
        let observer2 = NotificationCenter.default.addObserver(
            forName: NSNotification.Name("RestartAppNotification"),
            object: nil,
            queue: .main
        ) { _ in
            expectationRestart.fulfill()
        }
        
        NotificationCenter.default.post(name: NSNotification.Name("ClosePopoverNotification"), object: nil)
        NotificationCenter.default.post(name: NSNotification.Name("RestartAppNotification"), object: nil)
        
        wait(for: [expectationClose, expectationRestart], timeout: 1.0)
        
        NotificationCenter.default.removeObserver(observer1)
        NotificationCenter.default.removeObserver(observer2)
    }
}

private func preserveClipboard() -> () -> Void {
    let pb = NSPasteboard.general
    let items = (pb.pasteboardItems ?? []).map { old -> NSPasteboardItem in
        let copy = NSPasteboardItem()
        for type in old.types {
            if let data = old.data(forType: type) { copy.setData(data, forType: type) }
        }
        return copy
    }
    return {
        pb.clearContents()
        if !items.isEmpty { pb.writeObjects(items) }
    }
}
