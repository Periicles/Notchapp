import Foundation
import SwiftUI

enum SnapshotBuilder {
    static func computeSnapshot(
        events: [CalendarEvent],
        allDayEvents: [CalendarEvent] = [],
        selectedCalendarIDs: Set<String>,
        now: Date,
        calendar: Calendar,
        locale: Locale = .current
    ) -> EventProgressSnapshot {
        guard !selectedCalendarIDs.isEmpty else { return .noCalendar(locale: locale) }

        let relevant = events
            .filter { selectedCalendarIDs.contains($0.calendarIdentifier) }
            .sorted { $0.startDate < $1.startDate }

        // Overlapping events: the one ending first is the one the user is
        // waiting on; the others are only counted.
        let running = relevant.filter { $0.startDate <= now && $0.endDate > now }
        if let current = running.min(by: { $0.endDate < $1.endDate }) {
            var snapshot = inProgressSnapshot(for: current, now: now, calendar: calendar, locale: locale)
            snapshot.concurrentEventCount = running.count - 1
            return snapshot
        }

        guard let next = relevant.first(where: { $0.startDate > now }) else {
            let allDayTitles = allDayEvents
                .filter { selectedCalendarIDs.contains($0.calendarIdentifier) }
                .filter { $0.startDate <= now && $0.endDate > now }
                .map(\.title)
                .filter { !$0.isEmpty }
            return .emptyToday(locale: locale, allDayTitles: allDayTitles)
        }

        let secondsUntilStart = next.startDate.timeIntervalSince(now)

        if secondsUntilStart <= 5 * 60 {
            return startingSoonSnapshot(for: next, now: now, calendar: calendar, locale: locale)
        }

        let endOfToday = calendar.startOfDay(for: now.addingTimeInterval(86400))
        if next.startDate < endOfToday {
            return upcomingTodaySnapshot(for: next, now: now, calendar: calendar, locale: locale)
        }

        return upcomingLaterSnapshot(for: next, now: now, calendar: calendar, locale: locale)
    }

    /// Names the day and time rather than counting down: days away, a live
    /// `DD:HH:MM:SS` was hard to read and redrew every second for nothing.
    private static func upcomingLaterSnapshot(
        for event: CalendarEvent,
        now: Date,
        calendar: Calendar,
        locale: Locale
    ) -> EventProgressSnapshot {
        let title = event.title.nilIfEmpty
            ?? Localized.string("Upcoming Meeting", locale: locale)
        let time = formattedTime(event.startDate, calendar: calendar, locale: locale)
        let startOfTomorrow = calendar.startOfDay(for: now.addingTimeInterval(86400))
        let when = event.startDate < calendar.startOfDay(for: startOfTomorrow.addingTimeInterval(86400))
            ? Localized.string("tomorrow \(time)", locale: locale)
            : "\(formattedWeekday(event.startDate, calendar: calendar, locale: locale)) \(time)"

        return EventProgressSnapshot(
            title: title,
            progress: 0,
            startTimeLabel: time,
            endTimeLabel: formattedTime(event.endDate, calendar: calendar, locale: locale),
            elapsedLabel: "",
            remainingLabel: "",
            statusLabel: Localized.string("Upcoming", locale: locale),
            secondaryMessage: Localized.string("Next: \(title) — \(when)", locale: locale),
            tint: event.color,
            state: .upcomingLater
        )
    }

    private static func inProgressSnapshot(
        for event: CalendarEvent,
        now: Date,
        calendar: Calendar,
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
            startTimeLabel: formattedTime(event.startDate, calendar: calendar, locale: locale),
            endTimeLabel: formattedTime(event.endDate, calendar: calendar, locale: locale),
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
        calendar: Calendar,
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
            startTimeLabel: formattedTime(event.startDate, calendar: calendar, locale: locale),
            endTimeLabel: formattedTime(event.endDate, calendar: calendar, locale: locale),
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
        calendar: Calendar,
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
            startTimeLabel: formattedTime(event.startDate, calendar: calendar, locale: locale),
            endTimeLabel: formattedTime(event.endDate, calendar: calendar, locale: locale),
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

    private static func formattedTime(_ date: Date, calendar: Calendar, locale: Locale) -> String {
        date.formatted(
            Date.FormatStyle(
                date: .omitted,
                time: .shortened,
                locale: locale,
                calendar: calendar,
                timeZone: calendar.timeZone
            )
        )
    }

    private static func formattedWeekday(_ date: Date, calendar: Calendar, locale: Locale) -> String {
        date.formatted(
            Date.FormatStyle(locale: locale, calendar: calendar, timeZone: calendar.timeZone).weekday(.abbreviated)
        )
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
