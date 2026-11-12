import CoreGraphics

/// Geometry shared by the notch panel's content and the settings orb drawn on
/// top of it.
///
/// The orb lives in a `.overlay(alignment: .topTrailing)`, so it paints over
/// whatever the content puts in that corner — the event's time range, on the
/// in-progress layout. Nothing in SwiftUI reserves that space automatically:
/// the content has to inset itself by `contentTrailingClearance`. Deriving that
/// inset from the orb's own size here is what keeps the two from drifting apart
/// the next time either is retuned.
enum NotchPanelMetrics {
    /// Diameter of the settings orb's circular background.
    static let orbDiameter: CGFloat = 26
    /// Point size of the gear glyph inside the orb.
    static let orbIconSize: CGFloat = 12
    static let orbTopPadding: CGFloat = 18
    static let orbTrailingPadding: CGFloat = 20

    /// Horizontal inset applied to the panel's content.
    static let contentHorizontalPadding: CGFloat = 28

    /// Breathing room kept between the orb and any content drawn beside it.
    static let orbClearanceGap: CGFloat = 8

    /// Extra trailing inset a content row sharing the orb's line must add on top
    /// of `contentHorizontalPadding` to stay clear of it.
    static let contentTrailingClearance: CGFloat =
        orbTrailingPadding + orbDiameter + orbClearanceGap - contentHorizontalPadding

    /// Gap actually left between the content's trailing edge and the orb's
    /// leading edge. Independent of the panel width: both are measured from the
    /// trailing edge, so it cancels out.
    static var effectiveOrbClearance: CGFloat {
        (contentHorizontalPadding + contentTrailingClearance) - (orbTrailingPadding + orbDiameter)
    }

    // MARK: - Vertical layout around the physical notch
    //
    // The panel window starts `topBleed` above the screen, and the notch is a
    // hardware cut-out: anything drawn inside it simply is not displayed. Content
    // therefore has to start below `notchBottomEdge`, which depends on the
    // screen's real notch height — a fixed top padding is only right on one Mac.

    /// Space kept between the notch's lower edge and the content under it.
    static let notchContentGap: CGFloat = 6

    /// Height of the content area below the notch: title row, progress bar,
    /// metrics row and the bottom padding. Fixed, so the layout reads the same
    /// whatever the notch height; only the room above it grows.
    static let contentAreaHeight: CGFloat = 115

    /// Distance from the window's top edge down to the notch's lower edge.
    static func notchBottomEdge(notchHeight: CGFloat, topBleed: CGFloat) -> CGFloat {
        topBleed + notchHeight
    }

    /// Inset the open panel's content must keep from the window's top edge.
    static func contentTopInset(notchHeight: CGFloat, topBleed: CGFloat) -> CGFloat {
        notchBottomEdge(notchHeight: notchHeight, topBleed: topBleed) + notchContentGap
    }

    /// Height of the open panel's window for a notch of `notchHeight`.
    static func panelHeight(notchHeight: CGFloat, topBleed: CGFloat) -> CGFloat {
        contentTopInset(notchHeight: notchHeight, topBleed: topBleed) + contentAreaHeight
    }

    // MARK: - Outline hugging the notch
    //
    // macOS exposes the notch's bounding box, never its shape, so the two radii
    // are calibrated by eye rather than read from the screen.

    /// Radius of the flare where the notch meets the top of the screen.
    static let notchOutlineTopRadius: CGFloat = 6

    /// Radius of the notch's lower corners, measured on the stroke's centre line.
    static let notchOutlineBottomRadius: CGFloat = 15

    /// How much narrower the physical notch is, per side, than the width the
    /// screen's menu bar areas report. Measured on a photo of the screen: without
    /// it the stroke floats about a point off each side.
    static let notchOutlineSideInset: CGFloat = 0.5

    /// Size of the outline's box. The stroke is centred half a line width outside
    /// the notch so that the notch hides none of it; the box starts at the top of
    /// the screen and ends at the stroke's lower centre line.
    static func notchOutlineSize(notchSize: CGSize, lineWidth: CGFloat) -> CGSize {
        CGSize(
            width: notchSize.width - 2 * notchOutlineSideInset + lineWidth + 2 * notchOutlineTopRadius,
            height: notchSize.height + lineWidth / 2
        )
    }
}
