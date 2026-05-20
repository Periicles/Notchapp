import EventKit
import Foundation
import SwiftUI

@MainActor
final class Preferences: ObservableObject {
    private enum Keys {
        static let selectedCalendarIdentifier = "selectedCalendarIdentifier"
        static let legacySelectedCalendarIDs = "selectedCalendarIDs"
        static let legacyShowsNoMeetingState = "showsNoMeetingState"
    }

    @Published var selectedCalendarIdentifier: String? {
        didSet {
            if let selectedCalendarIdentifier {
                defaults.set(selectedCalendarIdentifier, forKey: Keys.selectedCalendarIdentifier)
            } else {
                defaults.removeObject(forKey: Keys.selectedCalendarIdentifier)
            }
        }
    }

    private let defaults: UserDefaults

    init(defaults: UserDefaults = .standard) {
        self.defaults = defaults

        Self.migrateLegacyMultiSelectIfNeeded(in: defaults)
        defaults.removeObject(forKey: Keys.legacyShowsNoMeetingState)

        self.selectedCalendarIdentifier = defaults.string(forKey: Keys.selectedCalendarIdentifier)
    }

    func ensureDefaultSelection(using calendars: [EKCalendar], store: EKEventStore) {
        guard selectedCalendarIdentifier == nil else { return }

        let availableIDs = calendars.map(\.calendarIdentifier)
        let nonSubscriptionSorted = calendars
            .filter { $0.type != .subscription }
            .sorted { $0.title.localizedCaseInsensitiveCompare($1.title) == .orderedAscending }
            .map(\.calendarIdentifier)

        selectedCalendarIdentifier = Self.pickDefaultIdentifier(
            available: availableIDs,
            nonSubscriptionAlphabetical: nonSubscriptionSorted,
            systemDefault: store.defaultCalendarForNewEvents?.calendarIdentifier
        )
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

    static func migrateLegacyMultiSelectIfNeeded(in defaults: UserDefaults) {
        guard defaults.object(forKey: Keys.selectedCalendarIdentifier) == nil,
              let legacy = defaults.stringArray(forKey: Keys.legacySelectedCalendarIDs) else {
            return
        }

        if let firstID = legacy.first {
            defaults.set(firstID, forKey: Keys.selectedCalendarIdentifier)
        }
        defaults.removeObject(forKey: Keys.legacySelectedCalendarIDs)
    }
}
