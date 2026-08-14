import AppKit
import EventKit
import ServiceManagement
import SwiftUI

struct SettingsView: View {
    @ObservedObject var preferences: Preferences
    @ObservedObject var calendarManager: CalendarManager
    let onPreferencesChanged: () -> Void

    @State private var launchAtLoginEnabled = false

    /// Width the scroller occupies, re-read on each render so the "always show
    /// scroll bars" setting is honored without relaunching.
    private static var scrollerInset: CGFloat {
        NSScroller.scrollerWidth(for: .regular, scrollerStyle: NSScroller.preferredScrollerStyle) + 2
    }

    var body: some View {
        VStack(alignment: .leading, spacing: 12) {
            Text("NotchBar")
                .font(.headline)

            if calendarManager.authorizationState == .denied {
                Text(
                    "Calendar access is disabled. Enable it in System Settings > Privacy & Security > Calendars.",
                    bundle: Localized.resources
                )
                    .font(.footnote)
                    .foregroundStyle(.secondary)
            } else if calendarManager.authorizationState == .insufficient {
                Text(
                    """
                    NotchBar has write-only calendar access and cannot read your events. \
                    Switch it to Full Access in System Settings > Privacy & Security > Calendars.
                    """,
                    bundle: Localized.resources
                )
                    .font(.footnote)
                    .foregroundStyle(.secondary)
            } else {
                Text("Tracked Calendars", bundle: Localized.resources)
                    .font(.subheadline.weight(.semibold))

                ScrollView {
                    VStack(alignment: .leading, spacing: 4) {
                        ForEach(calendarManager.availableCalendars, id: \.calendarIdentifier) { calendar in
                            calendarRow(for: calendar)
                        }
                    }
                    // Clears the scroller, which otherwise sits on top of the
                    // right-aligned checkboxes when scroll bars are always shown.
                    .padding(.trailing, Self.scrollerInset)
                }
                .frame(maxHeight: 220)
            }

            settingRow("Show countdown in the menu bar", isOn: $preferences.showsMenuBarCountdown)

            settingRow("Notify me 5 minutes before an event starts or ends", isOn: $preferences.notifiesBeforeEvents)

            settingRow("Launch at login", isOn: $launchAtLoginEnabled)
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
                Button {
                    NSApplication.shared.terminate(nil)
                } label: {
                    Text("Quit NotchBar", bundle: Localized.resources)
                }
                .buttonStyle(.plain)
                .font(.system(size: 12))
                .foregroundStyle(.secondary)
            }
        }
        .padding(14)
        .frame(width: 320)
        .onChange(of: preferences.selectedCalendarIdentifiers) { _, _ in
            onPreferencesChanged()
        }
        .onChange(of: preferences.showsMenuBarCountdown) { _, _ in
            onPreferencesChanged()
        }
        .onChange(of: preferences.notifiesBeforeEvents) { _, _ in
            onPreferencesChanged()
        }
    }

    /// One settings line: label flush left, control flush right. A plain
    /// `Toggle` sizes itself to its label, so rows with different label lengths
    /// end up with their switches at different x positions.
    private func settingRow(_ title: LocalizedStringKey, isOn: Binding<Bool>) -> some View {
        HStack(spacing: 8) {
            Text(title, bundle: Localized.resources)
                .fixedSize(horizontal: false, vertical: true)
                .frame(maxWidth: .infinity, alignment: .leading)

            Toggle("", isOn: isOn)
                .toggleStyle(.switch)
                .labelsHidden()
        }
    }

    private func calendarRow(for calendar: EKCalendar) -> some View {
        let isSelected = preferences.selectedCalendarIdentifiers.contains(calendar.calendarIdentifier)
        let dotColor = Color(nsColor: NSColor(cgColor: calendar.cgColor) ?? .controlAccentColor)

        return Button {
            preferences.selectedCalendarIdentifiers.formSymmetricDifference([calendar.calendarIdentifier])
        } label: {
            HStack(spacing: 8) {
                Circle()
                    .fill(dotColor)
                    .frame(width: 8, height: 8)

                Text(calendar.title)
                    .font(.system(size: 12))
                    .foregroundStyle(.primary)

                Spacer(minLength: 8)

                Image(systemName: isSelected ? "checkmark.square.fill" : "square")
                    .foregroundStyle(isSelected ? Color.accentColor : Color.secondary)
                    .font(.system(size: 14))
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
