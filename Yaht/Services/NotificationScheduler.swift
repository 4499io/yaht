import Foundation
import OSLog
import UserNotifications

/// Concrete `NotificationScheduling` backed by `UNUserNotificationCenter`.
///
/// Scheduling reads model state (habit + reminders) and therefore stays on the
/// app's default MainActor isolation; the notification-center calls are awaited.
/// Pure identifier/scope helpers live in `NotificationScheduler+Identifiers`.
final class NotificationScheduler: NotificationScheduling {
    static let shared = NotificationScheduler()

    private let logger = Logger(subsystem: "io.yaht.Yaht", category: "notifications")

    private init() {}

    private var center: UNUserNotificationCenter { .current() }

    // MARK: Authorization

    func requestAuthorization() async -> Bool {
        do {
            return try await center.requestAuthorization(options: [.alert, .sound, .badge])
        } catch {
            logger.error("Authorization request failed: \(error.localizedDescription, privacy: .public)")
            return false
        }
    }

    // MARK: Scheduling

    func reschedule(for habit: Habit) async {
        // Clear any stale requests for this habit first so we never duplicate.
        await cancel(forHabitID: habit.id)

        let reminders = (habit.reminders ?? []).filter(\.isEnabled)
        guard !reminders.isEmpty else { return }

        let habitID = habit.id
        let title = "\(habit.emoji) \(habit.name)"
        let sound: UNNotificationSound = habit.soundName
            .map { UNNotificationSound(named: UNNotificationSoundName($0)) } ?? .default

        // Stay under the system's pending-request budget (shared across habits).
        let alreadyPending = await center.pendingNotificationRequests().count
        var remaining = Self.pendingBudget - alreadyPending

        for reminder in reminders {
            let hour = reminder.hour
            let minute = reminder.minute
            let reminderID = reminder.id

            for weekday in Self.weekdays(for: reminder.reminderScope) {
                guard remaining > 0 else {
                    logger.notice("Pending-request budget reached; skipping remaining reminders for habit \(habitID.uuidString, privacy: .public).")
                    return
                }

                var components = DateComponents()
                components.hour = hour
                components.minute = minute
                if let weekday { components.weekday = weekday }

                let content = UNMutableNotificationContent()
                content.title = title
                content.sound = sound

                let trigger = UNCalendarNotificationTrigger(dateMatching: components, repeats: true)
                let identifier = Self.identifier(
                    habitID: habitID,
                    reminderID: reminderID,
                    weekday: weekday
                )
                let request = UNNotificationRequest(
                    identifier: identifier,
                    content: content,
                    trigger: trigger
                )

                do {
                    try await center.add(request)
                    remaining -= 1
                } catch {
                    logger.error("Failed to add request \(identifier, privacy: .public): \(error.localizedDescription, privacy: .public)")
                }
            }
        }
    }

    func cancel(forHabitID id: UUID) async {
        let prefix = Self.identifierPrefix(forHabitID: id)
        let pending = await center.pendingNotificationRequests()
        let identifiers = pending.map(\.identifier).filter { $0.hasPrefix(prefix) }
        guard !identifiers.isEmpty else { return }
        center.removePendingNotificationRequests(withIdentifiers: identifiers)
    }

    func rescheduleAll(_ habits: [Habit]) async {
        for habit in habits {
            await reschedule(for: habit)
        }
    }
}
