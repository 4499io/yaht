import SwiftUI

/// Averages an array of colors in sRGB space, component-wise with equal weight.
///
/// Each color is resolved to concrete sRGB components (red, green, blue, opacity)
/// and the arithmetic mean is returned as a new `Color(.sRGB, …)`. An empty input
/// yields `.clear`, so callers can treat "no colors" as a fully transparent result.
///
/// Pure and unit-testable: it depends only on SwiftUI's `Color`, with no UIKit.
func blend(_ colors: [Color]) -> Color {
    guard !colors.isEmpty else { return .clear }

    var red = 0.0
    var green = 0.0
    var blue = 0.0
    var opacity = 0.0

    for color in colors {
        let resolved = color.resolve(in: EnvironmentValues())
        red += Double(resolved.red)
        green += Double(resolved.green)
        blue += Double(resolved.blue)
        opacity += Double(resolved.opacity)
    }

    let count = Double(colors.count)
    return Color(
        .sRGB,
        red: red / count,
        green: green / count,
        blue: blue / count,
        opacity: opacity / count
    )
}
