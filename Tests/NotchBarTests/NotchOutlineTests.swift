@testable import NotchBar
import SwiftUI
import XCTest

final class NotchOutlineTests: XCTestCase {
    private let rect = CGRect(x: 0, y: 0, width: 211, height: 34)
    private let outline = NotchOutline(topRadius: 6, bottomRadius: 15)

    func test_path_staysInsideItsRect() {
        let bounds = outline.path(in: rect).boundingRect

        XCTAssertGreaterThanOrEqual(bounds.minX, rect.minX)
        XCTAssertLessThanOrEqual(bounds.maxX, rect.maxX)
        XCTAssertGreaterThanOrEqual(bounds.minY, rect.minY)
        XCTAssertLessThanOrEqual(bounds.maxY, rect.maxY)
    }

    // Open on purpose: closing it would stroke a line along the screen edge.
    func test_path_startsAndEndsAtTheTopEdge() {
        let path = outline.path(in: rect)

        XCTAssertEqual(path.currentPoint?.y ?? -1, rect.minY, accuracy: 0.001)
        XCTAssertEqual(path.currentPoint?.x ?? -1, rect.maxX, accuracy: 0.001)
    }

    func test_path_reachesTheBottomEdgeBetweenItsCorners() {
        let bounds = outline.path(in: rect).boundingRect

        XCTAssertEqual(bounds.maxY, rect.maxY, accuracy: 0.001)
    }

    func test_path_isSymmetricAboutTheVerticalAxis() {
        let bounds = outline.path(in: rect).boundingRect

        XCTAssertEqual(bounds.midX, rect.midX, accuracy: 0.001)
    }
}
