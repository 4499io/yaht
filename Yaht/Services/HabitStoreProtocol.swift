import Foundation

/// Abstraction over the SwiftData-backed habit persistence layer. Kept as a
/// protocol so views/view-models can depend on a seam that is easy to fake in
/// tests. All access is main-actor isolated because it touches the UI-facing
/// `ModelContext`.
@MainActor
protocol HabitStoreProtocol {
    /// Non-archived habits ordered by `sortOrder` (ascending), then `createdAt`.
    func allActiveHabits() -> [Habit]

    /// Insert a new habit and persist.
    func create(_ habit: Habit)

    /// Persist pending changes to an existing habit (just saves the context).
    func update(_ habit: Habit)

    /// Permanently remove a habit; cascade deletes its logs and reminders.
    func delete(_ habit: Habit)

    /// Soft-delete: mark the habit archived so it drops out of active lists.
    func archive(_ habit: Habit)

    /// Persist a new ordering by rewriting each habit's `sortOrder`.
    func reorder(_ habits: [Habit])

    /// Logs for a habit whose `day` falls inside the inclusive `range`.
    func logs(for habit: Habit, in range: ClosedRange<Date>) -> [HabitLog]

    /// Binary habits: create today's log if absent, otherwise remove it.
    func toggleCompletion(for habit: Habit, on day: Date)

    /// Count habits: upsert the day's log, clamping the new tally to >= 0.
    func increment(_ habit: Habit, on day: Date, by delta: Int)

    /// Count habits: upsert the day's log to an exact value, clamped to >= 0.
    func setCount(_ habit: Habit, on day: Date, to value: Int)
}
