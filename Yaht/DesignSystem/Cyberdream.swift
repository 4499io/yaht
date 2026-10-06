import SwiftUI

/// Muted, always-dark "cyberdream" design tokens for Yaht.
///
/// The palette is intentionally desaturated so that neon accents stay readable
/// in a dim room without overwhelming the eye. All colors are derived from hex
/// strings through ``Color/init(hex:)`` so they round-trip cleanly with storage.
enum Cyberdream {
    // MARK: - Surfaces

    /// Deep near-black app background.
    static let background = Color(hex: backgroundHex) ?? .black
    /// Base surface for cards and grouped content.
    static let surface = Color(hex: surfaceHex) ?? .black
    /// Elevated surface for controls stacked above cards.
    static let elevated = Color(hex: elevatedHex) ?? .black

    // MARK: - Text

    /// Primary foreground text (soft off-white).
    static let textPrimary = Color(hex: textPrimaryHex) ?? .white
    /// Secondary / supporting text (muted slate).
    static let textSecondary = Color(hex: textSecondaryHex) ?? .gray

    // MARK: - Habit palette

    /// ~10 desaturated neon hues used to color individual habits.
    /// Order: cyan, teal, green, blue, purple, pink, red, orange, yellow, indigo.
    static let habitColors: [(hex: String, name: LocalizedStringKey)] = [
        ("5FB8C4", "Cyan"),
        ("4FB89C", "Teal"),
        ("6FB86A", "Green"),
        ("5B8FD6", "Blue"),
        ("9B7BD1", "Purple"),
        ("CE7BB0", "Pink"),
        ("D06D6D", "Red"),
        ("D9925A", "Orange"),
        ("D6C066", "Yellow"),
        ("7B7BD1", "Indigo"),
    ]

    /// Stored color tokens, in the same order as their accessible names.
    static let habitPaletteHex: [String] = habitColors.map(\.hex)

    /// ``habitPaletteHex`` mapped through ``Color/init(hex:)``.
    /// Any hue that fails to parse falls back to the accent color so indices
    /// remain stable and aligned with ``habitPaletteHex``.
    static var habitPalette: [Color] {
        habitPaletteHex.map { Color(hex: $0) ?? .accentColor }
    }

    // MARK: - Raw hex tokens

    static let backgroundHex = "12141A"
    static let surfaceHex = "181B22"
    static let elevatedHex = "1F232C"
    static let textPrimaryHex = "E6E9EF"
    static let textSecondaryHex = "9AA2B1"
}
