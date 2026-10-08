import SwiftUI

/// Display typography that follows the user's text size instead of staying fixed.
private struct ScaledRoundedFont: ViewModifier {
    @ScaledMetric private var size: CGFloat
    let weight: Font.Weight

    init(size: CGFloat, weight: Font.Weight, relativeTo style: Font.TextStyle) {
        _size = ScaledMetric(wrappedValue: size, relativeTo: style)
        self.weight = weight
    }

    func body(content: Content) -> some View {
        content.font(.rounded(size, weight: weight))
    }
}

extension View {
    func roundedFont(_ size: CGFloat, weight: Font.Weight = .bold, relativeTo style: Font.TextStyle = .body) -> some View {
        modifier(ScaledRoundedFont(size: size, weight: weight, relativeTo: style))
    }
}

/// Keep compact layouts side by side; give accessibility text its own full row.
struct AdaptiveStack<Content: View>: View {
    @Environment(\.dynamicTypeSize) private var textSize
    var spacing: CGFloat = 12
    @ViewBuilder let content: Content

    var body: some View {
        if textSize >= .xxxLarge {
            VStack(alignment: .leading, spacing: spacing) { content }
        } else {
            HStack(spacing: spacing) { content }
        }
    }
}

struct SectionHeading: View {
    let title: LocalizedStringKey
    var detail: String?

    var body: some View {
        AdaptiveStack(spacing: 4) {
            Text(title)
                .font(.headline)
                .foregroundStyle(Theme.textPrimary)
                .accessibilityAddTraits(.isHeader)
            if let detail {
                Text(detail)
                    .font(.subheadline)
                    .foregroundStyle(Theme.textSecondary)
            }
        }
        .frame(maxWidth: .infinity, alignment: .leading)
    }
}
