import Foundation
import SwiftUI

enum SnapshotBuilder {
    static func computeSnapshot(
        events: [CalendarEvent],
        selectedCalendarIDs: Set<String>,
        now: Date,
        calendar: Calendar,
        locale: Locale = .current
    ) -> EventProgressSnapshot {
        guard !selectedCalendarIDs.isEmpty else { return .noCalendar(locale: locale) }

        let relevant = events
            .filter { selectedCalendarIDs.contains($0.calendarIdentifier) }
            .sorted { $0.startDate < $1.startDate }

        if let current = relevant.first(where: { $0.startDate <= now && $0.endDate > now }) {
            return inProgressSnapshot(for: current, now: now, locale: locale)
        }

        guard let next = relevant.first(where: { $0.startDate > now }) else {
            return .emptyToday(locale: locale)
        }

        let secondsUntilStart = next.startDate.timeIntervalSince(now)

        if secondsUntilStart <= 5 * 60 {
            return startingSoonSnapshot(for: next, now: now, locale: locale)
        }

        let endOfToday = calendar.startOfDay(for: now.addingTimeInterval(86400))
        if next.startDate < endOfToday {
            return upcomingTodaySnapshot(for: next, now: now, locale: locale)
        }

        return upcomingLaterSnapshot(for: next, now: now, locale: locale)
    }

    private static func upcomingLaterSnapshot(
        for event: CalendarEvent,
        now: Date,
        locale: Locale
    ) -> EventProgressSnapshot {
        let interval = max(event.startDate.timeIntervalSince(now), 0)
        let totalSeconds = Int(interval)
        let days = totalSeconds / 86400
        let hours = (totalSeconds % 86400) / 3600
        let minutes = (totalSeconds % 3600) / 60
        let seconds = totalSeconds % 60

        let countdown = String(format: "%02d:%02d:%02d:%02d", days, hours, minutes, seconds)
        let title = event.title.nilIfEmpty
            ?? Localized.string("Upcoming Meeting", locale: locale)

        return EventProgressSnapshot(
            title: title,
            progress: 0,
            startTimeLabel: formattedTime(event.startDate),
            endTimeLabel: formattedTime(event.endDate),
            elapsedLabel: "",
            remainingLabel: "",
            statusLabel: Localized.string("Upcoming", locale: locale),
            secondaryMessage: Localized.string("Next event in: \(countdown)", locale: locale),
            tint: event.color,
            state: .upcomingLater
        )
    }

    private static func inProgressSnapshot(
        for event: CalendarEvent,
        now: Date,
        locale: Locale
    ) -> EventProgressSnapshot {
        let total = event.endDate.timeIntervalSince(event.startDate)
        let elapsed = now.timeIntervalSince(event.startDate)
        let progress = min(max(elapsed / max(total, 1), 0), 1)
        let elapsedSeconds = max(Int(elapsed), 0)
        let remainingSeconds = max(Int(event.endDate.timeIntervalSince(now)), 0)
        let title = event.title.nilIfEmpty
            ?? Localized.string("Current Meeting", locale: locale)

        return EventProgressSnapshot(
            title: title,
            progress: progress,
            startTimeLabel: formattedTime(event.startDate),
            endTimeLabel: formattedTime(event.endDate),
            elapsedLabel: formatDuration(seconds: elapsedSeconds),
            remainingLabel: formatDuration(seconds: remainingSeconds),
            statusLabel: Localized.string("In progress", locale: locale),
            secondaryMessage: nil,
            tint: event.color,
            state: .inProgress,
            joinURL: event.joinURL,
            remainingSeconds: remainingSeconds
        )
    }

    private static func startingSoonSnapshot(
        for event: CalendarEvent,
        now: Date,
        locale: Locale
    ) -> EventProgressSnapshot {
        let title = event.title.nilIfEmpty
            ?? Localized.string("Upcoming Meeting", locale: locale)
        let minutes = max(Int(event.startDate.timeIntervalSince(now) / 60), 0)
        let message = minutes == 0
            ? Localized.string("Starts now — \(title)", locale: locale)
            : Localized.string("Starts in \(minutes)m — \(title)", locale: locale)

        return EventProgressSnapshot(
            title: title,
            progress: 0,
            startTimeLabel: formattedTime(event.startDate),
            endTimeLabel: formattedTime(event.endDate),
            elapsedLabel: "",
            remainingLabel: "",
            statusLabel: Localized.string("Starts soon", locale: locale),
            secondaryMessage: message,
            tint: event.color,
            state: .startingSoon,
            joinURL: event.joinURL
        )
    }

    private static func upcomingTodaySnapshot(
        for event: CalendarEvent,
        now: Date,
        locale: Locale
    ) -> EventProgressSnapshot {
        let title = event.title.nilIfEmpty
            ?? Localized.string("Upcoming Meeting", locale: locale)
        let interval = max(event.startDate.timeIntervalSince(now), 0)
        let totalMinutes = Int(interval / 60)
        let hours = totalMinutes / 60
        let minutes = totalMinutes % 60

        let countdown = hours == 0
            ? Localized.string("\(minutes)min", locale: locale)
            : Localized.string("\(hours)h \(minutes)min", locale: locale)

        return EventProgressSnapshot(
            title: title,
            progress: 0,
            startTimeLabel: formattedTime(event.startDate),
            endTimeLabel: formattedTime(event.endDate),
            elapsedLabel: "",
            remainingLabel: "",
            statusLabel: Localized.string("Upcoming today", locale: locale),
            secondaryMessage: Localized.string("Next: \(title) in \(countdown)", locale: locale),
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
    /// EventKit's event identifier. Every instance of a recurring event shares
    /// it, so anything keying off an occurrence must pair it with `startDate`.
    let identifier: String
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
