import SwiftUI

extension Color {
    /// Creates a color from a hex string.
    ///
    /// Accepts 6-digit (`RRGGBB`) or 8-digit (`RRGGBBAA`) forms, with or without
    /// a leading `#`. Whitespace is trimmed and parsing is case-insensitive.
    /// Returns `nil` for any malformed input so callers can fall back gracefully.
    init?(hex: String) {
        var cleaned = hex.trimmingCharacters(in: .whitespacesAndNewlines)
        if cleaned.hasPrefix("#") {
            cleaned.removeFirst()
        }

        guard cleaned.count == 6 || cleaned.count == 8 else { return nil }
        guard let value = UInt64(cleaned, radix: 16) else { return nil }

        let red: Double
        let green: Double
        let blue: Double
        let alpha: Double

        if cleaned.count == 6 {
            red = Double((value & 0xFF0000) >> 16) / 255.0
            green = Double((value & 0x00FF00) >> 8) / 255.0
            blue = Double(value & 0x0000FF) / 255.0
            alpha = 1.0
        } else {
            red = Double((value & 0xFF00_0000) >> 24) / 255.0
            green = Double((value & 0x00FF_0000) >> 16) / 255.0
            blue = Double((value & 0x0000_FF00) >> 8) / 255.0
            alpha = Double(value & 0x0000_00FF) / 255.0
        }

        self.init(.sRGB, red: red, green: green, blue: blue, opacity: alpha)
    }

    /// Serializes the color to an 8-digit `RRGGBBAA` hex string (uppercase, no `#`).
    ///
    /// Resolves the color in the sRGB space. Returns `nil` if the color cannot be
    /// resolved to concrete components.
    func toHex() -> String? {
        let resolved = resolve(in: EnvironmentValues())
        let red = clampChannel(resolved.red)
        let green = clampChannel(resolved.green)
        let blue = clampChannel(resolved.blue)
        let alpha = clampChannel(resolved.opacity)

        return String(format: "%02X%02X%02X%02X", red, green, blue, alpha)
    }

    private func clampChannel(_ value: Float) -> Int {
        let clamped = min(max(value, 0), 1)
        return Int((clamped * 255).rounded())
    }
}
