import SwiftUI

/// Shared look for activity grids and calendars.
///
/// A day with activity composites the habit color over the empty fill (via
/// ``mix(_:_:_:)``) rather than layering `.opacity`, so a single completion stays
/// vivid while empty days still form a quiet lattice. Days outside the tracked
/// range (before a habit existed, or in the future) render as a faint ghost.
enum ActivityStyle {
    static let cellSpacing: CGFloat = 3
    static let cornerRadius: CGFloat = 3.5

    /// In-range day with no activity.
    static let emptyFill = Theme.raised
    /// Out-of-range day (pre-creation or future).
    static let ghostFill = Color(hex: "2D2B2A") ?? Theme.surface

    /// Fill for a day with activity, `level` in `0...1`. The high floor keeps a
    /// single completion clearly visible.
    static func fill(_ color: Color, level: Double) -> Color {
        mix(emptyFill, color, 0.45 + 0.55 * min(max(level, 0), 1))
    }
}
