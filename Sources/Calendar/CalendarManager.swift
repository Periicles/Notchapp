import AppKit
@preconcurrency import EventKit
import Foundation
import SwiftUI

@MainActor
final class CalendarManager: ObservableObject {
    enum AuthorizationState: Equatable {
        case unknown
        case granted
        case insufficient   // write-only access: cannot read events
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
        installStoreObserver(preferences: preferences)

        let requested = await requestAccessIfNeeded()
        // A store-change notification during the await may have already run recovery.
        guard authorizationState != .granted else { return }
        authorizationState = requested
        Log.calendar.info("Bootstrap authorization: \(String(describing: self.authorizationState), privacy: .public)")
        guard authorizationState == .granted else { return }

        availableCalendars = store.calendars(for: .event)
        preferences.ensureDefaultSelection(using: availableCalendars, store: store)
        await refreshEvents(using: preferences)
        startPolling(preferences: preferences)
    }

    func reevaluateAuthorizationIfNeeded(using preferences: Preferences) async {
        guard authorizationState != .granted else { return }
        let latest = Self.mapAuthorizationStatus(EKEventStore.authorizationStatus(for: .event))
        guard latest != authorizationState else { return }
        authorizationState = latest
        Log.calendar.info("Authorization changed: \(String(describing: latest), privacy: .public)")
        guard latest == .granted else { return }
        availableCalendars = store.calendars(for: .event)
        preferences.ensureDefaultSelection(using: availableCalendars, store: store)
        await refreshEvents(using: preferences)
        startPolling(preferences: preferences)
    }

    func refreshEvents(using preferences: Preferences) async {
        guard authorizationState == .granted else {
            Log.calendar.debug("Refresh: current=\(self.currentEvent != nil), next=\(self.nextEvent != nil)")
            return
        }

        guard let calendar = selectedCalendar(using: preferences) else {
            currentEvent = nil
            nextEvent = nil
            Log.calendar.debug("Refresh: current=\(self.currentEvent != nil), next=\(self.nextEvent != nil)")
            return
        }

        let now = Date()
        let endOfWindow = now.addingTimeInterval(7 * 86400)
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
        Log.calendar.debug("Refresh: current=\(self.currentEvent != nil), next=\(self.nextEvent != nil)")
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

        return SnapshotBuilder.computeSnapshot(
            events: inputs,
            selectedCalendarID: selectedCalendarID,
            now: now,
            calendar: .current
        )
    }

    private func startPolling(preferences: Preferences) {
        refreshTask?.cancel()
        Log.calendar.info("Polling started")
        refreshTask = Task { [weak self] in
            while !Task.isCancelled {
                try? await Task.sleep(for: .seconds(30))
                guard let self else { continue }
                await self.refreshEvents(using: preferences)
            }
        }
    }

    private func handleStoreChanged(using preferences: Preferences) async {
        await reevaluateAuthorizationIfNeeded(using: preferences)
        guard authorizationState == .granted else { return }
        availableCalendars = store.calendars(for: .event)
        let availableIDs = availableCalendars.map(\.calendarIdentifier)
        let resolved = Preferences.resolveSelection(
            current: preferences.selectedCalendarIdentifier,
            available: availableIDs
        )
        if resolved == nil {
            preferences.selectedCalendarIdentifier = nil
            preferences.ensureDefaultSelection(using: availableCalendars, store: store)
        }
        await refreshEvents(using: preferences)
    }

    private func installStoreObserver(preferences: Preferences) {
        NotificationCenter.default.addObserver(
            forName: .EKEventStoreChanged,
            object: store,
            queue: .main
        ) { [weak self] _ in
            Task { await self?.handleStoreChanged(using: preferences) }
        }
    }

    static func mapAuthorizationStatus(_ status: EKAuthorizationStatus) -> AuthorizationState {
        switch status {
        case .fullAccess:
            return .granted
        case .writeOnly:
            return .insufficient
        case .denied, .restricted:
            return .denied
        case .notDetermined:
            return .unknown
        @unknown default:
            return .denied
        }
    }

    private func requestAccessIfNeeded() async -> AuthorizationState {
        let status = EKEventStore.authorizationStatus(for: .event)
        guard status == .notDetermined else {
            return Self.mapAuthorizationStatus(status)
        }
        do {
            let granted = try await store.requestFullAccessToEvents()
            return granted ? .granted : .denied
        } catch {
            Log.calendar.error("Full-access request failed: \(error.localizedDescription, privacy: .public)")
            return .denied
        }
    }
}
