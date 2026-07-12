@preconcurrency import EventKit
import Foundation
import SwiftUI

@MainActor
final class Preferences: ObservableObject {
    private enum Keys {
        static let selectedCalendarIdentifiers = "selectedCalendarIdentifiers"
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

    var hasStoredSelection: Bool {
        defaults.object(forKey: Keys.selectedCalendarIdentifiers) != nil
    }

    private let defaults: UserDefaults

    init(defaults: UserDefaults = .standard) {
        self.defaults = defaults

        Self.migrateIfNeeded(in: defaults)

        self.selectedCalendarIdentifiers = Set(defaults.stringArray(forKey: Keys.selectedCalendarIdentifiers) ?? [])
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
            } else if let legacyArray = defaults.stringArray(forKey: Keys.legacySelectedCalendarIDs),
                      !legacyArray.isEmpty {
                defaults.set(legacyArray, forKey: Keys.selectedCalendarIdentifiers)
            }
        }
        defaults.removeObject(forKey: Keys.legacySingleIdentifier)
        defaults.removeObject(forKey: Keys.legacySelectedCalendarIDs)
        defaults.removeObject(forKey: Keys.legacyShowsNoMeetingState)
    }
}
