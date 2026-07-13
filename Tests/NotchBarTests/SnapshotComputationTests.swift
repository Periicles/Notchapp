import XCTest
import SwiftUI
@testable import NotchBar

@MainActor
final class SnapshotComputationTests: XCTestCase {
    private let calendarID = "test-cal"
    private let otherCalendarID = "other-cal"
    // Pinned to UTC so day-boundary logic (startOfDay, upcomingToday vs
    // upcomingLater) is deterministic regardless of the CI runner's time zone.
    private let calendar: Calendar = {
        var calendar = Calendar(identifier: .gregorian)
        calendar.timeZone = TimeZone(identifier: "UTC")!
        return calendar
    }()

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

    func test_state_isNoCalendar_whenSelectedIDsIsEmpty() {
        let now = Date(timeIntervalSinceReferenceDate: 800_000_000)
        let snapshot = SnapshotBuilder.computeSnapshot(
            events: [makeEvent(startOffset: -60, durationSeconds: 1800, relativeTo: now)],
            selectedCalendarIDs: [],
            now: now,
            calendar: calendar,
            locale: Locale(identifier: "en")
        )

        XCTAssertEqual(snapshot.state, .noCalendar)
        XCTAssertEqual(snapshot.secondaryMessage, "Pick a calendar in Settings")
    }

    // MARK: - .inProgress

    func test_state_isInProgress_whenEventOverlapsNow() {
        let now = Date(timeIntervalSinceReferenceDate: 800_000_000)
        let snapshot = SnapshotBuilder.computeSnapshot(
            events: [makeEvent(title: "Standup", startOffset: -300, durationSeconds: 1800, relativeTo: now)],
            selectedCalendarIDs: [calendarID],
            now: now,
            calendar: calendar,
            locale: Locale(identifier: "en")
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
            selectedCalendarIDs: [calendarID],
            now: now,
            calendar: calendar,
            locale: Locale(identifier: "en")
        )

        XCTAssertEqual(snapshot.state, .inProgress)
        XCTAssertEqual(snapshot.title, "Right cal")
    }

    // MARK: - Multiple selected calendars

    func test_eventsMergedAcrossSelectedCalendars() {
        let now = fixedNoon()
        let snapshot = SnapshotBuilder.computeSnapshot(
            events: [
                makeEvent(title: "Cal B event", startOffset: 3600, durationSeconds: 1800,
                          calendarID: otherCalendarID, relativeTo: now),
                makeEvent(title: "Cal A event", startOffset: 7200, durationSeconds: 1800, relativeTo: now),
            ],
            selectedCalendarIDs: [calendarID, otherCalendarID],
            now: now,
            calendar: calendar,
            locale: Locale(identifier: "en")
        )
        XCTAssertEqual(snapshot.state, .upcomingToday)
        XCTAssertEqual(snapshot.secondaryMessage, "Next: Cal B event in 1h 0min")
    }

    func test_overlappingEvents_showEarliestStart() {
        let now = fixedNoon()
        let snapshot = SnapshotBuilder.computeSnapshot(
            events: [
                makeEvent(title: "Started second", startOffset: -600, durationSeconds: 3600,
                          calendarID: otherCalendarID, relativeTo: now),
                makeEvent(title: "Started first", startOffset: -1200, durationSeconds: 3600, relativeTo: now),
            ],
            selectedCalendarIDs: [calendarID, otherCalendarID],
            now: now,
            calendar: calendar,
            locale: Locale(identifier: "en")
        )
        XCTAssertEqual(snapshot.title, "Started first")
    }

    func test_emptySelection_isNoCalendar() {
        let now = fixedNoon()
        let snapshot = SnapshotBuilder.computeSnapshot(
            events: [makeEvent(startOffset: -60, durationSeconds: 1800, relativeTo: now)],
            selectedCalendarIDs: [],
            now: now,
            calendar: calendar,
            locale: Locale(identifier: "en")
        )
        XCTAssertEqual(snapshot.state, .noCalendar)
    }

    // MARK: - .startingSoon

    func test_state_isStartingSoon_whenNextEventWithinFiveMinutes() {
        let now = Date(timeIntervalSinceReferenceDate: 800_000_000)
        let snapshot = SnapshotBuilder.computeSnapshot(
            events: [makeEvent(title: "Standup", startOffset: 180, durationSeconds: 1800, relativeTo: now)],
            selectedCalendarIDs: [calendarID],
            now: now,
            calendar: calendar,
            locale: Locale(identifier: "en")
        )

        XCTAssertEqual(snapshot.state, .startingSoon)
        XCTAssertEqual(snapshot.secondaryMessage, "Starts in 3m — Standup")
    }

