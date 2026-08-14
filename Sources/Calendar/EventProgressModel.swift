import Foundation
import SwiftUI

struct EventProgressSnapshot: Equatable {
    enum State: Equatable {
        case inProgress
        case startingSoon
        case upcomingToday
        case upcomingLater
        case emptyToday
        case noCalendar
        case accessRevoked
    }

    let title: String
    let progress: Double
    let startTimeLabel: String
    let endTimeLabel: String
    let elapsedLabel: String
    let remainingLabel: String
    let statusLabel: String
    let secondaryMessage: String?
    let tint: Color
    let state: State
    var joinURL: URL?
    /// Raw seconds left on the running event — the unformatted datum callers that
    /// need their own presentation (the menu-bar countdown) build from. `nil`
    /// whenever no event is in progress.
    var remainingSeconds: Int?

    static func noCalendar(locale: Locale = .current) -> EventProgressSnapshot {
        EventProgressSnapshot(
            title: "",
            progress: 0,
            startTimeLabel: "",
            endTimeLabel: "",
            elapsedLabel: "",
            remainingLabel: "",
            statusLabel: "",
            secondaryMessage: Localized.string("Pick a calendar in Settings", locale: locale),
            tint: Color.secondary.opacity(0.35),
            state: .noCalendar
        )
    }

    static func emptyToday(locale: Locale = .current) -> EventProgressSnapshot {
        EventProgressSnapshot(
            title: "",
            progress: 0,
            startTimeLabel: "",
            endTimeLabel: "",
            elapsedLabel: "",
            remainingLabel: "",
            statusLabel: "",
            secondaryMessage: Localized.string("No event today", locale: locale),
            tint: Color.secondary.opacity(0.35),
            state: .emptyToday
        )
    }

    static func accessRevoked(locale: Locale = .current) -> EventProgressSnapshot {
        EventProgressSnapshot(
            title: "",
            progress: 0,
            startTimeLabel: "",
            endTimeLabel: "",
            elapsedLabel: "",
            remainingLabel: "",
            statusLabel: "",
            secondaryMessage: Localized.string("Calendar access is off — re-enable in Settings", locale: locale),
            tint: Color.secondary.opacity(0.35),
            state: .accessRevoked
        )
    }
}

@MainActor
final class EventProgressModel: ObservableObject {
    @Published private(set) var snapshot: EventProgressSnapshot = .noCalendar()
    @Published private(set) var isHoverVisible = false

    private var timerTask: Task<Void, Never>?
    private var idleTask: Task<Void, Never>?
    private weak var calendarManager: CalendarManager?
    private weak var preferences: Preferences?

    /// Compact countdown for the menu bar — the only surface that shows anything
    /// while the panel is closed. `nil` hides it entirely.
    var menuBarText: String? {
        MenuBarLabel.text(for: snapshot, enabled: preferences?.showsMenuBarCountdown ?? false)
    }

    deinit {
        timerTask?.cancel()
        idleTask?.cancel()
    }

    func bind(to calendarManager: CalendarManager, preferences: Preferences) {
        self.calendarManager = calendarManager
        self.preferences = preferences
        refreshSnapshot()
        syncIdleRefresh()
    }

    /// Start or stop the at-rest tick after anything that could change whether
    /// the menu-bar countdown is displayed.
    func syncIdleRefresh() {
        idleTask?.cancel()
        idleTask = nil

        guard !isHoverVisible, preferences?.showsMenuBarCountdown == true else { return }

        // Matches CalendarManager's polling cadence: the label can never be more
        // than one calendar poll behind, and it rounds to the minute anyway.
        idleTask = Task { [weak self] in
            while !Task.isCancelled {
                try? await Task.sleep(for: .seconds(30))
                guard let self else { return }
                self.refreshSnapshot()
            }
        }
    }

    /// The live 1s tick only runs while the panel is open. At rest the notch shows
    /// nothing from the snapshot, so recomputing it every second is wasted work.
    func setHoverVisible(_ visible: Bool) {
        guard visible != isHoverVisible else { return }
        isHoverVisible = visible
        Log.panel.debug("Panel \(visible ? "opened" : "closed", privacy: .public)")

        if visible {
            reconcileAuthorization()
            refreshSnapshot()
            startTicking()
        } else {
            stopTicking()
        }
        syncIdleRefresh()
    }

    func refreshSnapshot() {
        guard let calendarManager else {
            updateSnapshot(.noCalendar())
            return
        }

        switch calendarManager.authorizationState {
        case .denied, .insufficient:
            updateSnapshot(.accessRevoked())
        case .unknown, .granted:
            updateSnapshot(
                calendarManager.currentSnapshot(
                    selectedCalendarIDs: preferences?.selectedCalendarIdentifiers ?? []
                )
            )
        }
    }

    private func updateSnapshot(_ newSnapshot: EventProgressSnapshot) {
        guard newSnapshot != snapshot else { return }
        snapshot = newSnapshot
    }

    /// On panel open, reconcile our cached authorization with the system's, in
    /// both directions: access granted after launch, or revoked while running.
    /// Cheap — the status read is synchronous and work is spawned only on a real change.
    private func reconcileAuthorization() {
        guard let calendarManager, let preferences,
              calendarManager.authorizationStatusChanged() else { return }
        Task { [weak self] in
            await calendarManager.reevaluateAuthorizationIfNeeded(using: preferences)
            self?.refreshSnapshot()
        }
    }

    private func startTicking() {
        timerTask?.cancel()
        timerTask = Task { [weak self] in
            while !Task.isCancelled {
                try? await Task.sleep(for: .seconds(1))
                self?.refreshSnapshot()
            }
        }
    }

    private func stopTicking() {
        timerTask?.cancel()
        timerTask = nil
    }
}
