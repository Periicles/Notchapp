import EventKit
import ServiceManagement
import SwiftUI

struct SettingsView: View {
    @ObservedObject var preferences: Preferences
    @ObservedObject var calendarManager: CalendarManager
    let onPreferencesChanged: () -> Void

    @State private var launchAtLoginEnabled = false

    var body: some View {
        VStack(alignment: .leading, spacing: 12) {
            Text("NotchBar")
                .font(.headline)

            if calendarManager.authorizationState == .denied {
                Text("Calendar access is disabled. Enable it in System Settings > Privacy & Security > Calendars.")
                    .font(.footnote)
                    .foregroundStyle(.secondary)
            } else {
                Text("Tracked Calendars")
                    .font(.subheadline.weight(.semibold))

                ScrollView {
                    VStack(alignment: .leading, spacing: 8) {
                        ForEach(calendarManager.availableCalendars, id: \.calendarIdentifier) { calendar in
                            Toggle(isOn: binding(for: calendar)) {
                                HStack(spacing: 8) {
                                    Circle()
                                        .fill(Color(nsColor: NSColor(cgColor: calendar.cgColor) ?? .controlAccentColor))
                                        .frame(width: 8, height: 8)
                                    Text(calendar.title)
                                        .font(.system(size: 12))
                                }
                            }
                            .toggleStyle(.checkbox)
                        }
                    }
                }
                .frame(maxHeight: 220)
            }

            Toggle("Show \"No meeting\" state", isOn: $preferences.showsNoMeetingState)
                .toggleStyle(.switch)

            Toggle("Launch at login", isOn: $launchAtLoginEnabled)
                .toggleStyle(.switch)
                .onChange(of: launchAtLoginEnabled) { _, newValue in
                    setLaunchAtLogin(newValue)
                }
                .onAppear {
                    launchAtLoginEnabled = SMAppService.mainApp.status == .enabled
                }
        }
        .padding(14)
        .frame(width: 320)
        .onChange(of: preferences.selectedCalendarIDs) { _, _ in
            onPreferencesChanged()
        }
        .onChange(of: preferences.showsNoMeetingState) { _, _ in
            onPreferencesChanged()
        }
    }

    private func binding(for calendar: EKCalendar) -> Binding<Bool> {
        Binding {
            preferences.selectedCalendarIDs.contains(calendar.calendarIdentifier)
        } set: { isEnabled in
            if isEnabled {
                preferences.selectedCalendarIDs.append(calendar.calendarIdentifier)
            } else {
                preferences.selectedCalendarIDs.removeAll { $0 == calendar.calendarIdentifier }
            }
        }
    }

    private func setLaunchAtLogin(_ enabled: Bool) {
        do {
            if enabled {
                try SMAppService.mainApp.register()
            } else {
                try SMAppService.mainApp.unregister()
            }
        } catch {
            launchAtLoginEnabled.toggle()
        }
    }
}
