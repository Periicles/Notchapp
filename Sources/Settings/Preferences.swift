import EventKit
import Foundation
import SwiftUI

@MainActor
final class Preferences: ObservableObject {
    private enum Keys {
        static let selectedCalendarIDs = "selectedCalendarIDs"
        static let showsNoMeetingState = "showsNoMeetingState"
    }

    @Published var selectedCalendarIDs: [String] {
        didSet {
            defaults.set(selectedCalendarIDs, forKey: Keys.selectedCalendarIDs)
        }
    }

    @Published var showsNoMeetingState: Bool {
        didSet {
            defaults.set(showsNoMeetingState, forKey: Keys.showsNoMeetingState)
        }
    }

    private let defaults: UserDefaults

    init(defaults: UserDefaults = .standard) {
        self.defaults = defaults
        self.selectedCalendarIDs = defaults.stringArray(forKey: Keys.selectedCalendarIDs) ?? []
        self.showsNoMeetingState = defaults.object(forKey: Keys.showsNoMeetingState) as? Bool ?? false
    }

    func ensureDefaultSelection(using calendars: [EKCalendar]) {
        guard selectedCalendarIDs.isEmpty else { return }
        selectedCalendarIDs = calendars
            .filter { $0.type != .subscription }
            .map(\.calendarIdentifier)
    }
}
