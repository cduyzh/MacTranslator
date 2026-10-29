import XCTest
import AppKit
@testable import cduyzhTranslatorCore

@MainActor
final class StatusMenuTests: XCTestCase {
    func testContextMenuOpensPanelAndGroupsMaintenance() {
        let menu = StatusMenuFactory.makeMenu(target: AppDelegate(), engineName: "DeepSeek", updateAvailable: false)
        XCTAssertGreaterThanOrEqual(menu.minimumWidth, 260)
        XCTAssertNotNil(menu.items.first?.view)
        let actions = menu.items.filter { !$0.isSeparatorItem && $0.view == nil }
        XCTAssertEqual(actions.map(\.title), ["打开翻译面板", "设置…", "检查更新…", "维护", "退出译栏"])
        XCTAssertEqual(actions.first?.action, #selector(AppDelegate.openPanelAction))
        XCTAssertTrue(actions.allSatisfy { $0.image != nil })
        XCTAssertEqual(actions.first(where: { $0.title == "维护" })?.submenu?.items.count, 3)
    }

    func testTranslationIconIsTemplateAndReadableAtMenuBarSize() {
        let icon = StatusBarIconFactory.makeTemplateIcon()
        XCTAssertTrue(icon.isTemplate)
        XCTAssertEqual(icon.size, NSSize(width: 24, height: 18))
        XCTAssertNotNil(icon.tiffRepresentation)
    }

    func testPopoverAnchorIsHorizontallyCenteredAtTopOfUsableScreen() {
        let screen = NSRect(x: -1920, y: 24, width: 1920, height: 1056)
        let size = NSSize(width: 1, height: 1)
        let origin = PopoverAnchorPlacement.origin(visibleFrame: screen, anchorSize: size)
        XCTAssertEqual(origin.x + size.width / 2, screen.midX, accuracy: 0.01)
        XCTAssertEqual(origin.y + size.height, screen.maxY, accuracy: 0.01)
    }
}
