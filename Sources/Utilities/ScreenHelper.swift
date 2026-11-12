import AppKit

enum ScreenHelper {
    // Deployed (hover-expanded) panel width, 25% smaller than the original 640×190.
    static let panelWidth: CGFloat = 480
    /// How far the panel window pokes above the top of the screen.
    static let panelTopBleed: CGFloat = 2
    private static let closedNotchFallbackSize = CGSize(width: 185, height: 32)

    /// Deployed panel height. It follows the screen's notch height: the content
    /// area keeps a fixed size and the window grows by whatever the notch takes.
    static var panelHeight: CGFloat {
        NotchPanelMetrics.panelHeight(notchHeight: closedHeight(), topBleed: panelTopBleed)
    }

    /// Inset the open panel's content keeps from the window's top so that it
    /// starts below the notch rather than being cut by it.
    static var contentTopInset: CGFloat {
        NotchPanelMetrics.contentTopInset(notchHeight: closedHeight(), topBleed: panelTopBleed)
    }

    static func panelRect() -> NSRect {
        let screenFrame = preferredScreen().frame
        return NSRect(
            x: screenFrame.midX - panelWidth / 2,
            y: screenFrame.maxY - panelHeight + panelTopBleed,
            width: panelWidth,
            height: panelHeight
        )
    }

    static func sensorRect() -> NSRect {
        let closedRect = closedNotchRect()

        return NSRect(
            x: closedRect.minX,
            y: closedRect.minY,
            width: closedRect.width,
            height: closedRect.height
        )
    }

    /// How far the physical notch's centre sits right of the screen's centre.
    /// The two menu bar areas on either side are rarely the same width, so the
    /// notch is off-centre by a fraction of a point — enough to open a visible
    /// gap on one side of anything drawn tight around it.
    static func notchCenterOffset() -> CGFloat {
        let screen = preferredScreen()
        guard let topLeftArea = screen.auxiliaryTopLeftArea,
              let topRightArea = screen.auxiliaryTopRightArea else {
            return 0
        }
        return (topLeftArea.maxX + topRightArea.minX) / 2 - screen.frame.midX
    }

    static func collapsedWidth() -> CGFloat {
        closedNotchSize().width
    }

    static func closedHeight() -> CGFloat {
        closedNotchSize().height
    }

    private static func closedNotchRect() -> NSRect {
        let screen = preferredScreen()
        let closedSize = closedNotchSize(for: screen)

        return NSRect(
            x: screen.frame.midX - closedSize.width / 2,
            y: screen.frame.maxY - closedSize.height,
            width: closedSize.width,
            height: closedSize.height
        )
    }

    private static func closedNotchSize(for screen: NSScreen = preferredScreen()) -> CGSize {
        var width = closedNotchFallbackSize.width
        var height = closedNotchFallbackSize.height

        if let topLeftArea = screen.auxiliaryTopLeftArea,
           let topRightArea = screen.auxiliaryTopRightArea {
            width = screen.frame.width - topLeftArea.width - topRightArea.width
        }

        if screen.safeAreaInsets.top > 0 {
            height = screen.safeAreaInsets.top
        } else {
            height = max(closedNotchFallbackSize.height, screen.frame.maxY - screen.visibleFrame.maxY)
        }

        return CGSize(
            width: max(width, closedNotchFallbackSize.width),
            height: max(height, closedNotchFallbackSize.height)
        )
    }

    private static func preferredScreen() -> NSScreen {
        NSScreen.screens.first(where: isBuiltInDisplay) ?? NSScreen.main ?? NSScreen.screens[0]
    }

    private static func isBuiltInDisplay(screen: NSScreen) -> Bool {
        let key = NSDeviceDescriptionKey("NSScreenNumber")
        guard let displayID = screen.deviceDescription[key] as? CGDirectDisplayID else {
            return false
        }
        return CGDisplayIsBuiltin(displayID) != 0
    }
}
