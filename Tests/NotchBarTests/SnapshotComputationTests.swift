import XCTest
import SwiftUI
@testable import NotchBar

@MainActor
final class SnapshotComputationTests: XCTestCase {
    private let calendarID = "test-cal"
    private let otherCalendarID = "other-cal"
    private let calendar = Calendar(identifier: .gregorian)

    private func makeEvent(
        title: String = "Test Event",
        startOffset: TimeInterval,
        durationSeconds: TimeInterval,
        calendarID: String? = nil,
        relativeTo now: Date
    ) -> CalendarEvent {
        CalendarEvent(
            title: title,
            startDate: now.addingTimeInterval(startOffset),
            endDate: now.addingTimeInterval(startOffset + durationSeconds),
            calendarIdentifier: calendarID ?? self.calendarID,
            color: .blue
        )
    }

    // MARK: - .noCalendar

    func test_state_isNoCalendar_whenSelectedIDIsNil() {
        let now = Date(timeIntervalSinceReferenceDate: 800_000_000)
        let snapshot = SnapshotBuilder.computeSnapshot(
            events: [makeEvent(startOffset: -60, durationSeconds: 1800, relativeTo: now)],
            selectedCalendarID: nil,
            now: now,
            calendar: calendar
        )

        XCTAssertEqual(snapshot.state, .noCalendar)
        XCTAssertEqual(snapshot.secondaryMessage, "Pick a calendar in Settings")
    }

    // MARK: - .inProgress

    func test_state_isInProgress_whenEventOverlapsNow() {
        let now = Date(timeIntervalSinceReferenceDate: 800_000_000)
        let snapshot = SnapshotBuilder.computeSnapshot(
            events: [makeEvent(title: "Standup", startOffset: -300, durationSeconds: 1800, relativeTo: now)],
            selectedCalendarID: calendarID,
            now: now,
            calendar: calendar
        )

        XCTAssertEqual(snapshot.state, .inProgress)
        XCTAssertEqual(snapshot.title, "Standup")
        XCTAssertEqual(snapshot.progress, 300.0 / 1800.0, accuracy: 0.0001)
        XCTAssertNil(snapshot.secondaryMessage)
    }

    func test_inProgress_filtersByCalendarID() {
        let now = Date(timeIntervalSinceReferenceDate: 800_000_000)
        let snapshot = SnapshotBuilder.computeSnapshot(
            events: [
                makeEvent(title: "Wrong cal", startOffset: -60, durationSeconds: 1800,
                          calendarID: otherCalendarID, relativeTo: now),
                makeEvent(title: "Right cal", startOffset: -120, durationSeconds: 1800, relativeTo: now)
            ],
            selectedCalendarID: calendarID,
            now: now,
            calendar: calendar
        )

        XCTAssertEqual(snapshot.state, .inProgress)
        XCTAssertEqual(snapshot.title, "Right cal")
    }

    // MARK: - .startingSoon

    func test_state_isStartingSoon_whenNextEventWithinFiveMinutes() {
        let now = Date(timeIntervalSinceReferenceDate: 800_000_000)
        let snapshot = SnapshotBuilder.computeSnapshot(
            events: [makeEvent(title: "Standup", startOffset: 180, durationSeconds: 1800, relativeTo: now)],
            selectedCalendarID: calendarID,
            now: now,
            calendar: calendar
        )

        XCTAssertEqual(snapshot.state, .startingSoon)
        XCTAssertEqual(snapshot.secondaryMessage, "Starts in 3m — Standup")
    }

    func test_startingSoon_atExactFiveMinuteBoundary() {
        let now = Date(timeIntervalSinceReferenceDate: 800_000_000)
        let snapshot = SnapshotBuilder.computeSnapshot(
            events: [makeEvent(startOffset: 300, durationSeconds: 1800, relativeTo: now)],
            selectedCalendarID: calendarID,
            now: now,
            calendar: calendar
        )

        XCTAssertEqual(snapshot.state, .startingSoon)
    }

    // MARK: - .upcomingToday

