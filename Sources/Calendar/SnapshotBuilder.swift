import Foundation
import SwiftUI

enum SnapshotBuilder {
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

        return upcomingLaterSnapshot(for: next, now: now)
    }

    private static func upcomingLaterSnapshot(for event: CalendarEvent, now: Date) -> EventProgressSnapshot {
        let interval = max(event.startDate.timeIntervalSince(now), 0)
        let totalSeconds = Int(interval)
        let days = totalSeconds / 86400
        let hours = (totalSeconds % 86400) / 3600
        let minutes = (totalSeconds % 3600) / 60
        let seconds = totalSeconds % 60

        let countdown = String(format: "%02d:%02d:%02d:%02d", days, hours, minutes, seconds)

        return EventProgressSnapshot(
            title: event.title.nilIfEmpty ?? "Upcoming Meeting",
            progress: 0,
            startTimeLabel: formattedTime(event.startDate),
            endTimeLabel: formattedTime(event.endDate),
            elapsedLabel: "",
            remainingLabel: "",
            statusLabel: "Upcoming",
            secondaryMessage: "Next event in: \(countdown)",
            tint: event.color,
            state: .upcomingLater
        )
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
            state: .inProgress,
            joinURL: event.joinURL
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
            state: .startingSoon,
            joinURL: event.joinURL
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

    private static func formatDuration(seconds: Int) -> String {
        let hours = seconds / 3600
        let minutes = (seconds % 3600) / 60
        let seconds = seconds % 60

        return String(format: "%02d:%02d:%02d", hours, minutes, seconds)
    }

    private static func formattedTime(_ date: Date) -> String {
        date.formatted(date: .omitted, time: .shortened)
    }
}

struct CalendarEvent: Equatable {
    let title: String
    let startDate: Date
    let endDate: Date
    let calendarIdentifier: String
    let color: Color
    var joinURL: URL?
}

private extension String {
    var nilIfEmpty: String? {
        isEmpty ? nil : self
    }
}
