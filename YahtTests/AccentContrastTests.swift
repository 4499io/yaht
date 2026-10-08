import Testing
@testable import Yaht

@MainActor
struct AccentContrastTests {
    @Test func everyPaletteControlMeetsNormalTextContrast() {
        for hex in Theme.habitPaletteHex {
            let foreground = AccentContrast.foregroundHex(on: hex)
            #expect(AccentContrast.ratio(foreground: foreground, background: hex) >= 4.5)
        }
    }

    @Test func darkAndLightCustomColorsUseReadableForegrounds() {
        #expect(AccentContrast.foregroundHex(on: "101010") == "FFFFFF")
        #expect(AccentContrast.foregroundHex(on: "F0F0F0") == "000000")
        #expect(AccentContrast.foregroundHex(on: "#b16286") == "000000")
    }

    @Test func alphaIsCompositedOverTheCardSurface() {
        #expect(AccentContrast.foregroundHex(on: "FFFFFF00") == "FFFFFF")
        #expect(AccentContrast.foregroundHex(on: "FFFFFFFF") == "000000")
    }

    @Test func malformedColorsUseTheHabitFallback() {
        #expect(AccentContrast.foregroundHex(on: "invalid") == AccentContrast.foregroundHex(on: Theme.defaultHabitHex))
    }
}
