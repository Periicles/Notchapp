import AppKit

final class NotchPanelWindow: NSPanel {
    override init(
        contentRect: NSRect,
        styleMask: NSWindow.StyleMask,
        backing: NSWindow.BackingStoreType,
        defer flag: Bool
    ) {
        super.init(
            contentRect: contentRect,
            styleMask: styleMask,
            backing: backing,
            defer: flag
        )

        isFloatingPanel = true
        isOpaque = false
        titleVisibility = .hidden
        titlebarAppearsTransparent = true
        backgroundColor = .clear
        isMovable = false
        collectionBehavior = [
            .canJoinAllSpaces,
            .stationary,
            .fullScreenAuxiliary,
            .ignoresCycle,
        ]
        isReleasedWhenClosed = false
        // Sit at the shielding level (above the menu bar) rather than .statusBar.
        // .canJoinAllSpaces + .stationary keep the panel on every Space and out of
        // Mission Control, but at .statusBar the interactive desktop-switch gesture
        // still drags the panel along with the sliding Space. The shielding level is
        // treated as fixed system UI, so the notch stays pinned across Space switches.
        level = NSWindow.Level(rawValue: Int(CGShieldingWindowLevel()))
        hasShadow = false
        hidesOnDeactivate = false
    }

    override var canBecomeKey: Bool { false }
    override var canBecomeMain: Bool { false }
}
