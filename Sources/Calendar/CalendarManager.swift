import AppKit
import EventKit
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
        preferences.ensureDefaultSelection(using: availableCalendars)
        installStoreObserver(preferences: preferences)
        await refreshEvents(using: preferences)
        startPolling(preferences: preferences)
    }

    func refreshEvents(using preferences: Preferences) async {
        guard authorizationState == .granted else { return }

        let calendars = selectedCalendars(using: preferences)
        let now = Date()
        let predicate = store.predicateForEvents(
            withStart: now.addingTimeInterval(-8 * 3600),
            end: now.addingTimeInterval(2 * 3600),
            calendars: calendars
        )

        let events = store.events(matching: predicate)
            .filter { !$0.isAllDay }
            .sorted { $0.startDate < $1.startDate }

        currentEvent = events.first(where: { $0.startDate <= now && $0.endDate > now })
        nextEvent = events.first(where: { $0.startDate > now })
    }

    func selectedCalendars(using preferences: Preferences) -> [EKCalendar]? {
        let selectedIDs = preferences.selectedCalendarIDs
        guard !selectedIDs.isEmpty else {
            return availableCalendars.filter { $0.type != .subscription }
        }

        let calendars = availableCalendars.filter { selectedIDs.contains($0.calendarIdentifier) }
        return calendars.isEmpty ? nil : calendars
    }

    func currentSnapshot(now: Date = .now) -> EventProgressSnapshot? {
        if let currentEvent {
            let total = currentEvent.endDate.timeIntervalSince(currentEvent.startDate)
            let elapsed = now.timeIntervalSince(currentEvent.startDate)
            let progress = min(max(elapsed / max(total, 1), 0), 1)
            let elapsedMinutes = max(Int(elapsed / 60), 0)
            let remaining = max(Int(currentEvent.endDate.timeIntervalSince(now) / 60), 0)
            let tint = Color(nsColor: NSColor(cgColor: currentEvent.calendar.cgColor) ?? .controlAccentColor)

            return EventProgressSnapshot(
                title: currentEvent.title.nilIfEmpty ?? "Current Meeting",
                progress: progress,
                elapsedLabel: format(minutes: elapsedMinutes),
                trailingLabel: "\(remaining)m",
                statusLabel: "Ends \(formattedTime(currentEvent.endDate))",
                tint: tint,
                state: .inProgress
            )
        }

        if let nextEvent {
            let minutes = Int(nextEvent.startDate.timeIntervalSince(now) / 60)
            if minutes >= 0 && minutes < 5 {
                return EventProgressSnapshot(
                    title: nextEvent.title.nilIfEmpty ?? "Upcoming Meeting",
                    progress: 0,
                    elapsedLabel: "",
                    trailingLabel: "in \(minutes)m",
                    statusLabel: "Starts \(formattedTime(nextEvent.startDate))",
                    tint: .accentColor,
                    state: .startingSoon
                )
            }
        }

        return nil
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

    private func format(minutes: Int) -> String {
        let hours = minutes / 60
        let remainingMinutes = minutes % 60

        if hours > 0 {
            return "\(hours)h \(remainingMinutes)m"
        }

        return "\(remainingMinutes)m"
    }

    private func formattedTime(_ date: Date) -> String {
        let formatter = DateFormatter()
        formatter.timeStyle = .short
        return formatter.string(from: date)
    }
}

private extension String {
    var nilIfEmpty: String? {
        isEmpty ? nil : self
    }
}
