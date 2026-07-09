import SwiftUI

/// Human-facing showcase of the Yaht design system: a ``GlassCard``, a ``Pill``,
/// and the full ``Cyberdream/habitPalette`` rendered as swatches.
#Preview("Design System") {
    ScrollView {
        VStack(alignment: .leading, spacing: 24) {
            GlassCard {
                VStack(alignment: .leading, spacing: 12) {
                    HStack {
                        Text("🧩")
                            .font(.system(size: 36))
                        VStack(alignment: .leading) {
                            Text("Yaht")
                                .font(.title2.bold())
                                .foregroundStyle(Cyberdream.textPrimary)
                            Text("yet another habit tracker")
                                .font(.subheadline)
                                .foregroundStyle(Cyberdream.textSecondary)
                        }
                    }
                    HStack(spacing: 8) {
                        Pill("Daily")
                        Pill("3 / week")
                        Pill("Streak 12")
                    }
                }
            }

            Text("Habit palette")
                .font(.headline)
                .foregroundStyle(Cyberdream.textPrimary)

            LazyVGrid(columns: Array(repeating: GridItem(.flexible(), spacing: 12), count: 5), spacing: 12) {
                ForEach(Array(Cyberdream.habitPalette.enumerated()), id: \.offset) { _, color in
                    RoundedRectangle(cornerRadius: 12, style: .continuous)
                        .fill(color)
                        .frame(height: 56)
                }
            }
        }
        .padding()
    }
    .preferredColorScheme(.dark)
}