    func test_startingSoon_atExactFiveMinuteBoundary() {
        let now = Date(timeIntervalSinceReferenceDate: 800_000_000)
        let snapshot = SnapshotBuilder.computeSnapshot(
            events: [makeEvent(startOffset: 300, durationSeconds: 1800, relativeTo: now)],
            selectedCalendarIDs: [calendarID],
            now: now,
            calendar: calendar,
            locale: Locale(identifier: "en")
        )

        XCTAssertEqual(snapshot.state, .startingSoon)
    }

    // MARK: - .upcomingToday

    func test_state_isUpcomingToday_whenEventLaterTodayBeyondFiveMinutes() {
        let now = fixedNoon()
        let snapshot = SnapshotBuilder.computeSnapshot(
            events: [makeEvent(title: "Algo", startOffset: 2 * 3600 + 14 * 60, durationSeconds: 3600, relativeTo: now)],
            selectedCalendarIDs: [calendarID],
            now: now,
            calendar: calendar,
            locale: Locale(identifier: "en")
        )

        XCTAssertEqual(snapshot.state, .upcomingToday)
        XCTAssertEqual(snapshot.secondaryMessage, "Next: Algo in 2h 14min")
    }

    func test_upcomingToday_minutesOnly_whenUnderOneHour() {
        let now = fixedNoon()
        let snapshot = SnapshotBuilder.computeSnapshot(
            events: [makeEvent(title: "Coffee", startOffset: 45 * 60, durationSeconds: 1800, relativeTo: now)],
            selectedCalendarIDs: [calendarID],
            now: now,
            calendar: calendar,
            locale: Locale(identifier: "en")
        )

        XCTAssertEqual(snapshot.state, .upcomingToday)
        XCTAssertEqual(snapshot.secondaryMessage, "Next: Coffee in 45min")
    }

    // MARK: - .upcomingLater

    func test_state_isUpcomingLater_whenNextEventIsTomorrow() {
        let now = fixedNoon()
        let snapshot = SnapshotBuilder.computeSnapshot(
            events: [makeEvent(title: "Tomorrow", startOffset: 86_400, durationSeconds: 3600, relativeTo: now)],
            selectedCalendarIDs: [calendarID],
            now: now,
            calendar: calendar,
            locale: Locale(identifier: "en")
        )
        XCTAssertEqual(snapshot.state, .upcomingLater)
        XCTAssertEqual(snapshot.statusLabel, "Upcoming")
    }

    func test_state_isUpcomingLater_whenNextEventInThreeDays() {
        let now = fixedNoon()
        let snapshot = SnapshotBuilder.computeSnapshot(
            events: [makeEvent(title: "Conf", startOffset: 3 * 86_400, durationSeconds: 3600, relativeTo: now)],
            selectedCalendarIDs: [calendarID],
            now: now,
            calendar: calendar,
            locale: Locale(identifier: "en")
        )
        XCTAssertEqual(snapshot.state, .upcomingLater)
        XCTAssertEqual(snapshot.secondaryMessage, "Next event in: 03:00:00:00")
    }

    func test_boundary_eventBeforeMidnight_isUpcomingToday() {
        let now = calendar.date(byAdding: DateComponents(hour: 23, minute: 30),
                                to: calendar.startOfDay(for: fixedNoon()))!
        let snapshot = SnapshotBuilder.computeSnapshot(
            events: [makeEvent(title: "Late", startOffset: 20 * 60, durationSeconds: 1800, relativeTo: now)],
            selectedCalendarIDs: [calendarID],
            now: now,
            calendar: calendar,
            locale: Locale(identifier: "en")
        )
        XCTAssertEqual(snapshot.state, .upcomingToday)
    }

    func test_boundary_eventAfterMidnight_isUpcomingLater() {
        let now = calendar.date(byAdding: DateComponents(hour: 23, minute: 30),
                                to: calendar.startOfDay(for: fixedNoon()))!
        let snapshot = SnapshotBuilder.computeSnapshot(
            events: [makeEvent(title: "Early", startOffset: 40 * 60, durationSeconds: 1800, relativeTo: now)],
            selectedCalendarIDs: [calendarID],
            now: now,
            calendar: calendar,
            locale: Locale(identifier: "en")
        )
        XCTAssertEqual(snapshot.state, .upcomingLater)
        XCTAssertEqual(snapshot.secondaryMessage, "Next event in: 00:00:40:00")
    }

