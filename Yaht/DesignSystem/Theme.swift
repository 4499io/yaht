import SwiftUI

/// Yaht's design tokens: the Gruvbox dark color scheme.
///
/// Surfaces step up from `bg0_h` (the screen) through `bg0` (cards) to `bg1`
/// (controls on cards). Habit colors are Gruvbox's bright accents plus three of
/// its neutral accents, so every habit reads clearly on the dark surfaces.
/// All colors come from hex strings through ``Color/init(hex:)`` so stored habit
/// colors round-trip with the palette.
enum Theme {
    // MARK: - Surfaces

    /// Screen background (`bg0_h`).
    static let background = color(backgroundHex)
    /// Cards and grouped content (`bg0`).
    static let surface = color(surfaceHex)
    /// Controls and chips placed on a card (`bg0_s`).
    static let raised = color(raisedHex)
    /// Empty progress tracks and stepper buttons (`bg1`).
    static let track = color(trackHex)
    /// Hairline borders around cards.
    static let hairline = color(textPrimaryHex).opacity(0.06)

    // MARK: - Text

    /// Primary text (`fg1`).
    static let textPrimary = color(textPrimaryHex)
    /// Secondary text (`fg3`).
    static let textSecondary = color(textSecondaryHex)
    /// Captions and labels (`fg4`).
    static let textTertiary = color(textTertiaryHex)
    /// Disabled and future content (`bg3`).
    static let textDisabled = color(textDisabledHex)
    /// Text and icons drawn on a filled habit color.
    static let onAccent = background

    // MARK: - Accents

    /// Destructive actions (bright red).
    static let danger = color("FB4934")
    /// App tint for system controls (bright aqua).
    static let tint = color("8EC07C")

    // MARK: - Habit palette

    /// The colors a habit can take, in picker order, with their spoken names.
    static let habitColors: [(hex: String, name: LocalizedStringKey)] = [
        ("FB4934", "Red"),
        ("FE8019", "Orange"),
        ("FABD2F", "Yellow"),
        ("B8BB26", "Green"),
        ("8EC07C", "Aqua"),
        ("83A598", "Blue"),
        ("D3869B", "Purple"),
        ("D79921", "Gold"),
        ("689D6A", "Teal"),
        ("B16286", "Plum"),
    ]

    /// Stored color tokens, in the same order as their accessible names.
    static let habitPaletteHex: [String] = habitColors.map(\.hex)

    /// ``habitPaletteHex`` resolved to colors, index-aligned.
    static var habitPalette: [Color] {
        habitPaletteHex.map { Color(hex: $0) ?? .accentColor }
    }

    /// Default color for a new habit.
    static let defaultHabitHex = "8EC07C"

    /// Earlier palette → closest Gruvbox color, so habits created before the
    /// Gruvbox theme keep a color the picker still offers.
    static let legacyHabitHex: [String: String] = [
        "5FB8C4": "8EC07C", // cyan → aqua
        "4FB89C": "689D6A", // teal → teal
        "6FB86A": "B8BB26", // green → green
        "5B8FD6": "83A598", // blue → blue
        "9B7BD1": "B16286", // purple → plum
        "CE7BB0": "D3869B", // pink → purple
        "D06D6D": "FB4934", // red → red
        "D9925A": "FE8019", // orange → orange
        "D6C066": "FABD2F", // yellow → yellow
        "7B7BD1": "83A598", // indigo → blue
    ]

    /// The Gruvbox replacement for an earlier palette color, or `nil` when the
    /// hex is not from the earlier palette.
    static func migratedHex(for hex: String) -> String? {
        let key = hex.trimmingCharacters(in: CharacterSet(charactersIn: "# ")).uppercased()
        return legacyHabitHex[key]
    }

    // MARK: - Raw hex tokens

    static let backgroundHex = "1D2021"
    static let surfaceHex = "282828"
    static let raisedHex = "32302F"
    static let trackHex = "3C3836"
    static let textPrimaryHex = "EBDBB2"
    static let textSecondaryHex = "BDAE93"
    static let textTertiaryHex = "A89984"
    static let textDisabledHex = "665C54"

    private static func color(_ hex: String) -> Color {
        Color(hex: hex) ?? .gray
    }
}
