import SwiftData
import SwiftUI

/// Isolated, in-memory data for inspecting real screens in Xcode previews.
@MainActor
struct PreviewHabits {
    let container: ModelContainer
    let store: HabitStore
    let habits: [Habit]

    init(populated: Bool = true) throws {
        let schema = Schema(versionedSchema: SchemaV1.self)
        container = try ModelContainer(
            for: schema,
            configurations: [ModelConfiguration(schema: schema, isStoredInMemoryOnly: true, cloudKitDatabase: .none)]
        )
        store = HabitStore(modelContext: container.mainContext)
        guard populated else { habits = []; return }

        let calendar = Calendar.current
        let today = calendar.startOfDay(for: Date())
        let created = calendar.date(byAdding: .day, value: -42, to: today) ?? today
        habits = [
            Habit(name: "Drink water", emoji: "💧", colorHex: "83A598", createdAt: created,
                  sortOrder: 0, kind: .count, dailyTarget: 8, unit: "glasses"),
            Habit(name: "Read a chapter before bed", emoji: "📖", colorHex: "FE8019", createdAt: created, sortOrder: 1),
            Habit(name: "Take a walk outside", emoji: "🚶", colorHex: "B16286", createdAt: created, sortOrder: 2),
        ]
        for (index, habit) in habits.enumerated() {
            habit.logs = (0..<42).compactMap { offset in
                guard (offset + index) % 4 != 0,
                      let date = calendar.date(byAdding: .day, value: -offset, to: today) else { return nil }
                return HabitLog(day: date, count: habit.habitKind == .count ? (offset == 0 ? 3 : 8) : 1)
            }
            store.create(habit)
        }
    }
}
