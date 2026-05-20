import Foundation
import SwiftUI

struct EventProgressSnapshot {
    enum State {
        case inProgress
        case startingSoon
        case idle
        case empty
    }

    let title: String
    let progress: Double
    let startTimeLabel: String
    let endTimeLabel: String
    let elapsedLabel: String
    let remainingLabel: String
    let statusLabel: String
    let tint: Color
    let state: State

    static let empty = EventProgressSnapshot(
        title: "",
        progress: 0,
        startTimeLabel: "",
        endTimeLabel: "",
        elapsedLabel: "",
        remainingLabel: "",
        statusLabel: "",
        tint: .clear,
        state: .empty
    )

    static let idle = EventProgressSnapshot(
        title: "No meeting",
        progress: 0,
        startTimeLabel: "",
        endTimeLabel: "",
        elapsedLabel: "",
        remainingLabel: "",
        statusLabel: "Nothing in progress right now",
        tint: Color.secondary.opacity(0.35),
        state: .idle
    )
}

@MainActor
final class EventProgressModel: ObservableObject {
    @Published private(set) var snapshot: EventProgressSnapshot = .empty
    @Published private(set) var isHoverVisible = false

    var onEmptyStateChanged: ((Bool) -> Void)?

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
        let nextSnapshot = calendarManager?.currentSnapshot() ?? .empty
        let shouldShowEmptyState = preferences?.showsNoMeetingState ?? false
        let resolvedSnapshot: EventProgressSnapshot

        if nextSnapshot.state == .empty && !shouldShowEmptyState {
            resolvedSnapshot = .empty
        } else if nextSnapshot.state == .empty && shouldShowEmptyState {
            resolvedSnapshot = .idle
        } else {
            resolvedSnapshot = nextSnapshot
        }

        let wasEmpty = snapshot.state == .empty
        let isEmpty = resolvedSnapshot.state == .empty

        snapshot = resolvedSnapshot

        if wasEmpty != isEmpty {
            onEmptyStateChanged?(isEmpty)
        }
    }
}
