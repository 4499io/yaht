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

/// Linearly interpolates between two colors in sRGB space. `t == 0` returns `a`,
/// `t == 1` returns `b`; values are clamped to that range. Unlike layering with
/// `.opacity`, this composites to a concrete opaque color, so a tinted cell over a
/// dark surface stays vivid instead of bleeding toward black.
func mix(_ a: Color, _ b: Color, _ t: Double) -> Color {
    let tt = min(max(t, 0), 1)
    let ra = a.resolve(in: EnvironmentValues())
    let rb = b.resolve(in: EnvironmentValues())
    func lerp(_ x: Float, _ y: Float) -> Double { Double(x) + (Double(y) - Double(x)) * tt }
    return Color(
        .sRGB,
        red: lerp(ra.red, rb.red),
        green: lerp(ra.green, rb.green),
        blue: lerp(ra.blue, rb.blue),
        opacity: lerp(ra.opacity, rb.opacity)
    )
}
