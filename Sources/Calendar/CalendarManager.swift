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
        let predicate = store.predicateForEvents(
            withStart: now.addingTimeInterval(-8 * 3600),
            end: now.addingTimeInterval(2 * 3600),
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

    func currentSnapshot(now: Date = .now) -> EventProgressSnapshot? {
        if let currentEvent {
            let total = currentEvent.endDate.timeIntervalSince(currentEvent.startDate)
            let elapsed = now.timeIntervalSince(currentEvent.startDate)
            let progress = min(max(elapsed / max(total, 1), 0), 1)
            let elapsedSeconds = max(Int(elapsed), 0)
            let remainingSeconds = max(Int(currentEvent.endDate.timeIntervalSince(now)), 0)
            let tint = Color(nsColor: NSColor(cgColor: currentEvent.calendar.cgColor) ?? .controlAccentColor)

            return EventProgressSnapshot(
                title: currentEvent.title.nilIfEmpty ?? "Current Meeting",
                progress: progress,
                startTimeLabel: formattedTime(currentEvent.startDate),
                endTimeLabel: formattedTime(currentEvent.endDate),
                elapsedLabel: formatDuration(seconds: elapsedSeconds),
                remainingLabel: formatDuration(seconds: remainingSeconds),
                statusLabel: "In progress",
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
                    startTimeLabel: formattedTime(nextEvent.startDate),
                    endTimeLabel: formattedTime(nextEvent.endDate),
                    elapsedLabel: "",
                    remainingLabel: formatDuration(seconds: max(Int(nextEvent.startDate.timeIntervalSince(now)), 0)),
                    statusLabel: "Starts soon",
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

    private func formatDuration(seconds: Int) -> String {
        let hours = seconds / 3600
        let minutes = (seconds % 3600) / 60
        let seconds = seconds % 60

        return String(format: "%02d:%02d:%02d", hours, minutes, seconds)
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
