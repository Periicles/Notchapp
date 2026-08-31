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
}
