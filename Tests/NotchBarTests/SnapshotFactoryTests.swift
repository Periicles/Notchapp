@testable import NotchBar
import XCTest

final class SnapshotFactoryTests: XCTestCase {
    private let english = Locale(identifier: "en_GB")

    func test_noCalendar_asksToPickOne() {
        let snapshot = EventProgressSnapshot.noCalendar(locale: english)

        XCTAssertEqual(snapshot.state, .noCalendar)
        XCTAssertEqual(snapshot.secondaryMessage, "Pick a calendar in Settings")
        XCTAssertEqual(snapshot.progress, 0)
        XCTAssertNil(snapshot.remainingSeconds)
    }

    func test_accessRevoked_pointsToSettings() {
        let snapshot = EventProgressSnapshot.accessRevoked(locale: english)

        XCTAssertEqual(snapshot.state, .accessRevoked)
        XCTAssertEqual(snapshot.secondaryMessage, "Calendar access is off — re-enable in Settings")
    }

    func test_emptyToday_saysSo_whenNothingCoversToday() {
        let snapshot = EventProgressSnapshot.emptyToday(locale: english)

        XCTAssertEqual(snapshot.state, .emptyToday)
        XCTAssertEqual(snapshot.secondaryMessage, "No event today")
    }

    func test_emptyToday_namesAnAllDayEvent_ratherThanClaimingTheDayIsEmpty() {
        let snapshot = EventProgressSnapshot.emptyToday(locale: english, allDayTitles: ["Holiday"])

        XCTAssertEqual(snapshot.secondaryMessage, "All day: Holiday")
    }

    func test_allDayMessage_countsTheTitlesItDoesNotName() {
        XCTAssertEqual(
            EventProgressSnapshot.allDayMessage(for: ["Holiday", "Birthday", "Trip"], locale: english),
            "All day: Holiday +2"
        )
    }

    func test_allDayMessage_isNil_withoutTitles() {
        XCTAssertNil(EventProgressSnapshot.allDayMessage(for: [], locale: english))
    }
}
