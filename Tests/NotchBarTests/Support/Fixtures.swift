import EventKit
import Foundation
@testable import NotchBar
import SwiftUI
import UserNotifications

enum Fixtures {
    static let calendarID = "work"

    /// An event running from `start` seconds from now for `duration` seconds.
    static func event(
        title: String = "Design review",
        start: TimeInterval,
        duration: TimeInterval,
        calendarID: String = Fixtures.calendarID,
        joinURL: URL? = nil,
        relativeTo now: Date = Date()
    ) -> CalendarEvent {
        CalendarEvent(
            identifier: "\(title)-\(start)",
            title: title,
            startDate: now.addingTimeInterval(start),
            endDate: now.addingTimeInterval(start + duration),
            calendarIdentifier: calendarID,
            color: .blue,
            joinURL: joinURL
        )
    }

    /// Preferences backed by a throwaway suite, so no test reads or writes the
    /// developer's real defaults.
    @MainActor
    static func preferences(
        selected: Set<String> = [Fixtures.calendarID],
        restingLine: Bool = false,
        countdown: Bool = true,
        notifies: Bool = false
    ) -> Preferences {
        let suite = "NotchBarTests-\(UUID().uuidString)"
        let defaults = UserDefaults(suiteName: suite)!
        defaults.removePersistentDomain(forName: suite)
        let preferences = Preferences(defaults: defaults)
        preferences.selectedCalendarIdentifiers = selected
        preferences.showsRestingProgressLine = restingLine
        preferences.showsMenuBarCountdown = countdown
        preferences.notifiesBeforeEvents = notifies
        return preferences
    }

    @MainActor
    static func calendarManager(
        state: CalendarManager.AuthorizationState = .granted,
        status: EKAuthorizationStatus = .fullAccess,
        events: [CalendarEvent] = [],
        allDay: [CalendarEvent] = []
    ) -> CalendarManager {
        CalendarManager(
            authorizationStatus: { status },
            authorizationState: state,
            events: events,
            allDayEvents: allDay
        )
    }
}

/// Records what the notifier asks of the system, and answers as scripted.
final class FakeScheduler: NotificationScheduling, @unchecked Sendable {
    private let lock = NSLock()
    private var status: UNAuthorizationStatus
    private let grantsRequest: Bool
    private let requestFails: Bool
    private let addFails: Bool
    private var recordedRequests: [UNNotificationRequest] = []
    private var removals = 0
    private var requests = 0

    init(
        status: UNAuthorizationStatus = .authorized,
        grantsRequest: Bool = true,
        requestFails: Bool = false,
        addFails: Bool = false
    ) {
        self.status = status
        self.grantsRequest = grantsRequest
        self.requestFails = requestFails
        self.addFails = addFails
    }

    var addedRequests: [UNNotificationRequest] { lock.withLock { recordedRequests } }
    var removalCount: Int { lock.withLock { removals } }
    var authorizationRequestCount: Int { lock.withLock { requests } }

    func authorizationStatus() async -> UNAuthorizationStatus {
        lock.withLock { status }
    }

    func requestAuthorization() async throws -> Bool {
        lock.withLock { requests += 1 }
        if requestFails { throw FakeError.refused }
        return grantsRequest
    }

    func removeAllPending() {
        lock.withLock { removals += 1 }
    }

    func add(_ request: UNNotificationRequest) async throws {
        if addFails { throw FakeError.refused }
        lock.withLock { recordedRequests.append(request) }
    }

    enum FakeError: Error {
        case refused
    }
}
