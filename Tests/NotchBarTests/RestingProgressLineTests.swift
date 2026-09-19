import SwiftUI
import XCTest
@testable import NotchBar

final class RestingProgressLineTests: XCTestCase {
    private func snapshot(state: EventProgressSnapshot.State, progress: Double) -> EventProgressSnapshot {
        EventProgressSnapshot(
            title: "Maths",
            progress: progress,
            startTimeLabel: "10:00",
            endTimeLabel: "11:00",
            elapsedLabel: "00:15:00",
            remainingLabel: "00:45:00",
            statusLabel: "In progress",
            secondaryMessage: nil,
            tint: .orange,
            state: state
        )
    }

    func test_progress_isNil_whenDisabled() {
        let value = RestingProgressLine.progress(for: snapshot(state: .inProgress, progress: 0.4), enabled: false)

        XCTAssertNil(value)
    }

    func test_progress_isShown_forARunningEvent() {
        let value = RestingProgressLine.progress(for: snapshot(state: .inProgress, progress: 0.4), enabled: true)

        XCTAssertEqual(try XCTUnwrap(value), 0.4, accuracy: 0.0001)
    }

    func test_progress_isShown_forABreak() {
        let value = RestingProgressLine.progress(for: snapshot(state: .onBreak, progress: 0.25), enabled: true)

        XCTAssertEqual(try XCTUnwrap(value), 0.25, accuracy: 0.0001)
    }

    func test_progress_isNil_forEveryOtherState() {
        let states: [EventProgressSnapshot.State] = [
            .startingSoon, .upcomingToday, .upcomingLater, .emptyToday, .noCalendar, .accessRevoked,
        ]

        for state in states {
            XCTAssertNil(RestingProgressLine.progress(for: snapshot(state: state, progress: 0), enabled: true), "\(state)")
        }
    }

    func test_progress_isClampedToTheBar() {
        XCTAssertEqual(
            try XCTUnwrap(RestingProgressLine.progress(for: snapshot(state: .inProgress, progress: 1.4), enabled: true)),
            1,
            accuracy: 0.0001
        )
        XCTAssertEqual(
            try XCTUnwrap(RestingProgressLine.progress(for: snapshot(state: .inProgress, progress: -0.2), enabled: true)),
            0,
            accuracy: 0.0001
        )
    }
}