    func test_state_isUpcomingToday_whenEventLaterTodayBeyondFiveMinutes() {
        let now = fixedNoon()
        let snapshot = SnapshotBuilder.computeSnapshot(
            events: [makeEvent(title: "Algo", startOffset: 2 * 3600 + 14 * 60, durationSeconds: 3600, relativeTo: now)],
            selectedCalendarID: calendarID,
            now: now,
            calendar: calendar
        )

        XCTAssertEqual(snapshot.state, .upcomingToday)
        XCTAssertEqual(snapshot.secondaryMessage, "Next: Algo in 2h 14min")
    }

    func test_upcomingToday_minutesOnly_whenUnderOneHour() {
        let now = fixedNoon()
        let snapshot = SnapshotBuilder.computeSnapshot(
            events: [makeEvent(title: "Coffee", startOffset: 45 * 60, durationSeconds: 1800, relativeTo: now)],
            selectedCalendarID: calendarID,
            now: now,
            calendar: calendar
        )

        XCTAssertEqual(snapshot.state, .upcomingToday)
        XCTAssertEqual(snapshot.secondaryMessage, "Next: Coffee in 45min")
    }

    // MARK: - .upcomingLater

    func test_state_isUpcomingLater_whenNextEventIsTomorrow() {
        let now = fixedNoon()
        let snapshot = SnapshotBuilder.computeSnapshot(
            events: [makeEvent(title: "Tomorrow", startOffset: 86_400, durationSeconds: 3600, relativeTo: now)],
            selectedCalendarID: calendarID,
            now: now,
            calendar: calendar
        )
        XCTAssertEqual(snapshot.state, .upcomingLater)
        XCTAssertEqual(snapshot.statusLabel, "Upcoming")
    }

    func test_state_isUpcomingLater_whenNextEventInThreeDays() {
        let now = fixedNoon()
        let snapshot = SnapshotBuilder.computeSnapshot(
            events: [makeEvent(title: "Conf", startOffset: 3 * 86_400, durationSeconds: 3600, relativeTo: now)],
            selectedCalendarID: calendarID,
            now: now,
            calendar: calendar
        )
        XCTAssertEqual(snapshot.state, .upcomingLater)
        XCTAssertEqual(snapshot.secondaryMessage, "Next event in: 03:00:00:00")
    }

    func test_boundary_eventBeforeMidnight_isUpcomingToday() {
        let now = calendar.date(byAdding: DateComponents(hour: 23, minute: 30),
                                to: calendar.startOfDay(for: fixedNoon()))!
        let snapshot = SnapshotBuilder.computeSnapshot(
            events: [makeEvent(title: "Late", startOffset: 20 * 60, durationSeconds: 1800, relativeTo: now)],
            selectedCalendarID: calendarID,
            now: now,
            calendar: calendar
        )
        XCTAssertEqual(snapshot.state, .upcomingToday)
    }

    func test_boundary_eventAfterMidnight_isUpcomingLater() {
        let now = calendar.date(byAdding: DateComponents(hour: 23, minute: 30),
                                to: calendar.startOfDay(for: fixedNoon()))!
        let snapshot = SnapshotBuilder.computeSnapshot(
            events: [makeEvent(title: "Early", startOffset: 40 * 60, durationSeconds: 1800, relativeTo: now)],
            selectedCalendarID: calendarID,
            now: now,
            calendar: calendar
        )
        XCTAssertEqual(snapshot.state, .upcomingLater)
        XCTAssertEqual(snapshot.secondaryMessage, "Next event in: 00:00:40:00")
    }

    func test_upcomingLater_countdownFormat() {
        let now = Date(timeIntervalSinceReferenceDate: 800_000_000)
        let offsetSeconds: TimeInterval = 95415 // 1d 2h 30m 15s
        let snapshot = SnapshotBuilder.computeSnapshot(
            events: [makeEvent(title: "Sprint Review", startOffset: offsetSeconds, durationSeconds: 3600, relativeTo: now)],
            selectedCalendarID: calendarID,
            now: now,
            calendar: calendar
        )

        XCTAssertEqual(snapshot.state, .upcomingLater)
        XCTAssertEqual(snapshot.secondaryMessage, "Next event in: 01:02:30:15")
    }

    // MARK: - .emptyToday

    func test_state_isEmptyToday_whenAllEventsAreInThePast() {
        let now = Date(timeIntervalSinceReferenceDate: 800_000_000)
        let snapshot = SnapshotBuilder.computeSnapshot(
            events: [makeEvent(startOffset: -3600, durationSeconds: 1800, relativeTo: now)],
            selectedCalendarID: calendarID,
            now: now,
            calendar: calendar
        )

        XCTAssertEqual(snapshot.state, .emptyToday)
    }

