import Testing
import Foundation
import SwiftData
@testable import Yaht

/// Integration tests for `HabitStore` against an in-memory SwiftData container.
@MainActor
struct HabitStoreTests {

    /// Fresh, isolated in-memory store per test.
    private func makeContainer() throws -> ModelContainer {
        let schema = Schema(versionedSchema: SchemaV1.self)
        let config = ModelConfiguration(schema: schema, isStoredInMemoryOnly: true)
        return try ModelContainer(for: schema, configurations: [config])
    }

    private func allLogs(_ context: ModelContext) throws -> [HabitLog] {
        try context.fetch(FetchDescriptor<HabitLog>())
    }

    // MARK: - Habit lifecycle

    @Test func createSurfacesInActiveHabits() throws {
        let container = try makeContainer()
        let store = HabitStore(modelContext: container.mainContext)

        let habit = Habit(name: "Read", sortOrder: 0)
        store.create(habit)

        let active = store.allActiveHabits()
        #expect(active.count == 1)
        #expect(active.first?.name == "Read")
    }

    @Test func allActiveHabitsSortedBySortOrder() throws {
        let container = try makeContainer()
        let store = HabitStore(modelContext: container.mainContext)

        store.create(Habit(name: "B", sortOrder: 2))
        store.create(Habit(name: "A", sortOrder: 1))
        store.create(Habit(name: "C", sortOrder: 3))

        let names = store.allActiveHabits().map(\.name)
        #expect(names == ["A", "B", "C"])
    }

    @Test func archiveHidesFromActiveHabits() throws {
        let container = try makeContainer()
        let store = HabitStore(modelContext: container.mainContext)

        let habit = Habit(name: "Meditate")
        store.create(habit)
        #expect(store.allActiveHabits().count == 1)

        store.archive(habit)
        #expect(habit.isArchived)
        #expect(store.allActiveHabits().isEmpty)
    }

    @Test func deleteCascadesLogs() throws {
        let container = try makeContainer()
        let context = container.mainContext
        let store = HabitStore(modelContext: context)

        let habit = Habit(name: "Water", kind: .count, dailyTarget: 2)
        store.create(habit)
        store.increment(habit, on: Date(), by: 1)
        #expect(try allLogs(context).count == 1)

        store.delete(habit)
        #expect(store.allActiveHabits().isEmpty)
        #expect(try allLogs(context).isEmpty)
    }

    // MARK: - Binary logging

    @Test func binaryToggleIsIdempotentPerDay() throws {
        let container = try makeContainer()
        let context = container.mainContext
        let store = HabitStore(modelContext: context)

        let habit = Habit(name: "Floss", kind: .binary)
        store.create(habit)

        // Anchor both taps to the same calendar day (08:00 and 20:00 local) so
        // the test is deterministic regardless of wall-clock time / timezone —
        // morning+8h could otherwise cross midnight and hit a different day.
        let base = Calendar.current.startOfDay(for: Date())
        let morning = base.addingTimeInterval(8 * 3600)
        store.toggleCompletion(for: habit, on: morning)
        #expect(try allLogs(context).count == 1)
        #expect(habit.isCompleted(on: morning))

        // Toggling again the same calendar day (different time) removes the
        // single log rather than creating a duplicate.
        let evening = base.addingTimeInterval(20 * 3600)
        store.toggleCompletion(for: habit, on: evening)
        #expect(try allLogs(context).isEmpty)
        #expect(!habit.isCompleted(on: morning))
    }

    // MARK: - Count logging

    @Test func incrementThenSetCountCrossesTarget() throws {
        let container = try makeContainer()
        let context = container.mainContext
        let store = HabitStore(modelContext: context)

        let habit = Habit(name: "Pushups", kind: .count, dailyTarget: 3)
        store.create(habit)
        let day = Date()

        store.increment(habit, on: day, by: 1)
        store.increment(habit, on: day, by: 1)
        #expect(habit.dayCount(on: day) == 2)
        #expect(!habit.isCompleted(on: day))
        #expect(try allLogs(context).count == 1) // single upserted log

        store.setCount(habit, on: day, to: 3)
        #expect(habit.dayCount(on: day) == 3)
        #expect(habit.isCompleted(on: day))
        #expect(try allLogs(context).count == 1)
    }

    @Test func countClampsAtZeroAndDeletesLog() throws {
        let container = try makeContainer()
        let context = container.mainContext
        let store = HabitStore(modelContext: context)

        let habit = Habit(name: "Glasses", kind: .count, dailyTarget: 2)
        store.create(habit)
        let day = Date()

        store.increment(habit, on: day, by: 1)
        #expect(try allLogs(context).count == 1)

        // Going below zero clamps to 0 and removes the day's log.
        store.increment(habit, on: day, by: -5)
        #expect(habit.dayCount(on: day) == 0)
        #expect(try allLogs(context).isEmpty)

        // setCount to a negative value also clamps to 0 (no log created).
        store.setCount(habit, on: day, to: -3)
        #expect(try allLogs(context).isEmpty)
    }

    // MARK: - Range queries

    @Test func logsInRangeFiltersByDay() throws {
        let container = try makeContainer()
        let store = HabitStore(modelContext: container.mainContext)
        let calendar = Calendar.current

        let habit = Habit(name: "Walk", kind: .binary)
        store.create(habit)

        let today = calendar.startOfDay(for: Date())
        guard
            let yesterday = calendar.date(byAdding: .day, value: -1, to: today),
            let tomorrow = calendar.date(byAdding: .day, value: 1, to: today)
        else {
            Issue.record("date math failed")
            return
        }

        store.toggleCompletion(for: habit, on: yesterday)
        store.toggleCompletion(for: habit, on: today)

        let inRange = store.logs(for: habit, in: yesterday...today)
        #expect(inRange.count == 2)

        let narrow = store.logs(for: habit, in: today...tomorrow)
        #expect(narrow.count == 1)
    }
}
