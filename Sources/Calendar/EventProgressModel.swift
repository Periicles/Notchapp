import Foundation
import SwiftUI

struct EventProgressSnapshot {
    enum State {
        case inProgress
        case startingSoon
        case upcomingToday
        case upcomingTomorrow
        case emptyToday
        case noCalendar
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

    static let noCalendar = EventProgressSnapshot(
        title: "",
        progress: 0,
        startTimeLabel: "",
        endTimeLabel: "",
        elapsedLabel: "",
        remainingLabel: "",
        statusLabel: "",
        secondaryMessage: "Pick a calendar in Settings",
        tint: Color.secondary.opacity(0.35),
        state: .noCalendar
    )

    static let emptyToday = EventProgressSnapshot(
        title: "",
        progress: 0,
        startTimeLabel: "",
        endTimeLabel: "",
        elapsedLabel: "",
        remainingLabel: "",
        statusLabel: "",
        secondaryMessage: "No event today",
        tint: Color.secondary.opacity(0.35),
        state: .emptyToday
    )
}

@MainActor
final class EventProgressModel: ObservableObject {
    @Published private(set) var snapshot: EventProgressSnapshot = .noCalendar
    @Published private(set) var isHoverVisible = false

    private var timerTask: Task<Void, Never>?
    private weak var calendarManager: CalendarManager?
    private weak var preferences: Preferences?

    deinit {
        timerTask?.cancel()
    }

    func bind(to calendarManager: CalendarManager, preferences: Preferences) {
        self.calendarManager = calendarManager
        self.preferences = preferences
        timerTask?.cancel()
        refreshSnapshot()
        timerTask = Task { [weak self] in
            while !Task.isCancelled {
                try? await Task.sleep(for: .seconds(1))
                self?.refreshSnapshot()
            }
        }
    }

    func setHoverVisible(_ visible: Bool) {
        isHoverVisible = visible
    }

    func refreshSnapshot() {
        guard let calendarManager else {
            snapshot = .noCalendar
            return
        }

        snapshot = calendarManager.currentSnapshot(
            selectedCalendarID: preferences?.selectedCalendarIdentifier
        )
    }
}
