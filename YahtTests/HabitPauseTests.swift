import Foundation
import SwiftData
import Testing
@testable import Yaht

/// Pausing and resuming through the store, and the snapshot that holds back
/// reminders, against an in-memory container.
@MainActor
struct HabitPauseTests {
    private let calendar = Calendar.current

    private func makeStore() throws -> (ModelContainer, HabitStore) {
        let schema = Schema(versionedSchema: SchemaV1.self)
        let container = try ModelContainer(
            for: schema,
            configurations: [ModelConfiguration(schema: schema, isStoredInMemoryOnly: true)]
        )
        return (container, HabitStore(modelContext: container.mainContext))
    }

    private func day(_ offset: Int, from base: Date = Date()) -> Date {
        calendar.date(byAdding: .day, value: offset, to: calendar.startOfDay(for: base)) ?? base
    }

    @Test func pauseCoversItsDaysAndIsCappedAt90() throws {
        let (container, store) = try makeStore()
        let habit = Habit(name: "Gym")
        store.create(habit)

        store.pause(habit, from: day(0), through: day(200))

        let pauses = try container.mainContext.fetch(FetchDescriptor<HabitPause>())
        #expect(pauses.count == 1)
        #expect(habit.isPaused(on: day(0)))
        #expect(habit.isPaused(on: day(89)))
        #expect(!habit.isPaused(on: day(90)))
        #expect(!habit.isDue(on: day(3)))
    }

    @Test func resumeEndsARunningPauseYesterdayAndDropsFutureOnes() throws {
        let (container, store) = try makeStore()
        let habit = Habit(name: "Read")
        store.create(habit)
        store.pause(habit, from: day(-3), through: day(5))
        store.pause(habit, from: day(10), through: day(12))

        store.resume(habit, today: day(0))

        let pauses = try container.mainContext.fetch(FetchDescriptor<HabitPause>())
        #expect(pauses.count == 1)
        #expect(habit.isPaused(on: day(-1)))
        #expect(!habit.isPaused(on: day(0)))
        #expect(!habit.isPaused(on: day(11)))
    }

    @Test func deletingAHabitDeletesItsPauses() throws {
        let (container, store) = try makeStore()
        let habit = Habit(name: "Walk")
        store.create(habit)
        store.pause(habit, from: day(0), through: day(2))

        store.delete(habit)

        #expect(try container.mainContext.fetch(FetchDescriptor<HabitPause>()).isEmpty)
    }

    @Test func pausedHabitsScheduleNoReminders() throws {
        let (container, store) = try makeStore()
        let habit = Habit(name: "Meds")
        store.create(habit)
        let reminder = Reminder(hour: 8, minute: 0, habit: habit)
        container.mainContext.insert(reminder)
        habit.reminders = [reminder]
        #expect(NotificationHabitSnapshot(habit).reminders.count == 1)

        store.pause(habit, from: day(0), through: day(0))

        let snapshot = NotificationHabitSnapshot(habit)
        #expect(snapshot.isPaused)
        #expect(snapshot.reminders.isEmpty)
    }
}
