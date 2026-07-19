import XCTest
import SwiftUI
@testable import NotchBar

final class PanelMotionStyleTests: XCTestCase {
    // MARK: - Motion enabled (Reduce Motion off)

    func test_motionEnabled_keepsCollapseTransforms() {
        let style = PanelMotionStyle(reduceMotion: false)

        XCTAssertEqual(style.collapsedScale, 0.975)
        XCTAssertEqual(style.collapsedOffsetY, -7)
        XCTAssertEqual(style.collapsedBlur, 5)
        XCTAssertEqual(style.accessoryCollapsedScale, 0.85)
    }

    func test_motionEnabled_runsShimmerAndSpringAndStagger() {
        let style = PanelMotionStyle(reduceMotion: false)

        XCTAssertTrue(style.shimmerEnabled)
        XCTAssertTrue(style.usesSpring)
        XCTAssertTrue(style.popoverAnimates)
        XCTAssertEqual(style.fadeDuration, 0.16)
        XCTAssertEqual(style.openStaggerDelay, 0.08)
    }

    // MARK: - Reduce Motion on: crossfade in place

    func test_reduceMotion_flattensCollapseTransforms() {
        let style = PanelMotionStyle(reduceMotion: true)

        XCTAssertEqual(style.collapsedScale, 1)
        XCTAssertEqual(style.collapsedOffsetY, 0)
        XCTAssertEqual(style.collapsedBlur, 0)
        XCTAssertEqual(style.accessoryCollapsedScale, 1)
    }

    func test_reduceMotion_freezesShimmerDropsSpringAndStagger() {
        let style = PanelMotionStyle(reduceMotion: true)

        XCTAssertFalse(style.shimmerEnabled)
        XCTAssertFalse(style.usesSpring)
        XCTAssertFalse(style.popoverAnimates)
        XCTAssertEqual(style.fadeDuration, 0.10)
        XCTAssertEqual(style.openStaggerDelay, 0)
    }

    // MARK: - Resolved animations

    func test_containerAnimation_isSpringWhenMotionEnabled() {
        let style = PanelMotionStyle(reduceMotion: false)
        XCTAssertEqual(
            style.containerAnimation,
            .interactiveSpring(response: 0.42, dampingFraction: 0.86, blendDuration: 0.18)
        )
    }

    func test_containerAnimation_isShortFadeUnderReduceMotion() {
        let style = PanelMotionStyle(reduceMotion: true)
        XCTAssertEqual(style.containerAnimation, .easeOut(duration: 0.10))
    }
}
