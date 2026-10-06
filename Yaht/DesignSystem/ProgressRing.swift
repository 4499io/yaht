import SwiftUI

/// A circular progress track: an empty ring with `progress` (0...1) drawn over it.
struct ProgressRing: View {
    let progress: Double
    let color: Color
    var lineWidth: CGFloat = 3
    var trackColor: Color = Theme.track

    var body: some View {
        ZStack {
            Circle()
                .stroke(trackColor, lineWidth: lineWidth)
            Circle()
                .trim(from: 0, to: min(max(progress, 0), 1))
                .stroke(color, style: StrokeStyle(lineWidth: lineWidth, lineCap: .round))
                .rotationEffect(.degrees(-90))
        }
        .padding(lineWidth / 2)
        .animation(.snappy, value: progress)
    }
}

/// One ring split into equal segments, one per item. A filled segment shows the
/// item's color; an unfilled one shows a faint tint of it.
struct SegmentedRing: View {
    struct Segment: Identifiable {
        let id: String
        let color: Color
        let isFilled: Bool
    }

    let segments: [Segment]
    var lineWidth: CGFloat = 12
    /// Gap between segments, as a fraction of the full circle.
    var gap: Double = 0.045

    var body: some View {
        ZStack {
            if segments.isEmpty {
                Circle().stroke(Theme.track, lineWidth: lineWidth)
            }
            ForEach(Array(segments.enumerated()), id: \.element.id) { index, segment in
                let slot = 1.0 / Double(segments.count)
                let inset = segments.count > 1 ? min(gap, slot / 3) / 2 : 0
                Circle()
                    .trim(from: Double(index) * slot + inset, to: Double(index + 1) * slot - inset)
                    .stroke(
                        segment.isFilled ? segment.color : segment.color.opacity(0.2),
                        style: StrokeStyle(lineWidth: lineWidth, lineCap: segments.count > 1 ? .round : .butt)
                    )
                    .rotationEffect(.degrees(-90))
            }
        }
        .padding(lineWidth / 2)
        .animation(.snappy, value: segments.map(\.isFilled))
    }
}
