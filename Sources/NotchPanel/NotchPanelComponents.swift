import AppKit
import SwiftUI

struct AnimatedProgressBar: View {
    let progress: Double
    let tint: Color
    let isAnimating: Bool

    var body: some View {
        TimelineView(.animation(minimumInterval: 1 / 60, paused: !isAnimating)) { timeline in
            GeometryReader { geo in
                let width = geo.size.width
                let fillWidth = max(16, width * progress)
                let phase = timeline.date.timeIntervalSinceReferenceDate.truncatingRemainder(dividingBy: 1.7) / 1.7
                let highlightWidth = max(44, fillWidth * 0.32)
                let travel = fillWidth + highlightWidth * 2
                let highlightX = CGFloat(phase) * travel - highlightWidth

                ZStack(alignment: .leading) {
                    Capsule()
                        .fill(Color.white.opacity(0.11))

                    Capsule()
                        .fill(
                            LinearGradient(
                                colors: [
                                    tint.opacity(0.95),
                                    tint.opacity(0.68),
                                ],
                                startPoint: .leading,
                                endPoint: .trailing
                            )
                        )
                        .frame(width: fillWidth)
                        .overlay(alignment: .leading) {
                            LinearGradient(
                                stops: [
                                    .init(color: .white.opacity(0), location: 0),
                                    .init(color: .white.opacity(0.34), location: 0.5),
                                    .init(color: .white.opacity(0), location: 1),
                                ],
                                startPoint: .leading,
                                endPoint: .trailing
                            )
                            .frame(width: highlightWidth)
                            .offset(x: highlightX)
                            .blendMode(.screen)
                        }
                        .clipShape(Capsule())
                }
            }
        }
    }
}

struct TimeRangeView: View {
    let start: String
    let end: String

    var body: some View {
        HStack(spacing: 8) {
            Text(start)
            Text("-")
                .foregroundStyle(.white.opacity(0.38))
            Text(end)
        }
        .font(.system(size: 15, weight: .semibold, design: .rounded))
        .monospacedDigit()
        .foregroundStyle(.white.opacity(0.78))
    }
}

struct MetricLabel: View {
    let titleKey: LocalizedStringKey
    let value: String

    var body: some View {
        HStack(spacing: 7) {
            Text(titleKey, bundle: .module)
                .foregroundStyle(.white.opacity(0.42))
            Text(value.isEmpty ? "--:--:--" : value)
                .monospacedDigit()
                .foregroundStyle(.white.opacity(0.78))
        }
        .font(.system(size: 14, weight: .medium, design: .rounded))
    }
}

struct NotchSurface: View {
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

        }
        .drawingGroup()
    }
}

struct NotchShellShape: InsettableShape {
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

struct SettingsOrbButton: View {
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

struct JoinButton: View {
    let tint: Color
    let action: () -> Void

    var body: some View {
        Button(action: action) {
            HStack(spacing: 6) {
                Image(systemName: "video.fill")
                    .font(.system(size: 12, weight: .bold))
                Text("Join", bundle: .module)
                    .font(.system(size: 13, weight: .semibold, design: .rounded))
            }
            .foregroundStyle(.white)
            .padding(.horizontal, 14)
            .padding(.vertical, 7)
            .background(Capsule().fill(tint.opacity(0.35)))
            .overlay(Capsule().strokeBorder(tint.opacity(0.55), lineWidth: 1))
        }
        .buttonStyle(.plain)
    }
}
