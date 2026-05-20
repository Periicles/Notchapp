import AppKit
import SwiftUI

@MainActor
final class NotchPanelController: NSObject {
    private let calendarManager: CalendarManager
    private let progressModel: EventProgressModel
    private let preferences: Preferences

    private let panel: NSPanel
    private let sensorPanel: NSPanel
    private let hostingView: NSHostingView<NotchPanelView>
    private let settingsPopover = NSPopover()
    private var hideWorkItem: DispatchWorkItem?

    init(
        calendarManager: CalendarManager,
        progressModel: EventProgressModel,
        preferences: Preferences
    ) {
        self.calendarManager = calendarManager
        self.progressModel = progressModel
        self.preferences = preferences

        let contentRect = ScreenHelper.panelRect()
        panel = NSPanel(
            contentRect: contentRect,
            styleMask: [.borderless, .nonactivatingPanel],
            backing: .buffered,
            defer: false
        )

        sensorPanel = NSPanel(
            contentRect: ScreenHelper.sensorRect(),
            styleMask: [.borderless, .nonactivatingPanel],
            backing: .buffered,
            defer: false
        )

        hostingView = NSHostingView(
            rootView: NotchPanelView(
                progressModel: progressModel,
                onSettingsTapped: {}
            )
        )

        super.init()

        configurePanel()
        configureSensorPanel()
        installObservers()
        refreshLayout()
        panel.orderOut(nil)
        sensorPanel.orderOut(nil)
    }

    deinit {
        NotificationCenter.default.removeObserver(self)
    }

    private func configurePanel() {
        panel.level = .statusBar
        panel.collectionBehavior = [
            .canJoinAllSpaces,
            .stationary,
            .fullScreenAuxiliary,
        ]
        panel.isOpaque = false
        panel.backgroundColor = .clear
        panel.hasShadow = false
        panel.ignoresMouseEvents = true
        panel.hidesOnDeactivate = false
        panel.isFloatingPanel = true
        panel.contentView = TrackingContainerView()
        panel.contentView?.wantsLayer = true
        panel.contentView?.layer?.backgroundColor = NSColor.clear.cgColor
        panel.contentView?.addSubview(hostingView)
        panel.orderFrontRegardless()
        hostingView.rootView = NotchPanelView(
            progressModel: progressModel,
            onSettingsTapped: { [weak self] in
                self?.toggleSettingsPopover()
            }
        )

        if let trackingView = panel.contentView as? TrackingContainerView {
            trackingView.onMouseEntered = { [weak self] in
                self?.show()
            }
            trackingView.onMouseExited = { [weak self] in
                self?.hideWithDelay()
            }
        }
    }

    private func configureSensorPanel() {
        sensorPanel.level = .statusBar
        sensorPanel.collectionBehavior = [
            .canJoinAllSpaces,
            .stationary,
            .fullScreenAuxiliary,
        ]
        sensorPanel.isOpaque = false
        sensorPanel.backgroundColor = .clear
        sensorPanel.hasShadow = false
        sensorPanel.hidesOnDeactivate = false

        let trackingView = TrackingContainerView()
        trackingView.onMouseEntered = { [weak self] in
            self?.show()
        }
        trackingView.onMouseExited = { [weak self] in
            self?.hideWithDelay()
        }

        sensorPanel.contentView = trackingView
        sensorPanel.orderFrontRegardless()
    }

    private func installObservers() {
        NotificationCenter.default.addObserver(
            self,
            selector: #selector(handleScreenChange),
            name: NSApplication.didChangeScreenParametersNotification,
            object: nil
        )

        progressModel.onEmptyStateChanged = { [weak self] isEmpty in
            guard let self else { return }
            if isEmpty {
                self.panel.orderOut(nil)
                self.sensorPanel.orderOut(nil)
            } else {
                self.panel.orderFrontRegardless()
                self.sensorPanel.orderFrontRegardless()
            }
        }
    }

    @objc
    private func handleScreenChange() {
        refreshLayout()
    }

    private func refreshLayout() {
        let panelRect = ScreenHelper.panelRect()
        let sensorRect = ScreenHelper.sensorRect()

        panel.setFrame(panelRect, display: true)
        sensorPanel.setFrame(sensorRect, display: true)
        hostingView.frame = NSRect(origin: .zero, size: panelRect.size)
    }

    private func toggleSettingsPopover() {
        guard let contentView = panel.contentView else { return }

        if settingsPopover.isShown {
            settingsPopover.performClose(nil)
            return
        }

        settingsPopover.behavior = .transient
        settingsPopover.animates = true
        settingsPopover.contentSize = NSSize(width: 320, height: 300)
        settingsPopover.contentViewController = NSHostingController(
            rootView: SettingsView(
                preferences: preferences,
                calendarManager: calendarManager,
                onPreferencesChanged: { [weak self] in
                    self?.handlePreferencesChanged()
                }
            )
        )

        let anchorRect = NSRect(
            x: contentView.bounds.maxX - 52,
            y: contentView.bounds.maxY - 44,
            width: 32,
            height: 32
        )
        settingsPopover.show(relativeTo: anchorRect, of: contentView, preferredEdge: .minY)
    }

    private func handlePreferencesChanged() {
        Task { @MainActor in
            await calendarManager.refreshEvents(using: preferences)
            progressModel.refreshSnapshot()
        }
    }

    private func show() {
        hideWorkItem?.cancel()
        panel.ignoresMouseEvents = false
        progressModel.setHoverVisible(true)
    }

    private func hideWithDelay() {
        hideWorkItem?.cancel()
        let workItem = DispatchWorkItem { [weak self] in
            guard let self else { return }
            self.progressModel.setHoverVisible(false)
            DispatchQueue.main.asyncAfter(deadline: .now() + 0.22) { [weak self] in
                guard let self, !self.progressModel.isHoverVisible else { return }
                self.panel.ignoresMouseEvents = true
            }
        }
        hideWorkItem = workItem
        DispatchQueue.main.asyncAfter(deadline: .now() + 0.18, execute: workItem)
    }
}
