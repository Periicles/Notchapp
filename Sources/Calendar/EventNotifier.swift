import Foundation
@preconcurrency import UserNotifications

/// The part of the system notification centre the notifier uses, so the sync
/// logic can run against a fake in tests.
protocol NotificationScheduling: Sendable {
    func authorizationStatus() async -> UNAuthorizationStatus
    func requestAuthorization() async throws -> Bool
    func removeAllPending()
    func add(_ request: UNNotificationRequest) async throws
}

/// `UNUserNotificationCenter.current()` needs a real application bundle: it
/// throws `bundleProxyForCurrentProcess is nil` otherwise, which is what
/// `swift run` gives you. The centre is therefore looked up on each call, and
/// `EventNotifier.isAvailable` keeps this from being reached without a bundle.
struct SystemNotificationScheduler: NotificationScheduling {
    private var center: UNUserNotificationCenter { .current() }

    func authorizationStatus() async -> UNAuthorizationStatus {
        await center.notificationSettings().authorizationStatus
    }

    func requestAuthorization() async throws -> Bool {
        try await center.requestAuthorization(options: [.alert, .sound])
    }

    func removeAllPending() {
        center.removeAllPendingNotificationRequests()
    }

    func add(_ request: UNNotificationRequest) async throws {
        try await center.add(request)
    }
}

/// Applies a `NotificationPlanner` plan to the system notification centre.
///
/// The whole pending set is replaced on every sync rather than diffed: the plan
/// is cheap to recompute, the calendar can change underneath us at any time, and
/// a stale "starts in 5 min" for a cancelled event is worse than a rewrite.
@MainActor
final class EventNotifier: ObservableObject {
    /// What the system last answered. Published so the settings panel can say
    /// so instead of leaving an ineffective toggle switched on.
    @Published private(set) var authorizationState: NotificationAuthorization.State = .undetermined

    private let scheduler: any NotificationScheduling
    private let isAvailable: Bool

    /// `isAvailable` defaults to "running as a real application bundle", the only
    /// place the system centre can be used.
    init(
        scheduler: any NotificationScheduling = SystemNotificationScheduler(),
        isAvailable: Bool = Bundle.main.bundleIdentifier != nil
    ) {
        self.scheduler = scheduler
        self.isAvailable = isAvailable
    }

    func sync(events: [CalendarEvent], preferences: Preferences, now: Date = .now) async {
        guard isAvailable else { return }

        guard preferences.notifiesBeforeEvents else {
            scheduler.removeAllPending()
            authorizationState = NotificationAuthorization.state(
                for: await scheduler.authorizationStatus()
            )
            return
        }

        guard await isAuthorized() else { return }

        let plan = NotificationPlanner.plan(
            events: events,
            selectedCalendarIDs: preferences.selectedCalendarIdentifiers,
            now: now
        )

        scheduler.removeAllPending()
        for planned in plan {
            await schedule(planned)
        }
        Log.notifications.debug("Scheduled \(plan.count) notifications")
    }

    private func isAuthorized() async -> Bool {
        let status = await scheduler.authorizationStatus()
        Log.notifications.debug("Authorization status: \(status.rawValue, privacy: .public)")
        authorizationState = NotificationAuthorization.state(for: status)

        switch authorizationState {
        case .allowed:
            return true
        case .undetermined:
            do {
                let granted = try await scheduler.requestAuthorization()
                authorizationState = granted ? .allowed : .blocked
                return granted
            } catch {
                Log.notifications.error("Authorization request failed: \(error.localizedDescription, privacy: .public)")
                authorizationState = .blocked
                return false
            }
        case .blocked:
            // macOS never re-prompts once refused, so the only way out is the
            // Notifications pane — which is what the settings panel now offers.
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
            try await scheduler.add(request)
        } catch {
            Log.notifications.error("Scheduling failed: \(error.localizedDescription, privacy: .public)")
        }
    }
}
