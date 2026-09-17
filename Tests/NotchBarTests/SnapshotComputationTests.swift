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
            identifier: "event-\(startOffset)",
            title: title,
            startDate: now.addingTimeInterval(startOffset),
            endDate: now.addingTimeInterval(startOffset + durationSeconds),
            calendarIdentifier: calendarID ?? self.calendarID,
            color: .blue
        )
    }

    private func makeAllDayEvent(
        title: String,
        dayOffset: Int,
        calendarID: String? = nil,
        relativeTo now: Date
    ) -> CalendarEvent {
        let start = calendar.date(byAdding: .day, value: dayOffset, to: calendar.startOfDay(for: now))!
        return CalendarEvent(
            identifier: "all-day-\(title)",
            title: title,
            startDate: start,
            endDate: calendar.date(byAdding: .day, value: 1, to: start)!,
            calendarIdentifier: calendarID ?? self.calendarID,
            color: .blue
        )
    }

    private let english = Locale(identifier: "en_GB")
    private let french = Locale(identifier: "fr_FR")

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

    func test_inProgress_carriesRawRemainingSeconds() {
        let now = Date(timeIntervalSinceReferenceDate: 800_000_000)
        let snapshot = SnapshotBuilder.computeSnapshot(
            events: [makeEvent(startOffset: -300, durationSeconds: 1800, relativeTo: now)],
            selectedCalendarIDs: [calendarID],
            now: now,
            calendar: calendar,
            locale: Locale(identifier: "en")
        )

        XCTAssertEqual(snapshot.remainingSeconds, 1500)
    }

    func test_remainingSeconds_isNilOutsideAnInProgressEvent() {
        let now = Date(timeIntervalSinceReferenceDate: 800_000_000)
        let snapshot = SnapshotBuilder.computeSnapshot(
            events: [makeEvent(startOffset: 120, durationSeconds: 1800, relativeTo: now)],
            selectedCalendarIDs: [calendarID],
            now: now,
            calendar: calendar,
            locale: Locale(identifier: "en")
        )

        XCTAssertEqual(snapshot.state, .startingSoon)
        XCTAssertNil(snapshot.remainingSeconds)
        XCTAssertNil(EventProgressSnapshot.emptyToday().remainingSeconds)
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
            locale: english
        )
        XCTAssertEqual(snapshot.state, .upcomingLater)
        XCTAssertEqual(snapshot.secondaryMessage, "Next: Conf — \(weekday(of: now.addingTimeInterval(3 * 86_400))) \(time(of: now, locale: english))")
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
            locale: english
        )
        XCTAssertEqual(snapshot.state, .upcomingLater)
        XCTAssertEqual(snapshot.secondaryMessage, "Next: Early — tomorrow \(time(of: now.addingTimeInterval(40 * 60), locale: english))")
    }

    func test_upcomingLater_saysTomorrow_forTheNextDay() {
        let now = fixedNoon()
        let snapshot = SnapshotBuilder.computeSnapshot(
            events: [makeEvent(title: "Review", startOffset: 86_400 - 3 * 3600, durationSeconds: 3600, relativeTo: now)],
            selectedCalendarIDs: [calendarID],
            now: now,
            calendar: calendar,
            locale: english
        )

        XCTAssertEqual(snapshot.secondaryMessage, "Next: Review — tomorrow \(time(of: now.addingTimeInterval(21 * 3600), locale: english))")
    }

    func test_upcomingLater_isLocalized() {
        let now = fixedNoon()
        let snapshot = SnapshotBuilder.computeSnapshot(
            events: [makeEvent(title: "Maths", startOffset: 86_400 - 3 * 3600, durationSeconds: 3600, relativeTo: now)],
            selectedCalendarIDs: [calendarID],
            now: now,
            calendar: calendar,
            locale: french
        )

        XCTAssertEqual(snapshot.secondaryMessage, "Prochain : Maths — demain \(time(of: now.addingTimeInterval(21 * 3600), locale: french))")
    }

    func test_upcomingLater_isStable_acrossSeconds() {
        // The message names a day and a time, so it must not tick every second.
        let now = fixedNoon()
        let events = [makeEvent(title: "Conf", startOffset: 3 * 86_400, durationSeconds: 3600, relativeTo: now)]
        let first = SnapshotBuilder.computeSnapshot(
            events: events, selectedCalendarIDs: [calendarID], now: now, calendar: calendar, locale: english
        )
        let second = SnapshotBuilder.computeSnapshot(
            events: events, selectedCalendarIDs: [calendarID], now: now.addingTimeInterval(1),
            calendar: calendar, locale: english
        )

        XCTAssertEqual(first, second)
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

    // MARK: - Next event while one is running

    func test_inProgress_namesTheNextEventLaterToday() {
        let now = fixedNoon()
        let snapshot = SnapshotBuilder.computeSnapshot(
            events: [
                makeEvent(title: "Physics", startOffset: -600, durationSeconds: 3600, relativeTo: now),
                makeEvent(title: "Maths", startOffset: 2 * 3600, durationSeconds: 3600, relativeTo: now),
            ],
            selectedCalendarIDs: [calendarID],
            now: now,
            calendar: calendar,
            locale: english
        )

        XCTAssertEqual(snapshot.state, .inProgress)
        XCTAssertEqual(snapshot.nextEvent, .init(title: "Maths", startTimeLabel: time(of: now.addingTimeInterval(2 * 3600), locale: english)))
    }

    func test_inProgress_hasNoNextEvent_whenTheNextOneIsTomorrow() {
        let now = fixedNoon()
        let snapshot = SnapshotBuilder.computeSnapshot(
            events: [
                makeEvent(title: "Physics", startOffset: -600, durationSeconds: 3600, relativeTo: now),
                makeEvent(title: "Maths", startOffset: 86_400, durationSeconds: 3600, relativeTo: now),
            ],
            selectedCalendarIDs: [calendarID],
            now: now,
            calendar: calendar,
            locale: english
        )

        XCTAssertNil(snapshot.nextEvent)
    }

    func test_inProgress_nextEventSkipsOverlappingOnes() {
        let now = fixedNoon()
        let snapshot = SnapshotBuilder.computeSnapshot(
            events: [
                makeEvent(title: "Short", startOffset: -600, durationSeconds: 1200, relativeTo: now),
                makeEvent(title: "Long", startOffset: -300, durationSeconds: 3600, relativeTo: now),
                makeEvent(title: "Maths", startOffset: 3600, durationSeconds: 3600, relativeTo: now),
            ],
            selectedCalendarIDs: [calendarID],
            now: now,
            calendar: calendar,
            locale: french
        )

        XCTAssertEqual(snapshot.nextEvent, .init(title: "Maths", startTimeLabel: time(of: now.addingTimeInterval(3600), locale: french)))
    }

    // MARK: - .onBreak

    func test_state_isOnBreak_betweenTwoEventsOfTheDay() {
        let now = fixedNoon()
        let snapshot = SnapshotBuilder.computeSnapshot(
            events: [
                makeEvent(title: "Physics", startOffset: -3600 - 600, durationSeconds: 3600, relativeTo: now),
                makeEvent(title: "Maths", startOffset: 30 * 60, durationSeconds: 3600, relativeTo: now),
            ],
            selectedCalendarIDs: [calendarID],
            now: now,
            calendar: calendar,
            locale: english
        )

        XCTAssertEqual(snapshot.state, .onBreak)
        XCTAssertEqual(snapshot.title, "Break")
        XCTAssertEqual(snapshot.progress, 10.0 / 40.0, accuracy: 0.0001)
        XCTAssertEqual(snapshot.elapsedLabel, "00:10:00")
        XCTAssertEqual(snapshot.remainingLabel, "00:30:00")
        XCTAssertEqual(snapshot.remainingSeconds, 1800)
        XCTAssertEqual(snapshot.startTimeLabel, time(of: now.addingTimeInterval(-600), locale: english))
        XCTAssertEqual(snapshot.endTimeLabel, time(of: now.addingTimeInterval(30 * 60), locale: english))
        XCTAssertEqual(snapshot.nextEvent, .init(title: "Maths", startTimeLabel: time(of: now.addingTimeInterval(30 * 60), locale: english)))
        XCTAssertNil(snapshot.joinURL)
    }

    func test_onBreak_isLocalized() {
        let now = fixedNoon()
        let snapshot = SnapshotBuilder.computeSnapshot(
            events: [
                makeEvent(title: "Physique", startOffset: -3600 - 600, durationSeconds: 3600, relativeTo: now),
                makeEvent(title: "Maths", startOffset: 30 * 60, durationSeconds: 3600, relativeTo: now),
            ],
            selectedCalendarIDs: [calendarID],
            now: now,
            calendar: calendar,
            locale: french
        )

        XCTAssertEqual(snapshot.title, "Pause")
        XCTAssertEqual(snapshot.statusLabel, "Pause")
    }

    func test_onBreak_includesAGapOfExactlyTwoHours() {
        let now = fixedNoon()
        let snapshot = SnapshotBuilder.computeSnapshot(
            events: [
                makeEvent(startOffset: -3600 - 3600, durationSeconds: 3600, relativeTo: now),
                makeEvent(startOffset: 3600, durationSeconds: 3600, relativeTo: now),
            ],
            selectedCalendarIDs: [calendarID],
            now: now,
            calendar: calendar,
            locale: english
        )

        XCTAssertEqual(snapshot.state, .onBreak)
    }

    func test_upcomingToday_whenTheGapExceedsTwoHours() {
        let now = fixedNoon()
        let snapshot = SnapshotBuilder.computeSnapshot(
            events: [
                makeEvent(startOffset: -3600 - 3600, durationSeconds: 3600, relativeTo: now),
                makeEvent(startOffset: 3601, durationSeconds: 3600, relativeTo: now),
            ],
            selectedCalendarIDs: [calendarID],
            now: now,
            calendar: calendar,
            locale: english
        )

        XCTAssertEqual(snapshot.state, .upcomingToday)
    }

    func test_upcomingToday_whenNothingEndedEarlierToday() {
        // 00:30: the previous event ended yesterday, so this is not a break.
        let now = calendar.date(byAdding: DateComponents(minute: 30), to: calendar.startOfDay(for: fixedNoon()))!
        let snapshot = SnapshotBuilder.computeSnapshot(
            events: [
                makeEvent(startOffset: -3600, durationSeconds: 1200, relativeTo: now),
                makeEvent(startOffset: 30 * 60, durationSeconds: 3600, relativeTo: now),
            ],
            selectedCalendarIDs: [calendarID],
            now: now,
            calendar: calendar,
            locale: english
        )

        XCTAssertEqual(snapshot.state, .upcomingToday)
    }

    func test_upcomingToday_whenThePreviousEventIsUntracked() {
        let now = fixedNoon()
        let snapshot = SnapshotBuilder.computeSnapshot(
            events: [
                makeEvent(startOffset: -3600 - 600, durationSeconds: 3600, calendarID: otherCalendarID, relativeTo: now),
                makeEvent(startOffset: 30 * 60, durationSeconds: 3600, relativeTo: now),
            ],
            selectedCalendarIDs: [calendarID],
            now: now,
            calendar: calendar,
            locale: english
        )

        XCTAssertEqual(snapshot.state, .upcomingToday)
    }

    func test_startingSoon_winsOverABreak() {
        let now = fixedNoon()
        let snapshot = SnapshotBuilder.computeSnapshot(
            events: [
                makeEvent(startOffset: -3600 - 600, durationSeconds: 3600, relativeTo: now),
                makeEvent(startOffset: 4 * 60, durationSeconds: 3600, relativeTo: now),
            ],
            selectedCalendarIDs: [calendarID],
            now: now,
            calendar: calendar,
            locale: english
        )

        XCTAssertEqual(snapshot.state, .startingSoon)
    }

    func test_onBreak_measuresFromTheLatestEnd_whenEarlierEventsOverlapped() {
        let now = fixedNoon()
        let snapshot = SnapshotBuilder.computeSnapshot(
            events: [
                makeEvent(startOffset: -3 * 3600, durationSeconds: 2.5 * 3600, relativeTo: now),
                makeEvent(startOffset: -2 * 3600, durationSeconds: 3600 + 1200, relativeTo: now),
                makeEvent(startOffset: 20 * 60, durationSeconds: 3600, relativeTo: now),
            ],
            selectedCalendarIDs: [calendarID],
            now: now,
            calendar: calendar,
            locale: english
        )

        // Latest end is 30 minutes ago (the first event), not 40.
        XCTAssertEqual(snapshot.state, .onBreak)
        XCTAssertEqual(snapshot.progress, 30.0 / 50.0, accuracy: 0.0001)
    }

    // MARK: - Overlapping events

    func test_inProgress_showsTheEventEndingFirst_whenEventsOverlap() {
        let now = fixedNoon()
        let snapshot = SnapshotBuilder.computeSnapshot(
            events: [
                makeEvent(title: "Workshop", startOffset: -600, durationSeconds: 3600, relativeTo: now),
                makeEvent(title: "Standup", startOffset: -300, durationSeconds: 1200, relativeTo: now),
            ],
            selectedCalendarIDs: [calendarID],
            now: now,
            calendar: calendar,
            locale: english
        )

        XCTAssertEqual(snapshot.title, "Standup")
        XCTAssertEqual(snapshot.concurrentEventCount, 1)
    }

    func test_inProgress_hasNoConcurrentEvents_whenAlone() {
        let now = fixedNoon()
        let snapshot = SnapshotBuilder.computeSnapshot(
            events: [
                makeEvent(title: "Standup", startOffset: -300, durationSeconds: 1200, relativeTo: now),
                makeEvent(title: "Later", startOffset: 3600, durationSeconds: 1200, relativeTo: now),
            ],
            selectedCalendarIDs: [calendarID],
            now: now,
            calendar: calendar,
            locale: english
        )

        XCTAssertEqual(snapshot.concurrentEventCount, 0)
    }

    func test_inProgress_ignoresOverlapsFromUntrackedCalendars() {
        let now = fixedNoon()
        let snapshot = SnapshotBuilder.computeSnapshot(
            events: [
                makeEvent(title: "Workshop", startOffset: -600, durationSeconds: 3600, relativeTo: now),
                makeEvent(title: "Other", startOffset: -300, durationSeconds: 1200,
                          calendarID: otherCalendarID, relativeTo: now),
            ],
            selectedCalendarIDs: [calendarID],
            now: now,
            calendar: calendar,
            locale: english
        )

        XCTAssertEqual(snapshot.title, "Workshop")
        XCTAssertEqual(snapshot.concurrentEventCount, 0)
    }

    // MARK: - Time labels

    func test_timeLabels_followTheLocale() {
        let now = fixedNoon()
        let events = [makeEvent(startOffset: -300, durationSeconds: 3600, relativeTo: now)]

        let french = SnapshotBuilder.computeSnapshot(
            events: events, selectedCalendarIDs: [calendarID], now: now, calendar: calendar, locale: french
        )
        let american = SnapshotBuilder.computeSnapshot(
            events: events, selectedCalendarIDs: [calendarID], now: now, calendar: calendar,
            locale: Locale(identifier: "en_US")
        )

        XCTAssertEqual(french.startTimeLabel, "11:55")
        XCTAssertEqual(french.endTimeLabel, "12:55")
        XCTAssertTrue(american.endTimeLabel.hasSuffix("PM"), american.endTimeLabel)
    }

    // MARK: - All-day events

    func test_emptyToday_namesTodaysAllDayEvent() {
        let now = fixedNoon()
        let snapshot = SnapshotBuilder.computeSnapshot(
            events: [],
            allDayEvents: [makeAllDayEvent(title: "Holiday", dayOffset: 0, relativeTo: now)],
            selectedCalendarIDs: [calendarID],
            now: now,
            calendar: calendar,
            locale: english
        )

        XCTAssertEqual(snapshot.state, .emptyToday)
        XCTAssertEqual(snapshot.secondaryMessage, "All day: Holiday")
    }

    func test_emptyToday_countsExtraAllDayEvents() {
        let now = fixedNoon()
        let snapshot = SnapshotBuilder.computeSnapshot(
            events: [],
            allDayEvents: [
                makeAllDayEvent(title: "Holiday", dayOffset: 0, relativeTo: now),
                makeAllDayEvent(title: "Birthday", dayOffset: 0, relativeTo: now),
            ],
            selectedCalendarIDs: [calendarID],
            now: now,
            calendar: calendar,
            locale: french
        )

        XCTAssertEqual(snapshot.secondaryMessage, "Toute la journée : Holiday +1")
    }

    func test_emptyToday_ignoresAllDayEventsNotRunningToday() {
        let now = fixedNoon()
        let snapshot = SnapshotBuilder.computeSnapshot(
            events: [],
            allDayEvents: [
                makeAllDayEvent(title: "Yesterday", dayOffset: -1, relativeTo: now),
                makeAllDayEvent(title: "Untracked", dayOffset: 0, calendarID: otherCalendarID, relativeTo: now),
            ],
            selectedCalendarIDs: [calendarID],
            now: now,
            calendar: calendar,
            locale: english
        )

        XCTAssertEqual(snapshot.secondaryMessage, "No event today")
    }

    func test_allDayEvents_neverTakeOverATimedEvent() {
        let now = fixedNoon()
        let snapshot = SnapshotBuilder.computeSnapshot(
            events: [makeEvent(title: "Standup", startOffset: -300, durationSeconds: 1200, relativeTo: now)],
            allDayEvents: [makeAllDayEvent(title: "Holiday", dayOffset: 0, relativeTo: now)],
            selectedCalendarIDs: [calendarID],
            now: now,
            calendar: calendar,
            locale: english
        )

        XCTAssertEqual(snapshot.state, .inProgress)
        XCTAssertEqual(snapshot.title, "Standup")
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

    /// Zero-padding of the hour varies with the ICU version, so the expected
    /// time is built with the app's own style; what the tests pin is the rest.
    private func time(of date: Date, locale: Locale) -> String {
        date.formatted(
            Date.FormatStyle(date: .omitted, time: .shortened, locale: locale, calendar: calendar, timeZone: calendar.timeZone)
        )
    }

    private func weekday(of date: Date) -> String {
        date.formatted(Date.FormatStyle(locale: english, calendar: calendar, timeZone: calendar.timeZone).weekday(.abbreviated))
    }

    /// Noon of a fixed reference day — never depends on when the test runs.
    private func fixedNoon() -> Date {
        let reference = Date(timeIntervalSinceReferenceDate: 800_000_000)
        let startOfDay = calendar.startOfDay(for: reference)
        return calendar.date(byAdding: DateComponents(hour: 12), to: startOfDay)!
    }
}
