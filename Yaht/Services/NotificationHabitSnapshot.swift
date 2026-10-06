import Foundation

/// Value snapshots are captured before the scheduler suspends. No SwiftData
/// model or relationship is read while authorization or scheduling is awaited.
struct NotificationHabitSnapshot: Hashable, Sendable {
    struct ReminderSnapshot: Hashable, Sendable {
        let id: UUID
        let hour: Int
        let minute: Int
        let scope: ReminderScope
    }

    let id: UUID
    let title: String
    let soundName: String?
    let isArchived: Bool
    let reminders: [ReminderSnapshot]

    @MainActor
    init(_ habit: Habit) {
        id = habit.id
        title = "\(habit.emoji) \(habit.name)"
        soundName = habit.soundName
        isArchived = habit.isArchived
        reminders = (habit.reminders ?? []).filter(\.isEnabled).map {
            ReminderSnapshot(id: $0.id, hour: $0.hour, minute: $0.minute, scope: $0.reminderScope)
        }.sorted { $0.id.uuidString < $1.id.uuidString }
    }
}
