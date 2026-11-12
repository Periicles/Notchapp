@testable import NotchBar
import UserNotifications
import XCTest

@MainActor
final class EventNotifierIntegrationTests: XCTestCase {
    private let now = Date(timeIntervalSinceReferenceDate: 800_000_000)

    private func upcomingEvent() -> CalendarEvent {
        Fixtures.event(title: "Standup", start: 3600, duration: 1800, relativeTo: now)
    }

    func test_sync_doesNothing_whenNotRunningInAnAppBundle() async {
        let scheduler = FakeScheduler()
        let notifier = EventNotifier(scheduler: scheduler, isAvailable: false)

        await notifier.sync(events: [upcomingEvent()], preferences: Fixtures.preferences(notifies: true), now: now)

        XCTAssertEqual(scheduler.removalCount, 0)
        XCTAssertTrue(scheduler.addedRequests.isEmpty)
    }

    func test_sync_clearsPendingAndReportsState_whenNotificationsAreOff() async {
        let scheduler = FakeScheduler(status: .denied)
        let notifier = EventNotifier(scheduler: scheduler, isAvailable: true)

        await notifier.sync(events: [upcomingEvent()], preferences: Fixtures.preferences(notifies: false), now: now)

        XCTAssertEqual(scheduler.removalCount, 1)
        XCTAssertTrue(scheduler.addedRequests.isEmpty)
        XCTAssertEqual(notifier.authorizationState, .blocked)
    }

    func test_sync_schedulesOneNotificationPerBoundary_whenAuthorized() async {
        let scheduler = FakeScheduler(status: .authorized)
        let notifier = EventNotifier(scheduler: scheduler, isAvailable: true)

        await notifier.sync(events: [upcomingEvent()], preferences: Fixtures.preferences(notifies: true), now: now)

        XCTAssertEqual(scheduler.addedRequests.count, 2)
        XCTAssertEqual(scheduler.addedRequests.first?.content.title, "Standup")
        XCTAssertEqual(notifier.authorizationState, .allowed)
    }

    func test_sync_replacesThePendingSet_ratherThanDiffingIt() async {
        let scheduler = FakeScheduler(status: .authorized)
        let notifier = EventNotifier(scheduler: scheduler, isAvailable: true)
        let preferences = Fixtures.preferences(notifies: true)

        await notifier.sync(events: [upcomingEvent()], preferences: preferences, now: now)
        await notifier.sync(events: [], preferences: preferences, now: now)

        XCTAssertEqual(scheduler.removalCount, 2)
    }

    func test_sync_asksOnce_whenAuthorizationIsUndetermined() async {
        let scheduler = FakeScheduler(status: .notDetermined, grantsRequest: true)
        let notifier = EventNotifier(scheduler: scheduler, isAvailable: true)

        await notifier.sync(events: [upcomingEvent()], preferences: Fixtures.preferences(notifies: true), now: now)

        XCTAssertEqual(scheduler.authorizationRequestCount, 1)
        XCTAssertEqual(notifier.authorizationState, .allowed)
        XCTAssertEqual(scheduler.addedRequests.count, 2)
    }

    func test_sync_schedulesNothing_whenThePromptIsRefused() async {
        let scheduler = FakeScheduler(status: .notDetermined, grantsRequest: false)
        let notifier = EventNotifier(scheduler: scheduler, isAvailable: true)

        await notifier.sync(events: [upcomingEvent()], preferences: Fixtures.preferences(notifies: true), now: now)

        XCTAssertEqual(notifier.authorizationState, .blocked)
        XCTAssertTrue(scheduler.addedRequests.isEmpty)
    }

    func test_sync_treatsAFailedPromptAsBlocked() async {
        let scheduler = FakeScheduler(status: .notDetermined, requestFails: true)
        let notifier = EventNotifier(scheduler: scheduler, isAvailable: true)

        await notifier.sync(events: [upcomingEvent()], preferences: Fixtures.preferences(notifies: true), now: now)

        XCTAssertEqual(notifier.authorizationState, .blocked)
        XCTAssertTrue(scheduler.addedRequests.isEmpty)
    }

    func test_sync_neverReprompts_afterARefusal() async {
        let scheduler = FakeScheduler(status: .denied)
        let notifier = EventNotifier(scheduler: scheduler, isAvailable: true)

        await notifier.sync(events: [upcomingEvent()], preferences: Fixtures.preferences(notifies: true), now: now)

        XCTAssertEqual(scheduler.authorizationRequestCount, 0)
        XCTAssertEqual(scheduler.removalCount, 0)
    }

    func test_sync_survivesASchedulingFailure() async {
        let scheduler = FakeScheduler(status: .authorized, addFails: true)
        let notifier = EventNotifier(scheduler: scheduler, isAvailable: true)

        await notifier.sync(events: [upcomingEvent()], preferences: Fixtures.preferences(notifies: true), now: now)

        XCTAssertTrue(scheduler.addedRequests.isEmpty)
        XCTAssertEqual(notifier.authorizationState, .allowed)
    }

    func test_sync_ignoresEventsOfUntrackedCalendars() async {
        let scheduler = FakeScheduler(status: .authorized)
        let notifier = EventNotifier(scheduler: scheduler, isAvailable: true)
        let other = Fixtures.event(start: 3600, duration: 1800, calendarID: "other", relativeTo: now)

        await notifier.sync(events: [other], preferences: Fixtures.preferences(notifies: true), now: now)

        XCTAssertTrue(scheduler.addedRequests.isEmpty)
    }
}
