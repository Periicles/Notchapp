import AppKit
@preconcurrency import EventKit
import Foundation
import SwiftUI

@MainActor
final class CalendarManager: ObservableObject {
    enum AuthorizationState: Equatable {
        case unknown
        case granted
        case denied
    }

    private let store = EKEventStore()
    private var refreshTask: Task<Void, Never>?

    @Published private(set) var authorizationState: AuthorizationState = .unknown
    @Published private(set) var availableCalendars: [EKCalendar] = []
    @Published private(set) var currentEvent: EKEvent?
    @Published private(set) var nextEvent: EKEvent?

    deinit {
        refreshTask?.cancel()
        NotificationCenter.default.removeObserver(self)
    }

    func bootstrap(using preferences: Preferences) async {
        authorizationState = await requestAccessIfNeeded()
        guard authorizationState == .granted else { return }

        availableCalendars = store.calendars(for: .event)
        preferences.ensureDefaultSelection(using: availableCalendars, store: store)
        installStoreObserver(preferences: preferences)
        await refreshEvents(using: preferences)
        startPolling(preferences: preferences)
    }

    func refreshEvents(using preferences: Preferences) async {
        guard authorizationState == .granted else { return }

        guard let calendar = selectedCalendar(using: preferences) else {
            currentEvent = nil
            nextEvent = nil
            return
        }

        let now = Date()
        let endOfWindow = Calendar.current.startOfDay(for: now.addingTimeInterval(2 * 86400))
        let predicate = store.predicateForEvents(
            withStart: now.addingTimeInterval(-8 * 3600),
            end: endOfWindow,
            calendars: [calendar]
        )

        let events = store.events(matching: predicate)
            .filter { !$0.isAllDay }
            .sorted { $0.startDate < $1.startDate }

        currentEvent = events.first(where: { $0.startDate <= now && $0.endDate > now })
        nextEvent = events.first(where: { $0.startDate > now })
    }

    func selectedCalendar(using preferences: Preferences) -> EKCalendar? {
        guard let identifier = preferences.selectedCalendarIdentifier else { return nil }
        return availableCalendars.first { $0.calendarIdentifier == identifier }
    }

    func currentSnapshot(selectedCalendarID: String?, now: Date = .now) -> EventProgressSnapshot {
        let inputs = ([currentEvent, nextEvent].compactMap { $0 }).map { event -> CalendarEvent in
            CalendarEvent(
                title: event.title ?? "",
                startDate: event.startDate,
                endDate: event.endDate,
                calendarIdentifier: event.calendar.calendarIdentifier,
                color: Color(nsColor: NSColor(cgColor: event.calendar.cgColor) ?? .controlAccentColor)
            )
        }

        return Self.computeSnapshot(
            events: inputs,
            selectedCalendarID: selectedCalendarID,
            now: now,
            calendar: .current
        )
    }

    static func computeSnapshot(
        events: [CalendarEvent],
        selectedCalendarID: String?,
        now: Date,
        calendar: Calendar
    ) -> EventProgressSnapshot {
        guard let selectedCalendarID else {
            return .noCalendar
        }

        let relevant = events
            .filter { $0.calendarIdentifier == selectedCalendarID }
            .sorted { $0.startDate < $1.startDate }

        if let current = relevant.first(where: { $0.startDate <= now && $0.endDate > now }) {
            return inProgressSnapshot(for: current, now: now)
        }

        guard let next = relevant.first(where: { $0.startDate > now }) else {
            return .emptyToday
        }

        let secondsUntilStart = next.startDate.timeIntervalSince(now)

        if secondsUntilStart <= 5 * 60 {
            return startingSoonSnapshot(for: next, now: now)
        }

        let endOfToday = calendar.startOfDay(for: now.addingTimeInterval(86400))
        if next.startDate < endOfToday {
            return upcomingTodaySnapshot(for: next, now: now)
        }

        return .emptyToday
    }

