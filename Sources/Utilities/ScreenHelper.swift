import AppKit

enum ScreenHelper {
    static let panelWidth: CGFloat = 620
    static let panelHeight: CGFloat = 132
    static let panelTopBleed: CGFloat = 10
    static let collapsedPadding: CGFloat = 24
    private static let fallbackNotchWidth: CGFloat = 200
    private static let fallbackMenuBarHeight: CGFloat = 38
    private static let sensorExtraWidth: CGFloat = 92
    private static let sensorExtraHeight: CGFloat = 24

    static func panelRect() -> NSRect {
        let frame = physicalNotchRect()
        return NSRect(
            x: frame.midX - panelWidth / 2,
            y: frame.maxY - panelHeight + panelTopBleed,
            width: panelWidth,
            height: panelHeight
        )
    }

    static func sensorRect() -> NSRect {
        let frame = physicalNotchRect()
        let width = collapsedWidth() + sensorExtraWidth
        let height = closedHeight() + sensorExtraHeight

        return NSRect(
            x: frame.midX - width / 2,
            y: frame.maxY - height,
            width: width,
            height: height
        )
    }

    static func collapsedWidth() -> CGFloat {
        min(panelWidth * 0.42, inferredNotchWidth(for: preferredScreen()) + collapsedPadding)
    }

    static func closedHeight() -> CGFloat {
        min(panelHeight * 0.48, physicalNotchRect().height + 18)
    }

    private static func physicalNotchRect() -> NSRect {
        let screen = preferredScreen()
        let menuBarHeight = screen.frame.height - screen.visibleFrame.height - screen.visibleFrame.origin.y
        let notchHeight = max(menuBarHeight, fallbackMenuBarHeight)
        let notchWidth = inferredNotchWidth(for: screen)

        return NSRect(
            x: screen.frame.midX - notchWidth / 2,
            y: screen.frame.maxY - notchHeight,
            width: notchWidth,
            height: notchHeight
        )
    }

    private static func preferredScreen() -> NSScreen {
        NSScreen.screens.first(where: isBuiltInDisplay) ?? NSScreen.main ?? NSScreen.screens[0]
    }

    private static func isBuiltInDisplay(screen: NSScreen) -> Bool {
        guard let deviceDescription = screen.deviceDescription[NSDeviceDescriptionKey("NSScreenNumber")] as? CGDirectDisplayID else {
            return false
        }

        return CGDisplayIsBuiltin(deviceDescription) != 0
    }

    private static func inferredNotchWidth(for screen: NSScreen) -> CGFloat {
        if #available(macOS 12.0, *),
           let left = screen.auxiliaryTopLeftArea,
           let right = screen.auxiliaryTopRightArea {
            return max(screen.frame.width - left.width - right.width, fallbackNotchWidth)
        }

        return fallbackNotchWidth
    }
}
