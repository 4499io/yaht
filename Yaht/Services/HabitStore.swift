import Foundation
import SwiftData

/// SwiftData-backed implementation of ``HabitStoreProtocol``.
///
/// Reads go through `FetchDescriptor`; every mutation ends with a `save()` in a
/// `do/catch` (never `try?`). Day-scoped writes enforce a single `HabitLog` per
/// `(habit, startOfDay)` via upsert. Days are normalized to the local
/// start-of-day. When a count reaches 0 the log is deleted (chosen convention),
/// so `dayCount` reports 0 without a stray zero-count row.
@Observable
@MainActor
final class HabitStore: HabitStoreProtocol {
    private let modelContext: ModelContext
    private let calendar: Calendar

    init(modelContext: ModelContext) {
        self.modelContext = modelContext
        self.calendar = .current
    }

    // MARK: - Queries

    func allActiveHabits() -> [Habit] {
        let descriptor = FetchDescriptor<Habit>(
            predicate: #Predicate { !$0.isArchived },
            sortBy: [
                SortDescriptor(\Habit.sortOrder, order: .forward),
                SortDescriptor(\Habit.createdAt, order: .forward)
            ]
        )
        do {
            return try modelContext.fetch(descriptor)
        } catch {
            assertionFailure("allActiveHabits fetch failed: \(error)")
            return []
        }
    }

    func logs(for habit: Habit, in range: ClosedRange<Date>) -> [HabitLog] {
        let habitID = habit.id
        let lower = range.lowerBound
        let upper = range.upperBound
        let descriptor = FetchDescriptor<HabitLog>(
            predicate: #Predicate { log in
                log.habit?.id == habitID && log.day >= lower && log.day <= upper
            },
            sortBy: [SortDescriptor(\HabitLog.day, order: .forward)]
        )
        do {
            return try modelContext.fetch(descriptor)
        } catch {
            assertionFailure("logs(for:in:) fetch failed: \(error)")
            return []
        }
    }

    // MARK: - Habit mutations

    func create(_ habit: Habit) {
        modelContext.insert(habit)
        persist()
    }

    func update(_ habit: Habit) {
        persist()
    }

    func delete(_ habit: Habit) {
        modelContext.delete(habit)
        persist()
    }

    func archive(_ habit: Habit) {
        habit.isArchived = true
        persist()
    }

    func reorder(_ habits: [Habit]) {
        for (index, habit) in habits.enumerated() {
            habit.sortOrder = index
        }
        persist()
    }

    // MARK: - Day-scoped log mutations

    func toggleCompletion(for habit: Habit, on day: Date) {
        let start = calendar.startOfDay(for: day)
        if let existing = existingLog(for: habit, onStartOfDay: start) {
            modelContext.delete(existing)
        } else {
            insertLog(for: habit, onStartOfDay: start, count: 1)
        }
        persist()
    }

    func increment(_ habit: Habit, on day: Date, by delta: Int) {
        let start = calendar.startOfDay(for: day)
        let current = existingLog(for: habit, onStartOfDay: start)?.count ?? 0
        apply(count: max(0, current + delta), for: habit, onStartOfDay: start)
    }

    func setCount(_ habit: Habit, on day: Date, to value: Int) {
        let start = calendar.startOfDay(for: day)
        apply(count: max(0, value), for: habit, onStartOfDay: start)
    }

    // MARK: - Helpers

    /// Upsert the tally for a day. A resulting count of 0 deletes the log.
    private func apply(count: Int, for habit: Habit, onStartOfDay start: Date) {
        let existing = existingLog(for: habit, onStartOfDay: start)
        if count <= 0 {
            if let existing {
                modelContext.delete(existing)
            }
        } else if let existing {
            existing.count = count
            existing.updatedAt = Date()
        } else {
            insertLog(for: habit, onStartOfDay: start, count: count)
        }
        persist()
    }

    /// The single log for `(habit, start)`, if any. `start` must already be a
    /// start-of-day value.
    private func existingLog(for habit: Habit, onStartOfDay start: Date) -> HabitLog? {
        let habitID = habit.id
        guard let end = calendar.date(byAdding: .day, value: 1, to: start) else {
            return nil
        }
        var descriptor = FetchDescriptor<HabitLog>(
            predicate: #Predicate { log in
                log.habit?.id == habitID && log.day >= start && log.day < end
            },
            sortBy: [SortDescriptor(\HabitLog.day, order: .forward)]
        )
        descriptor.fetchLimit = 1
        do {
            return try modelContext.fetch(descriptor).first
        } catch {
            assertionFailure("existingLog fetch failed: \(error)")
            return nil
        }
    }

    private func insertLog(for habit: Habit, onStartOfDay start: Date, count: Int) {
        let log = HabitLog(day: start, count: count, updatedAt: Date(), habit: habit)
        modelContext.insert(log)
    }

    /// Persist pending changes; surfaces failures in debug without force-trying.
    private func persist() {
        guard modelContext.hasChanges else { return }
        do {
            try modelContext.save()
        } catch {
            assertionFailure("HabitStore save failed: \(error)")
        }
    }
}
