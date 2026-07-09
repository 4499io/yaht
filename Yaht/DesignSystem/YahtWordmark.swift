import SwiftUI

/// The yaht masthead: one oversized drop-cap "y" shared by both the name and the
/// tagline. The single glyph spans two lines — "aht" reads across the top
/// ("yaht"), "et another habit tracker" across the bottom ("yet another habit
/// tracker"). The big "y" is the signature; everything around it stays quiet.
struct YahtWordmark: View {
    var body: some View {
        HStack(alignment: .center, spacing: 4) {
            Text("y")
                .font(.system(size: 64, weight: .heavy, design: .rounded))
                .foregroundStyle(Cyberdream.textPrimary)

            VStack(alignment: .leading, spacing: 2) {
                Text("aht")
                    .font(.system(size: 34, weight: .heavy, design: .rounded))
                    .foregroundStyle(Cyberdream.textPrimary)
                Text("et another habit tracker")
                    .font(.system(size: 14, weight: .medium, design: .rounded))
                    .foregroundStyle(Cyberdream.textSecondary)
            }
        }
        .accessibilityElement()
        .accessibilityLabel("yaht — yet another habit tracker")
        .accessibilityAddTraits(.isHeader)
    }
}

#Preview {
    YahtWordmark()
        .padding()
        .frame(maxWidth: .infinity, alignment: .leading)
        .background(Cyberdream.background)
        .preferredColorScheme(.dark)
}
