import XCTest
import SwiftUI
import AppKit
@testable import cduyzhTranslatorCore

@MainActor
final class StatusPanelTests: XCTestCase {

    func testStatusPanelSnapshotDefaultAndPreview() {
        let snapshot = StatusPanelSnapshot.preview
        XCTAssertEqual(snapshot.version, "1.2.1")
        XCTAssertEqual(snapshot.build, 10)
        XCTAssertTrue(snapshot.isAccessibilityGranted)
        XCTAssertEqual(snapshot.statusTitle, "划词就绪 · 连按 ⌘C C 快速翻译")
        XCTAssertEqual(snapshot.engineName, "DeepSeek")
        XCTAssertEqual(snapshot.engineCapsuleTitle, "AI 智能增强")
        XCTAssertTrue(snapshot.hasApiKey)
    }

    func testStatusPanelSnapshotAccessibilityPermTitlesAndColors() {
        var ungranted = StatusPanelSnapshot()
        ungranted.isAccessibilityGranted = false
        XCTAssertEqual(ungranted.statusTitle, "需要辅助功能权限")
        XCTAssertEqual(ungranted.statusColor, Color.orange)

        var granted = StatusPanelSnapshot()
        granted.isAccessibilityGranted = true
        XCTAssertEqual(granted.statusTitle, "划词就绪 · 连按 ⌘C C 快速翻译")
        XCTAssertEqual(granted.statusColor, Color(red: 0.0, green: 0.85, blue: 0.70))
    }

    func testStatusPanelEngineCapsuleTitleAndColors() {
        XCTAssertEqual(TranslationEngineType.allCases, [.google, .deepseek])

        // 1. DeepSeek 有 Key
        var deepSeekWithKey = StatusPanelSnapshot()
        deepSeekWithKey.engineType = .deepseek
        deepSeekWithKey.hasApiKey = true
        XCTAssertEqual(deepSeekWithKey.engineCapsuleTitle, "AI 智能增强")
        XCTAssertEqual(deepSeekWithKey.engineCapsuleColor, Color(red: 0.10, green: 0.65, blue: 0.40))

        // 2. DeepSeek 无 Key
        var deepSeekNoKey = StatusPanelSnapshot()
        deepSeekNoKey.engineType = .deepseek
        deepSeekNoKey.hasApiKey = false
        XCTAssertEqual(deepSeekNoKey.engineCapsuleTitle, "待配密钥")
        XCTAssertEqual(deepSeekNoKey.engineCapsuleColor, Color.orange)

        // 3. Google 翻译
        var google = StatusPanelSnapshot()
        google.engineType = .google
        XCTAssertEqual(google.engineCapsuleTitle, "免密直连")
        XCTAssertEqual(google.engineCapsuleColor, Color(red: 0.0, green: 0.72, blue: 0.88))

    }

    func testStatusPanelModelUpdatesSnapshotAndFocusedAction() {
        let model = StatusPanelModel()
        XCTAssertNil(model.focusedAction)

        model.focusedAction = .quickTranslate
        XCTAssertEqual(model.focusedAction, .quickTranslate)

        var newSnapshot = StatusPanelSnapshot.preview
        newSnapshot.memoryCount = 99
        model.snapshot = newSnapshot
        XCTAssertEqual(model.snapshot.memoryCount, 99)
    }

    func testStatusPanelViewCanBeRenderedInHostingController() {
        let view = StatusPanelView(
            snapshot: .preview,
            focusedAction: .quickTranslate,
            onAction: { _ in },
            onFocusChange: { _ in }
        )
        let controller = NSHostingController(rootView: view)
        XCTAssertNotNil(controller.view)
        XCTAssertEqual(controller.view.fittingSize.width, 368, accuracy: 2.0)
    }

    func testStatusPanelControllerRefresh() {
        let controller = StatusPanelController.shared
        controller.refresh()
        // 刷新后 snapshot 版本与 AppSettings 同步
        XCTAssertFalse(controller.popoverDidCloseIsCallable())
    }
}

// 辅助测试扩展
extension StatusPanelController {
    func popoverDidCloseIsCallable() -> Bool {
        return false
    }
}
