import EventKit
@testable import NotchBar
import XCTest

@MainActor
final class CalendarManagerIntegrationTests: XCTestCase {
    func test_authorizationStatusChanged_comparesTheSystemWithTheCachedState() {
        let unchanged = Fixtures.calendarManager(state: .granted, status: .fullAccess)
        let changed = Fixtures.calendarManager(state: .granted, status: .denied)

        XCTAssertFalse(unchanged.authorizationStatusChanged())
        XCTAssertTrue(changed.authorizationStatusChanged())
    }

    func test_reevaluate_doesNothing_whenTheStatusIsUnchanged() async {
        let manager = Fixtures.calendarManager(state: .denied, status: .denied)

        let reloaded = await manager.reevaluateAuthorizationIfNeeded(using: Fixtures.preferences())

        XCTAssertFalse(reloaded)
        XCTAssertEqual(manager.authorizationState, .denied)
    }

    func test_reevaluate_clearsEvents_whenAccessIsRevoked() async {
        let manager = Fixtures.calendarManager(
            state: .granted,
            status: .denied,
            events: [Fixtures.event(start: -60, duration: 600)],
            allDay: [Fixtures.event(title: "Holiday", start: -60, duration: 86400)]
        )

        let reloaded = await manager.reevaluateAuthorizationIfNeeded(using: Fixtures.preferences())

        XCTAssertFalse(reloaded)
        XCTAssertEqual(manager.authorizationState, .denied)
        XCTAssertTrue(manager.events.isEmpty)
        XCTAssertTrue(manager.allDayEvents.isEmpty)
    }

    func test_reevaluate_keepsEvents_whenAccessWasNeverGranted() async {
        let manager = Fixtures.calendarManager(state: .unknown, status: .denied)

        _ = await manager.reevaluateAuthorizationIfNeeded(using: Fixtures.preferences())

        XCTAssertEqual(manager.authorizationState, .denied)
    }

    func test_reevaluate_ignoresAnUndeterminedStatus() async {
        let manager = Fixtures.calendarManager(state: .granted, status: .notDetermined)

        let reloaded = await manager.reevaluateAuthorizationIfNeeded(using: Fixtures.preferences())

        XCTAssertFalse(reloaded)
        XCTAssertEqual(manager.authorizationState, .unknown)
    }

    func test_refreshEvents_isSkipped_withoutFullAccess() async {
        let seeded = [Fixtures.event(start: -60, duration: 600)]
        let manager = Fixtures.calendarManager(state: .denied, status: .denied, events: seeded)

        await manager.refreshEvents(using: Fixtures.preferences())

        XCTAssertEqual(manager.events, seeded)
    }

    func test_refreshEvents_empties_whenNoCalendarIsTracked() async {
        let manager = Fixtures.calendarManager(
            state: .granted,
            status: .fullAccess,
            events: [Fixtures.event(start: -60, duration: 600)]
        )

        await manager.refreshEvents(using: Fixtures.preferences(selected: []))

        XCTAssertTrue(manager.events.isEmpty)
        XCTAssertTrue(manager.allDayEvents.isEmpty)
    }

    func test_currentSnapshot_resolvesAgainstTheGivenNow() {
        let now = Date()
        let running = Fixtures.event(start: -600, duration: 1800, relativeTo: now)
        let manager = Fixtures.calendarManager(events: [running])

        let during = manager.currentSnapshot(selectedCalendarIDs: [Fixtures.calendarID], now: now)
        let after = manager.currentSnapshot(
            selectedCalendarIDs: [Fixtures.calendarID],
            now: now.addingTimeInterval(7200)
        )

        XCTAssertEqual(during.state, .inProgress)
        XCTAssertNotEqual(after.state, .inProgress)
    }

    func test_selectedCalendars_isEmpty_beforeAnyCalendarIsLoaded() {
        let manager = Fixtures.calendarManager()

        XCTAssertTrue(manager.selectedCalendars(using: Fixtures.preferences()).isEmpty)
    }

    func test_fetchWindow_reachesBackFarEnoughForLongEvents() {
        let now = Date()

        let window = CalendarManager.fetchWindow(around: now)

        XCTAssertEqual(now.timeIntervalSince(window.start), 24 * 3600, accuracy: 0.001)
        XCTAssertEqual(window.end.timeIntervalSince(now), 7 * 86400, accuracy: 0.001)
    }
}
