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
                    height: isExpanded ? ScreenHelper.panelHeight : ScreenHelper.closedHeight()
                )
                .shadow(color: .black.opacity(isExpanded ? 0.34 : 0.22), radius: isExpanded ? 22 : 10, y: isExpanded ? 10 : 4)

            NotchContentView(progressModel: progressModel)
                .frame(width: ScreenHelper.panelWidth, height: ScreenHelper.panelHeight)
                .opacity(isExpanded ? 1 : 0)
                .blur(radius: isExpanded ? 0 : 5)
                .scaleEffect(isExpanded ? 1 : 0.975, anchor: .top)
                .offset(y: isExpanded ? 0 : -7)
                .animation(.easeOut(duration: 0.16).delay(isExpanded ? 0.08 : 0), value: isExpanded)
        }
        .overlay(alignment: .topTrailing) {
            if isExpanded {
                SettingsOrbButton(action: onSettingsTapped)
                    .padding(.top, 18)
                    .padding(.trailing, 20)
                    .transition(.asymmetric(insertion: .scale(scale: 0.85).combined(with: .opacity), removal: .opacity))
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

        VStack(alignment: .leading, spacing: 16) {
            HStack(alignment: .firstTextBaseline, spacing: 12) {
                Text(snapshot.title)
                    .font(.system(size: 22, weight: .semibold, design: .rounded))
                    .lineLimit(1)
                    .foregroundStyle(.white)

                Spacer(minLength: 0)

                if snapshot.state == .inProgress {
                    Text(snapshot.trailingLabel)
                        .font(.system(size: 20, weight: .semibold, design: .rounded))
                        .monospacedDigit()
                        .foregroundStyle(.white.opacity(0.84))
                } else {
                    Text(snapshot.trailingLabel)
                        .font(.system(size: 16, weight: .medium, design: .rounded))
                        .foregroundStyle(.white.opacity(0.72))
                }
            }
            .padding(.trailing, 46)

            VStack(alignment: .leading, spacing: 10) {
                GeometryReader { geo in
                    ZStack(alignment: .leading) {
                        Capsule()
                            .fill(Color.white.opacity(0.11))
                            .frame(height: 9)

                        Capsule()
                            .fill(
                                LinearGradient(
                                    colors: [
                                        snapshot.tint.opacity(0.95),
                                        snapshot.tint.opacity(0.68),
                                    ],
                                    startPoint: .leading,
                                    endPoint: .trailing
                                )
                            )
                            .frame(width: max(12, geo.size.width * snapshot.progress), height: 9)
                    }
                }
                .frame(maxWidth: .infinity)
                .frame(height: 9)

                HStack(spacing: 12) {
                    Text(snapshot.elapsedLabel)
                        .font(.system(size: 14, weight: .medium, design: .rounded))
                        .foregroundStyle(.white.opacity(0.56))

                    Spacer(minLength: 0)

                    Text(snapshot.statusLabel)
                        .font(.system(size: 14, weight: .medium, design: .rounded))
                        .foregroundStyle(.white.opacity(0.72))
                }
            }
        }
        .padding(.horizontal, 28)
        .padding(.top, 28)
        .padding(.bottom, 22)
        .frame(width: ScreenHelper.panelWidth, height: ScreenHelper.panelHeight)
        .allowsHitTesting(false)
    }
}

private struct NotchSurface: View {
    let isExpanded: Bool

    var body: some View {
        ZStack {
            NotchShellShape(cornerRadius: isExpanded ? 34 : 24)
                .fill(
                    LinearGradient(
                        colors: [
                            Color.black.opacity(0.98),
                            Color(red: 0.025, green: 0.025, blue: 0.03).opacity(0.99),
                        ],
                        startPoint: .top,
                        endPoint: .bottom
                    )
                )

            NotchShellShape(cornerRadius: isExpanded ? 34 : 24)
                .strokeBorder(.white.opacity(isExpanded ? 0.07 : 0.04), lineWidth: 1)

            if isExpanded {
                VStack(spacing: 0) {
                    LinearGradient(
                        colors: [
                            .white.opacity(0.08),
                            .clear,
                        ],
                        startPoint: .top,
                        endPoint: .bottom
                    )
                    .frame(height: 34)

                    Spacer(minLength: 0)
                }
                .clipShape(NotchShellShape(cornerRadius: 34))
            }
        }
        .drawingGroup()
    }
}

private struct NotchShellShape: InsettableShape {
    var cornerRadius: CGFloat
    var insetAmount: CGFloat = 0

    var animatableData: AnimatablePair<CGFloat, CGFloat> {
        get { AnimatablePair(cornerRadius, insetAmount) }
        set {
            cornerRadius = newValue.first
            insetAmount = newValue.second
        }
    }

    func path(in rect: CGRect) -> Path {
        let rect = rect.insetBy(dx: insetAmount, dy: insetAmount)
        let radius = min(cornerRadius, rect.height / 2)

        var path = Path()
        path.move(to: CGPoint(x: rect.minX, y: rect.minY))
        path.addLine(to: CGPoint(x: rect.maxX, y: rect.minY))
        path.addLine(to: CGPoint(x: rect.maxX, y: rect.maxY - radius))
        path.addQuadCurve(
            to: CGPoint(x: rect.maxX - radius, y: rect.maxY),
            control: CGPoint(x: rect.maxX, y: rect.maxY)
        )
        path.addLine(to: CGPoint(x: rect.minX + radius, y: rect.maxY))
        path.addQuadCurve(
            to: CGPoint(x: rect.minX, y: rect.maxY - radius),
            control: CGPoint(x: rect.minX, y: rect.maxY)
        )
        path.closeSubpath()

        return path
    }

    func inset(by amount: CGFloat) -> Self {
        var copy = self
        copy.insetAmount += amount
        return copy
    }
}

private struct SettingsOrbButton: View {
    let action: () -> Void

    var body: some View {
        Button(action: action) {
            Image(systemName: "gearshape.fill")
                .font(.system(size: 14, weight: .bold))
                .foregroundStyle(.white.opacity(0.92))
                .frame(width: 32, height: 32)
                .background(
                    Circle()
                        .fill(Color.white.opacity(0.08))
                )
                .overlay(
                    Circle()
                        .strokeBorder(.white.opacity(0.08), lineWidth: 1)
                )
        }
        .buttonStyle(.plain)
    }
}
