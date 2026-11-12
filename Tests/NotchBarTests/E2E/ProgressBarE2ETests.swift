@testable import NotchBar
import SwiftUI
import XCTest

@MainActor
final class ProgressBarE2ETests: XCTestCase {
    private let size = CGSize(width: 400, height: 60)
    private let barWidth: CGFloat = 300
    private let barHeight: CGFloat = 13
    private let inset: CGFloat = 20

    // The rendered view is centred horizontally and pinned to the top.
    private var barLeft: Int { Int((size.width - barWidth - 2 * inset) / 2 + inset) }
    private var barTop: Int { Int(inset) }
    private var barMidRow: Int { barTop + Int(barHeight / 2) }

    private func isBlue(_ pixel: Pixel) -> Bool {
        pixel.alpha > 200 && pixel.blue > pixel.red + 60
    }

    private func render(progress: Double) throws -> RenderedImage {
        let bar = AnimatedProgressBar(progress: progress, tint: .blue, isAnimating: false)
            .frame(width: barWidth, height: barHeight)
            .padding(inset)
        return try XCTUnwrap(RenderedImage(bar, size: size))
    }

    // The fill has to track the progress: this is the whole point of the bar.
    func test_bar_fillsInProportionToProgress() throws {
        let midRow = barMidRow
        let left = barLeft

        let half = try render(progress: 0.5)
        XCTAssertTrue(isBlue(half.color(x: left + 60, y: midRow)), "first part should be filled")
        XCTAssertFalse(isBlue(half.color(x: left + 240, y: midRow)), "last part should be empty")

        let nearlyFull = try render(progress: 0.9)
        XCTAssertTrue(isBlue(nearlyFull.color(x: left + 240, y: midRow)))
    }

    func test_bar_neverCollapsesToNothing_atZeroProgress() throws {
        let image = try render(progress: 0)

        XCTAssertTrue(isBlue(image.color(x: barLeft + 6, y: barMidRow)))
    }

    func test_bar_glowsBeyondItsOwnEdge() throws {
        let image = try render(progress: 0.5)
        let aboveBar = image.color(x: barLeft + 60, y: barTop - 3)

        XCTAssertGreaterThan(aboveBar.alpha, 0, "the neon halo should spill past the bar")
    }

    func test_restingLine_fillsAlongTheOutlineInProportionToProgress() throws {
        let width = 211.0
        let height = 36.0
        func line(_ progress: Double) throws -> RenderedImage {
            try XCTUnwrap(RenderedImage(
                RestingProgressLineView(progress: progress, tint: .blue).padding(16),
                size: CGSize(width: width + 32, height: height + 32)
            ))
        }

        let empty = try line(0)
        let full = try line(1)

        func blueCount(_ image: RenderedImage) -> Int {
            var count = 0
            for y in 0..<image.height {
                for x in 0..<image.width where isBlue(image.color(x: x, y: y)) {
                    count += 1
                }
            }
            return count
        }
        XCTAssertEqual(blueCount(empty), 0)
        XCTAssertGreaterThan(blueCount(full), 100)
    }
}
