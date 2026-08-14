import Foundation

/// Compact countdown rendered next to the menu-bar icon. Deliberately answers a
/// single question — "how long until this is over?" — so it stays a few glyphs
/// wide and never competes with the notch panel for detail.
enum MenuBarLabel {
    static func text(
        for snapshot: EventProgressSnapshot,
        enabled: Bool,
        locale: Locale = .current
    ) -> String? {
        guard enabled else { return nil }
        return text(remainingSeconds: snapshot.remainingSeconds, locale: locale)
    }

    static func text(remainingSeconds: Int?, locale: Locale = .current) -> String? {
        guard let remainingSeconds, remainingSeconds > 0 else { return nil }

        // Round up: a countdown that reads "0 min" while the event is still
        // running is wrong, and the last minute should tick away as "1 min".
        let totalMinutes = (remainingSeconds + 59) / 60
        let hours = totalMinutes / 60
        let minutes = totalMinutes % 60

        guard hours > 0 else {
            return Localized.string("\(minutes) min", locale: locale)
        }

        let paddedMinutes = String(format: "%02d", minutes)
        return Localized.string("\(hours)h\(paddedMinutes)", locale: locale)
    }
}