    func test_upcomingLater_countdownFormat() {
        let now = Date(timeIntervalSinceReferenceDate: 800_000_000)
        let offsetSeconds: TimeInterval = 95415 // 1d 2h 30m 15s
        let snapshot = SnapshotBuilder.computeSnapshot(
            events: [makeEvent(title: "Sprint Review", startOffset: offsetSeconds, durationSeconds: 3600, relativeTo: now)],
            selectedCalendarIDs: [calendarID],
            now: now,
            calendar: calendar,
            locale: Locale(identifier: "en")
        )

        XCTAssertEqual(snapshot.state, .upcomingLater)
        XCTAssertEqual(snapshot.secondaryMessage, "Next event in: 01:02:30:15")
    }

    // MARK: - .emptyToday

    func test_state_isEmptyToday_whenAllEventsAreInThePast() {
        let now = Date(timeIntervalSinceReferenceDate: 800_000_000)
        let snapshot = SnapshotBuilder.computeSnapshot(
            events: [makeEvent(startOffset: -3600, durationSeconds: 1800, relativeTo: now)],
            selectedCalendarIDs: [calendarID],
            now: now,
            calendar: calendar,
            locale: Locale(identifier: "en")
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
            selectedCalendarIDs: [calendarID],
            now: now,
            calendar: calendar,
            locale: Locale(identifier: "en")
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
            selectedCalendarIDs: [calendarID],
            now: now,
            calendar: calendar,
            locale: Locale(identifier: "en")
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
            events: [event], selectedCalendarIDs: [calendarID], now: now, calendar: calendar, locale: Locale(identifier: "en")
        )
        XCTAssertEqual(snapshot.joinURL, join)
    }

    func test_joinURL_nilForEmptyToday() {
        let now = fixedNoon()
        let snapshot = SnapshotBuilder.computeSnapshot(
            events: [], selectedCalendarIDs: [calendarID], now: now, calendar: calendar, locale: Locale(identifier: "en")
        )
        XCTAssertNil(snapshot.joinURL)
    }

    // MARK: - Equatable (guards redundant @Published invalidations)

    func test_snapshot_isEqual_forIdenticalInputsAtSameInstant() {
        let now = Date(timeIntervalSinceReferenceDate: 800_000_000)
        let events = [makeEvent(title: "Standup", startOffset: -300, durationSeconds: 1800, relativeTo: now)]

        let first = SnapshotBuilder.computeSnapshot(
            events: events, selectedCalendarIDs: [calendarID], now: now, calendar: calendar, locale: Locale(identifier: "en")
        )
        let second = SnapshotBuilder.computeSnapshot(
            events: events, selectedCalendarIDs: [calendarID], now: now, calendar: calendar, locale: Locale(identifier: "en")
        )

        XCTAssertEqual(first, second)
    }

    func test_snapshot_isNotEqual_whenElapsedTimeAdvances() {
        let now = Date(timeIntervalSinceReferenceDate: 800_000_000)
        let events = [makeEvent(startOffset: -300, durationSeconds: 1800, relativeTo: now)]

        let earlier = SnapshotBuilder.computeSnapshot(
            events: events, selectedCalendarIDs: [calendarID], now: now, calendar: calendar, locale: Locale(identifier: "en")
        )
        let later = SnapshotBuilder.computeSnapshot(
            events: events, selectedCalendarIDs: [calendarID], now: now.addingTimeInterval(1), calendar: calendar, locale: Locale(identifier: "en")
        )

        XCTAssertNotEqual(earlier, later)
    }

    func test_snapshot_isNotEqual_acrossDifferentStates() {
        XCTAssertNotEqual(EventProgressSnapshot.noCalendar(), EventProgressSnapshot.emptyToday())
    }

    // MARK: - .accessRevoked

    func test_accessRevoked_hasAccessMessageAndState() {
        let snapshot = EventProgressSnapshot.accessRevoked(locale: Locale(identifier: "en"))

        XCTAssertEqual(snapshot.state, .accessRevoked)
        XCTAssertEqual(snapshot.secondaryMessage, "Calendar access is off — re-enable in Settings")
    }

    func test_accessRevoked_isDistinctFromNoCalendar() {
        XCTAssertNotEqual(EventProgressSnapshot.accessRevoked(), EventProgressSnapshot.noCalendar())
    }

    // MARK: - Helpers

    /// Noon of a fixed reference day — never depends on when the test runs.
    private func fixedNoon() -> Date {
        let reference = Date(timeIntervalSinceReferenceDate: 800_000_000)
        let startOfDay = calendar.startOfDay(for: reference)
        return calendar.date(byAdding: DateComponents(hour: 12), to: startOfDay)!
    }
}
