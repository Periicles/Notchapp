import AppKit
import SwiftUI

@main
struct NotchBarApp: App {
    @NSApplicationDelegateAdaptor(AppDelegate.self) private var appDelegate

    var body: some Scene {
        MenuBarExtra {
            SettingsView(
                preferences: appDelegate.preferences,
                calendarManager: appDelegate.calendarManager,
                onPreferencesChanged: {
                    appDelegate.handlePreferencesChanged()
                }
            )
            Divider()
            Button {
                Task {
                    await appDelegate.calendarManager.refreshEvents(using: appDelegate.preferences)
                    appDelegate.progressModel.refreshSnapshot()
                }
            } label: {
                Text("Refresh Events", bundle: .module)
            }
            Button {
                NSApp.terminate(nil)
            } label: {
                Text("Quit", bundle: .module)
            }
        } label: {
            MenuBarStatusLabel(
                progressModel: appDelegate.progressModel,
                preferences: appDelegate.preferences
            )
        }
        .menuBarExtraStyle(.window)
    }
}

/// The status item itself: icon alone, plus the remaining time of the running
/// event when the countdown preference is on. This is the only place NotchBar
/// shows anything without being hovered.
struct MenuBarStatusLabel: View {
    @ObservedObject var progressModel: EventProgressModel
    @ObservedObject var preferences: Preferences

    var body: some View {
        if let countdown = progressModel.menuBarText {
            HStack(spacing: 4) {
                Image(systemName: "capsule.tophalf.filled")
                Text(countdown)
            }
            .accessibilityElement(children: .ignore)
            .accessibilityLabel(Text("Remaining", bundle: .module))
            .accessibilityValue(Text(countdown))
        } else {
            Image(systemName: "capsule.tophalf.filled")
                .accessibilityLabel(Text(verbatim: "NotchBar"))
        }
    }
}

@MainActor
final class AppDelegate: NSObject, NSApplicationDelegate {
    let preferences = Preferences()
    let calendarManager = CalendarManager()
    let progressModel = EventProgressModel()

    private var panelController: NotchPanelController?

    func applicationDidFinishLaunching(_ notification: Notification) {
        NSApp.setActivationPolicy(.accessory)
        panelController = NotchPanelController(
            calendarManager: calendarManager,
            progressModel: progressModel,
            preferences: preferences
        )
        progressModel.bind(to: calendarManager, preferences: preferences)

        Task {
            await calendarManager.bootstrap(using: preferences)
            progressModel.refreshSnapshot()
        }
    }

    func handlePreferencesChanged() {
        Task { @MainActor in
            await calendarManager.refreshEvents(using: preferences)
            progressModel.refreshSnapshot()
            progressModel.syncIdleRefresh()
        }
    }
}
