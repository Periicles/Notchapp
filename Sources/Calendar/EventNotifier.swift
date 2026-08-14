import Foundation
import UserNotifications

/// Applies a `NotificationPlanner` plan to the system notification centre.
///
/// The whole pending set is replaced on every sync rather than diffed: the plan
/// is cheap to recompute, the calendar can change underneath us at any time, and
/// a stale "starts in 5 min" for a cancelled event is worse than a rewrite.
@MainActor
final class EventNotifier {
    /// `UNUserNotificationCenter.current()` needs a real application bundle: it
    /// throws `bundleProxyForCurrentProcess is nil` otherwise, which is what
    /// `swift run` gives you. Hence `lazy` — as a stored property it would be
    /// evaluated in `init`, before `isAvailable` ever gets a say, and take the
    /// documented development flow down with it.
    private lazy var center = UNUserNotificationCenter.current()

    private var isAvailable: Bool { Bundle.main.bundleIdentifier != nil }

    func sync(events: [CalendarEvent], preferences: Preferences, now: Date = .now) async {
        guard isAvailable else { return }

        guard preferences.notifiesBeforeEvents else {
            center.removeAllPendingNotificationRequests()
            return
        }

        guard await isAuthorized() else { return }

        let plan = NotificationPlanner.plan(
            events: events,
            selectedCalendarIDs: preferences.selectedCalendarIdentifiers,
            now: now
        )

        center.removeAllPendingNotificationRequests()
        for planned in plan {
            await schedule(planned)
        }
        Log.notifications.debug("Scheduled \(plan.count) notifications")
    }

    private func isAuthorized() async -> Bool {
        switch await center.notificationSettings().authorizationStatus {
        case .authorized, .provisional:
            return true
        case .notDetermined:
            do {
                return try await center.requestAuthorization(options: [.alert, .sound])
            } catch {
                Log.notifications.error("Authorization request failed: \(error.localizedDescription, privacy: .public)")
                return false
            }
        default:
            Log.notifications.info("Notifications not permitted")
            return false
        }
    }

    private func schedule(_ planned: PlannedNotification) async {
        let content = UNMutableNotificationContent()
        content.title = planned.displayTitle()
        content.body = planned.message()
        content.sound = .default

        let components = Calendar.current.dateComponents(
            [.year, .month, .day, .hour, .minute, .second],
            from: planned.fireDate
        )

        let request = UNNotificationRequest(
            identifier: planned.identifier,
            content: content,
            trigger: UNCalendarNotificationTrigger(dateMatching: components, repeats: false)
        )

        do {
            try await center.add(request)
        } catch {
            Log.notifications.error("Scheduling failed: \(error.localizedDescription, privacy: .public)")
        }
    }
}
