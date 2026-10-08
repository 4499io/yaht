import Foundation

/// Choose a readable foreground for filled habit controls, including custom colors.
enum AccentContrast {
    static func foregroundHex(on hex: String) -> String {
        luminance(of: hex) > 0.179 ? "000000" : "FFFFFF"
    }

    static func ratio(foreground: String, background: String) -> Double {
        let first = luminance(of: foreground)
        let second = luminance(of: background)
        return (max(first, second) + 0.05) / (min(first, second) + 0.05)
    }

    private static func luminance(of hex: String) -> Double {
        var cleaned = hex.trimmingCharacters(in: .whitespacesAndNewlines)
        if cleaned.hasPrefix("#") { cleaned.removeFirst() }
        guard (cleaned.count == 6 || cleaned.count == 8), let value = UInt64(cleaned, radix: 16) else {
            return luminance(of: Theme.defaultHabitHex)
        }
        let rgb = cleaned.count == 8 ? value >> 8 : value
        let alpha = cleaned.count == 8 ? Double(value & 0xFF) / 255 : 1
        // Controls sit on the card surface; account for translucent custom colors.
        let surface: [Double] = [40.0 / 255, 40.0 / 255, 40.0 / 255]
        let channels = [Double((rgb >> 16) & 0xFF), Double((rgb >> 8) & 0xFF), Double(rgb & 0xFF)]
        let linear = zip(channels, surface).map { channel, backdrop in
            let component = channel / 255 * alpha + backdrop * (1 - alpha)
            return component <= 0.04045 ? component / 12.92 : pow((component + 0.055) / 1.055, 2.4)
        }
        return linear[0] * 0.2126 + linear[1] * 0.7152 + linear[2] * 0.0722
    }
}
