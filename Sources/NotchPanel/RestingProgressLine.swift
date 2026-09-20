import SwiftUI

/// The one thing NotchBar draws while the panel is closed, and only when asked:
/// a hairline under the notch filled with the running event's progress.
///
/// It is off by default because anything drawn at rest slides with the desktop
/// during an interactive Space switch — no window flag prevents that (see the
/// collapsed surface removed for the same reason).
enum RestingProgressLine {
    static let height: CGFloat = 3

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

struct RestingProgressLineView: View {
    let progress: Double
    let tint: Color

    var body: some View {
        GeometryReader { geometry in
            ZStack(alignment: .leading) {
                Capsule()
                    .fill(Color.white.opacity(0.18))

                Capsule()
                    .fill(tint)
                    .frame(width: geometry.size.width * progress)
            }
        }
        .frame(height: RestingProgressLine.height)
    }
}
