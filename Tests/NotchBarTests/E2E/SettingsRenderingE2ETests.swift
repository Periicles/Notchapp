import EventKit
@testable import NotchBar
import SwiftUI
import XCTest

@MainActor
final class SettingsRenderingE2ETests: XCTestCase {
    private var owned: [AnyObject] = []
    private let size = CGSize(width: 320, height: 520)

    private func render(
        state: CalendarManager.AuthorizationState = .granted,
        calendars: [EKCalendar] = [],
        notifies: Bool = false,
        notificationsBlocked: Bool = false,
        updates: UpdateChecker = UpdateChecker(installedVersion: ReleaseVersion("1.0.0"))
    ) throws -> RenderedImage {
        let manager = CalendarManager(authorizationState: state, availableCalendars: calendars)
        let preferences = Fixtures.preferences(notifies: notifies)
        let scheduler = FakeScheduler(status: notificationsBlocked ? .denied : .authorized)
        let notifier = EventNotifier(scheduler: scheduler, isAvailable: true)
        owned.append(contentsOf: [manager, preferences, notifier, updates] as [AnyObject])

        let view = SettingsView(
            preferences: preferences,
            calendarManager: manager,
            updateChecker: updates,
            notifier: notifier,
            onPreferencesChanged: {}
        )
        return try XCTUnwrap(RenderedImage(view, size: size))
    }

    private func makeCalendars() -> [EKCalendar] {
        let store = EKEventStore()
        return ["Work", "Home"].map { title in
            let calendar = EKCalendar(for: .event, eventStore: store)
            calendar.title = title
            calendar.cgColor = CGColor(red: 0.2, green: 0.5, blue: 0.9, alpha: 1)
            return calendar
        }
    }

    func test_settings_listTheCalendars_whenAccessIsGranted() throws {
        let withCalendars = try render(calendars: makeCalendars())
        let without = try render()

        XCTAssertTrue(withCalendars.hasInk(inRows: 0..<withCalendars.height))
        XCTAssertGreaterThan(
            try XCTUnwrap(withCalendars.lastInkRow),
            try XCTUnwrap(without.lastInkRow) - 1,
            "calendar rows should not shrink the view"
        )
    }

    func test_settings_explainTheSituation_whenAccessIsDeniedOrWriteOnly() throws {
        for state in [CalendarManager.AuthorizationState.denied, .insufficient] {
            let image = try render(state: state)

            XCTAssertTrue(image.hasInk(inRows: 0..<image.height), "\(state)")
        }
    }

    func test_settings_pointToSystemSettings_whenNotificationsAreBlocked() async throws {
        let scheduler = FakeScheduler(status: .denied)
        let notifier = EventNotifier(scheduler: scheduler, isAvailable: true)
        await notifier.sync(events: [], preferences: Fixtures.preferences(notifies: true))
        XCTAssertEqual(notifier.authorizationState, .blocked)

        let manager = CalendarManager(authorizationState: .granted)
        let preferences = Fixtures.preferences(notifies: true)
        owned.append(contentsOf: [manager, preferences, notifier] as [AnyObject])
        let blocked = try XCTUnwrap(RenderedImage(
            SettingsView(
                preferences: preferences,
                calendarManager: manager,
                updateChecker: UpdateChecker(installedVersion: nil),
                notifier: notifier,
                onPreferencesChanged: {}
            ),
            size: size
        ))
        let plain = try render()

        XCTAssertGreaterThan(try XCTUnwrap(blocked.lastInkRow), try XCTUnwrap(plain.lastInkRow) - 1)
    }

    func test_settings_renderEveryUpdateState() async throws {
        let release = try XCTUnwrap(URL(string: "https://github.com/Periicles/Notchapp/releases/tag/v2.0.0"))
        let fetchers: [(String, UpdateChecker)] = [
            ("available", UpdateChecker(installedVersion: ReleaseVersion("1.0.0"), fetchLatestRelease: { release })),
            ("upToDate", UpdateChecker(installedVersion: ReleaseVersion("2.0.0"), fetchLatestRelease: { release })),
            ("failed", UpdateChecker(installedVersion: ReleaseVersion("1.0.0"), fetchLatestRelease: {
                throw URLError(.notConnectedToInternet)
            })),
            ("unversioned", UpdateChecker(installedVersion: nil)),
        ]

        for (name, checker) in fetchers {
            await checker.check()
            let image = try render(updates: checker)

            XCTAssertTrue(image.hasInk(inRows: 0..<image.height), name)
        }
    }
}
