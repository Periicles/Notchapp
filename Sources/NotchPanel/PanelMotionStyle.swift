import CoreGraphics
import SwiftUI

/// Presentation values for the notch panel's open/close transition, resolved
/// against the Reduce Motion accessibility setting.
///
/// With motion enabled the panel springs open while its content scales, offsets
/// and unblurs in a short staggered fade. Under Reduce Motion it crossfades in
/// place instead: no scale, offset or blur, a plain short fade rather than the
/// spring, and the progress bar's shimmer is frozen. Keeping the decision here
/// gives the views (and the tests) a single source of truth.
struct PanelMotionStyle: Equatable {
    let collapsedScale: CGFloat
    let collapsedOffsetY: CGFloat
    let collapsedBlur: CGFloat
    let accessoryCollapsedScale: CGFloat
    let shimmerEnabled: Bool
    let usesSpring: Bool
    let popoverAnimates: Bool
    let fadeDuration: Double
    let openStaggerDelay: Double

    init(reduceMotion: Bool) {
        collapsedScale = reduceMotion ? 1 : 0.975
        collapsedOffsetY = reduceMotion ? 0 : -7
        collapsedBlur = reduceMotion ? 0 : 5
        accessoryCollapsedScale = reduceMotion ? 1 : 0.85
        shimmerEnabled = !reduceMotion
        usesSpring = !reduceMotion
        popoverAnimates = !reduceMotion
        fadeDuration = reduceMotion ? 0.10 : 0.16
        openStaggerDelay = reduceMotion ? 0 : 0.08
    }

    /// The expand/collapse animation for the panel container.
    var containerAnimation: Animation {
        usesSpring
            ? .interactiveSpring(response: 0.42, dampingFraction: 0.86, blendDuration: 0.18)
            : .easeOut(duration: fadeDuration)
    }

    /// The fade/scale/offset animation for content and accessories, staggered on open.
    func contentAnimation(isExpanded: Bool) -> Animation {
        .easeOut(duration: fadeDuration).delay(isExpanded ? openStaggerDelay : 0)
    }
}
