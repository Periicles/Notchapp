import SwiftUI
import XCTest
@testable import NotchBar

final class MenuBarLabelTests: XCTestCase {
    private let english = Locale(identifier: "en")

    private static func inProgressSnapshot(remainingSeconds: Int) -> EventProgressSnapshot {
        EventProgressSnapshot(
            title: "Standup",
            progress: 0.5,
            startTimeLabel: "10:00",
            endTimeLabel: "10:30",
            elapsedLabel: "00:15:00",
            remainingLabel: "00:15:00",
            statusLabel: "In progress",
            secondaryMessage: nil,
            tint: .blue,
            state: .inProgress,
            remainingSeconds: remainingSeconds
        )
    }

    // MARK: - Nothing to count down

    func test_text_isNil_whenNoRemainingSeconds() {
        XCTAssertNil(MenuBarLabel.text(remainingSeconds: nil, locale: english))
    }

    func test_text_isNil_whenRemainingIsZeroOrNegative() {
        XCTAssertNil(MenuBarLabel.text(remainingSeconds: 0, locale: english))
        XCTAssertNil(MenuBarLabel.text(remainingSeconds: -30, locale: english))
    }

    // MARK: - Under an hour: minutes, rounded up

    func test_text_roundsPartialMinuteUp_soItNeverReadsZero() {
        XCTAssertEqual(MenuBarLabel.text(remainingSeconds: 1, locale: english), "1 min")
        XCTAssertEqual(MenuBarLabel.text(remainingSeconds: 59, locale: english), "1 min")
        XCTAssertEqual(MenuBarLabel.text(remainingSeconds: 60, locale: english), "1 min")
        XCTAssertEqual(MenuBarLabel.text(remainingSeconds: 61, locale: english), "2 min")
    }

    func test_text_showsMinutes_underOneHour() {
        XCTAssertEqual(MenuBarLabel.text(remainingSeconds: 23 * 60, locale: english), "23 min")
        XCTAssertEqual(MenuBarLabel.text(remainingSeconds: 59 * 60, locale: english), "59 min")
    }

    // MARK: - One hour and over: padded hours notation

    func test_text_switchesToHoursNotation_atOneHour() {
        XCTAssertEqual(MenuBarLabel.text(remainingSeconds: 3600, locale: english), "1h00")
    }

    func test_text_rollsUpToTheNextHour_whenMinutesRoundTo60() {
        XCTAssertEqual(MenuBarLabel.text(remainingSeconds: 3599, locale: english), "1h00")
    }

    func test_text_padsMinutesToTwoDigits() {
        XCTAssertEqual(MenuBarLabel.text(remainingSeconds: 3660, locale: english), "1h01")
        XCTAssertEqual(MenuBarLabel.text(remainingSeconds: 2 * 3600 + 45 * 60, locale: english), "2h45")
    }

    // MARK: - Derivation from a snapshot

    func test_textForSnapshot_isNil_whenTheToggleIsOff() {
        let snapshot = Self.inProgressSnapshot(remainingSeconds: 900)

        XCTAssertNil(MenuBarLabel.text(for: snapshot, enabled: false, locale: english))
    }

    func test_textForSnapshot_countsDownTheRunningEvent() {
        let snapshot = Self.inProgressSnapshot(remainingSeconds: 900)

        XCTAssertEqual(MenuBarLabel.text(for: snapshot, enabled: true, locale: english), "15 min")
    }

    func test_textForSnapshot_isNil_whenNothingIsRunning() {
        XCTAssertNil(MenuBarLabel.text(for: .emptyToday(), enabled: true, locale: english))
        XCTAssertNil(MenuBarLabel.text(for: .accessRevoked(), enabled: true, locale: english))
    }

    // MARK: - French typography

    func test_text_usesFrenchSpacing_forHours() {
        let value = MenuBarLabel.text(remainingSeconds: 3660, locale: Locale(identifier: "fr"))
        XCTAssertEqual(value, "1 h 01")
    }

    func test_text_isIdenticalInFrench_forMinutes() {
        let value = MenuBarLabel.text(remainingSeconds: 23 * 60, locale: Locale(identifier: "fr"))
        XCTAssertEqual(value, "23 min")
    }
}