    func test_state_isEmptyToday_whenEventsExistButNoneMatchSelectedID() {
        let now = Date(timeIntervalSinceReferenceDate: 800_000_000)
        let snapshot = SnapshotBuilder.computeSnapshot(
            events: [
                makeEvent(startOffset: -60, durationSeconds: 1800,
                          calendarID: otherCalendarID, relativeTo: now)
            ],
            selectedCalendarID: calendarID,
            now: now,
            calendar: calendar
        )

        XCTAssertEqual(snapshot.state, .emptyToday)
    }

    // MARK: - Progress truncation

    func test_progress_isClampedJustUnderOne_when997PercentElapsed() {
        let now = Date(timeIntervalSinceReferenceDate: 800_000_000)
        let duration: TimeInterval = 1000
        let elapsed = duration * 0.997
        let snapshot = SnapshotBuilder.computeSnapshot(
            events: [makeEvent(startOffset: -elapsed, durationSeconds: duration, relativeTo: now)],
            selectedCalendarID: calendarID,
            now: now,
            calendar: calendar
        )

        XCTAssertEqual(snapshot.state, .inProgress)
        XCTAssertEqual(snapshot.progress, 0.997, accuracy: 0.0001)
        XCTAssertLessThan(snapshot.progress, 1.0)
    }

    // MARK: - joinURL propagation

    func test_joinURL_propagatedForInProgress() {
        let now = fixedNoon()
        let join = URL(string: "https://meet.google.com/abc-defg-hij")!
        var event = makeEvent(title: "Standup", startOffset: -300, durationSeconds: 1800, relativeTo: now)
        event.joinURL = join
        let snapshot = SnapshotBuilder.computeSnapshot(
            events: [event], selectedCalendarID: calendarID, now: now, calendar: calendar
        )
        XCTAssertEqual(snapshot.joinURL, join)
    }

    func test_joinURL_nilForEmptyToday() {
        let now = fixedNoon()
        let snapshot = SnapshotBuilder.computeSnapshot(
            events: [], selectedCalendarID: calendarID, now: now, calendar: calendar
        )
        XCTAssertNil(snapshot.joinURL)
    }

    // MARK: - Equatable (guards redundant @Published invalidations)

    func test_snapshot_isEqual_forIdenticalInputsAtSameInstant() {
        let now = Date(timeIntervalSinceReferenceDate: 800_000_000)
        let events = [makeEvent(title: "Standup", startOffset: -300, durationSeconds: 1800, relativeTo: now)]

        let first = SnapshotBuilder.computeSnapshot(
            events: events, selectedCalendarID: calendarID, now: now, calendar: calendar
        )
        let second = SnapshotBuilder.computeSnapshot(
            events: events, selectedCalendarID: calendarID, now: now, calendar: calendar
        )

        XCTAssertEqual(first, second)
    }

    func test_snapshot_isNotEqual_whenElapsedTimeAdvances() {
        let now = Date(timeIntervalSinceReferenceDate: 800_000_000)
        let events = [makeEvent(startOffset: -300, durationSeconds: 1800, relativeTo: now)]

        let earlier = SnapshotBuilder.computeSnapshot(
            events: events, selectedCalendarID: calendarID, now: now, calendar: calendar
        )
        let later = SnapshotBuilder.computeSnapshot(
            events: events, selectedCalendarID: calendarID, now: now.addingTimeInterval(1), calendar: calendar
        )

        XCTAssertNotEqual(earlier, later)
    }

    func test_snapshot_isNotEqual_acrossDifferentStates() {
        XCTAssertNotEqual(EventProgressSnapshot.noCalendar, EventProgressSnapshot.emptyToday)
    }

    // MARK: - Helpers

    /// Noon of a fixed reference day — never depends on when the test runs.
    private func fixedNoon() -> Date {
        let reference = Date(timeIntervalSinceReferenceDate: 800_000_000)
        let startOfDay = calendar.startOfDay(for: reference)
        return calendar.date(byAdding: DateComponents(hour: 12), to: startOfDay)!
    }
}
