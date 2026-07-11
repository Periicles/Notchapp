import AppKit
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
            } else if calendarManager.authorizationState == .insufficient {
                Text(
                    "NotchBar has write-only calendar access and cannot read your events. "
                    + "Switch it to Full Access in System Settings > Privacy & Security > Calendars."
                )
                    .font(.footnote)
                    .foregroundStyle(.secondary)
            } else {
                Text("Tracked Calendar")
                    .font(.subheadline.weight(.semibold))

                ScrollView {
                    VStack(alignment: .leading, spacing: 4) {
                        ForEach(calendarManager.availableCalendars, id: \.calendarIdentifier) { calendar in
                            calendarRow(for: calendar)
                        }
                    }
                }
                .frame(maxHeight: 220)
            }

            Toggle("Launch at login", isOn: $launchAtLoginEnabled)
                .toggleStyle(.switch)
                .onChange(of: launchAtLoginEnabled) { _, newValue in
                    setLaunchAtLogin(newValue)
                }
                .onAppear {
                    launchAtLoginEnabled = SMAppService.mainApp.status == .enabled
                }

            Divider()
                .padding(.top, 2)

            HStack {
                Spacer()
                Button("Quit NotchBar") {
                    NSApplication.shared.terminate(nil)
                }
                .buttonStyle(.plain)
                .font(.system(size: 12))
                .foregroundStyle(.secondary)
            }
        }
        .padding(14)
        .frame(width: 320)
        .onChange(of: preferences.selectedCalendarIdentifier) { _, _ in
            onPreferencesChanged()
        }
    }

    private func calendarRow(for calendar: EKCalendar) -> some View {
        let isSelected = preferences.selectedCalendarIdentifier == calendar.calendarIdentifier
        let dotColor = Color(nsColor: NSColor(cgColor: calendar.cgColor) ?? .controlAccentColor)

        return Button {
            if !isSelected {
                preferences.selectedCalendarIdentifier = calendar.calendarIdentifier
            }
        } label: {
            HStack(spacing: 8) {
                Image(systemName: isSelected ? "largecircle.fill.circle" : "circle")
                    .foregroundStyle(isSelected ? Color.accentColor : Color.secondary)
                    .font(.system(size: 14))

                Circle()
                    .fill(dotColor)
                    .frame(width: 8, height: 8)

                Text(calendar.title)
                    .font(.system(size: 12))
                    .foregroundStyle(.primary)

                Spacer(minLength: 0)
            }
            .contentShape(Rectangle())
            .padding(.vertical, 2)
        }
        .buttonStyle(.plain)
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
            Log.preferences.error("Launch-at-login toggle failed: \(error.localizedDescription, privacy: .public)")
        }
    }
}
