import AppKit
import SwiftUI

@MainActor
final class NotchPanelController: NSObject {
    private let calendarManager: CalendarManager
    private let progressModel: EventProgressModel
    private let preferences: Preferences

    private let panel: NotchPanelWindow
    private let sensorPanel: NotchPanelWindow
    private var hostingView: NSHostingView<NotchPanelView>!
    private let settingsPopover = NSPopover()
    private lazy var settingsContentController: NSHostingController<SettingsView> = {
        NSHostingController(
            rootView: SettingsView(
                preferences: preferences,
                calendarManager: calendarManager,
                onPreferencesChanged: { [weak self] in
                    self?.handlePreferencesChanged()
                }
            )
        )
    }()
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
        panel = NotchPanelWindow(
            contentRect: contentRect,
            styleMask: [.borderless, .nonactivatingPanel],
            backing: .buffered,
            defer: false
        )

        sensorPanel = NotchPanelWindow(
            contentRect: ScreenHelper.sensorRect(),
            styleMask: [.borderless, .nonactivatingPanel],
            backing: .buffered,
            defer: false
        )

        super.init()

        hostingView = NSHostingView(
            rootView: NotchPanelView(
                progressModel: progressModel,
                onSettingsTapped: { [weak self] in
                    self?.toggleSettingsPopover()
                }
            )
        )

        configurePanel()
        configureSensorPanel()
        installObservers()
        refreshLayout()
        panel.orderFrontRegardless()
        sensorPanel.orderFrontRegardless()
    }

    deinit {
        NotificationCenter.default.removeObserver(self)
    }

    private func configurePanel() {
        panel.ignoresMouseEvents = true
        panel.contentView = TrackingContainerView()
        panel.contentView?.wantsLayer = true
        panel.contentView?.layer?.backgroundColor = NSColor.clear.cgColor
        panel.contentView?.addSubview(hostingView)
        panel.orderFrontRegardless()

        if let trackingView = panel.contentView as? TrackingContainerView {
            trackingView.onMouseEntered = { [weak self] in
                self?.show()
            }
            trackingView.onMouseExited = { [weak self] in
                self?.hideIfOutsideOpenPanel()
            }
        }
    }

    private func configureSensorPanel() {
        let trackingView = TrackingContainerView()
        trackingView.onMouseEntered = { [weak self] in
            self?.show()
        }
        trackingView.onMouseExited = nil

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
    }

    @objc
    private func handleScreenChange() {
        refreshLayout()
        Task { @MainActor in
            await calendarManager.refreshEvents(using: preferences)
            progressModel.refreshSnapshot()
        }
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

        if settingsPopover.contentViewController !== settingsContentController {
            settingsPopover.behavior = .transient
            settingsPopover.animates = true
            settingsPopover.contentSize = NSSize(width: 320, height: 300)
            settingsPopover.contentViewController = settingsContentController
        }

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
        sensorPanel.ignoresMouseEvents = true
        panel.ignoresMouseEvents = false
        progressModel.setHoverVisible(true)
    }

    private func hideIfOutsideOpenPanel() {
        guard progressModel.isHoverVisible else { return }

        hideWorkItem?.cancel()
        let workItem = DispatchWorkItem { [weak self] in
            guard let self else { return }
            let mouseLocation = NSEvent.mouseLocation
            guard !self.panel.frame.insetBy(dx: -2, dy: -2).contains(mouseLocation) else { return }

            self.progressModel.setHoverVisible(false)
            self.panel.ignoresMouseEvents = true
            self.sensorPanel.ignoresMouseEvents = false
            (self.sensorPanel.contentView as? TrackingContainerView)?.updateTrackingAreas()
        }
        hideWorkItem = workItem
        DispatchQueue.main.asyncAfter(deadline: .now() + 0.08, execute: workItem)
    }
}
