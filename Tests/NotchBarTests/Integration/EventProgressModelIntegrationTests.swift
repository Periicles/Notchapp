import EventKit
@testable import NotchBar
import XCTest

@MainActor
final class EventProgressModelIntegrationTests: XCTestCase {
    // The model holds its manager and preferences weakly, as the app delegate
    // owns them in production; the test has to play that owner.
    private var owned: [AnyObject] = []

    private func makeModel(
        manager: CalendarManager,
        preferences: Preferences = Fixtures.preferences()
    ) -> EventProgressModel {
        owned.append(manager)
        owned.append(preferences)
        let model = EventProgressModel()
        model.bind(to: manager, preferences: preferences)
        return model
    }

    private func waitUntil(_ condition: @MainActor () -> Bool, timeout: TimeInterval = 2) async {
        let deadline = Date().addingTimeInterval(timeout)
        while !condition(), Date() < deadline {
            try? await Task.sleep(for: .milliseconds(10))
        }
    }

    // MARK: - Snapshot follows the calendar

    func test_unboundModel_showsNoCalendar() {
        let model = EventProgressModel()

        model.refreshSnapshot()

        XCTAssertEqual(model.snapshot.state, .noCalendar)
        XCTAssertNil(model.menuBarText)
        XCTAssertNil(model.restingProgress)
    }

    func test_bind_showsTheRunningEvent() {
        let running = Fixtures.event(title: "Planning", start: -600, duration: 1800)
        let model = makeModel(manager: Fixtures.calendarManager(events: [running]))

        XCTAssertEqual(model.snapshot.state, .inProgress)
        XCTAssertEqual(model.snapshot.title, "Planning")
        XCTAssertEqual(model.snapshot.progress, 600.0 / 1800.0, accuracy: 0.02)
    }

    func test_bind_showsNoCalendar_whenNothingIsTracked() {
        let running = Fixtures.event(start: -600, duration: 1800)
        let model = makeModel(
            manager: Fixtures.calendarManager(events: [running]),
            preferences: Fixtures.preferences(selected: [])
        )

        XCTAssertEqual(model.snapshot.state, .noCalendar)
    }

    func test_refresh_showsAccessRevoked_whenAccessIsDenied() {
        for state in [CalendarManager.AuthorizationState.denied, .insufficient] {
            let model = makeModel(manager: Fixtures.calendarManager(state: state, status: .denied))

            XCTAssertEqual(model.snapshot.state, .accessRevoked, "\(state)")
        }
    }

    func test_refresh_showsTheNextEvent_afterTheCurrentOneEnds() {
        let manager = Fixtures.calendarManager(events: [Fixtures.event(start: -3600, duration: 1800)])
        let model = makeModel(manager: manager)

        XCTAssertNotEqual(model.snapshot.state, .inProgress)
    }

    // MARK: - What is drawn at rest

    func test_restingProgress_followsThePreference() {
        let manager = Fixtures.calendarManager(events: [Fixtures.event(start: -900, duration: 1800)])

        let off = makeModel(manager: manager, preferences: Fixtures.preferences(restingLine: false))
        let on = makeModel(manager: manager, preferences: Fixtures.preferences(restingLine: true))

        XCTAssertNil(off.restingProgress)
        XCTAssertEqual(try XCTUnwrap(on.restingProgress), 0.5, accuracy: 0.02)
    }

    func test_menuBarText_followsThePreference() {
        let manager = Fixtures.calendarManager(events: [Fixtures.event(start: -900, duration: 1800)])

        let shown = makeModel(manager: manager, preferences: Fixtures.preferences(countdown: true))
        let hidden = makeModel(manager: manager, preferences: Fixtures.preferences(countdown: false))

        XCTAssertNotNil(shown.menuBarText)
        XCTAssertNil(hidden.menuBarText)
    }

    // MARK: - Hover

    func test_setHoverVisible_togglesTheOpenState() {
        let model = makeModel(manager: Fixtures.calendarManager())

        model.setHoverVisible(true)
        XCTAssertTrue(model.isHoverVisible)

        model.setHoverVisible(false)
        XCTAssertFalse(model.isHoverVisible)
    }

    func test_setHoverVisible_ignoresARepeatedValue() {
        let model = makeModel(manager: Fixtures.calendarManager())

        model.setHoverVisible(false)

        XCTAssertFalse(model.isHoverVisible)
    }

    func test_opening_reconcilesAuthorizationGrantedAfterLaunch() async {
        // The cached state says "unknown" but the system now says full access.
        let manager = Fixtures.calendarManager(state: .unknown, status: .fullAccess)
        let model = makeModel(manager: manager)

        model.setHoverVisible(true)
        await waitUntil { manager.authorizationState == .granted }
        model.setHoverVisible(false)

        XCTAssertEqual(manager.authorizationState, .granted)
    }

    func test_opening_reconcilesAuthorizationRevokedWhileRunning() async {
        let manager = Fixtures.calendarManager(
            state: .granted,
            status: .denied,
            events: [Fixtures.event(start: -600, duration: 1800)]
        )
        let model = makeModel(manager: manager)
        XCTAssertEqual(model.snapshot.state, .inProgress)

        model.setHoverVisible(true)
        await waitUntil { model.snapshot.state == .accessRevoked }
        model.setHoverVisible(false)

        XCTAssertEqual(model.snapshot.state, .accessRevoked)
        XCTAssertTrue(manager.events.isEmpty)
    }

    func test_syncIdleRefresh_isSafeToCallRepeatedly() {
        let model = makeModel(
            manager: Fixtures.calendarManager(),
            preferences: Fixtures.preferences(restingLine: true)
        )

        model.syncIdleRefresh()
        model.syncIdleRefresh()
        model.setHoverVisible(true)
        model.syncIdleRefresh()

        XCTAssertTrue(model.isHoverVisible)
    }
}
