import XCTest
@testable import NotchBar

final class FetchWindowTests: XCTestCase {
    private let now = Date(timeIntervalSinceReferenceDate: 800_000_000)

    func test_window_reachesSevenDaysAhead() {
        let window = CalendarManager.fetchWindow(around: now)

        XCTAssertEqual(window.end, now.addingTimeInterval(7 * 86400))
    }

    func test_window_looksBackAFullDay_soLongRunningEventsAreStillFound() {
        // An all-day-length timed event — a workshop, a shift — starts well
        // before the previous 8h look-back and is still in progress.
        let window = CalendarManager.fetchWindow(around: now)

        XCTAssertEqual(window.start, now.addingTimeInterval(-24 * 3600))
    }

    func test_window_containsAnEventThatStartedTwelveHoursAgo() {
        let window = CalendarManager.fetchWindow(around: now)
        let longRunningStart = now.addingTimeInterval(-12 * 3600)

        XCTAssertLessThan(window.start, longRunningStart)
    }
}
