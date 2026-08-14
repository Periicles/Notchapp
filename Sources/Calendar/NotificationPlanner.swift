import Foundation

struct PlannedNotification: Equatable {
    enum Kind: Equatable {
        case starting
        case ending
    }

    let identifier: String
    let kind: Kind
    let title: String
    let fireDate: Date

    func displayTitle(locale: Locale = .current) -> String {
        title.isEmpty ? Localized.string("Upcoming Meeting", locale: locale) : title
    }

    func message(locale: Locale = .current) -> String {
        let minutes = Int(NotificationPlanner.leadTime / 60)
        switch kind {
        case .starting:
            return Localized.string("Starts in \(minutes) min", locale: locale)
        case .ending:
            return Localized.string("Ends in \(minutes) min", locale: locale)
        }
    }
}

/// Turns the fetched window into the notifications that should be pending right
/// now. Pure: the caller hands it the events and the clock, and applies the
/// result wholesale to the notification centre.
enum NotificationPlanner {
    static let leadTime: TimeInterval = 5 * 60
    /// The system caps pending local notifications at 64; staying well under it
    /// leaves room and keeps the batch to a horizon that actually matters.
    static let maxScheduled = 32

    static func plan(
        events: [CalendarEvent],
        selectedCalendarIDs: Set<String>,
        now: Date
    ) -> [PlannedNotification] {
        events
            .filter { selectedCalendarIDs.contains($0.calendarIdentifier) }
            .flatMap { boundaries(for: $0, now: now) }
            .sorted { $0.fireDate < $1.fireDate }
            .prefix(maxScheduled)
            .map { $0 }
    }

    private static func boundaries(for event: CalendarEvent, now: Date) -> [PlannedNotification] {
        var planned: [PlannedNotification] = []

        let startFire = event.startDate.addingTimeInterval(-leadTime)
        if startFire > now {
            planned.append(notification(for: event, kind: .starting, fireDate: startFire))
        }

        // An event no longer than the lead time would fire "ends in 5 min" at or
        // before its own start — noise on top of the start notification.
        let endFire = event.endDate.addingTimeInterval(-leadTime)
        if endFire > now, endFire > event.startDate {
            planned.append(notification(for: event, kind: .ending, fireDate: endFire))
        }

        return planned
    }

    private static func notification(
        for event: CalendarEvent,
        kind: PlannedNotification.Kind,
        fireDate: Date
    ) -> PlannedNotification {
        let occurrence = Int(event.startDate.timeIntervalSinceReferenceDate)
        let suffix = kind == .starting ? "starting" : "ending"

        return PlannedNotification(
            identifier: "\(event.identifier).\(occurrence).\(suffix)",
            kind: kind,
            title: event.title,
            fireDate: fireDate
        )
    }
}
