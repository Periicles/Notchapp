import Foundation
@preconcurrency import UserNotifications

/// What the system's answer means for the notification toggle.
///
/// macOS records a refusal for good: once denied, `requestAuthorization` no
/// longer shows anything, so an app that only ever asks leaves the user with a
/// toggle that is on and notifications that never come.
enum NotificationAuthorization {
    enum State: Equatable {
        /// Never asked — turning the toggle on is what prompts.
        case undetermined
        case allowed
        /// The system refuses; only System Settings can undo it.
        case blocked
    }

    static let systemSettingsURL = URL(string: "x-apple.systempreferences:com.apple.Notifications-Settings.extension")!

    static func state(for status: UNAuthorizationStatus) -> State {
        switch status {
        case .authorized, .provisional:
            return .allowed
        case .notDetermined:
            return .undetermined
        case .denied:
            return .blocked
        @unknown default:
            // Anything new counts as blocked: better a visible note than a
            // toggle that is on while nothing is ever delivered.
            return .blocked
        }
    }
}
