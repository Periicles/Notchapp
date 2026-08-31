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
}
