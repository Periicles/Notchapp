import SwiftUI
import XCTest
@testable import NotchBar

final class NotificationPlannerTests: XCTestCase {
    private let calendarID = "test-cal"
    private let now = Date(timeIntervalSinceReferenceDate: 800_000_000)

    private func makeEvent(
        identifier: String = "event-1",
        title: String = "Organic Chemistry",
        startOffset: TimeInterval,
        durationSeconds: TimeInterval,
        calendarID: String? = nil
    ) -> CalendarEvent {
        CalendarEvent(
            identifier: identifier,
            title: title,
            startDate: now.addingTimeInterval(startOffset),
            endDate: now.addingTimeInterval(startOffset + durationSeconds),
            calendarIdentifier: calendarID ?? self.calendarID,
            color: .blue
        )
    }

    private func plan(_ events: [CalendarEvent], selected: Set<String>? = nil) -> [PlannedNotification] {
        NotificationPlanner.plan(
            events: events,
            selectedCalendarIDs: selected ?? [calendarID],
            now: now
        )
    }

    // MARK: - Both boundaries

    func test_plan_schedulesFiveMinutesBeforeStartAndBeforeEnd() {
        let event = makeEvent(startOffset: 3600, durationSeconds: 3600)

        let planned = plan([event])

        XCTAssertEqual(planned.map(\.kind), [.starting, .ending])
        XCTAssertEqual(planned[0].fireDate, now.addingTimeInterval(3600 - 300))
        XCTAssertEqual(planned[1].fireDate, now.addingTimeInterval(7200 - 300))
        XCTAssertEqual(planned[0].title, "Organic Chemistry")
    }

    // MARK: - The past is not schedulable

    func test_plan_dropsBoundariesAlreadyPassed() {
        // Running event: its start lead time is long gone, its end is not.
        let event = makeEvent(startOffset: -1800, durationSeconds: 3600)

        let planned = plan([event])

        XCTAssertEqual(planned.map(\.kind), [.ending])
        XCTAssertEqual(planned[0].fireDate, now.addingTimeInterval(1800 - 300))
    }

    func test_plan_isEmpty_forAnEventEndingWithinTheLeadTime() {
        let planned = plan([makeEvent(startOffset: -1800, durationSeconds: 1980)])

        XCTAssertTrue(planned.isEmpty)
    }

    // MARK: - Short events would fire twice for nothing

    func test_plan_skipsTheEndingNotification_whenItWouldLandOnTheStart() {
        // A 5-minute event: "ends in 5 min" fires exactly when it starts.
        let planned = plan([makeEvent(startOffset: 3600, durationSeconds: 300)])

        XCTAssertEqual(planned.map(\.kind), [.starting])
    }

    func test_plan_keepsTheEndingNotification_forEventsLongerThanTheLeadTime() {
        let planned = plan([makeEvent(startOffset: 3600, durationSeconds: 301)])

        XCTAssertEqual(planned.map(\.kind), [.starting, .ending])
    }

    // MARK: - Calendar filtering

    func test_plan_ignoresUntrackedCalendars() {
        let tracked = makeEvent(identifier: "a", startOffset: 3600, durationSeconds: 3600)
        let other = makeEvent(identifier: "b", startOffset: 3600, durationSeconds: 3600, calendarID: "other-cal")

        let planned = plan([tracked, other])

        XCTAssertEqual(planned.count, 2)
        XCTAssertTrue(planned.allSatisfy { $0.identifier.hasPrefix("a.") })
    }

    func test_plan_isEmpty_whenNoCalendarIsTracked() {
        XCTAssertTrue(plan([makeEvent(startOffset: 3600, durationSeconds: 3600)], selected: []).isEmpty)
    }

    // MARK: - Ordering and volume

    func test_plan_isSortedByFireDate() {
        let late = makeEvent(identifier: "late", startOffset: 7200, durationSeconds: 3600)
        let soon = makeEvent(identifier: "soon", startOffset: 1800, durationSeconds: 3600)

        let fireDates = plan([late, soon]).map(\.fireDate)

        XCTAssertEqual(fireDates, fireDates.sorted())
    }

    func test_plan_capsTheBatchAndKeepsTheSoonest() {
        let events = (1...40).map {
            makeEvent(identifier: "event-\($0)", startOffset: TimeInterval($0) * 3600, durationSeconds: 3600)
        }

        let planned = plan(events)

        XCTAssertEqual(planned.count, NotificationPlanner.maxScheduled)
        XCTAssertEqual(planned.first?.fireDate, now.addingTimeInterval(3600 - 300))
    }

    // MARK: - Identifiers

    func test_identifier_separatesRecurringInstancesOfTheSameEvent() {
        // EventKit hands every instance of a recurring event the same
        // eventIdentifier, so the start date has to be part of the key.
        let monday = makeEvent(identifier: "weekly", startOffset: 3600, durationSeconds: 3600)
        let tuesday = makeEvent(identifier: "weekly", startOffset: 90000, durationSeconds: 3600)

        let identifiers = plan([monday, tuesday]).map(\.identifier)

        XCTAssertEqual(Set(identifiers).count, identifiers.count)
    }

    func test_identifier_separatesTheTwoKindsOfTheSameEvent() {
        let planned = plan([makeEvent(startOffset: 3600, durationSeconds: 3600)])

        XCTAssertNotEqual(planned[0].identifier, planned[1].identifier)
    }

    // MARK: - Messages

    func test_message_readsAsALeadTimeCountdown() {
        let planned = plan([makeEvent(startOffset: 3600, durationSeconds: 3600)])
        let english = Locale(identifier: "en")

        XCTAssertEqual(planned[0].message(locale: english), "Starts in 5 min")
        XCTAssertEqual(planned[1].message(locale: english), "Ends in 5 min")
    }

    func test_message_isLocalized() {
        let planned = plan([makeEvent(startOffset: 3600, durationSeconds: 3600)])
        let french = Locale(identifier: "fr")

        XCTAssertEqual(planned[0].message(locale: french), "Commence dans 5 min")
        XCTAssertEqual(planned[1].message(locale: french), "Se termine dans 5 min")
    }

    func test_title_fallsBackWhenTheEventHasNoTitle() {
        let planned = plan([makeEvent(title: "", startOffset: 3600, durationSeconds: 3600)])

        XCTAssertEqual(planned[0].displayTitle(locale: Locale(identifier: "en")), "Upcoming Meeting")
    }
}
