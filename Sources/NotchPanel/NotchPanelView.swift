import AppKit
import SwiftUI

struct NotchPanelView: View {
    @ObservedObject var progressModel: EventProgressModel
    @Environment(\.accessibilityReduceMotion) private var reduceMotion
    let onSettingsTapped: () -> Void

    var body: some View {
        let isExpanded = progressModel.isHoverVisible
        let motion = PanelMotionStyle(reduceMotion: reduceMotion)

        ZStack(alignment: .top) {
            // Invisible at rest: on a notched Mac the physical notch already shows
            // through, and with nothing drawn there is no overlay layer for the
            // interactive Space-switch gesture to slide along with the desktop.
            // The surface fades/grows in only while the panel is open.
            NotchSurface(isExpanded: isExpanded)
                .frame(
                    width: isExpanded ? ScreenHelper.panelWidth : ScreenHelper.collapsedWidth(),
                    height: isExpanded ? ScreenHelper.openNotchSize.height : ScreenHelper.closedHeight()
                )
                .opacity(isExpanded ? 1 : 0)

            NotchContentView(progressModel: progressModel, shimmerEnabled: motion.shimmerEnabled)
                .frame(width: ScreenHelper.panelWidth, height: ScreenHelper.openNotchSize.height)
                .opacity(isExpanded ? 1 : 0)
                .blur(radius: isExpanded ? 0 : motion.collapsedBlur)
                .scaleEffect(isExpanded ? 1 : motion.collapsedScale, anchor: .top)
                .offset(y: isExpanded ? 0 : motion.collapsedOffsetY)
                .animation(motion.contentAnimation(isExpanded: isExpanded), value: isExpanded)
        }
        .overlay(alignment: .top) {
            // Sits just below the closed notch, the only place a line reads as
            // belonging to it rather than floating on the desktop.
            if !isExpanded, let progress = progressModel.restingProgress {
                RestingProgressLineView(progress: progress, tint: progressModel.snapshot.tint)
                    .frame(width: ScreenHelper.collapsedWidth())
                    .offset(y: ScreenHelper.closedHeight())
                    .allowsHitTesting(false)
            }
        }
        .overlay(alignment: .topTrailing) {
            SettingsOrbButton(action: onSettingsTapped)
                .padding(.top, NotchPanelMetrics.orbTopPadding)
                .padding(.trailing, NotchPanelMetrics.orbTrailingPadding)
                .opacity(isExpanded ? 1 : 0)
                .scaleEffect(isExpanded ? 1 : motion.accessoryCollapsedScale, anchor: .topTrailing)
                .allowsHitTesting(isExpanded)
                .animation(motion.contentAnimation(isExpanded: isExpanded), value: isExpanded)
        }
        .overlay(alignment: .bottom) {
            if let joinURL = progressModel.snapshot.joinURL {
                JoinButton(tint: progressModel.snapshot.tint) {
                    NSWorkspace.shared.open(joinURL)
                }
                .padding(.bottom, 16)
                .opacity(isExpanded ? 1 : 0)
                .scaleEffect(isExpanded ? 1 : motion.accessoryCollapsedScale, anchor: .bottom)
                .allowsHitTesting(isExpanded)
                .animation(motion.contentAnimation(isExpanded: isExpanded), value: isExpanded)
            }
        }
        .frame(width: ScreenHelper.panelWidth, height: ScreenHelper.panelHeight, alignment: .top)
        .compositingGroup()
        .animation(motion.containerAnimation, value: isExpanded)
    }
}

struct NotchContentView: View {
    @ObservedObject var progressModel: EventProgressModel
    let shimmerEnabled: Bool

    var body: some View {
        let snapshot = progressModel.snapshot

        Group {
            switch snapshot.state {
            case .inProgress, .onBreak:
                InProgressContent(
                    snapshot: snapshot,
                    isAnimating: progressModel.isHoverVisible && shimmerEnabled
                )
            case .startingSoon, .upcomingToday, .upcomingLater, .emptyToday, .noCalendar, .accessRevoked:
                SecondaryContent(message: snapshot.secondaryMessage ?? "")
            }
        }
        .padding(.horizontal, NotchPanelMetrics.contentHorizontalPadding)
        .padding(.top, 28)
        .padding(.bottom, 22)
        .frame(width: ScreenHelper.panelWidth, height: ScreenHelper.openNotchSize.height)
        .allowsHitTesting(false)
    }
}

private struct InProgressContent: View {
    let snapshot: EventProgressSnapshot
    let isAnimating: Bool

    var body: some View {
        VStack(alignment: .leading, spacing: 18) {
            HStack(alignment: .firstTextBaseline, spacing: 12) {
                Text(snapshot.title)
                    .font(.system(size: 22, weight: .semibold, design: .rounded))
                    .lineLimit(1)
                    .foregroundStyle(.white)

                if snapshot.concurrentEventCount > 0 {
                    Text(verbatim: "+\(snapshot.concurrentEventCount)")
                        .font(.system(size: 15, weight: .semibold, design: .rounded))
                        .foregroundStyle(.white.opacity(0.42))
                        .fixedSize()
                }

                Spacer(minLength: 0)

                TimeRangeView(start: snapshot.startTimeLabel, end: snapshot.endTimeLabel)
            }
            .padding(.trailing, NotchPanelMetrics.contentTrailingClearance)

            VStack(alignment: .leading, spacing: 12) {
                AnimatedProgressBar(progress: snapshot.progress, tint: snapshot.tint, isAnimating: isAnimating)
                .frame(maxWidth: .infinity)
                .frame(height: 13)

                HStack(spacing: 8) {
                    MetricLabel(titleKey: "Elapsed", value: snapshot.elapsedLabel)
                        .fixedSize()

                    Spacer(minLength: 0)

                    if let nextEvent = snapshot.nextEvent {
                        // Ahead of the spacers, which otherwise claim the room
                        // the title needs and truncate even a short one.
                        NextEventLabel(nextEvent: nextEvent)
                            .layoutPriority(1)

                        Spacer(minLength: 0)
                    }

                    MetricLabel(titleKey: "Remaining", value: snapshot.remainingLabel)
                        .fixedSize()
                }
            }
        }
    }
}

/// `→ <title> <time>`: only the title gives way when space runs out. An arrow
/// rather than a word, because the row already carries two labelled metrics.
private struct NextEventLabel: View {
    let nextEvent: EventProgressSnapshot.NextEvent

    var body: some View {
        HStack(spacing: 4) {
            Image(systemName: "arrow.right")
                .font(.system(size: 10, weight: .bold))
                .foregroundStyle(.white.opacity(0.42))
                .accessibilityLabel(Text("Then:", bundle: Localized.resources))
            Text(nextEvent.title)
                .lineLimit(1)
                .foregroundStyle(.white.opacity(0.78))
            Text(nextEvent.startTimeLabel)
                .monospacedDigit()
                .foregroundStyle(.white.opacity(0.78))
                .fixedSize()
        }
        .font(.system(size: 13, weight: .medium, design: .rounded))
    }
}

private struct SecondaryContent: View {
    let message: String

    var body: some View {
        VStack {
            Spacer(minLength: 0)
            Text(message)
                .font(.system(size: 17, weight: .medium, design: .rounded))
                .foregroundStyle(.white.opacity(0.78))
                .multilineTextAlignment(.center)
                .lineLimit(3)
                .padding(.trailing, 46)
            Spacer(minLength: 0)
        }
        .frame(maxWidth: .infinity, maxHeight: .infinity)
    }
}
