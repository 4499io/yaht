import Foundation

/// Abstraction over local-notification scheduling so view models and the app
/// can depend on a protocol (and be tested with fakes) rather than
/// `UNUserNotificationCenter` directly.
protocol NotificationScheduling: Sendable {
    /// Requests alert/sound/badge authorization. Returns `false` on denial or error.
    func requestAuthorization() async -> Bool

    /// Cancels the habit's pending requests, then schedules one repeating
    /// calendar trigger per enabled reminder (fanned out by scope).
    func reschedule(for habit: Habit) async

    /// Removes every pending request belonging to the given habit id.
    func cancel(forHabitID id: UUID) async

    /// Convenience: reschedules each habit in turn.
    func rescheduleAll(_ habits: [Habit]) async
}
