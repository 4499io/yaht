import Foundation
import SwiftData
import Testing
@testable import Yaht

/// A store written with schema version 1 opens with the current schema and
/// keeps its data.
@MainActor
struct SchemaMigrationTests {
    @Test func versionOneStoreMigratesAndKeepsItsData() throws {
        let directory = FileManager.default.temporaryDirectory
            .appendingPathComponent(UUID().uuidString, isDirectory: true)
        try FileManager.default.createDirectory(at: directory, withIntermediateDirectories: true)
        defer { try? FileManager.default.removeItem(at: directory) }
        let url = directory.appendingPathComponent("Yaht.sqlite")
        let habitID = UUID()
        let day = Calendar.current.startOfDay(for: Date())

        // Release containers and contexts before reopening the same file.
        try autoreleasepool {
            let schema = Schema(versionedSchema: SchemaV1.self)
            let container = try ModelContainer(
                for: schema,
                configurations: [ModelConfiguration(schema: schema, url: url, cloudKitDatabase: .none)]
            )
            let habit = SchemaV1.Habit()
            habit.id = habitID
            habit.name = "Read"
            habit.colorHex = "FABD2F"
            let log = SchemaV1.HabitLog()
            log.day = day
            log.count = 1
            log.habit = habit
            container.mainContext.insert(habit)
            container.mainContext.insert(log)
            try container.mainContext.save()
        }

        try autoreleasepool {
            let schema = Schema(versionedSchema: CurrentSchema.self)
            let container = try ModelContainer(
                for: schema,
                migrationPlan: AppMigrationPlan.self,
                configurations: [ModelConfiguration(schema: schema, url: url, cloudKitDatabase: .none)]
            )
            let habits = try container.mainContext.fetch(FetchDescriptor<Habit>())
            let habit = try #require(habits.first)
            #expect(habits.count == 1)
            #expect(habit.id == habitID)
            #expect(habit.name == "Read")
            #expect(habit.isCompleted(on: day))
            #expect((habit.pauses ?? []).isEmpty)

            let pause = HabitPause(start: day, end: day, habit: habit)
            container.mainContext.insert(pause)
            try container.mainContext.save()
            #expect(habit.isPaused(on: day))
        }
    }
}