    private static func inProgressSnapshot(for event: CalendarEvent, now: Date) -> EventProgressSnapshot {
        let total = event.endDate.timeIntervalSince(event.startDate)
        let elapsed = now.timeIntervalSince(event.startDate)
        let progress = min(max(elapsed / max(total, 1), 0), 1)
        let elapsedSeconds = max(Int(elapsed), 0)
        let remainingSeconds = max(Int(event.endDate.timeIntervalSince(now)), 0)

        return EventProgressSnapshot(
            title: event.title.nilIfEmpty ?? "Current Meeting",
            progress: progress,
            startTimeLabel: formattedTime(event.startDate),
            endTimeLabel: formattedTime(event.endDate),
            elapsedLabel: formatDuration(seconds: elapsedSeconds),
            remainingLabel: formatDuration(seconds: remainingSeconds),
            statusLabel: "In progress",
            secondaryMessage: nil,
            tint: event.color,
            state: .inProgress
        )
    }

    private static func startingSoonSnapshot(for event: CalendarEvent, now: Date) -> EventProgressSnapshot {
        let title = event.title.nilIfEmpty ?? "Upcoming Meeting"
        let minutes = max(Int(event.startDate.timeIntervalSince(now) / 60), 0)
        let message = minutes == 0
            ? "Starts now — \(title)"
            : "Starts in \(minutes)m — \(title)"

        return EventProgressSnapshot(
            title: title,
            progress: 0,
            startTimeLabel: formattedTime(event.startDate),
            endTimeLabel: formattedTime(event.endDate),
            elapsedLabel: "",
            remainingLabel: "",
            statusLabel: "Starts soon",
            secondaryMessage: message,
            tint: event.color,
            state: .startingSoon
        )
    }

    private static func upcomingTodaySnapshot(for event: CalendarEvent, now: Date) -> EventProgressSnapshot {
        let title = event.title.nilIfEmpty ?? "Upcoming Meeting"
        let interval = max(event.startDate.timeIntervalSince(now), 0)
        let totalMinutes = Int(interval / 60)
        let hours = totalMinutes / 60
        let minutes = totalMinutes % 60

        let countdown = hours == 0
            ? "\(minutes)min"
            : "\(hours)h \(minutes)min"

        return EventProgressSnapshot(
            title: title,
            progress: 0,
            startTimeLabel: formattedTime(event.startDate),
            endTimeLabel: formattedTime(event.endDate),
            elapsedLabel: "",
            remainingLabel: "",
            statusLabel: "Upcoming today",
            secondaryMessage: "Next: \(title) in \(countdown)",
            tint: event.color,
            state: .upcomingToday
        )
    }

    private func startPolling(preferences: Preferences) {
        refreshTask?.cancel()
        refreshTask = Task { [weak self] in
            while !Task.isCancelled {
                try? await Task.sleep(for: .seconds(30))
                guard let self else { continue }
                await self.refreshEvents(using: preferences)
            }
        }
    }

    private func installStoreObserver(preferences: Preferences) {
        NotificationCenter.default.addObserver(
            forName: .EKEventStoreChanged,
            object: store,
            queue: .main
        ) { [weak self] _ in
            Task {
                await self?.refreshEvents(using: preferences)
            }
        }
    }

    private func requestAccessIfNeeded() async -> AuthorizationState {
        switch EKEventStore.authorizationStatus(for: .event) {
        case .fullAccess, .writeOnly:
            return .granted
        case .denied, .restricted:
            return .denied
        case .notDetermined:
            do {
                let granted = try await store.requestFullAccessToEvents()
                return granted ? .granted : .denied
            } catch {
                return .denied
            }
        @unknown default:
            return .denied
        }
    }

    private static func formatDuration(seconds: Int) -> String {
        let hours = seconds / 3600
        let minutes = (seconds % 3600) / 60
        let seconds = seconds % 60

        return String(format: "%02d:%02d:%02d", hours, minutes, seconds)
    }

    private static func formattedTime(_ date: Date) -> String {
        let formatter = DateFormatter()
        formatter.timeStyle = .short
        return formatter.string(from: date)
    }
}

struct CalendarEvent: Equatable {
    let title: String
    let startDate: Date
    let endDate: Date
    let calendarIdentifier: String
    let color: Color
}

private extension String {
    var nilIfEmpty: String? {
        isEmpty ? nil : self
    }
}
