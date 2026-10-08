import SwiftUI

/// Showcase of the design system: a card, rings and the habit palette.
#Preview("Design System") {
    ScrollView {
        VStack(alignment: .leading, spacing: 24) {
            Card {
                HStack(spacing: 16) {
                    SegmentedRing(segments: Theme.habitPalette.prefix(5).enumerated().map { index, color in
                        SegmentedRing.Segment(id: "\(index)", color: color, isFilled: index < 3)
                    })
                    .frame(width: 96, height: 96)
                    VStack(alignment: .leading, spacing: 4) {
                        Text("Two to go")
                            .roundedFont(20)
                            .foregroundStyle(Theme.textPrimary)
                        Text("Next: Gym, Call mum.")
                            .font(.subheadline)
                            .foregroundStyle(Theme.textSecondary)
                    }
                }
            }

            Text("Habit palette")
                .font(.headline)
                .foregroundStyle(Theme.textPrimary)

            LazyVGrid(columns: Array(repeating: GridItem(.flexible(), spacing: 12), count: 5), spacing: 12) {
                ForEach(Array(Theme.habitPalette.enumerated()), id: \.offset) { _, color in
                    RoundedRectangle(cornerRadius: 12, style: .continuous)
                        .fill(color)
                        .frame(height: 56)
                }
            }
        }
        .padding()
    }
    .background(Theme.background)
    .preferredColorScheme(.dark)
}
