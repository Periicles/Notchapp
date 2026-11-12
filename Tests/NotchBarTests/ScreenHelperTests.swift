@testable import NotchBar
import XCTest

final class ScreenHelperTests: XCTestCase {
    // 14" MacBook Pro at its default resolution: 663 / 664 pt of menu bar either
    // side of a 185 x 32 notch.
    func test_notchSize_isWhatTheMenuBarAreasLeaveBetweenThem() {
        let size = ScreenHelper.notchSize(
            screenWidth: 1512,
            leftAreaWidth: 663,
            rightAreaWidth: 664,
            safeAreaTop: 32,
            menuBarHeight: 24
        )

        XCTAssertEqual(size.width, 185, accuracy: 0.001)
        XCTAssertEqual(size.height, 32, accuracy: 0.001)
    }

    func test_notchSize_readsTheTallerNotchOfA16InchScreen() {
        let size = ScreenHelper.notchSize(
            screenWidth: 1728,
            leftAreaWidth: 754,
            rightAreaWidth: 754,
            safeAreaTop: 38,
            menuBarHeight: 24
        )

        XCTAssertEqual(size.width, 220, accuracy: 0.001)
        XCTAssertEqual(size.height, 38, accuracy: 0.001)
    }

    func test_notchSize_fallsBackOnAScreenWithoutANotch() {
        let size = ScreenHelper.notchSize(
            screenWidth: 1920,
            leftAreaWidth: nil,
            rightAreaWidth: nil,
            safeAreaTop: 0,
            menuBarHeight: 24
        )

        XCTAssertEqual(size.width, 185, accuracy: 0.001)
        XCTAssertEqual(size.height, 32, accuracy: 0.001)
    }

    func test_notchSize_usesTheMenuBarHeight_whenThereIsNoSafeArea() {
        let size = ScreenHelper.notchSize(
            screenWidth: 1920,
            leftAreaWidth: nil,
            rightAreaWidth: nil,
            safeAreaTop: 0,
            menuBarHeight: 40
        )

        XCTAssertEqual(size.height, 40, accuracy: 0.001)
    }

    func test_notchSize_neverShrinksBelowTheFallback() {
        let size = ScreenHelper.notchSize(
            screenWidth: 1000,
            leftAreaWidth: 480,
            rightAreaWidth: 480,
            safeAreaTop: 10,
            menuBarHeight: 10
        )

        XCTAssertEqual(size.width, 185, accuracy: 0.001)
        XCTAssertEqual(size.height, 32, accuracy: 0.001)
    }

    // The two menu bar areas are rarely equal, so the notch is slightly off-centre.
    func test_centerOffset_isNegative_whenTheNotchSitsLeftOfCentre() {
        let offset = ScreenHelper.centerOffset(leftAreaMaxX: 663, rightAreaMinX: 848, screenMidX: 756)

        XCTAssertEqual(offset, -0.5, accuracy: 0.001)
    }

    func test_centerOffset_isZero_whenTheNotchIsCentred() {
        let offset = ScreenHelper.centerOffset(leftAreaMaxX: 663.5, rightAreaMinX: 848.5, screenMidX: 756)

        XCTAssertEqual(offset, 0, accuracy: 0.001)
    }

    func test_panelHeight_growsWithTheNotchAndKeepsItsContentArea() {
        XCTAssertGreaterThan(ScreenHelper.panelHeight, NotchPanelMetrics.contentAreaHeight)
        XCTAssertGreaterThan(ScreenHelper.contentTopInset, ScreenHelper.closedHeight())
    }

    func test_panelRect_isCentredOnTheScreenAndPokesAboveIt() {
        let rect = ScreenHelper.panelRect()

        XCTAssertEqual(rect.width, ScreenHelper.panelWidth, accuracy: 0.001)
        XCTAssertEqual(rect.height, ScreenHelper.panelHeight, accuracy: 0.001)
    }

    func test_sensorRect_isTheClosedNotch() {
        let rect = ScreenHelper.sensorRect()

        XCTAssertEqual(rect.width, ScreenHelper.collapsedWidth(), accuracy: 0.001)
        XCTAssertEqual(rect.height, ScreenHelper.closedHeight(), accuracy: 0.001)
    }
}
