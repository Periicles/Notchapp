@preconcurrency import UserNotifications
import XCTest
@testable import NotchBar

final class NotificationAuthorizationTests: XCTestCase {
    func test_state_isAllowed_whenTheSystemSaysYes() {
        XCTAssertEqual(NotificationAuthorization.state(for: .authorized), .allowed)
        XCTAssertEqual(NotificationAuthorization.state(for: .provisional), .allowed)
    }

    func test_state_isUndetermined_beforeAnyAnswer() {
        XCTAssertEqual(NotificationAuthorization.state(for: .notDetermined), .undetermined)
    }

    func test_state_isBlocked_whenDenied() {
        XCTAssertEqual(NotificationAuthorization.state(for: .denied), .blocked)
    }

    func test_settingsURL_opensTheNotificationsPane() {
        XCTAssertEqual(
            NotificationAuthorization.systemSettingsURL.absoluteString,
            "x-apple.systempreferences:com.apple.Notifications-Settings.extension"
        )
    }
}
