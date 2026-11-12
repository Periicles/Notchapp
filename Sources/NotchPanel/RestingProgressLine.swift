import SwiftUI

/// The one thing NotchBar draws while the panel is closed, and only when asked:
/// a hairline under the notch filled with the running event's progress.
///
/// It is off by default because anything drawn at rest slides with the desktop
/// during an interactive Space switch — no window flag prevents that (see the
/// collapsed surface removed for the same reason).
enum RestingProgressLine {
    static let height: CGFloat = 4
    /// Blur radius of the neon halo around the filled part.
    static let glowRadius: CGFloat = 5

    /// The fraction to fill, or `nil` when nothing should be drawn.
    static func progress(for snapshot: EventProgressSnapshot, enabled: Bool) -> Double? {
        guard enabled else { return nil }

        switch snapshot.state {
        case .inProgress, .onBreak:
            return min(max(snapshot.progress, 0), 1)
        case .startingSoon, .upcomingToday, .upcomingLater, .emptyToday, .noCalendar, .accessRevoked:
            return nil
        }
    }
}

/// The open outline of the notch: a flare on each side where it meets the top of
/// the screen, straight sides, rounded lower corners. Open, so that nothing is
/// stroked along the screen edge.
struct NotchOutline: Shape {
    let topRadius: CGFloat
    let bottomRadius: CGFloat

    func path(in rect: CGRect) -> Path {
        var path = Path()
        path.move(to: CGPoint(x: rect.minX, y: rect.minY))
        path.addQuadCurve(
            to: CGPoint(x: rect.minX + topRadius, y: rect.minY + topRadius),
            control: CGPoint(x: rect.minX + topRadius, y: rect.minY)
        )
        path.addLine(to: CGPoint(x: rect.minX + topRadius, y: rect.maxY - bottomRadius))
        path.addQuadCurve(
            to: CGPoint(x: rect.minX + topRadius + bottomRadius, y: rect.maxY),
            control: CGPoint(x: rect.minX + topRadius, y: rect.maxY)
        )
        path.addLine(to: CGPoint(x: rect.maxX - topRadius - bottomRadius, y: rect.maxY))
        path.addQuadCurve(
            to: CGPoint(x: rect.maxX - topRadius, y: rect.maxY - bottomRadius),
            control: CGPoint(x: rect.maxX - topRadius, y: rect.maxY)
        )
        path.addLine(to: CGPoint(x: rect.maxX - topRadius, y: rect.minY + topRadius))
        path.addQuadCurve(
            to: CGPoint(x: rect.maxX, y: rect.minY),
            control: CGPoint(x: rect.maxX - topRadius, y: rect.minY)
        )
        return path
    }
}

/// Progress drawn along the notch's own contour, from its left edge round the
/// bottom to its right edge.
struct RestingProgressLineView: View {
    let progress: Double
    let tint: Color

    var body: some View {
        let outline = NotchOutline(
            topRadius: NotchPanelMetrics.notchOutlineTopRadius,
            bottomRadius: NotchPanelMetrics.notchOutlineBottomRadius
        )
        let trackStyle = StrokeStyle(lineWidth: RestingProgressLine.height)
        let fillStyle = StrokeStyle(lineWidth: RestingProgressLine.height, lineCap: .round)

        ZStack {
            outline.stroke(Color.white.opacity(0.18), style: trackStyle)
            outline.trim(from: 0, to: progress)
                .stroke(tint, style: fillStyle)
                .shadow(color: tint.opacity(0.9), radius: RestingProgressLine.glowRadius)
                .shadow(color: tint.opacity(0.5), radius: RestingProgressLine.glowRadius / 2)
        }
    }
}
