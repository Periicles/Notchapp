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
        let screenFrame = preferredScreen()?.frame ?? fallbackScreenFrame
        return NSRect(
            x: screenFrame.midX - panelWidth / 2,
            y: screenFrame.maxY - panelHeight + panelTopBleed,
            width: panelWidth,
            height: panelHeight
        )
    }

    static func sensorRect() -> NSRect {
        closedNotchRect()
    }

    /// How far the physical notch's centre sits right of the screen's centre.
    /// The two menu bar areas on either side are rarely the same width, so the
    /// notch is off-centre by a fraction of a point — enough to open a visible
    /// gap on one side of anything drawn tight around it.
    static func notchCenterOffset() -> CGFloat {
        guard let screen = preferredScreen(),
              let topLeftArea = screen.auxiliaryTopLeftArea,
              let topRightArea = screen.auxiliaryTopRightArea else {
            return 0
        }
        return centerOffset(
            leftAreaMaxX: topLeftArea.maxX,
            rightAreaMinX: topRightArea.minX,
            screenMidX: screen.frame.midX
        )
    }

    static func collapsedWidth() -> CGFloat {
        closedNotchSize().width
    }

    static func closedHeight() -> CGFloat {
        closedNotchSize().height
    }

    // MARK: - Pure geometry

    /// The notch is whatever the two menu bar areas leave between them; a screen
    /// without a notch (or too small a result) gets the fallback so the panel
    /// still has something to hang from.
    static func notchSize(
        screenWidth: CGFloat,
        leftAreaWidth: CGFloat?,
        rightAreaWidth: CGFloat?,
        safeAreaTop: CGFloat,
        menuBarHeight: CGFloat
    ) -> CGSize {
        var width = closedNotchFallbackSize.width
        if let leftAreaWidth, let rightAreaWidth {
            width = screenWidth - leftAreaWidth - rightAreaWidth
        }

        let height = safeAreaTop > 0 ? safeAreaTop : menuBarHeight

        return CGSize(
            width: max(width, closedNotchFallbackSize.width),
            height: max(height, closedNotchFallbackSize.height)
        )
    }

    static func centerOffset(leftAreaMaxX: CGFloat, rightAreaMinX: CGFloat, screenMidX: CGFloat) -> CGFloat {
        (leftAreaMaxX + rightAreaMinX) / 2 - screenMidX
    }

    // MARK: - Screen lookup

    private static let fallbackScreenFrame = NSRect(x: 0, y: 0, width: 1512, height: 982)

    private static func closedNotchRect() -> NSRect {
        let screenFrame = preferredScreen()?.frame ?? fallbackScreenFrame
        let closedSize = closedNotchSize()

        return NSRect(
            x: screenFrame.midX - closedSize.width / 2,
            y: screenFrame.maxY - closedSize.height,
            width: closedSize.width,
            height: closedSize.height
        )
    }

    private static func closedNotchSize() -> CGSize {
        guard let screen = preferredScreen() else { return closedNotchFallbackSize }

        return notchSize(
            screenWidth: screen.frame.width,
            leftAreaWidth: screen.auxiliaryTopLeftArea?.width,
            rightAreaWidth: screen.auxiliaryTopRightArea?.width,
            safeAreaTop: screen.safeAreaInsets.top,
            menuBarHeight: screen.frame.maxY - screen.visibleFrame.maxY
        )
    }

    /// `nil` only when no display is attached, as on a headless machine.
    private static func preferredScreen() -> NSScreen? {
        NSScreen.screens.first(where: isBuiltInDisplay) ?? NSScreen.main ?? NSScreen.screens.first
    }

    private static func isBuiltInDisplay(screen: NSScreen) -> Bool {
        let key = NSDeviceDescriptionKey("NSScreenNumber")
        guard let displayID = screen.deviceDescription[key] as? CGDirectDisplayID else {
            return false
        }
        return CGDisplayIsBuiltin(displayID) != 0
    }
}
