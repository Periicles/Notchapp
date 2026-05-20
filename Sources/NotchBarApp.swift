import AppKit
import SwiftUI

@main
struct NotchBarApp: App {
    @NSApplicationDelegateAdaptor(AppDelegate.self) private var appDelegate

    var body: some Scene {
        MenuBarExtra("NotchBar", systemImage: "capsule.tophalf.filled") {
            SettingsView(
                preferences: appDelegate.preferences,
                calendarManager: appDelegate.calendarManager,
                onPreferencesChanged: {
                    appDelegate.handlePreferencesChanged()
                }
            )
            Divider()
            Button("Refresh Events") {
                Task {
                    await appDelegate.calendarManager.refreshEvents(using: appDelegate.preferences)
                    appDelegate.progressModel.refreshSnapshot()
                }
            }
            Button("Quit") {
                NSApp.terminate(nil)
            }
        }
        .menuBarExtraStyle(.window)
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
        }
    }
}
