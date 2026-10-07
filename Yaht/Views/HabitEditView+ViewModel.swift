import Foundation
import SwiftData
import SwiftUI

/// A plain, editable copy of a ``Reminder`` used while the edit sheet is open.
/// Kept as a value type so the sheet never mutates persisted model objects
/// until the user taps Save.
struct ReminderDraft: Identifiable, Hashable {
    var id: UUID
    /// Only the hour/minute components are meaningful; the date part is ignored.
    var time: Date
    var scope: ReminderScope
    var isEnabled: Bool
    var repeatsHourly: Bool

    init(
        id: UUID = UUID(),
        time: Date,
        scope: ReminderScope = .everyDay,
        isEnabled: Bool = true,
        repeatsHourly: Bool = false
    ) {
        self.id = id
        self.time = time
        self.scope = scope
        self.isEnabled = isEnabled
        self.repeatsHourly = repeatsHourly
    }

    /// Snapshot an existing reminder into an editable draft.
    init(_ reminder: Reminder) {
        self.id = reminder.id
        self.time = ReminderDraft.date(hour: reminder.hour, minute: reminder.minute)
        self.scope = reminder.reminderScope
        self.isEnabled = reminder.isEnabled
        self.repeatsHourly = reminder.repeatsHourly
    }

    var hour: Int { Calendar.current.component(.hour, from: time) }
    var minute: Int { Calendar.current.component(.minute, from: time) }

    /// A `Date` today at the given hour/minute (used to seed the `DatePicker`).
    static func date(hour: Int, minute: Int) -> Date {
        var components = Calendar.current.dateComponents([.year, .month, .day], from: Date())
        components.hour = hour
        components.minute = minute
        return Calendar.current.date(from: components) ?? Date()
    }
}

/// Holds the editable state for the add/edit habit sheet. Plain value fields are
/// mutated freely while the sheet is open; nothing touches SwiftData until
/// ``commit(store:modelContext:)`` runs on Save.
@Observable
final class HabitEditViewModel {
    /// The habit being edited, or `nil` when creating a new one.
    let existingHabit: Habit?

    var name: String
    var emoji: String {
        didSet {
            // Keep only the most-recently typed grapheme cluster.
            if emoji.count > 1 { emoji = String(emoji.suffix(1)) }
        }
    }
    var colorHex: String
    var kind: HabitKind
    var dailyTarget: Int
    var unit: String
    var scheduleKind: ScheduleKind
    var scheduleDaysMask: Int
    var intervalDays: Int
    var weeklyTarget: Int
    var reminders: [ReminderDraft]

    var isEditing: Bool { existingHabit != nil }

    var trimmedName: String {
        name.trimmingCharacters(in: .whitespacesAndNewlines)
    }

    var canSave: Bool { !trimmedName.isEmpty }

    /// The currently chosen habit color, resolved from ``colorHex``.
    var selectedColor: Color { Color(hex: colorHex) ?? .accentColor }

    init(habit: Habit?) {
        existingHabit = habit
        let fallbackHex = Theme.defaultHabitHex

        if let habit {
            name = habit.name
            emoji = habit.emoji
            colorHex = habit.colorHex.isEmpty
                ? fallbackHex
                : (Theme.migratedHex(for: habit.colorHex) ?? habit.colorHex)
            kind = habit.habitKind
            dailyTarget = max(1, habit.dailyTarget)
            unit = habit.unit ?? ""
            scheduleKind = habit.schedule
            scheduleDaysMask = habit.scheduleDaysMask
            intervalDays = max(1, habit.intervalDays)
            weeklyTarget = max(1, habit.weeklyTarget)
            reminders = (habit.reminders ?? [])
                .sorted { ($0.hour, $0.minute) < ($1.hour, $1.minute) }
                .map(ReminderDraft.init)
        } else {
            name = ""
            emoji = "✅"
            colorHex = fallbackHex
            kind = .binary
            dailyTarget = 1
            unit = ""
            scheduleKind = .daily
            scheduleDaysMask = 0
            intervalDays = 2
            weeklyTarget = 3
            reminders = []
        }
    }

    // MARK: - Weekday mask helpers

    /// Whether the given Calendar weekday (1 = Sunday ... 7 = Saturday) is set.
    func isWeekdaySelected(_ weekday: Int) -> Bool {
        (scheduleDaysMask & (1 << (weekday - 1))) != 0
    }

    /// Toggle a Calendar weekday (1...7) in the schedule mask.
    func toggleWeekday(_ weekday: Int) {
        let bit = 1 << (weekday - 1)
        if scheduleDaysMask & bit != 0 {
            scheduleDaysMask &= ~bit
        } else {
            scheduleDaysMask |= bit
        }
    }

    // MARK: - Reminders

    func addReminder() {
        reminders.append(ReminderDraft(time: ReminderDraft.date(hour: 9, minute: 0)))
    }

    func removeReminder(id: ReminderDraft.ID) {
        reminders.removeAll { $0.id == id }
    }

    // MARK: - Commit

    /// Build (or update) the ``Habit`` from the current fields and persist it.
    /// Returns the committed habit so the caller can reschedule notifications.
    func commit(store: HabitStore, modelContext: ModelContext) -> Habit {
        let habit = existingHabit ?? Habit()
        let isNew = existingHabit == nil

        habit.name = trimmedName
        habit.emoji = emoji.isEmpty ? "✅" : emoji
        habit.colorHex = colorHex
        habit.habitKind = kind
        habit.dailyTarget = kind == .count ? max(1, dailyTarget) : 1

        let trimmedUnit = unit.trimmingCharacters(in: .whitespacesAndNewlines)
        habit.unit = (kind == .count && !trimmedUnit.isEmpty) ? trimmedUnit : nil

        habit.schedule = scheduleKind
        habit.scheduleDaysMask = scheduleKind == .specificWeekdays ? scheduleDaysMask : 0
        habit.intervalDays = scheduleKind == .everyNDays ? max(1, intervalDays) : 1
        habit.weeklyTarget = scheduleKind == .timesPerWeek ? max(1, weeklyTarget) : 0

        reconcileReminders(on: habit, modelContext: modelContext)

        if isNew {
            store.create(habit)
        } else {
            store.update(habit)
        }
        return habit
    }

    /// Diff the draft reminders against the persisted ones: update matches,
    /// insert new ones, delete removed ones.
    private func reconcileReminders(on habit: Habit, modelContext: ModelContext) {
        let existing = habit.reminders ?? []
        var kept: [Reminder] = []

        for draft in reminders {
            if let match = existing.first(where: { $0.id == draft.id }) {
                match.hour = draft.hour
                match.minute = draft.minute
                match.reminderScope = draft.scope
                match.isEnabled = draft.isEnabled
                match.repeatsHourly = draft.repeatsHourly
                kept.append(match)
            } else {
                let reminder = Reminder(
                    id: draft.id,
                    hour: draft.hour,
                    minute: draft.minute,
                    scope: draft.scope,
                    isEnabled: draft.isEnabled,
                    repeatsHourly: draft.repeatsHourly,
                    habit: habit
                )
                modelContext.insert(reminder)
                kept.append(reminder)
            }
        }

        let keptIDs = Set(kept.map(\.id))
        for stale in existing where !keptIDs.contains(stale.id) {
            modelContext.delete(stale)
        }

        habit.reminders = kept
    }
}
