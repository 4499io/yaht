import Testing
import SwiftUI
@testable import Yaht

/// Pure-color tests for `blend(_:)` — no persistence or UIKit involved.
/// Colors are resolved in sRGB and compared component-wise with a small tolerance
/// to absorb floating-point rounding.
@MainActor
struct ColorBlendTests {

    private let tolerance = 0.01

    @Test func blendsTwoColorsToMidpoint() {
        let red = Color(.sRGB, red: 1, green: 0, blue: 0, opacity: 1)
        let blue = Color(.sRGB, red: 0, green: 0, blue: 1, opacity: 1)

        let mid = blend([red, blue]).resolve(in: EnvironmentValues())

        #expect(abs(Double(mid.red) - 0.5) < tolerance)
        #expect(abs(Double(mid.green) - 0.0) < tolerance)
        #expect(abs(Double(mid.blue) - 0.5) < tolerance)
        #expect(abs(Double(mid.opacity) - 1.0) < tolerance)
    }

    @Test func averagesOpacityToo() {
        let opaque = Color(.sRGB, red: 0.4, green: 0.4, blue: 0.4, opacity: 1)
        let faint = Color(.sRGB, red: 0.4, green: 0.4, blue: 0.4, opacity: 0)

        let mid = blend([opaque, faint]).resolve(in: EnvironmentValues())

        #expect(abs(Double(mid.opacity) - 0.5) < tolerance)
    }

    @Test func emptyBlendIsClear() {
        let clear = blend([]).resolve(in: EnvironmentValues())
        #expect(Double(clear.opacity) < tolerance)
    }

    @Test func singleColorIsUnchanged() {
        let source = Color(.sRGB, red: 0.2, green: 0.6, blue: 0.8, opacity: 1)
        let result = blend([source]).resolve(in: EnvironmentValues())

        #expect(abs(Double(result.red) - 0.2) < tolerance)
        #expect(abs(Double(result.green) - 0.6) < tolerance)
        #expect(abs(Double(result.blue) - 0.8) < tolerance)
    }

    // MARK: - mix

    @Test func mixEndpointsReturnInputs() {
        let a = Color(.sRGB, red: 0, green: 0, blue: 0, opacity: 1)
        let b = Color(.sRGB, red: 1, green: 1, blue: 1, opacity: 1)

        let low = mix(a, b, 0).resolve(in: EnvironmentValues())
        let high = mix(a, b, 1).resolve(in: EnvironmentValues())

        #expect(abs(Double(low.red) - 0.0) < tolerance)
        #expect(abs(Double(high.red) - 1.0) < tolerance)
    }

    @Test func mixHalfwayIsMidpoint() {
        let a = Color(.sRGB, red: 0.2, green: 0.2, blue: 0.2, opacity: 1)
        let b = Color(.sRGB, red: 0.8, green: 0.8, blue: 0.8, opacity: 1)

        let mid = mix(a, b, 0.5).resolve(in: EnvironmentValues())

        #expect(abs(Double(mid.red) - 0.5) < tolerance)
    }

    @Test func mixClampsOutOfRange() {
        let a = Color(.sRGB, red: 0, green: 0, blue: 0, opacity: 1)
        let b = Color(.sRGB, red: 1, green: 1, blue: 1, opacity: 1)

        let below = mix(a, b, -1).resolve(in: EnvironmentValues())
        let above = mix(a, b, 2).resolve(in: EnvironmentValues())

        #expect(abs(Double(below.red) - 0.0) < tolerance)
        #expect(abs(Double(above.red) - 1.0) < tolerance)
    }
}
