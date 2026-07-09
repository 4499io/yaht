import SwiftUI

/// Shared visual language for the activity grids — the global blended grid and
/// each habit's grid — so both read as the same signature element.
///
/// Cells sit on a card surface. A day with activity composites the habit color
/// *over* an always-visible empty lattice (via ``mix(_:_:_:)``) rather than
/// layering `.opacity` on near-black, so a single completion stays vivid and the
/// empty days still form a clear mesh. Out-of-range days (before a habit existed,
/// or in the future) render as a faint ghost so the live area is what draws the eye.
enum ActivityStyle {
    static let cellSize: CGFloat = 13
    static let cellSpacing: CGFloat = 3
    static let cornerRadius: CGFloat = 3.5

    /// In-range day with no activity — a clear lattice step above the card.
    static let emptyFill = Color(hex: "262B37") ?? Cyberdream.elevated
    /// Out-of-range day (pre-creation or future) — a faint ghost of the lattice.
    static let ghostFill = Color(hex: "1B1F28") ?? Cyberdream.surface

    /// Fill for a day with activity. `level` in `0...1` (completion fraction /
    /// progress). Composited over ``emptyFill`` so low levels stay legible and a
    /// full day reads as the solid habit color.
    static func fill(_ color: Color, level: Double) -> Color {
        mix(emptyFill, color, 0.4 + 0.6 * min(max(level, 0), 1))
    }

    /// Legend steps, low → high. `0` renders as ``emptyFill``.
    static let legendLevels: [Double] = [0, 0.25, 0.5, 0.75, 1]

    /// A legend swatch for `level` in the given accent color.
    static func legendFill(_ color: Color, level: Double) -> Color {
        level <= 0 ? emptyFill : fill(color, level: level)
    }
}
