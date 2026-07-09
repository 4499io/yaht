import SwiftUI
import UIKit

/// The yaht masthead: one oversized drop-cap "y" shared by both the name and the
/// tagline. The single glyph spans two lines — "aht" reads across the top
/// ("yaht"), "et another habit tracker" across the bottom ("yet another habit
/// tracker"). The big "y" is aligned so its **cap top matches "aht"'s cap top**
/// (shared ceiling) and its extra height + descender fall through the second line.
struct YahtWordmark: View {
    private let ySize: CGFloat = 62
    private let topSize: CGFloat = 34
    private let tagSize: CGFloat = 14

    var body: some View {
        HStack(alignment: .capTop, spacing: 3) {
            Text("y")
                .font(.system(size: ySize, weight: .heavy, design: .rounded))
                .foregroundStyle(Cyberdream.textPrimary)
                // A lowercase "y" has no cap/ascender — its top is the x-height.
                .alignmentGuide(.capTop) { _ in Self.glyphTopInset(ySize, .heavy, metric: .xHeight) }

            VStack(alignment: .leading, spacing: 2) {
                Text("aht")
                    .font(.system(size: topSize, weight: .heavy, design: .rounded))
                    .foregroundStyle(Cyberdream.textPrimary)
                Text("et another habit tracker")
                    .font(.system(size: tagSize, weight: .medium, design: .rounded))
                    .foregroundStyle(Cyberdream.textSecondary)
            }
            // "aht"'s visible top is the ascender/cap of h & t (aht is line 1).
            .alignmentGuide(.capTop) { _ in Self.glyphTopInset(topSize, .heavy, metric: .capHeight) }
        }
        .accessibilityElement()
        .accessibilityLabel("yaht — yet another habit tracker")
        .accessibilityAddTraits(.isHeader)
    }

    private enum TopMetric { case xHeight, capHeight }

    /// Distance from a rendered text view's top down to the visible top of its
    /// glyphs, so runs of different sizes align by where their letters actually
    /// end. Use `.xHeight` for the lowercase "y" (its top is the x-height) and
    /// `.capHeight` for "aht" (its top is the ascender of h/t).
    private static func glyphTopInset(_ size: CGFloat, _ weight: UIFont.Weight, metric: TopMetric) -> CGFloat {
        let base = UIFont.systemFont(ofSize: size, weight: weight)
        let font = base.fontDescriptor.withDesign(.rounded)
            .map { UIFont(descriptor: $0, size: size) } ?? base
        let top = metric == .xHeight ? font.xHeight : font.capHeight
        return font.ascender - top
    }
}

/// Aligns views by the top of their capital letters rather than their frames.
private extension VerticalAlignment {
    enum CapTopID: AlignmentID {
        static func defaultValue(in dimensions: ViewDimensions) -> CGFloat { dimensions[.top] }
    }
    static let capTop = VerticalAlignment(CapTopID.self)
}

#Preview {
    YahtWordmark()
        .padding()
        .frame(maxWidth: .infinity, alignment: .leading)
        .background(Cyberdream.background)
        .preferredColorScheme(.dark)
}
