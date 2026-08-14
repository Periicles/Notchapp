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
    /// The whole fetch window as plain values, sorted by start date. Kept in full
    /// rather than narrowed to current/next at fetch time: the snapshot resolves
    /// "what is running now" against a live `now`, so a truncated list goes stale
    /// between polls as soon as one event ends and the following one starts.
    @Published private(set) var events: [CalendarEvent] = []

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

    /// Cheap synchronous check used on the hover path: has the OS authorization
    /// status diverged from our cached state, in either direction?
    func authorizationStatusChanged() -> Bool {
        Self.mapAuthorizationStatus(EKEventStore.authorizationStatus(for: .event)) != authorizationState
    }

    /// Reconcile the cached authorization with the system's. Handles both a grant
    /// after launch (loads calendars, starts polling) and a revocation while running
    /// (stops polling, clears events so the notch shows the access-off state).
    ///
    /// Returns `true` when it performed the granted reload (calendars + events),
    /// so a caller reacting to the same trigger can skip re-fetching.
    @discardableResult
    func reevaluateAuthorizationIfNeeded(using preferences: Preferences) async -> Bool {
        let latest = Self.mapAuthorizationStatus(EKEventStore.authorizationStatus(for: .event))
        guard latest != authorizationState else { return false }

        let wasGranted = authorizationState == .granted
        authorizationState = latest
        Log.calendar.info("Authorization changed: \(String(describing: latest), privacy: .public)")

        switch latest {
        case .granted:
            availableCalendars = store.calendars(for: .event)
            preferences.ensureDefaultSelection(using: availableCalendars, store: store)
            await refreshEvents(using: preferences)
            startPolling(preferences: preferences)
            return true
        case .denied, .insufficient:
            if wasGranted {
                stopPollingAndClearEvents()
            }
            return false
        case .unknown:
            return false
        }
    }

    func refreshEvents(using preferences: Preferences) async {
        guard authorizationState == .granted else {
            Log.calendar.debug("Refresh skipped: access not granted")
            return
        }

        let calendars = selectedCalendars(using: preferences)
        guard !calendars.isEmpty else {
            events = []
            Log.calendar.debug("Refresh: no calendar tracked")
            return
        }

        let now = Date()
        let endOfWindow = now.addingTimeInterval(7 * 86400)
        let predicate = store.predicateForEvents(
            withStart: now.addingTimeInterval(-8 * 3600),
            end: endOfWindow,
            calendars: calendars
        )

        events = store.events(matching: predicate)
            .filter { !$0.isAllDay }
            .sorted { $0.startDate < $1.startDate }
            .map(Self.makeEvent)
        Log.calendar.debug("Refresh: \(self.events.count) events in window")
    }

    private static func makeEvent(from event: EKEvent) -> CalendarEvent {
        CalendarEvent(
            title: event.title ?? "",
            startDate: event.startDate,
            endDate: event.endDate,
            calendarIdentifier: event.calendar.calendarIdentifier,
            color: Color(nsColor: NSColor(cgColor: event.calendar.cgColor) ?? .controlAccentColor),
            joinURL: MeetingLinkDetector.detect(url: event.url, location: event.location, notes: event.notes)
        )
    }

    func selectedCalendars(using preferences: Preferences) -> [EKCalendar] {
        availableCalendars.filter { preferences.selectedCalendarIdentifiers.contains($0.calendarIdentifier) }
    }

    func currentSnapshot(selectedCalendarIDs: Set<String>, now: Date = .now) -> EventProgressSnapshot {
        SnapshotBuilder.computeSnapshot(
            events: events,
            selectedCalendarIDs: selectedCalendarIDs,
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

    private func stopPollingAndClearEvents() {
        refreshTask?.cancel()
        refreshTask = nil
        events = []
        Log.calendar.info("Polling stopped: calendar access lost")
    }

    private func handleStoreChanged(using preferences: Preferences) async {
        // A grant transition here already reloads calendars + events; only do the
        // data-change refresh below when authorization was steady (the common case).
        let reloadedOnGrant = await reevaluateAuthorizationIfNeeded(using: preferences)
        guard authorizationState == .granted, !reloadedOnGrant else { return }
        availableCalendars = store.calendars(for: .event)
        let resolved = Preferences.resolveSelection(
            current: preferences.selectedCalendarIdentifiers,
            available: availableCalendars.map(\.calendarIdentifier)
        )
        if resolved != preferences.selectedCalendarIdentifiers {
            preferences.selectedCalendarIdentifiers = resolved
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
