import SwiftUI

/// A rounded Liquid Glass card that hosts arbitrary content.
///
/// Uses the system `.regularMaterial` inside a `RoundedRectangle` so it adopts
/// the platform's glass treatment. Never sets a manual color background.
struct GlassCard<Content: View>: View {
    private let cornerRadius: CGFloat
    private let content: Content

    init(cornerRadius: CGFloat = 16, @ViewBuilder content: () -> Content) {
        self.cornerRadius = cornerRadius
        self.content = content()
    }

    var body: some View {
        content
            .padding(16)
            .background(.regularMaterial, in: RoundedRectangle(cornerRadius: cornerRadius, style: .continuous))
    }
}

/// A compact glass pill, typically used for tags, counts, and status chips.
///
/// Uses `.ultraThinMaterial` in a `Capsule` for a lighter treatment than
/// ``GlassCard``.
struct Pill<Content: View>: View {
    private let content: Content

    init(@ViewBuilder content: () -> Content) {
        self.content = content()
    }

    var body: some View {
        content
            .font(.footnote.weight(.medium))
            .padding(.horizontal, 12)
            .padding(.vertical, 6)
            .background(.ultraThinMaterial, in: Capsule())
    }
}

extension Pill where Content == Text {
    /// Convenience initializer for a text-only pill.
    init(_ title: String) {
        self.init { Text(title) }
    }
}
