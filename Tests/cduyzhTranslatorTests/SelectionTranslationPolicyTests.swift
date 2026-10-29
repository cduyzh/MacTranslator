import XCTest
import AppKit
@testable import cduyzhTranslatorCore

final class SelectionTranslationPolicyTests: XCTestCase {
    func testSingleClickCannotOfferAnOldSelection() {
        XCTAssertFalse(SelectionTranslationPolicy.shouldOffer(didDrag: false, clickCount: 1))
        XCTAssertTrue(SelectionTranslationPolicy.shouldOffer(didDrag: true, clickCount: 1))
        XCTAssertTrue(SelectionTranslationPolicy.shouldOffer(didDrag: false, clickCount: 2))
        XCTAssertTrue(SelectionTranslationPolicy.shouldOffer(didDrag: false, clickCount: 3))
    }

    func testSelectionRejectsBlankAndOversizedText() {
        XCTAssertNil(SelectionTranslationPolicy.normalizedSelection(" \n\t"))
        XCTAssertNil(SelectionTranslationPolicy.normalizedSelection(String(repeating: "x", count: 10_001)))
        XCTAssertNotNil(SelectionTranslationPolicy.normalizedSelection(String(repeating: "x", count: 10_000)))
        // AX selected ranges are measured in UTF-16 units, including surrogate pairs.
        XCTAssertNil(SelectionTranslationPolicy.normalizedSelection(String(repeating: "😀", count: 5_001)))
    }

    func testSelectionPreservesParagraphsAndRejectsControlBytes() {
        XCTAssertEqual(SelectionTranslationPolicy.normalizedSelection("  First\nSecond\tcolumn  "), "First\nSecond\tcolumn")
        XCTAssertNil(SelectionTranslationPolicy.normalizedSelection("unsafe\u{0}text"))
    }

    func testPanelStaysInsideEveryScreenEdge() {
        let screen = NSRect(x: 0, y: 25, width: 1280, height: 750)
        let panel = NSSize(width: 114, height: 34)
        for point in [NSPoint(x: 0, y: 25), NSPoint(x: 1280, y: 25),
                      NSPoint(x: 0, y: 775), NSPoint(x: 1280, y: 775)] {
            let origin = SelectionTranslationPolicy.panelOrigin(anchor: point, panelSize: panel, visibleFrame: screen)
            XCTAssertGreaterThanOrEqual(origin.x, screen.minX + 8)
            XCTAssertGreaterThanOrEqual(origin.y, screen.minY + 8)
            XCTAssertLessThanOrEqual(origin.x + panel.width, screen.maxX - 8)
            XCTAssertLessThanOrEqual(origin.y + panel.height, screen.maxY - 8)
        }
    }

    func testPanelSupportsScreensToTheLeftOfMainScreen() {
        let screen = NSRect(x: -1440, y: -100, width: 1440, height: 900)
        let panel = NSSize(width: 114, height: 34)
        let origin = SelectionTranslationPolicy.panelOrigin(
            anchor: NSPoint(x: -10, y: -95), panelSize: panel, visibleFrame: screen
        )
        XCTAssertGreaterThanOrEqual(origin.x, screen.minX + 8)
        XCTAssertLessThanOrEqual(origin.x + panel.width, screen.maxX - 8)
        XCTAssertGreaterThan(origin.y, -95, "屏幕底部应将按钮放在鼠标上方")
    }
}
