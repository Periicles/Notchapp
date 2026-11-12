import AppKit
import SwiftUI

struct NotchPanelView: View {
    @ObservedObject var progressModel: EventProgressModel
    @Environment(\.accessibilityReduceMotion) private var reduceMotion
    // Bumped when the display configuration changes. The geometry below is read
    // from the screen on every evaluation, but nothing else invalidates this
    // body when only the notch height changes (e.g. another scaled resolution).
    @State private var screenRevision = 0
    let onSettingsTapped: () -> Void

    var body: some View {
        let isExpanded = progressModel.isHoverVisible
        let motion = PanelMotionStyle(reduceMotion: reduceMotion)
        let panelHeight = ScreenHelper.panelHeight

        ZStack(alignment: .top) {
            // Invisible at rest: on a notched Mac the physical notch already shows
            // through, and with nothing drawn there is no overlay layer for the
            // interactive Space-switch gesture to slide along with the desktop.
            // The surface fades/grows in only while the panel is open.
            NotchSurface(isExpanded: isExpanded)
                .frame(
                    width: isExpanded ? ScreenHelper.panelWidth : ScreenHelper.collapsedWidth(),
                    height: isExpanded ? panelHeight : ScreenHelper.closedHeight()
                )
                .opacity(isExpanded ? 1 : 0)

            NotchContentView(
                progressModel: progressModel,
                shimmerEnabled: motion.shimmerEnabled,
                topInset: ScreenHelper.contentTopInset,
                height: panelHeight
            )
                .frame(width: ScreenHelper.panelWidth, height: panelHeight)
                .opacity(isExpanded ? 1 : 0)
                .blur(radius: isExpanded ? 0 : motion.collapsedBlur)
                .scaleEffect(isExpanded ? 1 : motion.collapsedScale, anchor: .top)
                .offset(y: isExpanded ? 0 : motion.collapsedOffsetY)
                .animation(motion.contentAnimation(isExpanded: isExpanded), value: isExpanded)
        }
        .overlay(alignment: .top) {
            // Wraps the closed notch, the only place a line reads as belonging
            // to it rather than floating on the desktop.
            if !isExpanded, let progress = progressModel.restingProgress {
                let outlineSize = NotchPanelMetrics.notchOutlineSize(
                    notchSize: CGSize(width: ScreenHelper.collapsedWidth(), height: ScreenHelper.closedHeight()),
                    lineWidth: RestingProgressLine.height
                )
                RestingProgressLineView(progress: progress, tint: progressModel.snapshot.tint)
                    .frame(width: outlineSize.width, height: outlineSize.height)
                    .offset(x: ScreenHelper.notchCenterOffset(), y: ScreenHelper.panelTopBleed)
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
        .frame(width: ScreenHelper.panelWidth, height: panelHeight, alignment: .top)
        .compositingGroup()
        .animation(motion.containerAnimation, value: isExpanded)
        .onReceive(screenChanges) { _ in
            screenRevision &+= 1
        }
    }

    private var screenChanges: NotificationCenter.Publisher {
        NotificationCenter.default.publisher(for: NSApplication.didChangeScreenParametersNotification)
    }
}

struct NotchContentView: View {
    @ObservedObject var progressModel: EventProgressModel
    let shimmerEnabled: Bool
    /// Distance from the top of the window to where the content may start: the
    /// notch's lower edge plus a small gap. Anything above it is cut by the notch.
    let topInset: CGFloat
    let height: CGFloat

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
                SecondaryContent(
                    message: snapshot.secondaryMessage ?? "",
                    allDayMessage: snapshot.allDayMessage
                )
            }
        }
        .padding(.horizontal, NotchPanelMetrics.contentHorizontalPadding)
        .padding(.top, topInset)
        .padding(.bottom, 22)
        .frame(width: ScreenHelper.panelWidth, height: height)
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
    var allDayMessage: String?

    var body: some View {
        VStack(spacing: 6) {
            Spacer(minLength: 0)
            Text(message)
                .font(.system(size: 17, weight: .medium, design: .rounded))
                .foregroundStyle(.white.opacity(0.78))
                .multilineTextAlignment(.center)
                .lineLimit(2)
                .padding(.trailing, 46)

            if let allDayMessage {
                Text(allDayMessage)
                    .font(.system(size: 13, weight: .medium, design: .rounded))
                    .foregroundStyle(.white.opacity(0.45))
                    .multilineTextAlignment(.center)
                    .lineLimit(1)
                    .padding(.trailing, 46)
            }
            Spacer(minLength: 0)
        }
        .frame(maxWidth: .infinity, maxHeight: .infinity)
    }
}
