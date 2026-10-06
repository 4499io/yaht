import Foundation
import SwiftData
import Testing
@testable import Yaht

@MainActor
struct ThemeMigrationTests {
    @Test func everyLegacyColorMapsIntoTheCurrentPalette() {
        #expect(Theme.legacyHabitHex.count == 10)
        for replacement in Theme.legacyHabitHex.values {
            #expect(Theme.habitPaletteHex.contains(replacement))
        }
    }

    @Test func migratedHexIgnoresCaseAndHashAndSkipsUnknownColors() {
        #expect(Theme.migratedHex(for: "#5fb8c4") == "8EC07C")
        #expect(Theme.migratedHex(for: "D06D6D") == "FB4934")
        #expect(Theme.migratedHex(for: "FB4934") == nil)
        #expect(Theme.migratedHex(for: "") == nil)
    }

    @Test func storeMigratesActiveAndArchivedHabitsOnce() throws {
        let schema = Schema(versionedSchema: CurrentSchema.self)
        let container = try ModelContainer(
            for: schema,
            configurations: [ModelConfiguration(schema: schema, isStoredInMemoryOnly: true)]
        )
        let store = HabitStore(modelContext: container.mainContext)
        let legacy = Habit(name: "Meds", colorHex: "CE7BB0")
        let archived = Habit(name: "Old", colorHex: "5B8FD6", isArchived: true)
        let current = Habit(name: "Read", colorHex: "FABD2F")
        let custom = Habit(name: "Custom", colorHex: "123456")
        for habit in [legacy, archived, current, custom] { store.create(habit) }

        #expect(store.migrateLegacyColors() == 2)
        #expect(legacy.colorHex == "D3869B")
        #expect(archived.colorHex == "83A598")
        #expect(current.colorHex == "FABD2F")
        #expect(custom.colorHex == "123456")
        #expect(store.migrateLegacyColors() == 0)
    }

    @Test func editorShowsTheMigratedColorForALegacyHabit() {
        let habit = Habit(name: "Gym", colorHex: "D9925A")
        #expect(HabitEditViewModel(habit: habit).colorHex == "FE8019")
        #expect(HabitEditViewModel(habit: nil).colorHex == Theme.defaultHabitHex)
    }
}
