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
    private var unconfirmedRemovalIDs: Set<String> = []
    private var busy = false
    private var waiters: [CheckedContinuation<Void, Never>] = []

    init(center: any NotificationCenterClient) {
        self.center = center
    }

    func requestAuthorization() async -> Bool {
        await acquire()
        defer { release() }
        guard !Task.isCancelled else { return false }
        let status = await center.authorizationStatus()
        guard !Task.isCancelled else { return false }
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
        let snapshots = habits.map { NotificationHabitSnapshot($0) }
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
        guard !Task.isCancelled else { return }
        // A timed-out removal can still finish later. Never reuse its IDs until
        // their absence has been observed, even in a subsequent transaction.
        if !unconfirmedRemovalIDs.isEmpty {
            guard await center.waitUntilRemoved(unconfirmedRemovalIDs) else { return }
            unconfirmedRemovalIDs.removeAll()
        }
        guard !Task.isCancelled else { return }
        let status = await center.authorizationStatus()
        guard !Task.isCancelled else { return }
        let pending = await center.pendingRequests()
        guard !Task.isCancelled else { return }
        let retainedCount = pending.filter { !scope.includes($0.identifier) }.count
        let capacity = max(0, Self.pendingBudget - retainedCount)
        let desired = Self.canSchedule(status) ? requests(for: snapshots) : []
        let keptIDs = Set(desired.prefix(capacity).map(\.identifier))
        let scopedIDs = Set(pending.filter { scope.includes($0.identifier) }.map(\.identifier))
        let staleIDs = scopedIDs.subtracting(keptIDs)
        if !staleIDs.isEmpty {
            unconfirmedRemovalIDs.formUnion(staleIDs)
            guard await center.removePendingRequests(withIdentifiers: Array(staleIDs)) else {
                logger.error("Notification removal did not finish; deferring scheduling.")
                return
            }
            unconfirmedRemovalIDs.subtract(staleIDs)
        }
        guard !Task.isCancelled else { return }
        var occupiedIDs = scopedIDs.intersection(keptIDs)
        for request in desired {
            guard !Task.isCancelled else { return }
            // Existing IDs are replaced directly by add(), never remove/add.
            // Failed replacements still occupy a slot; failed new additions do
            // not consume capacity, allowing the next reminder to use it.
            if !occupiedIDs.contains(request.identifier) && occupiedIDs.count >= capacity { continue }
            do {
                try await center.add(request)
                occupiedIDs.insert(request.identifier)
            } catch {
                logger.error("Failed to add notification: \(error.localizedDescription, privacy: .public)")
            }
        }
    }

    /// Weekly reminders for every habit come first, then hourly nudges
    /// earliest first, so a full budget drops the furthest nudges.
    private func requests(for snapshots: [NotificationHabitSnapshot]) -> [UNNotificationRequest] {
        let calendar = Calendar.current
        let now = Date()
        var result: [UNNotificationRequest] = []
        var nudges: [(date: Date, request: UNNotificationRequest)] = []
        for habit in snapshots.sorted(by: { $0.id.uuidString < $1.id.uuidString }) where !habit.isArchived {
            for reminder in habit.reminders {
                let weekdays = Self.reminderWeekdays(scope: reminder.scope, habitWeekdays: habit.scheduledWeekdays)
                for weekday in weekdays {
                    var components = DateComponents()
                    components.hour = reminder.hour
                    components.minute = reminder.minute
                    if let weekday { components.weekday = weekday }
                    result.append(UNNotificationRequest(
                        identifier: Self.identifier(habitID: habit.id, reminderID: reminder.id, weekday: weekday),
                        content: makeContent(for: habit),
                        trigger: UNCalendarNotificationTrigger(dateMatching: components, repeats: true)
                    ))
                }
                guard reminder.repeatsHourly else { continue }
                let dates = Self.nudgeDates(
                    hour: reminder.hour,
                    minute: reminder.minute,
                    weekdays: weekdays,
                    days: habit.nudgeDays,
                    now: now,
                    calendar: calendar
                )
                for date in dates {
                    let content = makeContent(for: habit)
                    content.body = String(localized: "Still to do today.")
                    let components = calendar.dateComponents([.year, .month, .day, .hour, .minute], from: date)
                    nudges.append((date, UNNotificationRequest(
                        identifier: Self.nudgeIdentifier(habitID: habit.id, reminderID: reminder.id, date: date, calendar: calendar),
                        content: content,
                        trigger: UNCalendarNotificationTrigger(dateMatching: components, repeats: false)
                    )))
                }
            }
        }
        return result + nudges.sorted { $0.date < $1.date }.map(\.request)
    }

    private func makeContent(for habit: NotificationHabitSnapshot) -> UNMutableNotificationContent {
        let content = UNMutableNotificationContent()
        content.title = habit.title
        content.sound = habit.soundName.map {
            UNNotificationSound(named: UNNotificationSoundName($0))
        } ?? .default
        return content
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
