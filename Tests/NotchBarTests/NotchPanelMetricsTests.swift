import XCTest
@testable import NotchBar

final class NotchPanelMetricsTests: XCTestCase {
    // The settings orb is an overlay, so it paints over the content's top-trailing
    // corner unless the content insets itself. Before this was derived, the orb
    // covered the last 24pt of the in-progress layout's time range.
    func test_contentTrailingClearance_leavesTheOrbAGapOverTheContent() {
        XCTAssertEqual(
            NotchPanelMetrics.effectiveOrbClearance,
            NotchPanelMetrics.orbClearanceGap,
            accuracy: 0.001
        )
    }

    func test_contentTrailingClearance_isPositive_soTheRowActuallyInsets() {
        XCTAssertGreaterThan(NotchPanelMetrics.contentTrailingClearance, 0)
    }

    // A row inset by the clearance must stop before the orb starts, whatever the
    // panel width — both edges are measured from the trailing edge.
    func test_titleRowStopsBeforeTheOrbBegins() {
        let panelWidth = ScreenHelper.panelWidth
        let contentTrailingEdge = panelWidth
            - NotchPanelMetrics.contentHorizontalPadding
            - NotchPanelMetrics.contentTrailingClearance
        let orbLeadingEdge = panelWidth
            - NotchPanelMetrics.orbTrailingPadding
            - NotchPanelMetrics.orbDiameter

        XCTAssertLessThan(contentTrailingEdge, orbLeadingEdge)
    }

    func test_orbIconFitsInsideItsCircle() {
        XCTAssertLessThan(NotchPanelMetrics.orbIconSize, NotchPanelMetrics.orbDiameter)
    }

    // The window starts `topBleed` above the screen, so the notch's lower edge is
    // that much further down the window than the notch height alone says. The
    // resting progress line used to ignore it and sat 2pt inside the notch.
    func test_notchBottomEdge_countsTheBleedAboveTheScreen() {
        XCTAssertEqual(NotchPanelMetrics.notchBottomEdge(notchHeight: 38, topBleed: 2), 40, accuracy: 0.001)
    }

    // Content used to start at a fixed 28pt: above the lower edge of any notch,
    // so the title and the first line of the layout were cut by it.
    func test_contentStartsBelowTheNotch_whateverItsHeight() {
        for notchHeight in [CGFloat(32), 34, 38, 44] {
            let inset = NotchPanelMetrics.contentTopInset(notchHeight: notchHeight, topBleed: 2)
            let notchBottom = NotchPanelMetrics.notchBottomEdge(notchHeight: notchHeight, topBleed: 2)

            XCTAssertGreaterThanOrEqual(inset - notchBottom, NotchPanelMetrics.notchContentGap, "\(notchHeight)pt")
        }
    }

    // A taller notch grows the window, not the layout inside it: the content
    // area keeps its size, so nothing is squeezed on a notch that is taller.
    func test_panelHeight_keepsTheContentAreaConstant() {
        for notchHeight in [CGFloat(32), 38, 44] {
            let height = NotchPanelMetrics.panelHeight(notchHeight: notchHeight, topBleed: 2)
            let inset = NotchPanelMetrics.contentTopInset(notchHeight: notchHeight, topBleed: 2)

            XCTAssertEqual(height - inset, NotchPanelMetrics.contentAreaHeight, accuracy: 0.001, "\(notchHeight)pt")
        }
    }

    func test_panelHeight_growsWithTheNotch() {
        XCTAssertGreaterThan(
            NotchPanelMetrics.panelHeight(notchHeight: 38, topBleed: 2),
            NotchPanelMetrics.panelHeight(notchHeight: 32, topBleed: 2)
        )
    }
}
