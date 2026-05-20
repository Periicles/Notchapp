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
        let snapshot = CalendarManager.computeSnapshot(
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
        let snapshot = CalendarManager.computeSnapshot(
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
        let snapshot = CalendarManager.computeSnapshot(
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
        let snapshot = CalendarManager.computeSnapshot(
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
        let snapshot = CalendarManager.computeSnapshot(
            events: [makeEvent(startOffset: 300, durationSeconds: 1800, relativeTo: now)],
            selectedCalendarID: calendarID,
            now: now,
            calendar: calendar
        )

        XCTAssertEqual(snapshot.state, .startingSoon)
    }

    // MARK: - .upcomingToday

    func test_state_isUpcomingToday_whenEventLaterTodayBeyondFiveMinutes() {
        let now = noonToday()
        let snapshot = CalendarManager.computeSnapshot(
            events: [makeEvent(title: "Algo", startOffset: 2 * 3600 + 14 * 60, durationSeconds: 3600, relativeTo: now)],
            selectedCalendarID: calendarID,
            now: now,
            calendar: calendar
        )

        XCTAssertEqual(snapshot.state, .upcomingToday)
        XCTAssertEqual(snapshot.secondaryMessage, "Next: Algo in 2h 14min")
    }

    func test_upcomingToday_minutesOnly_whenUnderOneHour() {
        let now = noonToday()
        let snapshot = CalendarManager.computeSnapshot(
            events: [makeEvent(title: "Coffee", startOffset: 45 * 60, durationSeconds: 1800, relativeTo: now)],
            selectedCalendarID: calendarID,
            now: now,
            calendar: calendar
        )

        XCTAssertEqual(snapshot.state, .upcomingToday)
        XCTAssertEqual(snapshot.secondaryMessage, "Next: Coffee in 45min")
    }

    // MARK: - .emptyToday

    func test_state_isEmptyToday_whenNextEventIsTomorrow() {
        let now = noonToday()
        let tomorrowNoon = now.addingTimeInterval(86_400)
        let snapshot = CalendarManager.computeSnapshot(
            events: [makeEvent(
                title: "Tomorrow",
                startOffset: tomorrowNoon.timeIntervalSince(now),
                durationSeconds: 3600,
                relativeTo: now
            )],
            selectedCalendarID: calendarID,
            now: now,
            calendar: calendar
        )

        XCTAssertEqual(snapshot.state, .emptyToday)
        XCTAssertEqual(snapshot.secondaryMessage, "No event today")
    }

    func test_state_isEmptyToday_whenAllEventsAreInThePast() {
        let now = Date(timeIntervalSinceReferenceDate: 800_000_000)
        let snapshot = CalendarManager.computeSnapshot(
            events: [makeEvent(startOffset: -3600, durationSeconds: 1800, relativeTo: now)],
            selectedCalendarID: calendarID,
            now: now,
            calendar: calendar
        )

        XCTAssertEqual(snapshot.state, .emptyToday)
    }

    func test_state_isEmptyToday_whenEventsExistButNoneMatchSelectedID() {
        let now = Date(timeIntervalSinceReferenceDate: 800_000_000)
        let snapshot = CalendarManager.computeSnapshot(
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
        let snapshot = CalendarManager.computeSnapshot(
            events: [makeEvent(startOffset: -elapsed, durationSeconds: duration, relativeTo: now)],
            selectedCalendarID: calendarID,
            now: now,
            calendar: calendar
        )

        XCTAssertEqual(snapshot.state, .inProgress)
        XCTAssertEqual(snapshot.progress, 0.997, accuracy: 0.0001)
        XCTAssertLessThan(snapshot.progress, 1.0)
    }

    // MARK: - Helpers

    private func noonToday() -> Date {
        var components = calendar.dateComponents([.year, .month, .day], from: Date())
        components.hour = 12
        components.minute = 0
        components.second = 0
        return calendar.date(from: components)!
    }
}
