import Foundation
import OSLog
import UserNotifications

/// Serializes the entire read/remove/add transaction, including suspension
/// points. MainActor isolation alone would allow concurrent tasks to interleave.
@MainActor
final class NotificationScheduler: NotificationScheduling {
    static let shared = NotificationScheduler(center: SystemNotificationCenterClient())

    private let logger = Logger(subsystem: "io.yaht.Yaht", category: "notifications")
    private let center: any NotificationCenterClient
    private var busy = false
    private var waiters: [CheckedContinuation<Void, Never>] = []

    init(center: any NotificationCenterClient) {
        self.center = center
    }

    func requestAuthorization() async -> Bool {
        await acquire()
        defer { release() }
        let status = await center.authorizationStatus()
        guard status == .notDetermined else { return Self.canSchedule(status) }
        do {
            return try await center.requestAuthorization(options: [.alert, .sound, .badge])
        } catch {
            logger.error("Authorization request failed: \(error.localizedDescription, privacy: .public)")
            return false
        }
    }

    func reschedule(for habit: Habit) async {
        let snapshot = NotificationHabitSnapshot(habit)
        await replace(with: [snapshot], scope: .habit(snapshot.id))
    }

    func cancel(forHabitID id: UUID) async {
        await replace(with: [], scope: .habit(id))
    }

    /// Authoritative reconciliation also clears reminders for deleted or
    /// archived habits. Requests outside our identifier namespace are retained.
    func rescheduleAll(_ habits: [Habit]) async {
        let snapshots = habits.map(NotificationHabitSnapshot.init)
        await reconcile(snapshots)
    }

    func reconcile(_ snapshots: [NotificationHabitSnapshot]) async {
        await replace(with: snapshots, scope: .all)
    }

    private enum Scope {
        case all
        case habit(UUID)

        func includes(_ identifier: String) -> Bool {
            switch self {
            case .all: return identifier.hasPrefix("habit-")
            case let .habit(id):
                return identifier.hasPrefix(NotificationScheduler.identifierPrefix(forHabitID: id))
            }
        }
    }

    private func replace(with snapshots: [NotificationHabitSnapshot], scope: Scope) async {
        await acquire()
        defer { release() }
        let status = await center.authorizationStatus()
        let pending = await center.pendingRequests()
        let stale = pending.filter { scope.includes($0.identifier) }.map(\.identifier)
        if !stale.isEmpty { center.removePendingRequests(withIdentifiers: stale) }
        guard Self.canSchedule(status) else { return }

        let retainedCount = pending.filter { !scope.includes($0.identifier) }.count
        var remaining = max(0, Self.pendingBudget - retainedCount)
        // Stable ordering gives the same habits priority on every reconciliation.
        for habit in snapshots.sorted(by: { $0.id.uuidString < $1.id.uuidString }) where !habit.isArchived {
            for reminder in habit.reminders {
                for weekday in Self.weekdays(for: reminder.scope) {
                    guard remaining > 0 else {
                        logger.notice("Pending-request budget reached; skipping remaining reminders.")
                        return
                    }
                    var components = DateComponents()
                    components.hour = reminder.hour
                    components.minute = reminder.minute
                    if let weekday { components.weekday = weekday }
                    let content = UNMutableNotificationContent()
                    content.title = habit.title
                    content.sound = habit.soundName.map {
                        UNNotificationSound(named: UNNotificationSoundName($0))
                    } ?? .default
                    let request = UNNotificationRequest(
                        identifier: Self.identifier(habitID: habit.id, reminderID: reminder.id, weekday: weekday),
                        content: content,
                        trigger: UNCalendarNotificationTrigger(dateMatching: components, repeats: true)
                    )
                    do {
                        try await center.add(request)
                        remaining -= 1
                    } catch {
                        logger.error("Failed to add notification: \(error.localizedDescription, privacy: .public)")
                    }
                }
            }
        }
    }

    private static func canSchedule(_ status: UNAuthorizationStatus) -> Bool {
        status == .authorized || status == .provisional || status == .ephemeral
    }

    private func acquire() async {
        if busy {
            await withCheckedContinuation { waiters.append($0) }
        } else {
            busy = true
        }
    }

    private func release() {
        if waiters.isEmpty {
            busy = false
        } else {
            // Ownership transfers to the oldest waiter; it remains held.
            waiters.removeFirst().resume()
        }
    }
}
