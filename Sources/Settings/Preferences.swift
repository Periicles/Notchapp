@preconcurrency import EventKit
import Foundation
import SwiftUI

@MainActor
final class Preferences: ObservableObject {
    private enum Keys {
        static let selectedCalendarIdentifiers = "selectedCalendarIdentifiers"
        static let showsMenuBarCountdown = "showsMenuBarCountdown"
        static let notifiesBeforeEvents = "notifiesBeforeEvents"
        static let legacySingleIdentifier = "selectedCalendarIdentifier"
        static let legacySelectedCalendarIDs = "selectedCalendarIDs"
        static let legacyShowsNoMeetingState = "showsNoMeetingState"
    }

    @Published var selectedCalendarIdentifiers: Set<String> {
        didSet {
            defaults.set(Array(selectedCalendarIdentifiers).sorted(), forKey: Keys.selectedCalendarIdentifiers)
            Log.preferences.debug("Selected calendars changed (\(self.selectedCalendarIdentifiers.count))")
        }
    }

    /// On by default: at rest the notch draws nothing, so without this the app
    /// gives away no information at all until the user hovers.
    @Published var showsMenuBarCountdown: Bool {
        didSet {
            defaults.set(showsMenuBarCountdown, forKey: Keys.showsMenuBarCountdown)
            Log.preferences.debug("Menu-bar countdown \(self.showsMenuBarCountdown ? "on" : "off", privacy: .public)")
        }
    }

    /// Off by default: turning it on triggers the system notification prompt, so
    /// it has to be a deliberate choice rather than something the app assumes.
    @Published var notifiesBeforeEvents: Bool {
        didSet {
            defaults.set(notifiesBeforeEvents, forKey: Keys.notifiesBeforeEvents)
            Log.preferences.debug("Event notifications \(self.notifiesBeforeEvents ? "on" : "off", privacy: .public)")
        }
    }

    var hasStoredSelection: Bool {
        defaults.object(forKey: Keys.selectedCalendarIdentifiers) != nil
    }

    private let defaults: UserDefaults

    init(defaults: UserDefaults = .standard) {
        self.defaults = defaults

        Self.migrateIfNeeded(in: defaults)

        self.selectedCalendarIdentifiers = Set(defaults.stringArray(forKey: Keys.selectedCalendarIdentifiers) ?? [])
        self.showsMenuBarCountdown = Self.bool(in: defaults, forKey: Keys.showsMenuBarCountdown, default: true)
        self.notifiesBeforeEvents = Self.bool(in: defaults, forKey: Keys.notifiesBeforeEvents, default: false)
    }

    /// `UserDefaults.bool(forKey:)` cannot distinguish "stored false" from
    /// "never set", which matters for any toggle that defaults to on.
    static func bool(in defaults: UserDefaults, forKey key: String, default defaultValue: Bool) -> Bool {
        guard let stored = defaults.object(forKey: key) as? Bool else { return defaultValue }
        return stored
    }

    func ensureDefaultSelection(using calendars: [EKCalendar], store: EKEventStore) {
        guard !hasStoredSelection else { return }

        let availableIDs = calendars.map(\.calendarIdentifier)
        let nonSubscriptionSorted = calendars
            .filter { $0.type != .subscription }
            .sorted { $0.title.localizedCaseInsensitiveCompare($1.title) == .orderedAscending }
            .map(\.calendarIdentifier)

        if let id = Self.pickDefaultIdentifier(
            available: availableIDs,
            nonSubscriptionAlphabetical: nonSubscriptionSorted,
            systemDefault: store.defaultCalendarForNewEvents?.calendarIdentifier
        ) {
            selectedCalendarIdentifiers = [id]
        }
    }

    static func pickDefaultIdentifier(
        available: [String],
        nonSubscriptionAlphabetical: [String],
        systemDefault: String?
    ) -> String? {
        if let systemDefault, available.contains(systemDefault) {
            return systemDefault
        }
        return nonSubscriptionAlphabetical.first
    }

    static func resolveSelection(current: Set<String>, available: [String]) -> Set<String> {
        current.intersection(available)
    }

    static func migrateIfNeeded(in defaults: UserDefaults) {
        if defaults.object(forKey: Keys.selectedCalendarIdentifiers) == nil {
            if let single = defaults.string(forKey: Keys.legacySingleIdentifier) {
                defaults.set([single], forKey: Keys.selectedCalendarIdentifiers)
                Log.preferences.info("Migrated single calendar selection to multi-select")
            } else if let legacyArray = defaults.stringArray(forKey: Keys.legacySelectedCalendarIDs),
                      !legacyArray.isEmpty {
                defaults.set(legacyArray, forKey: Keys.selectedCalendarIdentifiers)
                Log.preferences.info("Migrated legacy multi-select selection (\(legacyArray.count) calendars)")
            }
        }
        defaults.removeObject(forKey: Keys.legacySingleIdentifier)
        defaults.removeObject(forKey: Keys.legacySelectedCalendarIDs)
        defaults.removeObject(forKey: Keys.legacyShowsNoMeetingState)
    }
}
