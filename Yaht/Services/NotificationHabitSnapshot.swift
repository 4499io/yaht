import Foundation

/// Value snapshots are captured before the scheduler suspends. No SwiftData
/// model or relationship is read while authorization or scheduling is awaited.
struct NotificationHabitSnapshot: Hashable, Sendable {
    struct ReminderSnapshot: Hashable, Sendable {
        let id: UUID
        let hour: Int
        let minute: Int
        let scope: ReminderScope
        let repeatsHourly: Bool
    }

    let id: UUID
    let title: String
    let soundName: String?
    let isArchived: Bool
    /// Paused today: reminders are held back until the pause ends.
    let isPaused: Bool
    /// Calendar weekdays (1 = Sunday … 7 = Saturday) a "some days" habit is
    /// scheduled on; its reminders fire only then. `nil` for other schedules.
    let scheduledWeekdays: [Int]?
    let reminders: [ReminderSnapshot]
    /// Start of today and tomorrow when the habit is due and still open:
    /// the days hourly nudges may fire on. Checking the habit off drops today.
    let nudgeDays: [Date]

    @MainActor
    init(_ habit: Habit, now: Date = Date(), calendar: Calendar = .current) {
        id = habit.id
        title = "\(habit.emoji) \(habit.name)"
        soundName = habit.soundName
        isArchived = habit.isArchived
        isPaused = habit.isPaused(on: now, calendar: calendar)
        scheduledWeekdays = habit.schedule == .specificWeekdays
            ? (1...7).filter { habit.scheduleDaysMask & (1 << ($0 - 1)) != 0 }
            : nil
        reminders = isPaused ? [] : (habit.reminders ?? []).filter(\.isEnabled).map {
            ReminderSnapshot(
                id: $0.id,
                hour: $0.hour,
                minute: $0.minute,
                scope: $0.reminderScope,
                repeatsHourly: $0.repeatsHourly
            )
        }.sorted { $0.id.uuidString < $1.id.uuidString }
        let today = calendar.startOfDay(for: now)
        nudgeDays = reminders.contains(where: \.repeatsHourly)
            ? [0, 1].compactMap { calendar.date(byAdding: .day, value: $0, to: today) }.filter {
                habit.isDue(on: $0, calendar: calendar) && !habit.isCompleted(on: $0, calendar: calendar)
            }
            : []
    }
}
