import AppKit
import SwiftUI

struct NotchPanelView: View {
    @ObservedObject var progressModel: EventProgressModel
    let onSettingsTapped: () -> Void

    var body: some View {
        let isExpanded = progressModel.isHoverVisible

        ZStack(alignment: .top) {
            NotchSurface(isExpanded: isExpanded)
                .frame(
                    width: isExpanded ? ScreenHelper.panelWidth : ScreenHelper.collapsedWidth(),
                    height: isExpanded ? ScreenHelper.openNotchSize.height : ScreenHelper.closedHeight()
                )

            NotchContentView(progressModel: progressModel)
                .frame(width: ScreenHelper.panelWidth, height: ScreenHelper.openNotchSize.height)
                .opacity(isExpanded ? 1 : 0)
                .blur(radius: isExpanded ? 0 : 5)
                .scaleEffect(isExpanded ? 1 : 0.975, anchor: .top)
                .offset(y: isExpanded ? 0 : -7)
                .animation(.easeOut(duration: 0.16).delay(isExpanded ? 0.08 : 0), value: isExpanded)
        }
        .overlay(alignment: .topTrailing) {
            SettingsOrbButton(action: onSettingsTapped)
                .padding(.top, 18)
                .padding(.trailing, 20)
                .opacity(isExpanded ? 1 : 0)
                .scaleEffect(isExpanded ? 1 : 0.85, anchor: .topTrailing)
                .allowsHitTesting(isExpanded)
                .animation(.easeOut(duration: 0.16).delay(isExpanded ? 0.08 : 0), value: isExpanded)
        }
        .overlay(alignment: .bottom) {
            if let joinURL = progressModel.snapshot.joinURL {
                JoinButton(tint: progressModel.snapshot.tint) {
                    NSWorkspace.shared.open(joinURL)
                }
                .padding(.bottom, 16)
                .opacity(isExpanded ? 1 : 0)
                .scaleEffect(isExpanded ? 1 : 0.85, anchor: .bottom)
                .allowsHitTesting(isExpanded)
                .animation(.easeOut(duration: 0.16).delay(isExpanded ? 0.08 : 0), value: isExpanded)
            }
        }
        .frame(width: ScreenHelper.panelWidth, height: ScreenHelper.panelHeight, alignment: .top)
        .compositingGroup()
        .animation(.interactiveSpring(response: 0.42, dampingFraction: 0.86, blendDuration: 0.18), value: isExpanded)
    }
}

struct NotchContentView: View {
    @ObservedObject var progressModel: EventProgressModel

    var body: some View {
        let snapshot = progressModel.snapshot

        Group {
            switch snapshot.state {
            case .inProgress:
                InProgressContent(snapshot: snapshot, isVisible: progressModel.isHoverVisible)
            case .startingSoon, .upcomingToday, .upcomingLater, .emptyToday, .noCalendar, .accessRevoked:
                SecondaryContent(message: snapshot.secondaryMessage ?? "")
            }
        }
        .padding(.horizontal, 28)
        .padding(.top, 28)
        .padding(.bottom, 22)
        .frame(width: ScreenHelper.panelWidth, height: ScreenHelper.openNotchSize.height)
        .allowsHitTesting(false)
    }
}

private struct InProgressContent: View {
    let snapshot: EventProgressSnapshot
    let isVisible: Bool

    var body: some View {
        VStack(alignment: .leading, spacing: 18) {
            HStack(alignment: .firstTextBaseline, spacing: 12) {
                Text(snapshot.title)
                    .font(.system(size: 22, weight: .semibold, design: .rounded))
                    .lineLimit(1)
                    .foregroundStyle(.white)

                Spacer(minLength: 0)

                TimeRangeView(start: snapshot.startTimeLabel, end: snapshot.endTimeLabel)
            }

            VStack(alignment: .leading, spacing: 12) {
                AnimatedProgressBar(progress: snapshot.progress, tint: snapshot.tint, isAnimating: isVisible)
                .frame(maxWidth: .infinity)
                .frame(height: 13)

                HStack(spacing: 12) {
                    MetricLabel(titleKey: "Elapsed", value: snapshot.elapsedLabel)

                    Spacer(minLength: 0)

                    MetricLabel(titleKey: "Remaining", value: snapshot.remainingLabel)
                }
            }
        }
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
