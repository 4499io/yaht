import SwiftUI

/// A small reusable stat tile: a short title over a prominent value, hosted in a
/// ``GlassCard``. Used to surface streaks and completion figures on the detail
/// screen. Purely presentational.
struct StatTile: View {
    let title: String
    let value: String
    var tint: Color = Cyberdream.textPrimary

    var body: some View {
        GlassCard {
            VStack(alignment: .leading, spacing: 4) {
                Text(title)
                    .font(.caption.weight(.medium))
                    .foregroundStyle(Cyberdream.textSecondary)
                Text(value)
                    .font(.title2.weight(.semibold))
                    .monospacedDigit()
                    .foregroundStyle(tint)
            }
            .frame(maxWidth: .infinity, alignment: .leading)
        }
        .accessibilityElement(children: .combine)
        .accessibilityLabel("\(title): \(value)")
    }
}

#Preview {
    LazyVGrid(columns: [GridItem(.flexible()), GridItem(.flexible())], spacing: 12) {
        StatTile(title: "Streak", value: "12", tint: Cyberdream.habitPalette.first ?? .accentColor)
        StatTile(title: "Best", value: "30")
        StatTile(title: "30-Day", value: "80%")
        StatTile(title: "Total", value: "146")
    }
    .padding()
    .preferredColorScheme(.dark)
}
